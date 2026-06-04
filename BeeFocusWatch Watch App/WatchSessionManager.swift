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
        print("[Watch] applySnapshotData: \(data.count) Bytes")
        guard let snap = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else {
            print("[Watch] applySnapshotData: Dekodierung fehlgeschlagen")
            return
        }
        print("[Watch] Snapshot decoded – planTasks=\(snap.planTasks.count) todayBausteine=\(snap.todayBausteine.count) monthTasks=\(snap.monthTasks.count)")
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
        print("[Watch] requestFreshSnapshot – isReachable=\(WCSession.default.isReachable)")
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(["requestSnapshot": true]) { [weak self] reply in
                print("[Watch] sendMessage reply erhalten – keys=\(reply.keys.joined(separator: ","))")
                if let data = reply["widgetSnapshot"] as? Data {
                    self?.applySnapshotData(data)
                } else {
                    print("[Watch] sendMessage reply enthält keinen widgetSnapshot")
                }
            } errorHandler: { error in
                print("[Watch] sendMessage errorHandler: \(error.localizedDescription)")
            }
        } else {
            print("[Watch] nicht erreichbar → transferUserInfo")
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
        print("[Watch] didReceiveApplicationContext – keys=\(applicationContext.keys.joined(separator: ","))")
        guard let data = applicationContext["widgetSnapshot"] as? Data else { return }
        applySnapshotData(data)
    }

    // Nach Aktivierung: gecachten Kontext laden und frischen Snapshot anfordern
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("[Watch] activationDidCompleteWith state=\(activationState.rawValue) error=\(error?.localizedDescription ?? "nil")")
        guard activationState == .activated else { return }
        let ctx = WCSession.default.receivedApplicationContext
        print("[Watch] receivedApplicationContext keys=\(ctx.keys.joined(separator: ","))")
        if let data = ctx["widgetSnapshot"] as? Data {
            applySnapshotData(data)
        }
        requestFreshSnapshot()
    }

    // iPhone wird erreichbar → sofort frischen Snapshot anfordern
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[Watch] sessionReachabilityDidChange isReachable=\(session.isReachable)")
        if session.isReachable {
            requestFreshSnapshot()
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    #endif
}
