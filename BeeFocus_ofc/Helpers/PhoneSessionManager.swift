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

    // MARK: - Pending completions (called on didBecomeActive)

    func applyPendingWatchCompletions() {
        guard let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc"),
              let store = todoStore else { return }

        // Task-Erledigungen
        if let ids = defaults.stringArray(forKey: "pendingWatchCompletions"), !ids.isEmpty {
            defaults.removeObject(forKey: "pendingWatchCompletions")
            DispatchQueue.main.async {
                for idString in ids {
                    guard let id = UUID(uuidString: idString),
                          let todo = store.todos.first(where: { $0.id == id }),
                          !todo.isCompleted else { continue }
                    store.toggleTodo(todo)
                }
                store.writeWidgetSnapshot()
            }
        }

        // Wasser
        if let mlValues = defaults.array(forKey: "pendingWatchWaterMl") as? [Int], !mlValues.isEmpty {
            defaults.removeObject(forKey: "pendingWatchWaterMl")
            DispatchQueue.main.async {
                for ml in mlValues { WasserStore.shared.add(ml: ml) }
                store.writeWidgetSnapshot()
            }
        }

        // Gewohnheiten
        if let ids = defaults.stringArray(forKey: "pendingWatchHabitToggles"), !ids.isEmpty {
            defaults.removeObject(forKey: "pendingWatchHabitToggles")
            DispatchQueue.main.async {
                for idString in ids {
                    guard let id = UUID(uuidString: idString),
                          let habit = HabitStore.shared.habits.first(where: { $0.id == id })
                    else { continue }
                    HabitStore.shared.toggle(habit)
                }
                store.writeWidgetSnapshot()
            }
        }
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
        if message["requestSnapshot"] != nil {
            DispatchQueue.main.async { self.todoStore?.writeWidgetSnapshot() }
        } else if let idString = message["completeTask"] as? String, let id = UUID(uuidString: idString) {
            DispatchQueue.main.async { self.completeWatchTask(id: id) }
        } else if let ml = message["addWater"] as? Int {
            Task { @MainActor in self.handleAddWater(ml: ml) }
        } else if let idString = message["toggleHabit"] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in self.handleToggleHabit(id: id) }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["requestSnapshot"] != nil else { replyHandler([:]); return }
        DispatchQueue.main.async {
            // Gecachten Snapshot sofort zurückschicken (todos sind zu diesem Zeitpunkt ggf. noch nicht bereit)
            if let data = UserDefaults(suiteName: beeFocusAppGroup)?.data(forKey: "widgetSnapshot") {
                replyHandler(["widgetSnapshot": data])
            } else {
                replyHandler([:])
            }
            // Frischen Snapshot bauen und kurz danach via updateApplicationContext nachliefern
            self.todoStore?.writeWidgetSnapshot()
        }
    }

    // Aktionen + Snapshot-Anfragen via transferUserInfo (auch wenn iPhone nicht erreichbar war)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if userInfo["requestSnapshot"] != nil {
            DispatchQueue.main.async { self.todoStore?.writeWidgetSnapshot() }
        } else if let idString = userInfo["completeTask"] as? String, let id = UUID(uuidString: idString) {
            DispatchQueue.main.async { self.completeWatchTask(id: id) }
        } else if let ml = userInfo["addWater"] as? Int {
            Task { @MainActor in self.handleAddWater(ml: ml) }
        } else if let idString = userInfo["toggleHabit"] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in self.handleToggleHabit(id: id) }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        DispatchQueue.main.async {
            if self.todoStore != nil {
                // TodoStore ist bereits bereit → frischen Snapshot bauen und senden
                self.todoStore?.writeWidgetSnapshot()
            } else if let data = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")?.data(forKey: "widgetSnapshot") {
                // Fallback: letzten gecachten Snapshot pushen
                try? WCSession.default.updateApplicationContext(["widgetSnapshot": data])
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
