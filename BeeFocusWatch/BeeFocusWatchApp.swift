import SwiftUI

@main
struct BeeFocusWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        WatchSessionManager.shared.requestFreshSnapshot()
                    }
                }
        }
    }
}
