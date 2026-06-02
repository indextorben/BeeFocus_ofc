import SwiftUI
import UserNotifications

struct MacSettingsView: View {
    @EnvironmentObject var timerMgr: MacTimerManager

    @AppStorage("mac_soundEnabled")       private var soundEnabled      = true
    @AppStorage("mac_autoStartBreaks")    private var autoStartBreaks   = false
    @AppStorage("mac_notifyOnComplete")   private var notifyOnComplete  = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsSection("Timer-Einstellungen", icon: "timer") {
                    settingRow("Fokuszeit") {
                        Stepper("\(timerMgr.focusDuration) min", value: $timerMgr.focusDuration, in: 5...90)
                            .onChange(of: timerMgr.focusDuration) { v in
                                UserDefaults.standard.set(v, forKey: "mac_focusDuration")
                                if timerMgr.mode == .focus { timerMgr.resetToCurrentMode() }
                            }
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Kurze Pause") {
                        Stepper("\(timerMgr.shortBreak) min", value: $timerMgr.shortBreak, in: 1...30)
                            .onChange(of: timerMgr.shortBreak) { v in
                                UserDefaults.standard.set(v, forKey: "mac_shortBreak")
                                if timerMgr.mode == .shortBreak { timerMgr.resetToCurrentMode() }
                            }
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Lange Pause") {
                        Stepper("\(timerMgr.longBreak) min", value: $timerMgr.longBreak, in: 5...60)
                            .onChange(of: timerMgr.longBreak) { v in
                                UserDefaults.standard.set(v, forKey: "mac_longBreak")
                                if timerMgr.mode == .longBreak { timerMgr.resetToCurrentMode() }
                            }
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Sitzungen bis lange Pause") {
                        Stepper("\(timerMgr.sessionsUntilLong)", value: $timerMgr.sessionsUntilLong, in: 2...8)
                            .onChange(of: timerMgr.sessionsUntilLong) { v in
                                UserDefaults.standard.set(v, forKey: "mac_sessionsUntilLong")
                            }
                    }
                }

                settingsSection("Benachrichtigungen", icon: "bell.fill") {
                    settingRow("Benachrichtigung bei Phasenwechsel") {
                        Toggle("", isOn: $notifyOnComplete).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Ton abspielen") {
                        Toggle("", isOn: $soundEnabled).labelsHidden()
                    }
                }

                settingsSection("Verhalten", icon: "gearshape") {
                    settingRow("Pause automatisch starten") {
                        Toggle("", isOn: $autoStartBreaks).labelsHidden()
                    }
                }

                settingsSection("Berechtigungen", icon: "lock.shield") {
                    Button("Benachrichtigungen erlauben") {
                        UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func settingRow<T: View>(_ label: String, @ViewBuilder control: () -> T) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
            Spacer()
            control()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
