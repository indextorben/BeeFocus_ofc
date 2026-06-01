import SwiftUI

// MARK: - Models

enum NotizTyp: String, Codable {
    case text
    case checkliste
}

struct CheckItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String = ""
    var isChecked: Bool = false
}

struct Notiz: Identifiable, Codable {
    var id: UUID = UUID()
    var titel: String = ""
    var inhalt: String = ""
    var typ: NotizTyp = .text
    var checkItems: [CheckItem] = []
    var farbName: String = "lila"
    var isPinned: Bool = false
    var erstelltAm: Date = Date()
    var bearbeitetAm: Date = Date()
    var tags: [String] = []
    var ordner: String = ""
}

extension Notiz {
    var farbe: Color {
        switch farbName {
        case "lila":   return Color(red: 0.6,  green: 0.3,  blue: 1.0)
        case "blau":   return Color(red: 0.2,  green: 0.6,  blue: 1.0)
        case "gruen":  return Color(red: 0.2,  green: 0.8,  blue: 0.5)
        case "orange": return Color(red: 1.0,  green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0,  green: 0.4,  blue: 0.7)
        case "cyan":   return Color(red: 0.1,  green: 0.85, blue: 0.95)
        case "rot":    return Color(red: 1.0,  green: 0.25, blue: 0.35)
        case "gelb":   return Color(red: 1.0,  green: 0.85, blue: 0.15)
        default:       return .purple
        }
    }

    var wortanzahl: Int {
        let text = typ == .checkliste ? checkItems.map(\.text).joined(separator: " ") : inhalt
        return text.split(separator: " ").count
    }

    var checkItemsDone: Int { checkItems.filter(\.isChecked).count }

    var vorschauText: String {
        if typ == .checkliste {
            return checkItems.prefix(4).map { ($0.isChecked ? "✓ " : "○ ") + $0.text }.joined(separator: "\n")
        }
        return inhalt
    }
}

// MARK: - Store

@MainActor
final class NotizStore: ObservableObject {
    static let shared = NotizStore()

    @Published var notizen: [Notiz] = []
    @Published var ordnerListe: [String] = []

    private let key       = "notizen_v1"
    private let ordnerKey = "notizen_ordner_v1"

    private init() { load() }

    var sortiert: [Notiz] {
        notizen.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.bearbeitetAm > $1.bearbeitetAm
        }
    }

    func gefiltert(ordner: String, suche: String, sort: NotizSortierung) -> [Notiz] {
        var result = notizen
        if ordner == "__pinned__" {
            result = result.filter { $0.isPinned }
        } else if ordner != "__alle__" {
            result = result.filter { $0.ordner == ordner }
        }
        if !suche.isEmpty {
            result = result.filter {
                $0.titel.localizedCaseInsensitiveContains(suche) ||
                $0.inhalt.localizedCaseInsensitiveContains(suche) ||
                $0.checkItems.contains { $0.text.localizedCaseInsensitiveContains(suche) }
            }
        }
        return result.sorted(by: sort.comparator)
    }

    func save(_ notiz: Notiz) {
        var n = notiz; n.bearbeitetAm = Date()
        if let idx = notizen.firstIndex(where: { $0.id == n.id }) {
            notizen[idx] = n
        } else {
            notizen.append(n)
        }
        persist()
    }

    func delete(_ notiz: Notiz) { notizen.removeAll { $0.id == notiz.id }; persist() }

    func togglePin(_ notiz: Notiz) {
        guard let idx = notizen.firstIndex(where: { $0.id == notiz.id }) else { return }
        notizen[idx].isPinned.toggle(); persist()
    }

    func addOrdner(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !ordnerListe.contains(trimmed) else { return }
        ordnerListe.append(trimmed)
        persistOrdner()
    }

    func deleteOrdner(_ name: String) {
        ordnerListe.removeAll { $0 == name }
        for idx in notizen.indices where notizen[idx].ordner == name {
            notizen[idx].ordner = ""
        }
        persist(); persistOrdner()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notizen) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func persistOrdner() {
        UserDefaults.standard.set(ordnerListe, forKey: ordnerKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Notiz].self, from: data) {
            notizen = decoded
        }
        ordnerListe = UserDefaults.standard.stringArray(forKey: ordnerKey) ?? []
    }
}

// MARK: - Sort

enum NotizSortierung: String, CaseIterable, Identifiable {
    case bearbeitet = "Bearbeitet"
    case erstellt   = "Erstellt"
    case titel      = "Titel"
    case farbe      = "Farbe"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .bearbeitet: return "clock"
        case .erstellt:   return "calendar"
        case .titel:      return "textformat.abc"
        case .farbe:      return "paintpalette"
        }
    }

    var comparator: (Notiz, Notiz) -> Bool {
        switch self {
        case .bearbeitet: return { $0.bearbeitetAm > $1.bearbeitetAm }
        case .erstellt:   return { $0.erstelltAm   > $1.erstelltAm }
        case .titel:      return { $0.titel.localizedCompare($1.titel) == .orderedAscending }
        case .farbe:      return { $0.farbName < $1.farbName }
        }
    }
}

// MARK: - Farben

let notizFarben: [(name: String, farbe: Color)] = [
    ("lila",   Color(red: 0.6,  green: 0.3,  blue: 1.0)),
    ("blau",   Color(red: 0.2,  green: 0.6,  blue: 1.0)),
    ("gruen",  Color(red: 0.2,  green: 0.8,  blue: 0.5)),
    ("cyan",   Color(red: 0.1,  green: 0.85, blue: 0.95)),
    ("orange", Color(red: 1.0,  green: 0.55, blue: 0.1)),
    ("rot",    Color(red: 1.0,  green: 0.25, blue: 0.35)),
    ("pink",   Color(red: 1.0,  green: 0.4,  blue: 0.7)),
    ("gelb",   Color(red: 1.0,  green: 0.85, blue: 0.15)),
]
