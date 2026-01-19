import SwiftUI
import UserNotifications

struct TimerView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var todoStore: TodoStore

    @AppStorage("focusTime") private var focusTime: Int = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") private var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") private var sessionsUntilLongBreak: Int = 2

    @State private var showingNotificationAlert = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false

    @ObservedObject private var localizer = LocalizationManager.shared

    // MARK: - Computed

    var sessionDisplay: String {
        let displaySession = min(timerManager.currentSession, sessionsUntilLongBreak)
        return "\(displaySession)/\(sessionsUntilLongBreak)"
    }

    var progress: Double {
        let totalTime = timerManager.isBreak
            ? (timerManager.currentSession == sessionsUntilLongBreak
                ? TimeInterval(longBreakTime * 60)
                : TimeInterval(shortBreakTime * 60))
            : TimeInterval(focusTime * 60)

        guard totalTime > 0 else { return 0 }
        return 1 - (timerManager.timeRemaining / totalTime)
    }

    // MARK: - UI

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    timerManager.isBreak ? .green.opacity(0.3) : .blue.opacity(0.3),
                    timerManager.isBreak ? .mint.opacity(0.3) : .purple.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 30) {

                header

                focusTodayBanner

                ZStack {
                    TimerProgressCircle(progress: progress)
                    TimerDisplay(
                        timeRemaining: timerManager.timeRemaining,
                        isRunning: timerManager.isRunning
                    )
                }

                Text(timerManager.isBreak
                     ? localizer.localizedString(forKey: "timer_break")
                     : "\(localizer.localizedString(forKey: "timer_focus_session")) \(sessionDisplay)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                controls
            }
            .padding()
        }
        .alert(localizer.localizedString(forKey: "timer_skip_alert_title"), isPresented: $showingSkipConfirmation) {
            Button(localizer.localizedString(forKey: "timer_skip"), role: .destructive) {
                timerManager.forceComplete()
            }
            Button(localizer.localizedString(forKey: "timer_cancel"), role: .cancel) { }
        }

        .onAppear {
            NotificationManager.shared.requestAuthorization { granted in
                if !granted {
                    showingNotificationAlert = true
                }
            }
        }

        .onChange(of: scenePhase) { phase in
            if phase == .background {
                timerManager.saveState()
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

        .alert(localizer.localizedString(forKey: "timer_notification_title"), isPresented: $showingNotificationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(localizer.localizedString(forKey: "timer_notification_message"))
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Button(action: openSpotify) {
                Image(systemName: "music.note")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.green)
                    .clipShape(Circle())
            }

            Spacer()

            Button {
                showingSkipConfirmation = true
            } label: {
                Image(systemName: "forward.fill")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.gray.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
    }

    private var controls: some View {
        HStack(spacing: 40) {

            TimerControlButton(
                systemName: "arrow.clockwise",
                size: 24,
                action: { timerManager.reset() },
                isPrimary: false
            )

            TimerControlButton(
                systemName: timerManager.isRunning ? "pause.fill" : "play.fill",
                size: 30,
                action: {
                    timerManager.isRunning
                        ? timerManager.pause()
                        : timerManager.resume()
                },
                isPrimary: true
            )

            TimerControlButton(
                systemName: "gearshape.fill",
                size: 24,
                action: { showingSettings = true },
                isPrimary: false
            )
        }
    }

    private func openSpotify() {
        guard let url = URL(string: "spotify:"),
              UIApplication.shared.canOpenURL(url)
        else { return }

        UIApplication.shared.open(url)
    }
    
    private var focusTodayBanner: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let minutes = todoStore.dailyFocusMinutes[today] ?? 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
        formatter.dateFormat = "EEEE, d. MMM yyyy"
        let dateText = formatter.string(from: Date())
        return HStack(spacing: 8) {
            Image(systemName: "flame.fill").foregroundColor(.orange)
            Text("\(dateText) · \(minutes) \(localizer.localizedString(forKey: "minutes_short"))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

