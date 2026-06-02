import Foundation
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var snapshot: WatchSnapshot = .placeholder

    // Watch-lokaler Speicher (nicht App Group – die ist gerätegebunden)
    private let localKey = "watchLocalSnapshot"

    private override init() {
        super.init()
        loadLocalSnapshot()
        setupSession()
    }

    // MARK: - Lokaler Snapshot (UserDefaults auf der Watch selbst)

    private func loadLocalSnapshot() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        snapshot = snap
    }

    private func saveLocalSnapshot(_ data: Data) {
        UserDefaults.standard.set(data, forKey: localKey)
    }

    private func applySnapshotData(_ data: Data) {
        guard let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        saveLocalSnapshot(data)
        DispatchQueue.main.async { self.snapshot = snap }
    }

    // MARK: - WatchConnectivity

    private func setupSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Watch → iPhone

    func completeTask(id: UUID) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["completeTask": id.uuidString], replyHandler: nil)
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

    // Neuer Snapshot vom iPhone empfangen
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["widgetSnapshot"] as? Data else { return }
        applySnapshotData(data)
    }

    // Nach Aktivierung: gecachten Kontext prüfen
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        if let data = WCSession.default.receivedApplicationContext["widgetSnapshot"] as? Data {
            applySnapshotData(data)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
