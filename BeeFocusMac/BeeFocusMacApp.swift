import SwiftUI
import UserNotifications

@main
struct BeeFocusMacApp: App {
    @StateObject private var todoStore = MacTodoStore()
    @StateObject private var timerMgr  = MacTimerManager()
    @StateObject private var subManager = MacSubscriptionManager()
    @AppStorage("aktivesStatistikThema") private var activeTheme: String = ""

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        Window("BeeFocus", id: "main") {
            MacMainWindowView()
                .environmentObject(todoStore)
                .environmentObject(timerMgr)
                .environmentObject(subManager)
                .environment(\.activeTheme, activeTheme)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 660)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(todoStore)
                .environmentObject(timerMgr)
                .environmentObject(subManager)
                .environment(\.activeTheme, activeTheme)
                .frame(width: 300)
        } label: {
            MenuBarLabel()
                .environmentObject(timerMgr)
                .environment(\.activeTheme, activeTheme)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @EnvironmentObject var timerMgr: MacTimerManager
    @Environment(\.activeTheme)  private var activeTheme

    private var accent: Color {
        timerMgr.isRunning ? timerMgr.mode.color : (activeTheme.isEmpty ? .orange : activeTheme.themeAccent)
    }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: timerMgr.isRunning ? timerMgr.progress : 0)
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerMgr.progress)
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(timerMgr.isRunning ? accent : accent.opacity(0.8))
            }
            .frame(width: 16, height: 16)

            if timerMgr.isRunning {
                Text(timerMgr.timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
            }
        }
    }
}
