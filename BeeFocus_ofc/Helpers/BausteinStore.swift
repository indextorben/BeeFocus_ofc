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
    var verwendungen: Int = 0      // Wie oft eingefügt — für Smart-Ranking

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

    private init() { laden(); vorbelegenFallsLeer() }

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

    func verwendungErhoehen(_ b: TagesplanBaustein) {
        guard let idx = bausteine.firstIndex(where: { $0.id == b.id }) else { return }
        bausteine[idx].verwendungen += 1
        speichern()
    }

    // MARK: - Smart Suggestions (lokal, kein Server)

    func smartVorschlaege(datum: Date, eingabe: String) -> [TagesplanBaustein] {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: datum)
        let raw  = cal.component(.weekday, from: datum)
        let wochentag = raw == 1 ? 7 : raw - 1  // 1=Mo…7=So

        let trimmed = eingabe.trimmingCharacters(in: .whitespaces).lowercased()

        var scored: [(TagesplanBaustein, Int)] = bausteine.map { b in
            var score = 0

            // --- Texteingabe ---
            if !trimmed.isEmpty {
                let titel = b.titel.lowercased()
                if titel.hasPrefix(trimmed)        { score += 50 }
                else if titel.contains(trimmed)    { score += 28 }
                else if b.beschreibung.lowercased().contains(trimmed) { score += 12 }
                else                               { score -= 100 } // kein Match → raus
            }

            // --- Wochentag ---
            if b.wochentage.isEmpty || b.wochentage.contains(wochentag) { score += 12 }

            // --- Uhrzeit-Nähe (±2 h zur Startzeit) ---
            if b.hatStartZeit {
                let diff = abs(b.startStunde - hour)
                switch diff {
                case 0:      score += 30
                case 1:      score += 18
                case 2:      score += 8
                default:     break
                }
            }

            // --- Nutzungshäufigkeit ---
            score += min(b.verwendungen * 3, 20)

            return (b, score)
        }

        // Ohne Eingabe: nur Bausteine mit positivem Score
        if trimmed.isEmpty { scored = scored.filter { $0.1 > 0 } }

        return scored
            .filter  { $0.1 > -50 }
            .sorted  { $0.1 > $1.1 }
            .prefix  (6)
            .map     { $0.0 }
    }

    // MARK: - 10 Standard-Bausteine (werden nur angelegt wenn die Liste leer ist)

    private func vorbelegenFallsLeer() {
        guard bausteine.isEmpty else { return }
        let presets: [TagesplanBaustein] = [
            {
                var b = TagesplanBaustein()
                b.titel = "Morgenroutine"
                b.beschreibung = "Frühstück, Körperpflege, Tag starten"
                b.startStunde = 7; b.startMinute = 0
                b.endStunde   = 7; b.endMinute   = 30
                b.wochentage  = []   // täglich
                b.farbe = .gelb; b.symbol = "sun.max.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "E-Mails & Nachrichten"
                b.beschreibung = "Postfach leeren, Slack/Teams checken"
                b.startStunde = 8; b.startMinute = 0
                b.endStunde   = 8; b.endMinute   = 30
                b.wochentage  = [1,2,3,4,5]  // Mo–Fr
                b.farbe = .blau; b.symbol = "envelope.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Tagesplanung"
                b.beschreibung = "Prioritäten setzen, Kalender checken"
                b.startStunde = 8; b.startMinute = 30
                b.endStunde   = 9; b.endMinute   = 0
                b.wochentage  = [1,2,3,4,5]
                b.farbe = .teal; b.symbol = "list.bullet.clipboard.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Deep Work"
                b.beschreibung = "Tiefe Konzentration, Handy weg"
                b.startStunde = 9;  b.startMinute = 0
                b.endStunde   = 11; b.endMinute   = 0
                b.wochentage  = [1,2,3,4,5]
                b.isHighPriority = true
                b.farbe = .indigo; b.symbol = "brain.head.profile"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Fokus-Block"
                b.beschreibung = "Konzentrierte Arbeitseinheit"
                b.startStunde = 14; b.startMinute = 0
                b.endStunde   = 16; b.endMinute   = 0
                b.wochentage  = [1,2,3,4,5]
                b.farbe = .rot; b.symbol = "bolt.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Mittagspause"
                b.beschreibung = "Essen, kurze Auszeit"
                b.startStunde = 12; b.startMinute = 0
                b.endStunde   = 13; b.endMinute   = 0
                b.wochentage  = []
                b.farbe = .gruen; b.symbol = "fork.knife"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Sport & Training"
                b.beschreibung = "Gym, Laufen oder Heimtraining"
                b.startStunde = 17; b.startMinute = 0
                b.endStunde   = 18; b.endMinute   = 0
                b.wochentage  = [1,3,5]  // Mo, Mi, Fr
                b.farbe = .orange; b.symbol = "dumbbell.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Spaziergang"
                b.beschreibung = "Frische Luft, Kopf freibekommen"
                b.startStunde = 17; b.startMinute = 30
                b.endStunde   = 18; b.endMinute   = 0
                b.wochentage  = []
                b.farbe = .mint; b.symbol = "figure.walk"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Lesen"
                b.beschreibung = "Buch, Artikel oder Fachtext"
                b.startStunde = 20; b.startMinute = 0
                b.endStunde   = 21; b.endMinute   = 0
                b.wochentage  = []
                b.farbe = .lila; b.symbol = "book.fill"
                return b
            }(),
            {
                var b = TagesplanBaustein()
                b.titel = "Tagesreflexion"
                b.beschreibung = "Was lief gut? Was morgen besser?"
                b.startStunde = 21; b.startMinute = 30
                b.endStunde   = 22; b.endMinute   = 0
                b.wochentage  = []
                b.farbe = .cyan; b.symbol = "moon.fill"
                return b
            }(),
        ]
        bausteine = presets
        speichern()
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
