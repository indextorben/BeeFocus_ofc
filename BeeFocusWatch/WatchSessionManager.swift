import Foundation
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var snapshot: WatchSnapshot = .placeholder

    private let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")

    private override init() {
        super.init()
        loadSnapshot()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func loadSnapshot() {
        guard let data = defaults?.data(forKey: "widgetSnapshot"),
              let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        DispatchQueue.main.async { self.snapshot = snap }
    }

    func completeTask(id: UUID) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["completeTask": id.uuidString], replyHandler: nil)
        }
        var pending = defaults?.stringArray(forKey: "watchPendingCompletions") ?? []
        guard !pending.contains(id.uuidString) else { return }
        pending.append(id.uuidString)
        defaults?.set(pending, forKey: "watchPendingCompletions")
    }

    func addWater(ml: Int) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["addWater": ml], replyHandler: nil)
    }

    func toggleHabit(id: UUID) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["toggleHabit": id.uuidString], replyHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: @preconcurrency WCSessionDelegate {
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["widgetSnapshot"] as? Data,
              let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        DispatchQueue.main.async { self.snapshot = snap }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let data = WCSession.default.receivedApplicationContext["widgetSnapshot"] as? Data,
           let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) {
            DispatchQueue.main.async { self.snapshot = snap }
        } else {
            DispatchQueue.main.async { self.loadSnapshot() }
        }
    }
}
