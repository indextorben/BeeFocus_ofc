import Foundation
import UserNotifications
import SwiftUI
import ActivityKit

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
    
    @Published var timeRemaining: TimeInterval = 0
    @Published var isRunning = false
    @Published var isBreak = false
    @Published var currentSession = 1
    
    private var timer: Timer?
    private var activity: Activity<TimerActivityAttributes>? // Live Activity
    
    @AppStorage("focusTime") var focusTime: Int = 25
    @AppStorage("shortBreakTime") var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") var sessionsUntilLongBreak: Int = 4
    
    private init() {
        restoreTimer()
    }
    
    func startNewSession() {
        stop()
        
        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak ? TimeInterval(longBreakTime * 60) : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)
        
        resume()
    }
    
    func resume() {
        guard !isRunning else { return }
        
        if timeRemaining <= 0 {
            startNewSession()
            return
        }
        
        isRunning = true
        startTimer()
        saveState()
        scheduleNotification()
    }
    
    func pause() {
        guard isRunning else { return }
        stopTimer()
        isRunning = false
        saveState()
        NotificationManager.shared.cancelTimerNotification()
        
        Task { await activity?.end(using: TimerActivityAttributes.ContentState(timeRemaining: timeRemaining, isBreak: isBreak, sessionNumber: currentSession, totalSessions: sessionsUntilLongBreak)) }
    }
    
    func pauseAndSave() {
        if isRunning {
            stopTimer()
            saveState()
            isRunning = false
            
            Task { await activity?.end(using: TimerActivityAttributes.ContentState(timeRemaining: timeRemaining, isBreak: isBreak, sessionNumber: currentSession, totalSessions: sessionsUntilLongBreak)) }
        }
    }
    
    func stop() {
        pause()
    }
    
    func reset() {
        stop()
        timeRemaining = isBreak
            ? (currentSession == sessionsUntilLongBreak ? TimeInterval(longBreakTime * 60) : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)
        saveState()
    }
    
    private func startTimer() {
        stopTimer()
        
        // Live Activity starten
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let initialState = TimerActivityAttributes.ContentState(timeRemaining: timeRemaining, isBreak: isBreak, sessionNumber: currentSession, totalSessions: sessionsUntilLongBreak)
            activity = try? Activity<TimerActivityAttributes>.request(
                attributes: TimerActivityAttributes(),
                contentState: initialState,
                pushType: nil
            )
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeRemaining -= 1
            
            Task {
                await self.activity?.update(using: TimerActivityAttributes.ContentState(timeRemaining: self.timeRemaining, isBreak: self.isBreak, sessionNumber: self.currentSession, totalSessions: self.sessionsUntilLongBreak))
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
        
        Task { await activity?.end(using: TimerActivityAttributes.ContentState(timeRemaining: 0, isBreak: self.isBreak, sessionNumber: currentSession, totalSessions: sessionsUntilLongBreak)) }
        
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
        
        let timeSinceSave = -savedState.lastSaveDate.timeIntervalSinceNow
        
        isRunning = false
        currentSession = savedState.currentSession
        isBreak = savedState.isBreak
        
        if savedState.isRunning {
            timeRemaining = max(0, savedState.remainingTime - timeSinceSave)
        } else {
            timeRemaining = savedState.remainingTime
        }
    }
    
    func forceComplete() {
        stop()
        timeRemaining = 0
        timerCompleted()
    }
    
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
