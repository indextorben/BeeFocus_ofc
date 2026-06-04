import Foundation
import SwiftUI
import Combine
import UserNotifications

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

enum TimerMode: String {
    case focus     = "Fokuszeit"
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
        case .focus:       return "Focus"
        case .shortBreak:  return "Short Break"
        case .longBreak:   return "Long Break"
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

    init() {
        let ud = UserDefaults.standard
        focusDuration     = ud.integer(forKey: "mac_focusDuration").nonZero     ?? 25
        shortBreak        = ud.integer(forKey: "mac_shortBreak").nonZero        ?? 5
        longBreak         = ud.integer(forKey: "mac_longBreak").nonZero         ?? 15
        sessionsUntilLong = ud.integer(forKey: "mac_sessionsUntilLong").nonZero ?? 4
        sessionCount      = ud.integer(forKey: "mac_sessionCount")

        // Restore last saved remaining time (if app was quit while running)
        let savedRemaining = ud.integer(forKey: "mac_remaining").nonZero ?? (focusDuration * 60)
        let savedMode      = TimerMode(rawValue: ud.string(forKey: "mac_mode") ?? "") ?? .focus
        mode         = savedMode
        totalSeconds = savedRemaining  // will be recalculated when mode matches
        remaining    = savedRemaining

        // Recalculate total for current mode
        switch savedMode {
        case .focus:      totalSeconds = focusDuration * 60
        case .shortBreak: totalSeconds = shortBreak * 60
        case .longBreak:  totalSeconds = longBreak * 60
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
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func reset() {
        pause()
        remaining    = totalSeconds
    }

    func skipToNext() {
        pause()
        advance()
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
            sendCompletionNotification()
            advance()
            return
        }
        remaining -= 1
        // Persist state every 5 seconds so the menu bar survives app restarts
        if remaining % 5 == 0 {
            let ud = UserDefaults.standard
            ud.set(remaining, forKey: "mac_remaining")
            ud.set(mode.rawValue, forKey: "mac_mode")
            ud.set(sessionCount, forKey: "mac_sessionCount")
        }
    }

    private func advance() {
        switch mode {
        case .focus:
            sessionCount += 1
            if sessionCount % sessionsUntilLong == 0 {
                mode         = .longBreak
                totalSeconds = longBreak * 60
            } else {
                mode         = .shortBreak
                totalSeconds = shortBreak * 60
            }
        case .shortBreak, .longBreak:
            mode         = .focus
            totalSeconds = focusDuration * 60
        }
        remaining = totalSeconds
        start()
    }

    private func sendCompletionNotification() {
        let content      = UNMutableNotificationContent()
        content.sound    = .default
        switch mode {
        case .focus:
            content.title = "Focus session done! 🎉"
            content.body  = "Time for a short break."
        case .shortBreak:
            content.title = "Break over!"
            content.body  = "Time for the next focus block."
        case .longBreak:
            content.title = "Long break over!"
            content.body  = "You've completed \(sessionCount) Pomodoros. Keep it up!"
        }
        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }


    func resetToCurrentMode() {
        pause()
        switch mode {
        case .focus:       totalSeconds = focusDuration * 60
        case .shortBreak:  totalSeconds = shortBreak * 60
        case .longBreak:   totalSeconds = longBreak * 60
        }
        remaining = totalSeconds
    }
}
