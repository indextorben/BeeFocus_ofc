import SwiftUI

struct Notiz: Identifiable, Codable {
    var id: UUID = UUID()
    var titel: String = ""
    var inhalt: String = ""
    var farbName: String = "lila"
    var isPinned: Bool = false
    var erstelltAm: Date = Date()
    var bearbeitetAm: Date = Date()
    var tags: [String] = []
}

extension Notiz {
    var farbe: Color {
        switch farbName {
        case "lila":    return Color(red: 0.6, green: 0.3, blue: 1.0)
        case "blau":    return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":   return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange":  return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":    return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "cyan":    return Color(red: 0.1, green: 0.85, blue: 0.95)
        default:        return .purple
        }
    }
}

@MainActor
final class NotizStore: ObservableObject {
    static let shared = NotizStore()

    @Published var notizen: [Notiz] = []

    private let key = "notizen_v1"

    private init() { load() }

    var sortiert: [Notiz] {
        notizen.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.bearbeitetAm > $1.bearbeitetAm
        }
    }

    func add() -> Notiz {
        let n = Notiz()
        notizen.append(n)
        persist()
        return n
    }

    func save(_ notiz: Notiz) {
        if let idx = notizen.firstIndex(where: { $0.id == notiz.id }) {
            var updated = notiz
            updated.bearbeitetAm = Date()
            notizen[idx] = updated
        } else {
            notizen.append(notiz)
        }
        persist()
    }

    func delete(_ notiz: Notiz) {
        notizen.removeAll { $0.id == notiz.id }
        persist()
    }

    func togglePin(_ notiz: Notiz) {
        if let idx = notizen.firstIndex(where: { $0.id == notiz.id }) {
            notizen[idx].isPinned.toggle()
            persist()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notizen) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Notiz].self, from: data) else { return }
        notizen = decoded
    }
}

let notizFarben: [(name: String, farbe: Color)] = [
    ("lila",   Color(red: 0.6, green: 0.3, blue: 1.0)),
    ("blau",   Color(red: 0.2, green: 0.6, blue: 1.0)),
    ("gruen",  Color(red: 0.2, green: 0.8, blue: 0.5)),
    ("orange", Color(red: 1.0, green: 0.55, blue: 0.1)),
    ("pink",   Color(red: 1.0, green: 0.4,  blue: 0.7)),
    ("cyan",   Color(red: 0.1, green: 0.85, blue: 0.95)),
]
