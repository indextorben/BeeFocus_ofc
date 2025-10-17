import Foundation
import UserNotifications
import SwiftUI
import ActivityKit
import UIKit

struct TimerState: Codable {
    var endDate: Date?
    var isRunning: Bool
    var currentSession: Int
    var isBreak: Bool
    var remainingTime: TimeInterval
    var lastSaveDate: Date
}

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var isBreak: Bool
        var sessionNumber: Int
        var totalSessions: Int
    }
}

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    // MARK: - Published Properties
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var currentSession = 1
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var activity: Activity<TimerActivityAttributes>? // Live Activity
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - User Settings
    @AppStorage("focusTime") var focusTime: Int = 25
    @AppStorage("shortBreakTime") var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4
    
    private init() {
        restoreTimer()
    }
    
    // MARK: - Session Handling
    func startNewSession() {
        stop()
        
        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak
               ? TimeInterval(longBreakTime * 60)
               : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)
        
        resume()
    }
    
    func resume() {
        guard !isRunning else { return }
        guard timeRemaining > 0 else { return }

        isRunning = true
        startTimer()
        saveState()
        scheduleNotification()
        
        // Hintergrundtask aktivieren, solange App nicht geschlossen wird
        if backgroundTaskID == .invalid {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PomodoroTimer") {
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
            await activity?.end(using: TimerActivityAttributes.ContentState(
                timeRemaining: timeRemaining,
                isBreak: isBreak,
                sessionNumber: currentSession,
                totalSessions: sessionsUntilLongBreak
            ))
        }
        
        // ❌ Hintergrundlaufzeit beenden
        endBackgroundTask()
    }
    
    func stop() {
        pause()
    }
    
    func reset() {
        stop()
        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak
               ? TimeInterval(longBreakTime * 60)
               : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)
        saveState()
    }
    
    // MARK: - Timer Control
    private func startTimer() {
        stopTimer()
        
        // 🔵 Live Activity starten
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let initialState = TimerActivityAttributes.ContentState(
                timeRemaining: timeRemaining,
                isBreak: isBreak,
                sessionNumber: currentSession,
                totalSessions: sessionsUntilLongBreak
            )
            activity = try? Activity<TimerActivityAttributes>.request(
                attributes: TimerActivityAttributes(),
                contentState: initialState,
                pushType: nil
            )
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isRunning else { return } // ⛔️ Sicherheitscheck
            
            self.timeRemaining -= 1
            
            Task {
                await self.activity?.update(using: TimerActivityAttributes.ContentState(
                    timeRemaining: self.timeRemaining,
                    isBreak: self.isBreak,
                    sessionNumber: self.currentSession,
                    totalSessions: self.sessionsUntilLongBreak
                ))
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
    
    private func timerCompleted() {
        stop()
        
        Task {
            await activity?.end(using: TimerActivityAttributes.ContentState(
                timeRemaining: 0,
                isBreak: self.isBreak,
                sessionNumber: currentSession,
                totalSessions: sessionsUntilLongBreak
            ))
        }
        
        if isBreak {
            currentSession = (currentSession % sessionsUntilLongBreak) + 1
            isBreak = false
        } else {
            isBreak = true
        }
        
        NotificationManager.shared.sendCompletionNotification(isBreak: isBreak)
        saveState()
        startNewSession()
    }
    
    // MARK: - State Management
    func pauseAndSave() {
        if isRunning {
            stopTimer()
            saveState()
            isRunning = false
            
            Task {
                await activity?.end(using: TimerActivityAttributes.ContentState(
                    timeRemaining: timeRemaining,
                    isBreak: isBreak,
                    sessionNumber: currentSession,
                    totalSessions: sessionsUntilLongBreak
                ))
            }
        }
        endBackgroundTask()
    }
    
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
        guard let data = UserDefaults.standard.data(forKey: "timerState"),
              let savedState = try? JSONDecoder().decode(TimerState.self, from: data) else {
            reset()
            return
        }

        currentSession = savedState.currentSession
        isBreak = savedState.isBreak
        timeRemaining = savedState.remainingTime
        isRunning = false // Timer läuft erst nach Startbutton
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
    
    func forceComplete() {
        stop()
        timeRemaining = 0
        timerCompleted()
    }
}
