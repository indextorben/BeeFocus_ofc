import SwiftUI

enum SportArt: String, CaseIterable, Codable {
    case laufen    = "Laufen"
    case radfahren = "Radfahren"
    case schwimmen = "Schwimmen"
    case gym       = "Gym"
    case yoga      = "Yoga"
    case wandern   = "Wandern"
    case sport     = "Sport"
    case sonstiges = "Sonstiges"

    var icon: String {
        switch self {
        case .laufen:    return "figure.run"
        case .radfahren: return "bicycle"
        case .schwimmen: return "figure.pool.swim"
        case .gym:       return "dumbbell.fill"
        case .yoga:      return "figure.mind.and.body"
        case .wandern:   return "figure.hiking"
        case .sport:     return "sportscourt.fill"
        case .sonstiges: return "figure.mixed.cardio"
        }
    }

    var farbe: Color {
        switch self {
        case .laufen:    return .orange
        case .radfahren: return .green
        case .schwimmen: return .cyan
        case .gym:       return .red
        case .yoga:      return .purple
        case .wandern:   return Color(red: 0.4, green: 0.7, blue: 0.2)
        case .sport:     return .blue
        case .sonstiges: return .secondary
        }
    }
}

struct SportEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var datum: Date = Date()
    var art: SportArt
    var dauerMinuten: Int
    var intensitaet: Int   // 1–3: leicht, mittel, intensiv
    var notiz: String = ""
}

extension SportEintrag {
    var kalorien: Int {
        let base: Int
        switch art {
        case .laufen:    base = 8
        case .radfahren: base = 6
        case .schwimmen: base = 7
        case .gym:       base = 5
        case .yoga:      base = 3
        case .wandern:   base = 5
        case .sport:     base = 7
        case .sonstiges: base = 5
        }
        return base * dauerMinuten * intensitaet
    }
}

@MainActor
final class SportStore: ObservableObject {
    static let shared = SportStore()

    @Published var eintraege: [SportEintrag] = []

    private let key = "sport_eintraege_v1"

    private init() { load() }

    var heutigeEintraege: [SportEintrag] {
        eintraege.filter { Calendar.current.isDateInToday($0.datum) }
            .sorted { $0.datum > $1.datum }
    }

    var heutigeGesamtMinuten: Int { heutigeEintraege.reduce(0) { $0 + $1.dauerMinuten } }

    func add(_ eintrag: SportEintrag) {
        eintraege.append(eintrag)
        persist()
    }

    func delete(_ eintrag: SportEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        persist()
    }

    func last7Days() -> [(date: Date, minuten: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let mins = eintraege
                .filter { cal.isDate($0.datum, inSameDayAs: day) }
                .reduce(0) { $0 + $1.dauerMinuten }
            return (cal.startOfDay(for: day), mins)
        }
    }

    var streak: Int {
        let cal = Calendar.current
        var count = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let aktiv = eintraege.contains { cal.isDate($0.datum, inSameDayAs: day) }
            if !aktiv { break }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SportEintrag].self, from: data) else { return }
        eintraege = decoded
    }
}
