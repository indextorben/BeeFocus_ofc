import SwiftUI

@main
struct BeeFocusMacApp: App {
    @StateObject private var todoStore   = MacTodoStore()
    @StateObject private var timerMgr    = MacTimerManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(todoStore)
                .environmentObject(timerMgr)
                .frame(width: 360)
        } label: {
            MenuBarLabel()
                .environmentObject(timerMgr)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Dynamisches Menübar-Icon: Uhr läuft → zeigt Countdown
private struct MenuBarLabel: View {
    @EnvironmentObject var timerMgr: MacTimerManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hexagon.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(timerMgr.isRunning ? .orange : .primary)
            if timerMgr.isRunning {
                Text(timerMgr.timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.orange)
            }
        }
    }
}
