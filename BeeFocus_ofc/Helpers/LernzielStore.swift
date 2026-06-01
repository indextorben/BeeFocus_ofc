import SwiftUI

struct Lernziel: Identifiable, Codable {
    var id: UUID = UUID()
    var titel: String
    var beschreibung: String = ""
    var symbol: String = "book.fill"
    var farbName: String = "blau"
    var zielStunden: Double = 10.0
    var erstellt: Date = Date()
    var abgeschlossen: Bool = false
    var abgeschlossenAm: Date? = nil

    var farbe: Color {
        switch farbName {
        case "blau":   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":  return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "lila":   return Color(red: 0.6, green: 0.3, blue: 1.0)
        case "teal":   return Color(red: 0.2, green: 0.75, blue: 0.8)
        case "rot":    return Color(red: 1.0, green: 0.25, blue: 0.25)
        case "gelb":   return Color(red: 1.0, green: 0.8, blue: 0.1)
        case "mint":   return Color(red: 0.2, green: 0.9, blue: 0.7)
        default:       return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }
}

struct LernSession: Identifiable, Codable {
    var id: UUID = UUID()
    var lernzielID: UUID
    var datum: Date = Date()
    var dauerMinuten: Int
    var notiz: String = ""
}

@MainActor
final class LernzielStore: ObservableObject {
    static let shared = LernzielStore()

    @Published var ziele: [Lernziel] = []
    @Published var sessions: [LernSession] = []

    private let zielKey    = "lernziele_v1"
    private let sessionKey = "lernsessions_v1"

    private init() { load() }

    func erledigteMinuten(fuer ziel: Lernziel) -> Int {
        sessions.filter { $0.lernzielID == ziel.id }.reduce(0) { $0 + $1.dauerMinuten }
    }

    func erledigteStunden(fuer ziel: Lernziel) -> Double {
        Double(erledigteMinuten(fuer: ziel)) / 60.0
    }

    func fortschritt(fuer ziel: Lernziel) -> Double {
        guard ziel.zielStunden > 0 else { return 0 }
        return min(erledigteStunden(fuer: ziel) / ziel.zielStunden, 1.0)
    }

    func recenteSessions(fuer ziel: Lernziel, limit: Int = 5) -> [LernSession] {
        sessions
            .filter { $0.lernzielID == ziel.id }
            .sorted { $0.datum > $1.datum }
            .prefix(limit)
            .map { $0 }
    }

    var streak: Int {
        let cal = Calendar.current
        var count = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let hat = sessions.contains { cal.isDate($0.datum, inSameDayAs: day) }
            if !hat { break }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    var gesamtStundenHeute: Double {
        let heute = sessions.filter { Calendar.current.isDateInToday($0.datum) }
        return Double(heute.reduce(0) { $0 + $1.dauerMinuten }) / 60.0
    }

    func addZiel(_ ziel: Lernziel) {
        ziele.append(ziel)
        persistZiele()
    }

    func updateZiel(_ ziel: Lernziel) {
        if let i = ziele.firstIndex(where: { $0.id == ziel.id }) {
            ziele[i] = ziel
            persistZiele()
        }
    }

    func deleteZiel(_ ziel: Lernziel) {
        sessions.removeAll { $0.lernzielID == ziel.id }
        ziele.removeAll { $0.id == ziel.id }
        persistZiele()
        persistSessions()
    }

    func addSession(_ session: LernSession) {
        sessions.append(session)
        persistSessions()
        // Auto-complete goal if reached
        if let idx = ziele.firstIndex(where: { $0.id == session.lernzielID }),
           fortschritt(fuer: ziele[idx]) >= 1.0,
           !ziele[idx].abgeschlossen {
            ziele[idx].abgeschlossen = true
            ziele[idx].abgeschlossenAm = Date()
            persistZiele()
        }
    }

    func deleteSession(_ session: LernSession) {
        sessions.removeAll { $0.id == session.id }
        persistSessions()
    }

    private func persistZiele() {
        if let data = try? JSONEncoder().encode(ziele) {
            UserDefaults.standard.set(data, forKey: zielKey)
        }
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: zielKey),
           let decoded = try? JSONDecoder().decode([Lernziel].self, from: data) {
            ziele = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let decoded = try? JSONDecoder().decode([LernSession].self, from: data) {
            sessions = decoded
        }
    }
}
