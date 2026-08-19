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
              WCSession.default.isWatchAppInstalled else {
            print("[Phone] sendSnapshotData: Guard fehlgeschlagen – activated=\(WCSession.default.activationState.rawValue) paired=\(WCSession.default.isPaired) watchInstalled=\(WCSession.default.isWatchAppInstalled)")
            return
        }
        do {
            try WCSession.default.updateApplicationContext(["widgetSnapshot": data])
            print("[Phone] sendSnapshotData: updateApplicationContext OK (\(data.count) Bytes)")
        } catch {
            print("[Phone] sendSnapshotData: updateApplicationContext FEHLER: \(error)")
        }
    }

    // Sendet Snapshot über transferUserInfo (zuverlässig, auch wenn iPhone im Hintergrund)
    func sendSnapshotViaTransferUserInfo(_ data: Data) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        print("[Phone] sendSnapshotViaTransferUserInfo (\(data.count) Bytes)")
        WCSession.default.transferUserInfo(["widgetSnapshot": data])
    }

    // MARK: - Watch → iOS (live messages)

    private func completeWatchTask(id: UUID) {
        setWatchTask(id: id, completed: true)
    }

    // Setzt den Erledigt-Status gezielt (ermöglicht Undo von der Watch).
    private func setWatchTask(id: UUID, completed: Bool) {
        guard let store = todoStore,
              let todo = store.todos.first(where: { $0.id == id }),
              todo.isCompleted != completed else { return }
        store.toggleTodo(todo)
        store.writeWidgetSnapshot()
    }

    private func toggleWatchSubtask(taskId: UUID, subtaskId: UUID) {
        guard let store = todoStore,
              var todo = store.todos.first(where: { $0.id == taskId }),
              let idx = todo.subTasks.firstIndex(where: { $0.id == subtaskId }) else { return }
        todo.subTasks[idx].isCompleted.toggle()
        store.updateTodo(todo)
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

    // Gemeinsame Verarbeitung von Aktionen (sendMessage und transferUserInfo).
    // Gibt true zurück, wenn die Nachricht eine Aktion war.
    @discardableResult
    private func handleAction(_ payload: [String: Any]) -> Bool {
        if payload["requestSnapshot"] != nil {
            DispatchQueue.main.async { self.todoStore?.writeWidgetSnapshot() }
            return true
        }
        if let idString = payload["setTaskCompleted"] as? String, let id = UUID(uuidString: idString) {
            let completed = payload["completed"] as? Bool ?? true
            DispatchQueue.main.async { self.setWatchTask(id: id, completed: completed) }
            return true
        }
        if let idString = payload["completeTask"] as? String, let id = UUID(uuidString: idString) {
            DispatchQueue.main.async { self.completeWatchTask(id: id) }
            return true
        }
        if let taskString = payload["toggleSubtask"] as? String, let taskId = UUID(uuidString: taskString),
           let subString = payload["subtaskId"] as? String, let subId = UUID(uuidString: subString) {
            DispatchQueue.main.async { self.toggleWatchSubtask(taskId: taskId, subtaskId: subId) }
            return true
        }
        if let ml = payload["addWater"] as? Int {
            Task { @MainActor in self.handleAddWater(ml: ml) }
            return true
        }
        if let idString = payload["toggleHabit"] as? String, let id = UUID(uuidString: idString) {
            Task { @MainActor in self.handleToggleHabit(id: id) }
            return true
        }
        return false
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        print("[Phone] didReceiveMessage – keys=\(message.keys.joined(separator: ","))")
        handleAction(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["requestSnapshot"] != nil else { replyHandler([:]); return }
        print("[Phone] didReceiveMessage(replyHandler) – requestSnapshot empfangen")
        DispatchQueue.main.async {
            let cachedData = UserDefaults(suiteName: beeFocusAppGroup)?.data(forKey: "widgetSnapshot")
            print("[Phone] gecachter Snapshot: \(cachedData.map { "\($0.count) Bytes" } ?? "nil")")
            if let data = cachedData {
                replyHandler(["widgetSnapshot": data])
            } else {
                replyHandler([:])
            }
            self.todoStore?.writeWidgetSnapshot()
        }
    }

    // Aktionen + Snapshot-Anfragen via transferUserInfo (auch wenn iPhone nicht erreichbar war)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        print("[Phone] didReceiveUserInfo – keys=\(userInfo.keys.joined(separator: ","))")
        if userInfo["requestSnapshot"] != nil {
            DispatchQueue.main.async {
                self.todoStore?.writeWidgetSnapshot()
                // Snapshot auch direkt via transferUserInfo zurückschicken
                if let data = UserDefaults(suiteName: beeFocusAppGroup)?.data(forKey: "widgetSnapshot") {
                    self.sendSnapshotViaTransferUserInfo(data)
                }
            }
            return
        }
        handleAction(userInfo)
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
