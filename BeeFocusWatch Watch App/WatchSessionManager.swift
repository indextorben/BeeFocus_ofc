import Foundation
import WatchConnectivity
import Combine

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var snapshot: WatchSnapshot = .placeholder
    @Published var hasRealSnapshot: Bool = false

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
        hasRealSnapshot = true
    }

    private func saveLocalSnapshot(_ data: Data) {
        UserDefaults.standard.set(data, forKey: localKey)
    }

    private func applySnapshotData(_ data: Data) {
        guard let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        saveLocalSnapshot(data)
        DispatchQueue.main.async {
            self.snapshot = snap
            self.hasRealSnapshot = true
        }
    }

    // MARK: - WatchConnectivity

    private func setupSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestFreshSnapshot() {
        if WCSession.default.isReachable {
            // sendMessage mit replyHandler: iPhone schickt Snapshot direkt zurück
            WCSession.default.sendMessage(["requestSnapshot": true]) { [weak self] reply in
                if let data = reply["widgetSnapshot"] as? Data {
                    self?.applySnapshotData(data)
                }
            } errorHandler: { _ in }
        } else {
            // transferUserInfo: zugestellt sobald iPhone wieder läuft
            WCSession.default.transferUserInfo(["requestSnapshot": true])
        }
    }

    // MARK: - Watch → iPhone

    func completeTask(id: UUID) {
        let msg: [String: Any] = ["completeTask": id.uuidString]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }

    func addWater(ml: Int) {
        let msg: [String: Any] = ["addWater": ml]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
    }

    func toggleHabit(id: UUID) {
        let msg: [String: Any] = ["toggleHabit": id.uuidString]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(msg, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(msg)
        }
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

    // Nach Aktivierung: gecachten Kontext laden und frischen Snapshot anfordern
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        guard activationState == .activated else { return }
        if let data = WCSession.default.receivedApplicationContext["widgetSnapshot"] as? Data {
            applySnapshotData(data)
        }
        requestFreshSnapshot()
    }

    // iPhone wird erreichbar → sofort frischen Snapshot anfordern
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            requestFreshSnapshot()
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
