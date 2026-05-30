import Foundation

enum GeminiError: LocalizedError {
    case invalidKey
    case rateLimited
    case quotaExhausted
    case badResponse(Int)
    case noContent
    case apiError(Int, String)   // raw code + Gemini's actual message for diagnosis

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return String(localized: "gemini_error_invalid_key")
        case .rateLimited:
            return String(localized: "gemini_error_rate_limited")
        case .quotaExhausted:
            return String(localized: "gemini_error_quota_exhausted")
        case .badResponse(let code):
            return String(localized: "gemini_error_bad_response") + " (\(code))"
        case .noContent:
            return String(localized: "gemini_error_no_content")
        case .apiError(let code, let msg):
            if code == 429 || msg.lowercased().contains("quota") || msg.lowercased().contains("limit: 0") {
                return String(localized: "gemini_error_quota_exhausted")
            }
            return "Gemini \(code): \(msg)"
        }
    }
}

struct GeminiService {
    static let keychainKey = "beefocus_gemini_api_key"

    // All available models (first = default)
    static let models = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-2.0-flash-lite", "gemini-1.5-flash-8b"]

    // Ordered list starting with the user's selected model, rest as fallback
    private static var orderedModels: [String] {
        let selected = UserDefaults.standard.string(forKey: "geminiSelectedModel") ?? models[0]
        var list = models
        if let idx = list.firstIndex(of: selected), idx != 0 {
            list.remove(at: idx)
            list.insert(selected, at: 0)
        }
        return list
    }

    // Returns an AsyncThrowingStream that yields partial text chunks as they arrive.
    // Starts with the user-selected model, falls back automatically on 429/404.
    static func stream(prompt: String, apiKey: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lastCode = 429
                var lastMessage = ""
                for model in orderedModels {
                    let result = await attemptStream(prompt: prompt, apiKey: apiKey, model: model, continuation: continuation)
                    switch result {
                    case .success:
                        return
                    case .tryNext(let code, let message):
                        lastCode = code
                        lastMessage = message
                        continue
                    case .failure(let error):
                        continuation.finish(throwing: error)
                        return
                    }
                }
                // All models failed — show the actual Gemini error message for diagnosis
                continuation.finish(throwing: GeminiError.apiError(lastCode, lastMessage))
            }
        }
    }

    private enum StreamResult {
        case success
        case tryNext(code: Int, message: String)  // skip this model, try next
        case failure(Error)
    }

    // Reads the actual Gemini error message via the non-streaming endpoint (JSON body is reliable there)
    private static func fetchErrorMessage(apiKey: String, model: String) async -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        let body: [String: Any] = ["contents": [["role": "user", "parts": [["text": "hi"]]]]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }

    private static func attemptStream(
        prompt: String, apiKey: String, model: String,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async -> StreamResult {
        let urlString = "https://generativelanguage.googleapis.com/v1/models/\(model):streamGenerateContent?key=\(apiKey)&alt=sse"
        guard let url = URL(string: urlString) else { return .failure(GeminiError.invalidKey) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.8, "maxOutputTokens": 500]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(GeminiError.noContent)
        }
        request.httpBody = bodyData

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                if http.statusCode == 404 { return .tryNext(code: 404, message: "model not found") }
                if http.statusCode == 401 || http.statusCode == 403 { return .failure(GeminiError.invalidKey) }
                if http.statusCode == 429 {
                    let msg = await fetchErrorMessage(apiKey: apiKey, model: model) ?? "quota or billing issue"
                    return .tryNext(code: 429, message: msg)
                }
                return .failure(GeminiError.apiError(http.statusCode, "HTTP \(http.statusCode)"))
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let content = candidates.first?["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String else { continue }
                continuation.yield(text)
            }
            continuation.finish()
            return .success
        } catch {
            return .failure(error)
        }
    }

    // Validate key — tries models until one responds 200 or 429 (key valid, just limited)
    static func validate(apiKey: String) async -> Bool {
        for model in orderedModels {
            let urlString = "https://generativelanguage.googleapis.com/v1/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            let body: [String: Any] = ["contents": [["role": "user", "parts": [["text": "Hi"]]]]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            guard let (_, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse else { continue }
            if http.statusCode == 200 || http.statusCode == 429 { return true }
            if http.statusCode == 400 || http.statusCode == 401 || http.statusCode == 403 { return false }
            // 404 = model not found, try next
        }
        return false
    }
}
