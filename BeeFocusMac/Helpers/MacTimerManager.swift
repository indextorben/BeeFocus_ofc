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

    // Daily focus seconds: ["yyyy-MM-dd": seconds]
    @Published private(set) var dailyFocusSeconds: [String: Int] = [:]

    // MARK: - Focus Time Computed

    private func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    var todayFocusSeconds: Int {
        let stored = dailyFocusSeconds[dayKey()] ?? 0
        guard isRunning, mode == .focus else { return stored }
        return stored + (totalSeconds - remaining)
    }

    var weekFocusSeconds: Int {
        let cal = Calendar.current
        let base = (0..<7).compactMap { i -> Int? in
            guard let day = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            return i == 0 ? (dailyFocusSeconds[dayKey()] ?? 0) : (dailyFocusSeconds[dayKey(day)] ?? 0)
        }.reduce(0, +)
        return base + (isRunning && mode == .focus ? (totalSeconds - remaining) : 0)
    }

    var lastWeekFocusSeconds: Int {
        let cal = Calendar.current
        return (7..<14).compactMap { i -> Int? in
            guard let day = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            return dailyFocusSeconds[dayKey(day)]
        }.reduce(0, +)
    }

    var last7DaysData: [(date: Date, seconds: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { i -> (Date, Int)? in
            guard let day = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            let secs = i == 0 ? todayFocusSeconds : (dailyFocusSeconds[dayKey(day)] ?? 0)
            return (day, secs)
        }
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: Date())
        if todayFocusSeconds == 0 {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        for _ in 0..<365 {
            let hasFocus = (dailyFocusSeconds[dayKey(date)] ?? 0) > 0
                || (cal.isDateInToday(date) && todayFocusSeconds > 0)
            if hasFocus {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else { break }
        }
        return streak
    }

    var allTimeFocusSeconds: Int {
        dailyFocusSeconds.values.reduce(0, +) + (isRunning && mode == .focus ? (totalSeconds - remaining) : 0)
    }

    var activeFocusDays: Int { dailyFocusSeconds.filter { $0.value > 0 }.count }

    var bestDaySeconds: Int { dailyFocusSeconds.values.max() ?? 0 }

    private func loadDailyFocusSeconds() {
        guard let data = UserDefaults.standard.data(forKey: "mac_dailyFocusSeconds"),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
        dailyFocusSeconds = dict
    }

    private func saveDailyFocusSeconds() {
        guard let data = try? JSONEncoder().encode(dailyFocusSeconds) else { return }
        UserDefaults.standard.set(data, forKey: "mac_dailyFocusSeconds")
    }

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
        loadDailyFocusSeconds()

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
            // Record completed focus session
            dailyFocusSeconds[dayKey(), default: 0] += focusDuration * 60
            saveDailyFocusSeconds()
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
