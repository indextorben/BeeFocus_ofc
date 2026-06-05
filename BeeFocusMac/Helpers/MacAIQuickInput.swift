import Foundation
import Security

// MARK: - Keychain (macOS-compatible copy)

enum MacKeychain {
    static func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Parsed result

struct MacAITaskResult {
    var title: String         = ""
    var description: String   = ""
    var date: Date?           = nil
    var priority: MacTodoPriority = .medium
    var reminderOffset: Int?  = nil
}

// MARK: - AI Quick Input Service

enum MacAIProvider: String, CaseIterable {
    case openai = "openai"
    case groq   = "groq"

    var label: String {
        switch self {
        case .openai: return "OpenAI"
        case .groq:   return "Groq (kostenlos)"
        }
    }

    var keychainKey: String {
        switch self {
        case .openai: return "beefocus_mac_openai_key"
        case .groq:   return "beefocus_mac_groq_key"
        }
    }

    var apiURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .groq:   return "https://api.groq.com/openai/v1/chat/completions"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .groq:   return "llama-3.3-70b-versatile"
        }
    }
}

enum MacAIQuickInputService {
    static func parse(input: String, provider: MacAIProvider) async throws -> MacAITaskResult {
        guard let apiKey = MacKeychain.load(for: provider.keychainKey), !apiKey.isEmpty else {
            throw MacAIError.noKey
        }

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "EEEE, d. MMMM yyyy"
        let todayStr = df.string(from: Date())

        let prompt = """
        Today is \(todayStr). Parse this task and reply ONLY in the exact format below — no extra text.

        Input: \(input)

        TITLE: <short task title>
        DESCRIPTION: <one sentence or empty>
        DATE: <YYYY-MM-DD or none>
        TIME: <HH:MM or none>
        PRIORITY: <high|medium|low>
        REMINDER: <-1|0|5|15|30|60|1440>
        """

        let body: [String: Any] = [
            "model": provider.defaultModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 200,
            "temperature": 0.2
        ]

        guard let url = URL(string: provider.apiURL),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw MacAIError.badRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MacAIError.httpError(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw MacAIError.parseError
        }

        return parseResponse(content)
    }

    private static func parseResponse(_ raw: String) -> MacAITaskResult {
        var result = MacAITaskResult()
        var dateStr = ""
        var timeStr = ""

        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("TITLE:")       { result.title       = after("TITLE:", in: t) }
            else if t.hasPrefix("DESCRIPTION:") { result.description = after("DESCRIPTION:", in: t) }
            else if t.hasPrefix("DATE:")   { dateStr = after("DATE:", in: t) }
            else if t.hasPrefix("TIME:")   { timeStr = after("TIME:", in: t) }
            else if t.hasPrefix("PRIORITY:") {
                switch after("PRIORITY:", in: t).lowercased() {
                case "high": result.priority = .high
                case "low":  result.priority = .low
                default:     result.priority = .medium
                }
            } else if t.hasPrefix("REMINDER:") {
                let val = Int(after("REMINDER:", in: t)) ?? -1
                if val >= 0 { result.reminderOffset = val }
            }
        }

        if dateStr != "none", !dateStr.isEmpty {
            let isoFmt = DateFormatter()
            isoFmt.dateFormat = "yyyy-MM-dd"
            if let base = isoFmt.date(from: dateStr) {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: base)
                if timeStr != "none", !timeStr.isEmpty {
                    let parts = timeStr.split(separator: ":").compactMap { Int($0) }
                    if parts.count == 2 { comps.hour = parts[0]; comps.minute = parts[1] }
                } else {
                    comps.hour = 9; comps.minute = 0
                }
                result.date = Calendar.current.date(from: comps)
            }
        }

        return result
    }

    private static func after(_ prefix: String, in line: String) -> String {
        line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Errors

enum MacAIError: LocalizedError {
    case noKey
    case badRequest
    case httpError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noKey:           return "Kein API-Key gesetzt. Bitte in den Einstellungen eintragen."
        case .badRequest:      return "Ungültige Anfrage."
        case .httpError(let c): return "API-Fehler (Status \(c))."
        case .parseError:      return "Antwort konnte nicht gelesen werden."
        }
    }
}
