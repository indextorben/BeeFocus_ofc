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
    private var plannedFocusDuration: TimeInterval = 0
    private var elapsedFocusSeconds: TimeInterval = 0
    private var nextLiveMinuteThreshold: TimeInterval = 60
    private var timer: Timer?
    private var timerTask: Task<Void, Never>?
    private var activity: Activity<TimerActivityAttributes>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Settings
    @AppStorage("focusTime") var focusTime: Int = 25
    @AppStorage("shortBreakTime") var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4

    private init() {
        restoreTimer()
        
        // Listen for memory warnings to save state
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.saveState()
        }
    }
    
    deinit {
        stopTimer()
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
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

        // Track planned focus duration only for focus sessions
        if !isBreak {
            plannedFocusDuration = timeRemaining
        } else {
            plannedFocusDuration = 0
        }

        // Reset live minute tracking
        if !isBreak {
            elapsedFocusSeconds = 0
            nextLiveMinuteThreshold = 60
        } else {
            elapsedFocusSeconds = 0
            nextLiveMinuteThreshold = 60
        }

        print("▶️ New session started (isBreak=\(isBreak)), plannedFocusDuration=\(plannedFocusDuration)s")

        resume()
    }

    func resume() {
        if timeRemaining <= 0 {
            startNewSession()
            return
        }

        guard !isRunning else { return }

        isRunning = true

        // Ensure planned focus duration is set when resuming a focus session
        if !isBreak && plannedFocusDuration <= 0 {
            // If restoring, planned duration is the remaining time at resume start
            plannedFocusDuration = max(timeRemaining, TimeInterval(focusTime * 60))
        }

        if !isBreak && elapsedFocusSeconds <= 0 {
            // Start counting from 0 for live accumulation when resuming
            elapsedFocusSeconds = max(0, plannedFocusDuration - timeRemaining)
            // Align next threshold to the next full minute boundary
            let remainder = elapsedFocusSeconds.truncatingRemainder(dividingBy: 60)
            nextLiveMinuteThreshold = remainder == 0 ? 60 : (60 - remainder)
        }

        startTimer()
        saveState()
        print("🔔 Scheduling timer notification with duration=\(timeRemaining)s (isBreak=\(isBreak))")
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
        let wasFocus = !isBreak
        stopInternal()
        // timeRemaining is whatever remained at force moment; keep it for calculation
        // Count worked minutes if we were in a focus session
        if wasFocus {
            postWorkedMinutesIfNeeded()
        }
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

        // Use modern Swift Concurrency for timer instead of Foundation Timer
        timerTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled && self.isRunning {
                // Sleep for 1 second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Check if cancelled during sleep
                guard !Task.isCancelled else { break }
                
                // Update on main actor
                await MainActor.run { [weak self] in
                    guard let self = self, self.isRunning else { return }
                    
                    self.timeRemaining -= 1

                    // Live minute accumulation during focus sessions
                    if self.isRunning && !self.isBreak {
                        self.elapsedFocusSeconds += 1
                        if self.elapsedFocusSeconds >= self.nextLiveMinuteThreshold {
                            // Post +1 minute and move threshold forward by 60s
                            print("🟢 Live minute tick: +1 (elapsed=\(self.elapsedFocusSeconds)s)")
                            NotificationCenter.default.post(name: .focusSessionCompleted, object: nil, userInfo: ["minutes": 1])
                            self.nextLiveMinuteThreshold += 60
                        }
                    }

                    Task {
                        await self.activity?.update(using: self.liveState())
                    }

                    if self.timeRemaining <= 0 {
                        self.timerCompleted()
                    }
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerTask?.cancel()
        timerTask = nil
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

        // Post focus session completion (minutes) when a work session ends, using actual worked time
        if isBreak == true { // we just transitioned to break, meaning a focus session finished
            postWorkedMinutesIfNeeded()
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
        guard backgroundTaskID != .invalid else { return }
        
        let taskID = backgroundTaskID
        backgroundTaskID = .invalid
        
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    private func postWorkedMinutesIfNeeded() {
        // Only count when a focus session has been running
        guard !isBreak else { return }

        // Compute actually worked seconds as planned minus remaining
        let workedSeconds = max(0, plannedFocusDuration - timeRemaining)

        // Compute remainder under 60s that hasn't been posted live yet
        let remainder = workedSeconds.truncatingRemainder(dividingBy: 60)
        var roundedRemainderMinutes = 0
        if remainder >= 30 { roundedRemainderMinutes = 1 }

        if roundedRemainderMinutes > 0 {
            print("⏱️ Posting remainder minute due to completion: remainderSeconds=\(remainder), +\(roundedRemainderMinutes) min")
            NotificationCenter.default.post(name: .focusSessionCompleted, object: nil, userInfo: ["minutes": roundedRemainderMinutes])
        } else {
            print("⏱️ No remainder minute to post (remainderSeconds=\(remainder))")
        }

        // Reset trackers after posting to avoid double counting
        plannedFocusDuration = 0
        elapsedFocusSeconds = 0
        nextLiveMinuteThreshold = 60
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

