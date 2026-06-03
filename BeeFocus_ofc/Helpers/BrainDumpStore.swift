import SwiftUI

enum BrainDumpTag: String, CaseIterable, Codable {
    case idee = "idee"
    case aufgabe = "aufgabe"
    case frage = "frage"
    case sorge = "sorge"
    case danke = "danke"

    var label: String {
        switch self {
        case .idee:    return "Idee"
        case .aufgabe: return "Aufgabe"
        case .frage:   return "Frage"
        case .sorge:   return "Sorge"
        case .danke:   return "Dankbarkeit"
        }
    }

    var icon: String {
        switch self {
        case .idee:    return "lightbulb.fill"
        case .aufgabe: return "checkmark.circle.fill"
        case .frage:   return "questionmark.circle.fill"
        case .sorge:   return "exclamationmark.triangle.fill"
        case .danke:   return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .idee:    return Color(red: 1.0, green: 0.85, blue: 0.2)
        case .aufgabe: return Color(red: 0.3, green: 0.82, blue: 0.5)
        case .frage:   return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .sorge:   return Color(red: 1.0, green: 0.5, blue: 0.2)
        case .danke:   return Color(red: 1.0, green: 0.4, blue: 0.6)
        }
    }
}

struct BrainDumpEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var tag: BrainDumpTag = .idee
    var date: Date = Date()
    var isConverted: Bool = false
}

@MainActor
final class BrainDumpStore: ObservableObject {
    static let shared = BrainDumpStore()

    @Published var eintraege: [BrainDumpEintrag] = []

    private let key = "brain_dump_v1"

    private init() { load() }

    func add(text: String, tag: BrainDumpTag) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        eintraege.insert(BrainDumpEintrag(text: trimmed, tag: tag), at: 0)
        persist()
    }

    func delete(_ eintrag: BrainDumpEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        persist()
    }

    func markConverted(_ eintrag: BrainDumpEintrag) {
        if let idx = eintraege.firstIndex(where: { $0.id == eintrag.id }) {
            eintraege[idx].isConverted = true
        }
        persist()
    }

    func updateTag(_ eintrag: BrainDumpEintrag, newTag: BrainDumpTag) {
        if let idx = eintraege.firstIndex(where: { $0.id == eintrag.id }) {
            eintraege[idx].tag = newTag
        }
        persist()
    }

    func updateText(_ eintrag: BrainDumpEintrag, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = eintraege.firstIndex(where: { $0.id == eintrag.id }) {
            eintraege[idx].text = trimmed
        }
        persist()
    }

    func clearAll() {
        eintraege.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BrainDumpEintrag].self, from: data) else { return }
        eintraege = decoded
    }
}
