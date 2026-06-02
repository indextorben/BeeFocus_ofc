import SwiftUI
import UserNotifications

@main
struct BeeFocusMacApp: App {
    @StateObject private var todoStore = MacTodoStore()
    @StateObject private var timerMgr  = MacTimerManager()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

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

private struct MenuBarLabel: View {
    @EnvironmentObject var timerMgr: MacTimerManager

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "hexagon.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(timerMgr.isRunning ? Color.orange : Color.primary)
            if timerMgr.isRunning {
                Text(timerMgr.timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.orange)
            }
        }
    }
}
