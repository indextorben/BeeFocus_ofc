import SwiftUI

enum EisenhowerQuadrant: String, CaseIterable, Identifiable {
    case q1 = "q1"  // Wichtig + Dringend
    case q2 = "q2"  // Wichtig + Nicht Dringend
    case q3 = "q3"  // Nicht Wichtig + Dringend
    case q4 = "q4"  // Nicht Wichtig + Nicht Dringend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .q1: return "Sofort erledigen"
        case .q2: return "Einplanen"
        case .q3: return "Delegieren"
        case .q4: return "Eliminieren"
        }
    }

    var label: String {
        switch self {
        case .q1: return "Wichtig + Dringend"
        case .q2: return "Wichtig + Nicht dringend"
        case .q3: return "Nicht wichtig + Dringend"
        case .q4: return "Nicht wichtig + Nicht dringend"
        }
    }

    var icon: String {
        switch self {
        case .q1: return "exclamationmark.triangle.fill"
        case .q2: return "calendar.badge.clock"
        case .q3: return "arrow.turn.down.right"
        case .q4: return "trash.fill"
        }
    }

    var color: Color {
        switch self {
        case .q1: return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .q2: return Color(red: 0.3,  green: 0.65, blue: 1.0)
        case .q3: return Color(red: 1.0, green: 0.65, blue: 0.2)
        case .q4: return Color(red: 0.5, green: 0.5, blue: 0.55)
        }
    }
}

@MainActor
final class EisenhowerStore: ObservableObject {
    static let shared = EisenhowerStore()

    @Published var assignments: [String: EisenhowerQuadrant] = [:]

    private let key = "eisenhower_assignments_v1"

    private init() { load() }

    func assign(_ todoID: UUID, to quadrant: EisenhowerQuadrant) {
        assignments[todoID.uuidString] = quadrant
        save()
    }

    func unassign(_ todoID: UUID) {
        assignments.removeValue(forKey: todoID.uuidString)
        save()
    }

    func quadrant(of todoID: UUID) -> EisenhowerQuadrant? {
        assignments[todoID.uuidString]
    }

    private func save() {
        let raw = assignments.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        assignments = raw.compactMapValues { EisenhowerQuadrant(rawValue: $0) }
    }
}
