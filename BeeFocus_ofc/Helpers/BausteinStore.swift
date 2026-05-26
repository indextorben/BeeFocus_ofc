import SwiftUI

// MARK: - Farbe

enum BausteinFarbe: String, Codable, CaseIterable {
    case blau, gruen, orange, pink, lila, teal, rot, gelb, cyan, indigo, mint

    var color: Color {
        switch self {
        case .blau:   return .blue
        case .gruen:  return .green
        case .orange: return .orange
        case .pink:   return .pink
        case .lila:   return .purple
        case .teal:   return .teal
        case .rot:    return .red
        case .gelb:   return .yellow
        case .cyan:   return .cyan
        case .indigo: return .indigo
        case .mint:   return .mint
        }
    }

    var label: String {
        switch self {
        case .blau:   return "Blau"
        case .gruen:  return "Grün"
        case .orange: return "Orange"
        case .pink:   return "Pink"
        case .lila:   return "Lila"
        case .teal:   return "Teal"
        case .rot:    return "Rot"
        case .gelb:   return "Gelb"
        case .cyan:   return "Cyan"
        case .indigo: return "Indigo"
        case .mint:   return "Mint"
        }
    }
}

// MARK: - Model

struct TagesplanBaustein: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var titel: String = ""
    var beschreibung: String = ""
    var hatStartZeit: Bool = true
    var startStunde: Int = 9
    var startMinute: Int = 0
    var hatEndZeit: Bool = true
    var endStunde: Int = 10
    var endMinute: Int = 0
    var isHighPriority: Bool = false
    var wochentage: [Int] = []     // 1 = Mo … 7 = So; leer = kein fester Tag
    var farbe: BausteinFarbe = .blau
    var symbol: String = "square.fill"

    var zeitLabel: String {
        guard hatStartZeit else { return "Kein fester Zeitpunkt" }
        let s = String(format: "%02d:%02d", startStunde, startMinute)
        guard hatEndZeit else { return s }
        let e = String(format: "%02d:%02d", endStunde, endMinute)
        return "\(s) – \(e)"
    }

    var wochentageKurz: [String] {
        let namen = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        return wochentage.sorted().compactMap { idx in
            guard idx >= 1, idx <= 7 else { return nil }
            return namen[idx - 1]
        }
    }

    func todoItem(fuer datum: Date) -> TodoItem {
        let cal = Calendar.current
        var dueDate: Date? = nil
        var endDate: Date? = nil

        if hatStartZeit {
            dueDate = cal.date(bySettingHour: startStunde, minute: startMinute,
                               second: 0, of: datum)
        } else {
            dueDate = cal.startOfDay(for: datum)
        }

        if hatStartZeit && hatEndZeit {
            endDate = cal.date(bySettingHour: endStunde, minute: endMinute,
                               second: 0, of: datum)
        }

        return TodoItem(
            title: titel,
            description: beschreibung,
            dueDate: dueDate,
            priority: isHighPriority ? .high : .medium,
            endDate: endDate
        )
    }

    // Liegt dieser Baustein für den gegebenen Wochentag nahe?
    func passtzuWochentag(_ date: Date) -> Bool {
        guard !wochentage.isEmpty else { return false }
        // Calendar weekday: 1=So, 2=Mo ... 7=Sa → convert to 1=Mo…7=So
        let raw = Calendar.current.component(.weekday, from: date)
        let tag = raw == 1 ? 7 : raw - 1
        return wochentage.contains(tag)
    }
}

// MARK: - Store

@MainActor
class BausteinStore: ObservableObject {
    static let shared = BausteinStore()

    @Published var bausteine: [TagesplanBaustein] = []

    private init() { laden() }

    func upsert(_ b: TagesplanBaustein) {
        if let idx = bausteine.firstIndex(where: { $0.id == b.id }) {
            bausteine[idx] = b
        } else {
            bausteine.append(b)
        }
        speichern()
    }

    func loeschen(_ b: TagesplanBaustein) {
        bausteine.removeAll { $0.id == b.id }
        speichern()
    }

    func loeschenIndexSet(_ offsets: IndexSet, in list: [TagesplanBaustein]) {
        offsets.forEach { loeschen(list[$0]) }
    }

    private func laden() {
        guard let data = UserDefaults.standard.data(forKey: "tagesplanBausteine"),
              let decoded = try? JSONDecoder().decode([TagesplanBaustein].self, from: data)
        else { return }
        bausteine = decoded
    }

    private func speichern() {
        if let data = try? JSONEncoder().encode(bausteine) {
            UserDefaults.standard.set(data, forKey: "tagesplanBausteine")
        }
    }
}
