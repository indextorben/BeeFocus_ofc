import SwiftUI

struct ZielMeilenstein: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var completedAt: Date? = nil
}

struct LangzeitZiel: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var beschreibung: String = ""
    var icon: String = "target"
    var colorName: String = "purple"
    var deadline: Date? = nil
    var meilensteine: [ZielMeilenstein] = []
    var createdAt: Date = Date()
    var isArchived: Bool = false

    var color: Color {
        switch colorName {
        case "blue":   return Color(red: 0.3, green: 0.6, blue: 1.0)
        case "green":  return Color(red: 0.2, green: 0.82, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "red":    return Color(red: 1.0, green: 0.35, blue: 0.35)
        case "yellow": return Color(red: 1.0, green: 0.85, blue: 0.2)
        case "cyan":   return Color(red: 0.2, green: 0.85, blue: 0.95)
        case "teal":   return Color(red: 0.1, green: 0.7, blue: 0.65)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        default:       return Color(red: 0.6, green: 0.3, blue: 1.0)
        }
    }

    var progress: Double {
        guard !meilensteine.isEmpty else { return 0 }
        return Double(meilensteine.filter { $0.isCompleted }.count) / Double(meilensteine.count)
    }

    var isCompleted: Bool { !meilensteine.isEmpty && meilensteine.allSatisfy { $0.isCompleted } }

    var daysLeft: Int? {
        guard let dl = deadline else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: dl).day ?? 0)
    }

    static let availableIcons = ["target", "star.fill", "flag.fill", "trophy.fill", "rocket.fill",
                                  "heart.fill", "brain.head.profile", "book.fill", "briefcase.fill",
                                  "dumbbell.fill", "leaf.fill", "lightbulb.fill", "music.note",
                                  "paintbrush.fill", "globe", "house.fill", "airplane", "graduationcap.fill"]
}

@MainActor
final class LangzeitZieleStore: ObservableObject {
    static let shared = LangzeitZieleStore()

    @Published var ziele: [LangzeitZiel] = []

    private let key = "langzeit_ziele_v1"

    private init() { load() }

    var aktiveZiele: [LangzeitZiel] { ziele.filter { !$0.isArchived } }
    var archiviertZiele: [LangzeitZiel] { ziele.filter { $0.isArchived } }

    func save(_ ziel: LangzeitZiel) {
        if let idx = ziele.firstIndex(where: { $0.id == ziel.id }) {
            ziele[idx] = ziel
        } else {
            ziele.append(ziel)
        }
        persist()
    }

    func delete(_ ziel: LangzeitZiel) {
        ziele.removeAll { $0.id == ziel.id }
        persist()
    }

    func toggleMeilenstein(_ meilensteinID: UUID, in zielID: UUID) {
        guard let zi = ziele.firstIndex(where: { $0.id == zielID }),
              let mi = ziele[zi].meilensteine.firstIndex(where: { $0.id == meilensteinID }) else { return }
        let done = !ziele[zi].meilensteine[mi].isCompleted
        ziele[zi].meilensteine[mi].isCompleted = done
        ziele[zi].meilensteine[mi].completedAt = done ? Date() : nil
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(ziele) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LangzeitZiel].self, from: data) else { return }
        ziele = decoded
    }
}
