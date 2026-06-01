import SwiftUI

struct ZeitEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var datum: Date = Date()
    var projekt: String
    var dauerMinuten: Int
    var notiz: String = ""
    var farbName: String = "lila"
}

extension ZeitEintrag {
    var farbe: Color {
        switch farbName {
        case "blau":   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":  return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "cyan":   return Color(red: 0.1, green: 0.85, blue: 0.95)
        default:       return Color(red: 0.6, green: 0.3, blue: 1.0)
        }
    }
}

@MainActor
final class ZeiterfassungStore: ObservableObject {
    static let shared = ZeiterfassungStore()

    @Published var eintraege: [ZeitEintrag] = []
    @Published var projekte: [String] = []

    private let key      = "zeiterfassung_v1"
    private let projKey  = "zeiterfassung_projekte_v1"

    private init() { load() }

    func add(_ eintrag: ZeitEintrag) {
        eintraege.append(eintrag)
        if !projekte.contains(eintrag.projekt) {
            projekte.append(eintrag.projekt)
            saveProjekte()
        }
        persist()
    }

    func delete(_ eintrag: ZeitEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        persist()
    }

    func deleteProjekt(_ name: String) {
        projekte.removeAll { $0 == name }
        saveProjekte()
    }

    // Minuten pro Projekt in den letzten 7 Tagen
    func minutenProProjekt7Tage() -> [(projekt: String, minuten: Int, farbName: String)] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) else { return [] }
        let recent = eintraege.filter { $0.datum >= start }
        var map: [String: (Int, String)] = [:]
        for e in recent {
            let cur = map[e.projekt] ?? (0, e.farbName)
            map[e.projekt] = (cur.0 + e.dauerMinuten, e.farbName)
        }
        return map.map { (projekt: $0.key, minuten: $0.value.0, farbName: $0.value.1) }
            .sorted { $0.minuten > $1.minuten }
    }

    // Gesamtminuten heute
    var heuteGesamt: Int {
        eintraege.filter { Calendar.current.isDateInToday($0.datum) }
            .reduce(0) { $0 + $1.dauerMinuten }
    }

    // Tagesweise für Chart (letzte 7 Tage)
    func tagesMinuten7Tage() -> [(date: Date, minuten: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let mins = eintraege.filter { cal.isDate($0.datum, inSameDayAs: day) }
                .reduce(0) { $0 + $1.dauerMinuten }
            return (cal.startOfDay(for: day), mins)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func saveProjekte() {
        UserDefaults.standard.set(projekte, forKey: projKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ZeitEintrag].self, from: data) {
            eintraege = decoded
        }
        projekte = UserDefaults.standard.stringArray(forKey: projKey) ?? []
    }
}
