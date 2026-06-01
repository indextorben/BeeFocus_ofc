import SwiftUI

enum FinanzTyp: String, CaseIterable, Codable {
    case einnahme = "Einnahme"
    case ausgabe  = "Ausgabe"
}

struct FinanzKategorie: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var farbName: String

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
        default:       return .secondary
        }
    }

    static let defaults: [FinanzKategorie] = [
        FinanzKategorie(name: "Gehalt",       symbol: "briefcase.fill",    farbName: "gruen"),
        FinanzKategorie(name: "Freelance",    symbol: "laptopcomputer",     farbName: "mint"),
        FinanzKategorie(name: "Lebensmittel", symbol: "cart.fill",          farbName: "orange"),
        FinanzKategorie(name: "Wohnen",       symbol: "house.fill",         farbName: "blau"),
        FinanzKategorie(name: "Transport",    symbol: "car.fill",           farbName: "teal"),
        FinanzKategorie(name: "Freizeit",     symbol: "gamecontroller.fill", farbName: "lila"),
        FinanzKategorie(name: "Gesundheit",   symbol: "heart.fill",         farbName: "rot"),
        FinanzKategorie(name: "Bildung",      symbol: "book.fill",          farbName: "gelb"),
        FinanzKategorie(name: "Sonstiges",    symbol: "ellipsis.circle.fill", farbName: "pink"),
    ]
}

struct FinanzEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var datum: Date = Date()
    var typ: FinanzTyp
    var kategorieName: String
    var kategorieSymbol: String
    var kategorieFarbName: String
    var betrag: Double
    var notiz: String = ""

    var kategoriefarbe: Color {
        switch kategorieFarbName {
        case "blau":   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":  return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "lila":   return Color(red: 0.6, green: 0.3, blue: 1.0)
        case "teal":   return Color(red: 0.2, green: 0.75, blue: 0.8)
        case "rot":    return Color(red: 1.0, green: 0.25, blue: 0.25)
        case "gelb":   return Color(red: 1.0, green: 0.8, blue: 0.1)
        case "mint":   return Color(red: 0.2, green: 0.9, blue: 0.7)
        default:       return .secondary
        }
    }
}

@MainActor
final class FinanzStore: ObservableObject {
    static let shared = FinanzStore()

    @Published var eintraege: [FinanzEintrag] = []
    @Published var kategorien: [FinanzKategorie] = FinanzKategorie.defaults

    private let key     = "finanz_eintraege_v1"
    private let katKey  = "finanz_kategorien_v1"

    private init() { load() }

    var gesamtEinnahmen: Double {
        eintraege.filter { $0.typ == .einnahme }.reduce(0) { $0 + $1.betrag }
    }
    var gesamtAusgaben: Double {
        eintraege.filter { $0.typ == .ausgabe }.reduce(0) { $0 + $1.betrag }
    }
    var bilanz: Double { gesamtEinnahmen - gesamtAusgaben }

    var diesenMonat: [FinanzEintrag] {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return eintraege.filter { $0.datum >= start }.sorted { $0.datum > $1.datum }
    }

    var einnahmenDiesenMonat: Double {
        diesenMonat.filter { $0.typ == .einnahme }.reduce(0) { $0 + $1.betrag }
    }
    var ausgabenDiesenMonat: Double {
        diesenMonat.filter { $0.typ == .ausgabe }.reduce(0) { $0 + $1.betrag }
    }

    func ausgabenProKategorie() -> [(name: String, symbol: String, farbName: String, betrag: Double)] {
        let ausgaben = diesenMonat.filter { $0.typ == .ausgabe }
        var map: [String: (String, String, Double)] = [:]
        for e in ausgaben {
            let cur = map[e.kategorieName] ?? (e.kategorieSymbol, e.kategorieFarbName, 0)
            map[e.kategorieName] = (cur.0, cur.1, cur.2 + e.betrag)
        }
        return map.map { (name: $0.key, symbol: $0.value.0, farbName: $0.value.1, betrag: $0.value.2) }
            .sorted { $0.betrag > $1.betrag }
    }

    func add(_ eintrag: FinanzEintrag) {
        eintraege.append(eintrag)
        persist()
    }

    func delete(_ eintrag: FinanzEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        persist()
    }

    func addKategorie(_ k: FinanzKategorie) {
        kategorien.append(k)
        saveKategorien()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func saveKategorien() {
        if let data = try? JSONEncoder().encode(kategorien) {
            UserDefaults.standard.set(data, forKey: katKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([FinanzEintrag].self, from: data) {
            eintraege = decoded
        }
        if let data = UserDefaults.standard.data(forKey: katKey),
           let decoded = try? JSONDecoder().decode([FinanzKategorie].self, from: data) {
            kategorien = decoded
        }
    }
}
