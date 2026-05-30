import Foundation

enum GroqError: LocalizedError {
    case invalidKey
    case rateLimited
    case badResponse(Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidKey:         return String(localized: "groq_error_invalid_key")
        case .rateLimited:        return String(localized: "groq_error_rate_limited")
        case .badResponse(let c): return String(localized: "gemini_error_bad_response") + " (\(c))"
        case .noContent:          return String(localized: "gemini_error_no_content")
        }
    }
}

struct GroqService {
    static let keychainKey  = "beefocus_groq_api_key"
    static let models       = ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "gemma2-9b-it", "mixtral-8x7b-32768"]
    private static let base = "https://api.groq.com/openai/v1"

    static func stream(prompt: String, apiKey: String, model: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let url = URL(string: "\(base)/chat/completions") else {
                    continuation.finish(throwing: GroqError.invalidKey); return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json",      forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)",      forHTTPHeaderField: "Authorization")
                request.timeoutInterval = 30

                let body: [String: Any] = [
                    "model": model,
                    "messages": [["role": "user", "content": prompt]],
                    "stream": true,
                    "max_tokens": 600,
                    "temperature": 0.8
                ]
                guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
                    continuation.finish(throwing: GroqError.noContent); return
                }
                request.httpBody = bodyData

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        switch http.statusCode {
                        case 401, 403: continuation.finish(throwing: GroqError.invalidKey)
                        case 429:      continuation.finish(throwing: GroqError.rateLimited)
                        default:       continuation.finish(throwing: GroqError.badResponse(http.statusCode))
                        }
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        guard let data    = payload.data(using: .utf8),
                              let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta   = choices.first?["delta"] as? [String: Any],
                              let text    = delta["content"] as? String else { continue }
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
        guard let url = URL(string: "\(base)/models") else { return false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200 || http.statusCode == 429
    }
}
