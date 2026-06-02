import Foundation
import WatchConnectivity

// Handles iOS ↔ Watch communication:
// - Reads App Group for pending completions written by Watch
// - Pushes snapshot updates to Watch via WatchConnectivity
// - Receives live task-completion messages from Watch via WatchConnectivity
final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    private let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")
    weak var todoStore: TodoStore?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Snapshot push (called from writeWidgetSnapshot)

    func sendSnapshotData(_ data: Data) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired else { return }
        try? WCSession.default.updateApplicationContext(["widgetSnapshot": data])
    }

    // MARK: - App Group completions (called on didBecomeActive)

    func applyPendingWatchCompletions() {
        guard let pending = defaults?.stringArray(forKey: "watchPendingCompletions"),
              !pending.isEmpty,
              let store = todoStore else { return }

        let ids = pending.compactMap { UUID(uuidString: $0) }
        var applied = false

        for id in ids {
            if let todo = store.todos.first(where: { $0.id == id }), !todo.isCompleted {
                store.toggleTodo(todo)
                applied = true
            }
        }

        defaults?.removeObject(forKey: "watchPendingCompletions")

        if applied { store.writeWidgetSnapshot() }
    }

    // Called when Watch sends a live completion via WatchConnectivity.
    private func completeWatchTask(id: UUID) {
        guard let store = todoStore,
              let todo = store.todos.first(where: { $0.id == id }),
              !todo.isCompleted else { return }
        store.toggleTodo(todo)
        store.writeWidgetSnapshot()
    }

    @MainActor
    private func handleAddWater(ml: Int) {
        WasserStore.shared.add(ml: ml)
        todoStore?.writeWidgetSnapshot()
    }

    @MainActor
    private func handleToggleHabit(id: UUID) {
        guard let habit = HabitStore.shared.habits.first(where: { $0.id == id }) else { return }
        HabitStore.shared.toggle(habit)
        todoStore?.writeWidgetSnapshot()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let idString = message["completeTask"] as? String, let id = UUID(uuidString: idString) {
            DispatchQueue.main.async { self.completeWatchTask(id: id) }
        } else if let ml = message["addWater"] as? Int {
            Task { @MainActor in self.handleAddWater(ml: ml) }
        } else if let idString = message["toggleHabit"] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in self.handleToggleHabit(id: id) }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        // writeWidgetSnapshot() beim App-Start schlägt fehl weil Aktivierung async ist.
        // Daher: nach Aktivierung den bereits in der App Group gespeicherten Snapshot pushen.
        if let data = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")?.data(forKey: "widgetSnapshot") {
            try? WCSession.default.updateApplicationContext(["widgetSnapshot": data])
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
