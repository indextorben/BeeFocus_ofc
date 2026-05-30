import Foundation

enum OpenAIError: LocalizedError {
    case invalidKey
    case rateLimited
    case noCredits
    case badResponse(Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidKey:         return String(localized: "openai_error_invalid_key")
        case .rateLimited:        return String(localized: "gemini_error_rate_limited")
        case .noCredits:          return String(localized: "openai_error_no_credits")
        case .badResponse(let c): return String(localized: "gemini_error_bad_response") + " (\(c))"
        case .noContent:          return String(localized: "gemini_error_no_content")
        }
    }
}

struct OpenAIService {
    static let keychainKey = "beefocus_openai_api_key"
    static let models = ["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"]

    private static func parse429Error(data: Data) -> OpenAIError {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let code = error["code"] as? String,
           code == "insufficient_quota" {
            return .noCredits
        }
        return .rateLimited
    }

    static func stream(prompt: String, apiKey: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                    continuation.finish(throwing: OpenAIError.invalidKey); return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 30

                let body: [String: Any] = [
                    "model": model,
                    "messages": [["role": "user", "content": prompt]],
                    "stream": true,
                    "max_tokens": 500,
                    "temperature": 0.8
                ]
                guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: OpenAIError.noContent); return
                }
                request.httpBody = bodyData

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        switch http.statusCode {
                        case 401, 403:
                            continuation.finish(throwing: OpenAIError.invalidKey)
                        case 429:
                            // Collect body bytes to parse the error code
                            var bodyBytes = Data()
                            for try await byte in bytes {
                                bodyBytes.append(byte)
                                if bodyBytes.count > 4096 { break } // enough to parse the error
                            }
                            continuation.finish(throwing: parse429Error(data: bodyBytes))
                        default:
                            continuation.finish(throwing: OpenAIError.badResponse(http.statusCode))
                        }
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let text = delta["content"] as? String else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    static func validate(apiKey: String) async -> Bool {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        // 429 means key is valid but quota exceeded — still a valid key
        return http.statusCode == 200 || http.statusCode == 429
    }
}
