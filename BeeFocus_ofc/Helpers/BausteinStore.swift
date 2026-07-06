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
        case .blau:   return "Blue"
        case .gruen:  return "Green"
        case .orange: return "Orange"
        case .pink:   return "Pink"
        case .lila:   return "Purple"
        case .teal:   return "Teal"
        case .rot:    return "Red"
        case .gelb:   return "Yellow"
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
    var titelDe: String? = nil
    var beschreibungDe: String? = nil
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

    func localizedTitel(languageCode: String) -> String {
        languageCode == "de" ? (titelDe ?? titel) : titel
    }

    func localizedBeschreibung(languageCode: String) -> String {
        languageCode == "de" ? (beschreibungDe ?? beschreibung) : beschreibung
    }

    var zeitLabel: String {
        guard hatStartZeit else { return "–" }
        let s = String(format: "%02d:%02d", startStunde, startMinute)
        guard hatEndZeit else { return s }
        let e = String(format: "%02d:%02d", endStunde, endMinute)
        return "\(s) – \(e)"
    }

    var wochentageKurz: [String] {
        let namen = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
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

    private init() { laden(); vorbelegenFallsLeer(); migrateGermanTitlesIfNeeded() }

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

    private static let defaultPresets: [(titel: String, titelDe: String, beschreibung: String, beschreibungDe: String,
                                          startH: Int, startM: Int, endH: Int, endM: Int,
                                          wochentage: [Int], highPrio: Bool,
                                          farbe: BausteinFarbe, symbol: String)] = [
        ("Morning Routine",    "Morgenroutine",       "Breakfast, personal care, start the day",         "Frühstück, Körperpflege, in den Tag starten",    7,  0, 7, 30, [],        false, .gelb,  "sun.max.fill"),
        ("Emails & Messages",  "E-Mails & Nachrichten","Clear inbox, check Slack/Teams",                  "Posteingang leeren, Slack/Teams checken",         8,  0, 8, 30, [1,2,3,4,5], false, .blau,  "envelope.fill"),
        ("Daily Planning",     "Tagesplanung",        "Set priorities, check calendar",                  "Prioritäten setzen, Kalender checken",            8, 30, 9,  0, [1,2,3,4,5], false, .teal,  "list.bullet.clipboard.fill"),
        ("Deep Work",          "Tiefarbeit",          "Deep concentration, phone away",                  "Volle Konzentration, Handy weg",                  9,  0, 11, 0, [1,2,3,4,5], true,  .indigo,"brain.head.profile"),
        ("Focus Block",        "Fokus-Block",         "Concentrated work unit",                          "Konzentrierte Arbeitseinheit",                   14,  0, 16, 0, [1,2,3,4,5], false, .rot,   "bolt.fill"),
        ("Lunch Break",        "Mittagspause",        "Eat, short break",                               "Essen, kurze Auszeit",                           12,  0, 13, 0, [],        false, .gruen, "fork.knife"),
        ("Exercise & Training","Sport & Training",    "Gym, running, or home workout",                  "Fitnessstudio, Laufen oder Heimtraining",         17,  0, 18, 0, [1,3,5],   false, .orange,"dumbbell.fill"),
        ("Walk",               "Spaziergang",         "Fresh air, clear your head",                     "Frische Luft, Kopf frei machen",                 17, 30, 18, 0, [],        false, .mint,  "figure.walk"),
        ("Reading",            "Lesen",               "Book, article, or professional text",            "Buch, Artikel oder Fachtext",                    20,  0, 21, 0, [],        false, .lila,  "book.fill"),
        ("Daily Reflection",   "Tagesreflexion",      "What went well? What to improve tomorrow?",      "Was lief gut? Was morgen verbessern?",            21, 30, 22, 0, [],        false, .cyan,  "moon.fill"),
    ]

    private func vorbelegenFallsLeer() {
        guard bausteine.isEmpty else { return }
        bausteine = Self.defaultPresets.map { p in
            var b = TagesplanBaustein()
            b.titel = p.titel; b.titelDe = p.titelDe
            b.beschreibung = p.beschreibung; b.beschreibungDe = p.beschreibungDe
            b.startStunde = p.startH; b.startMinute = p.startM
            b.endStunde = p.endH; b.endMinute = p.endM
            b.wochentage = p.wochentage; b.isHighPriority = p.highPrio
            b.farbe = p.farbe; b.symbol = p.symbol
            return b
        }
        speichern()
    }

    private func migrateGermanTitlesIfNeeded() {
        guard bausteine.contains(where: { $0.titelDe == nil }) else { return }
        let lookup = Dictionary(uniqueKeysWithValues: Self.defaultPresets.map { ($0.titel, $0) })
        var changed = false
        for i in bausteine.indices where bausteine[i].titelDe == nil {
            if let p = lookup[bausteine[i].titel] {
                bausteine[i].titelDe = p.titelDe
                bausteine[i].beschreibungDe = p.beschreibungDe
                changed = true
            }
        }
        if changed { speichern() }
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
