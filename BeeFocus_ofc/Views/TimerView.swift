import SwiftUI
import UserNotifications

struct TimerView: View {
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var timerManager = TimerManager.shared
    
    @AppStorage("focusTime") private var focusTime: Int = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") private var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") private var sessionsUntilLongBreak: Int = 2
    
    @State private var showingNotificationAlert = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false
    
    var sessionDisplay: String {
        if timerManager.isBreak {
            if timerManager.currentSession > sessionsUntilLongBreak {
                return "1/\(sessionsUntilLongBreak)"
            }
            return "\(timerManager.currentSession)/\(sessionsUntilLongBreak)"
        } else {
            let displaySession = min(timerManager.currentSession, sessionsUntilLongBreak)
            return "\(displaySession)/\(sessionsUntilLongBreak)"
        }
    }
    
    var progress: Double {
        let totalTime = timerManager.isBreak
            ? (timerManager.currentSession == sessionsUntilLongBreak
               ? TimeInterval(longBreakTime * 60)
               : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)
        
        return 1 - (timerManager.timeRemaining / totalTime)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    timerManager.isBreak ? Color.green.opacity(0.3) : Color.blue.opacity(0.3),
                    timerManager.isBreak ? Color.mint.opacity(0.3) : Color.purple.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                HStack {
                    Spacer()
                    Button(action: {
                        showingSkipConfirmation = true
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.gray.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                }
                
                ZStack {
                    TimerProgressCircle(progress: progress)
                    TimerDisplay(timeRemaining: timerManager.timeRemaining, isRunning: timerManager.isRunning)
                }
                
                Text(timerManager.isBreak ? "Pause" : "Fokus-Session \(sessionDisplay)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 40) {
                    TimerControlButton(systemName: "arrow.clockwise", size: 24, action: {
                        timerManager.reset()
                        NotificationManager.shared.cancelTimerNotification()
                    }, isPrimary: false)
                    
                    TimerControlButton(systemName: timerManager.isRunning ? "pause.fill" : "play.fill", size: 30, action: toggleTimer, isPrimary: true)
                    
                    TimerControlButton(systemName: "gearshape.fill", size: 24, action: {
                        showingSettings = true
                    }, isPrimary: false)
                }
            }
            .padding()
        }
        .alert("Aktuelle Phase überspringen?", isPresented: $showingSkipConfirmation) {
            Button("Überspringen", role: .destructive) {
                timerManager.forceComplete()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Möchten Sie die aktuelle \(timerManager.isBreak ? "Pause" : "Fokus-Session") wirklich überspringen?")
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization { granted in
                if !granted {
                    showingNotificationAlert = true
                }
            }
            timerManager.restoreTimer()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                timerManager.pauseAndSave()
            case .active:
                timerManager.restoreTimer()
            @unknown default:
                break
            }
        }
        .sheet(isPresented: $showingSettings) {
            PomodoroSettingsView(
                focusTime: $focusTime,
                shortBreakTime: $shortBreakTime,
                longBreakTime: $longBreakTime,
                sessionsUntilLongBreak: $sessionsUntilLongBreak
            )
        }
        .alert("Benachrichtigungen", isPresented: $showingNotificationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Bitte erlauben Sie Benachrichtigungen in den Einstellungen.")
        }
    }
    
    private func toggleTimer() {
        if timerManager.isRunning {
            timerManager.pause()
        } else {
            timerManager.resume()
        }
    }
}
