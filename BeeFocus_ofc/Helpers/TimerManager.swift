import Foundation
import UserNotifications
import SwiftUI
import ActivityKit
import UIKit

extension Notification.Name {
    static let focusSessionCompleted = Notification.Name("FocusSessionCompleted")
}

// MARK: - Persisted State
struct TimerState: Codable {
    var endDate: Date?
    var isRunning: Bool
    var currentSession: Int
    var isBreak: Bool
    var remainingTime: TimeInterval
    var lastSaveDate: Date
}

// MARK: - Live Activity
struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var isBreak: Bool
        var sessionNumber: Int
        var totalSessions: Int
    }
}

// MARK: - Timer Manager
final class TimerManager: ObservableObject {

    static let shared = TimerManager()

    // MARK: - Published
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var isBreak: Bool = false
    @Published var currentSession: Int = 1

    // MARK: - Internals
    private var timer: Timer?
    private var activity: Activity<TimerActivityAttributes>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Settings
    @AppStorage("focusTime") var focusTime: Int = 25
    @AppStorage("shortBreakTime") var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4

    private init() {
        restoreTimer()
    }

    // MARK: - 🔥 SETTINGS LIVE UPDATE
    func applyUpdatedSettingsIfNeeded() {
        guard !isRunning else { return }

        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak
                ? TimeInterval(longBreakTime * 60)
                : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)

        saveState()
    }

    // MARK: - Session Logic
    func startNewSession() {
        stopInternal()

        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak
                ? TimeInterval(longBreakTime * 60)
                : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)

        resume()
    }

    func resume() {
        if timeRemaining <= 0 {
            startNewSession()
            return
        }

        guard !isRunning else { return }

        isRunning = true
        startTimer()
        saveState()
        scheduleNotification()

        if backgroundTaskID == .invalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(
                withName: "PomodoroTimer"
            ) {
                self.endBackgroundTask()
            }
        }
    }

    func pause() {
        guard isRunning else { return }

        stopTimer()
        isRunning = false
        saveState()
        NotificationManager.shared.cancelTimerNotification()

        Task {
            await activity?.end(using: liveState())
        }

        endBackgroundTask()
    }

    func reset() {
        stopInternal()

        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak
                ? TimeInterval(longBreakTime * 60)
                : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)

        saveState()
    }

    func forceComplete() {
        stopInternal()
        timeRemaining = 0
        timerCompleted()
    }

    // MARK: - Timer Core
    private func startTimer() {
        stopTimer()

        if ActivityAuthorizationInfo().areActivitiesEnabled {
            activity = try? Activity.request(
                attributes: TimerActivityAttributes(),
                contentState: liveState()
            )
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isRunning else { return }

            self.timeRemaining -= 1

            Task {
                await self.activity?.update(using: self.liveState())
            }

            if self.timeRemaining <= 0 {
                self.timerCompleted()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func stopInternal() {
        stopTimer()
        isRunning = false
        NotificationManager.shared.cancelTimerNotification()
        endBackgroundTask()
    }

    private func timerCompleted() {
        guard timeRemaining <= 0 else { return }

        stopInternal()

        Task {
            await activity?.end(using: liveState(timeRemaining: 0))
        }

        if isBreak {
            currentSession = (currentSession % sessionsUntilLongBreak) + 1
            isBreak = false
        } else {
            isBreak = true
        }

        NotificationManager.shared.sendCompletionNotification(isBreak: isBreak)

        // Post focus session completion (minutes) when a work session ends
        if isBreak == true { // we just transitioned to break, meaning a focus session finished
            let workedSeconds: TimeInterval = TimeInterval(focusTime * 60)
            let workedMinutes = max(1, Int(workedSeconds / 60))
            NotificationCenter.default.post(name: .focusSessionCompleted, object: nil, userInfo: ["minutes": workedMinutes])
        }

        saveState()
        startNewSession()
    }

    // MARK: - Persistence
    func saveState() {
        let endDate = isRunning ? Date().addingTimeInterval(timeRemaining) : nil

        let state = TimerState(
            endDate: endDate,
            isRunning: isRunning,
            currentSession: currentSession,
            isBreak: isBreak,
            remainingTime: timeRemaining,
            lastSaveDate: Date()
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: "timerState")
        }
    }

    func restoreTimer() {
        guard
            let data = UserDefaults.standard.data(forKey: "timerState"),
            let saved = try? JSONDecoder().decode(TimerState.self, from: data)
        else {
            reset()
            return
        }

        currentSession = saved.currentSession
        isBreak = saved.isBreak

        if let endDate = saved.endDate {
            let remaining = endDate.timeIntervalSinceNow
            timeRemaining = max(0, remaining)
        } else {
            timeRemaining = saved.remainingTime
        }

        isRunning = false
    }

    // MARK: - Helpers
    private func liveState(timeRemaining: TimeInterval? = nil)
        -> TimerActivityAttributes.ContentState {
        .init(
            timeRemaining: timeRemaining ?? self.timeRemaining,
            isBreak: isBreak,
            sessionNumber: currentSession,
            totalSessions: sessionsUntilLongBreak
        )
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }

    // MARK: - Notifications
    private func scheduleNotification() {
        let title = isBreak ? "Pause beendet" : "Fokuszeit vorbei"
        let body = isBreak ? "Weiter geht's mit Fokus!" : "Zeit für eine Pause."

        NotificationManager.shared.scheduleTimerNotification(
            title: title,
            body: body,
            duration: timeRemaining
        )
    }
}
