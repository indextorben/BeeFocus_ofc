import Foundation
import Combine
import WatchConnectivity

private let appGroupID  = "group.com.TorbenLehneke.BeeFocus-ofc"
private let snapshotKey = "widgetSnapshot"

// App-Group-Schlüssel für ausstehende Watch-Aktionen (Relay zur Haupt-App)
private let pendingCompletionsKey  = "pendingWatchCompletions"
private let pendingWaterKey        = "pendingWatchWaterMl"
®private let pendingHabitTogglesKey = "pendingWatchHabitToggles"

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var snapshot: WatchSnapshot = .placeholder
    @Published var hasRealSnapshot: Bool = false

    private override init() {
        super.init()
        setupWCSession()
        loadAndForward()
    }

    func requestFreshSnapshot() {
        loadAndForward()
    }

    // Lädt Snapshot aus der App Group, zeigt ihn lokal + leitet ihn an die Watch weiter
    private func loadAndForward() {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: snapshotKey),
            let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        else { return }

        DispatchQueue.main.async {
            self.snapshot = snap
            self.hasRealSnapshot = true
        }
        sendToWatch(data)
    }

    private func sendToWatch(_ data: Data) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext([snapshotKey: data])
    }

    private func setupWCSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Stubs – kein direkter Effekt in der Vorschau-App
    func completeTask(id: UUID) {}
    func addWater(ml: Int) {}
    func toggleHabit(id: UUID) {}

    // MARK: - Pending-Aktionen in App Group speichern

    private func queueCompletion(_ id: UUID) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var pending = defaults.stringArray(forKey: pendingCompletionsKey) ?? []
        pending.append(id.uuidString)
        defaults.set(pending, forKey: pendingCompletionsKey)
    }

    private func queueWater(ml: Int) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var pending = (defaults.array(forKey: pendingWaterKey) as? [Int]) ?? []
        pending.append(ml)
        defaults.set(pending, forKey: pendingWaterKey)
    }

    private func queueHabitToggle(_ id: UUID) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        var pending = defaults.stringArray(forKey: pendingHabitTogglesKey) ?? []
        pending.append(id.uuidString)
        defaults.set(pending, forKey: pendingHabitTogglesKey)
    }
}

extension WatchSessionManager: @preconcurrency WCSessionDelegate {

    // Watch sendet Aktionen → in App Group queuen, Haupt-App liest beim nächsten Start
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let idString = message["completeTask"] as? String, let id = UUID(uuidString: idString) {
            queueCompletion(id)
        } else if let ml = message["addWater"] as? Int {
            queueWater(ml: ml)
        } else if let idString = message["toggleHabit"] as? String, let id = UUID(uuidString: idString) {
            queueHabitToggle(id)
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        DispatchQueue.main.async { self.loadAndForward() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
