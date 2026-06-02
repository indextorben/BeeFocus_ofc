import Foundation
import SwiftUI
import UserNotifications

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
}

@MainActor
final class MacTimerManager: ObservableObject {
    @AppStorage("mac_focusDuration")  var focusDuration:  Int = 25
    @AppStorage("mac_shortBreak")     var shortBreak:     Int = 5
    @AppStorage("mac_longBreak")      var longBreak:      Int = 15
    @AppStorage("mac_sessionsUntilLong") var sessionsUntilLong: Int = 4

    @Published private(set) var remaining:      Int = 25 * 60
    @Published private(set) var totalSeconds:   Int = 25 * 60
    @Published private(set) var mode:           TimerMode = .focus
    @Published private(set) var isRunning:      Bool = false
    @Published private(set) var sessionCount:   Int = 0

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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
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
            content.title = "Fokuszeit geschafft! 🎉"
            content.body  = "Gönn dir eine kurze Pause."
        case .shortBreak:
            content.title = "Pause vorbei!"
            content.body  = "Zeit für den nächsten Fokus-Block."
        case .longBreak:
            content.title = "Lange Pause vorbei!"
            content.body  = "Du hast \(sessionCount) Pomodoros abgeschlossen. Weiter so!"
        }
        let req = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Mode Switch Helpers

    func setFocusDuration(_ mins: Int) {
        focusDuration = mins
        if mode == .focus { resetToCurrentMode() }
    }

    func setShortBreak(_ mins: Int) {
        shortBreak = mins
        if mode == .shortBreak { resetToCurrentMode() }
    }

    func setLongBreak(_ mins: Int) {
        longBreak = mins
        if mode == .longBreak { resetToCurrentMode() }
    }

    private func resetToCurrentMode() {
        pause()
        switch mode {
        case .focus:       totalSeconds = focusDuration * 60
        case .shortBreak:  totalSeconds = shortBreak * 60
        case .longBreak:   totalSeconds = longBreak * 60
        }
        remaining = totalSeconds
    }
}
