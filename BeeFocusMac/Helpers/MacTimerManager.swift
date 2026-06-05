import Foundation
import SwiftUI
import Combine
import UserNotifications

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

enum TimerMode: String {
    case focus      = "Fokuszeit"
    case shortBreak = "Kurze Pause"
    case longBreak  = "Lange Pause"

    var color: Color {
        switch self {
        case .focus:      return .orange
        case .shortBreak: return Color(red: 0.2, green: 0.8, blue: 0.5)
        case .longBreak:  return Color(red: 0.3, green: 0.6, blue: 1.0)
        }
    }

    var displayName: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break"
        }
    }
}

@MainActor
final class MacTimerManager: ObservableObject {
    @Published var focusDuration:     Int = 25
    @Published var shortBreak:        Int = 5
    @Published var longBreak:         Int = 15
    @Published var sessionsUntilLong: Int = 4

    @Published var remaining:    Int = 0
    @Published var totalSeconds: Int = 0
    @Published var mode:         TimerMode = .focus
    @Published var isRunning:    Bool = false
    @Published var sessionCount: Int = 0

    @Published var autoStart:    Bool = true
    @Published var soundEnabled: Bool = true
    @Published var linkedTaskID: UUID? = nil

    init() {
        let ud = UserDefaults.standard
        focusDuration     = ud.integer(forKey: "mac_focusDuration").nonZero     ?? 25
        shortBreak        = ud.integer(forKey: "mac_shortBreak").nonZero        ?? 5
        longBreak         = ud.integer(forKey: "mac_longBreak").nonZero         ?? 15
        sessionsUntilLong = ud.integer(forKey: "mac_sessionsUntilLong").nonZero ?? 4
        sessionCount      = ud.integer(forKey: "mac_sessionCount")
        autoStart         = ud.object(forKey: "mac_autoStart")    == nil ? true  : ud.bool(forKey: "mac_autoStart")
        soundEnabled      = ud.object(forKey: "mac_soundEnabled") == nil ? true  : ud.bool(forKey: "mac_soundEnabled")
        if let idStr = ud.string(forKey: "mac_linkedTaskID") { linkedTaskID = UUID(uuidString: idStr) }

        let savedRemaining = ud.integer(forKey: "mac_remaining").nonZero ?? (focusDuration * 60)
        let savedMode      = TimerMode(rawValue: ud.string(forKey: "mac_mode") ?? "") ?? .focus
        mode         = savedMode
        remaining    = savedRemaining
        switch savedMode {
        case .focus:      totalSeconds = focusDuration * 60
        case .shortBreak: totalSeconds = shortBreak    * 60
        case .longBreak:  totalSeconds = longBreak     * 60
        }
    }

    private var timer: Timer? = nil

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remaining) / Double(totalSeconds)
    }

    var timeString: String {
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Controls

    func startPause() {
        if isRunning { pause() } else { start() }
    }

    func reset() {
        pause()
        remaining = totalSeconds
    }

    func skipToNext() {
        pause()
        advance(triggerAutoStart: false)
    }

    func applySettings() {
        guard !isRunning else { return }
        resetToCurrentMode()
        let ud = UserDefaults.standard
        ud.set(focusDuration,     forKey: "mac_focusDuration")
        ud.set(shortBreak,        forKey: "mac_shortBreak")
        ud.set(longBreak,         forKey: "mac_longBreak")
        ud.set(sessionsUntilLong, forKey: "mac_sessionsUntilLong")
        ud.set(autoStart,         forKey: "mac_autoStart")
        ud.set(soundEnabled,      forKey: "mac_soundEnabled")
    }

    // MARK: - Private

    private func start() {
        isRunning = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard remaining > 0 else {
            pause()
            sendCompletionNotification()
            advance(triggerAutoStart: true)
            return
        }
        remaining -= 1
        if remaining % 5 == 0 {
            let ud = UserDefaults.standard
            ud.set(remaining,               forKey: "mac_remaining")
            ud.set(mode.rawValue,           forKey: "mac_mode")
            ud.set(sessionCount,            forKey: "mac_sessionCount")
            ud.set(linkedTaskID?.uuidString, forKey: "mac_linkedTaskID")
        }
    }

    private func advance(triggerAutoStart: Bool) {
        switch mode {
        case .focus:
            sessionCount += 1
            if sessionCount % sessionsUntilLong == 0 {
                mode         = .longBreak
                totalSeconds = longBreak  * 60
            } else {
                mode         = .shortBreak
                totalSeconds = shortBreak * 60
            }
        case .shortBreak, .longBreak:
            mode         = .focus
            totalSeconds = focusDuration * 60
        }
        remaining = totalSeconds
        if triggerAutoStart && autoStart { start() }
    }

    private func sendCompletionNotification() {
        guard soundEnabled else { return }
        let content   = UNMutableNotificationContent()
        content.sound = .default
        switch mode {
        case .focus:
            content.title = "Fokuszeit vorbei! 🎉"
            content.body  = linkedTaskID != nil ? "Zeit für eine Pause." : "Zeit für eine kurze Pause."
        case .shortBreak:
            content.title = "Pause vorbei!"
            content.body  = "Weiter mit dem nächsten Fokusblock."
        case .longBreak:
            content.title = "Lange Pause vorbei!"
            content.body  = "\(sessionCount) Pomodoros geschafft. Weiter so!"
        }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false))
        )
    }

    func resetToCurrentMode() {
        pause()
        switch mode {
        case .focus:      totalSeconds = focusDuration * 60
        case .shortBreak: totalSeconds = shortBreak    * 60
        case .longBreak:  totalSeconds = longBreak     * 60
        }
        remaining = totalSeconds
    }
}
