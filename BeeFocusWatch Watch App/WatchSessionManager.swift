import Foundation
import Combine

final class WatchSessionManager: ObservableObject {
    static let shared = WatchSessionManager()

    @Published var snapshot: WatchSnapshot = .placeholder

    private let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")

    private init() {
        loadSnapshot()
    }

    func loadSnapshot() {
        guard let data = defaults?.data(forKey: "widgetSnapshot"),
              let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        DispatchQueue.main.async { self.snapshot = snap }
    }

    // Writes the completed task ID into the App Group.
    // The iOS app reads and applies this list the next time it becomes active.
    func completeTask(id: UUID) {
        var pending = defaults?.stringArray(forKey: "watchPendingCompletions") ?? []
        guard !pending.contains(id.uuidString) else { return }
        pending.append(id.uuidString)
        defaults?.set(pending, forKey: "watchPendingCompletions")
    }
}
