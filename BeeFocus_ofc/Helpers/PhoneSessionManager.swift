import Foundation
import WatchConnectivity

final class PhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    weak var todoStore: TodoStore?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Snapshot push (iOS → Watch)

    func sendSnapshotData(_ data: Data) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext(["widgetSnapshot": data])
    }

    // MARK: - Watch → iOS (live messages)

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
        guard activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        // Erster writeWidgetSnapshot() schlägt fehl weil Aktivierung async läuft.
        // Nach Aktivierung direkt aus der App Group laden und pushen.
        if let data = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")?.data(forKey: "widgetSnapshot") {
            try? WCSession.default.updateApplicationContext(["widgetSnapshot": data])
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
