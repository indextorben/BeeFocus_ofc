import SwiftUI
import UserNotifications

struct TimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var todoStore: TodoStore

    @AppStorage("focusTime") private var focusTime: Int = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Int = 5
    @AppStorage("longBreakTime") private var longBreakTime: Int = 15
    @AppStorage("sessionsUntilLongBreak") private var sessionsUntilLongBreak: Int = 2

    @State private var showingNotificationAlert = false
    @State private var showingSettings = false
    @State private var showingSkipConfirmation = false
    @State private var appeared = false

    @StateObject private var notifDelegate = TimerNotificationDelegate()
    @ObservedObject private var localizer = LocalizationManager.shared

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Computed

    var sessionDisplay: String {
        "\(min(timerManager.currentSession, sessionsUntilLongBreak))/\(sessionsUntilLongBreak)"
    }

    var progress: Double {
        let total = timerManager.isBreak
            ? TimeInterval((timerManager.currentSession == sessionsUntilLongBreak ? longBreakTime : shortBreakTime) * 60)
            : TimeInterval(focusTime * 60)
        guard total > 0 else { return 0 }
        return 1 - (timerManager.timeRemaining / total)
    }

    var accentColors: [Color] {
        timerManager.isBreak ? [.green, .mint] : [.purple, .blue]
    }

    var accentColor: Color { accentColors[0] }

    var modeLabel: String {
        timerManager.isBreak
            ? localizer.localizedString(forKey: "timer_break")
            : "\(localizer.localizedString(forKey: "timer_focus_session")) \(sessionDisplay)"
    }

    var focusTodayMinutes: Int {
        todoStore.dailyFocusMinutes[Calendar.current.startOfDay(for: Date())] ?? 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer()

                // Focus today banner
                focusBanner
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                Spacer().frame(height: 32)

                // Timer ring
                timerRing
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.05), value: appeared)

                Spacer().frame(height: 28)

                // Mode label
                modeBadge
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

                Spacer().frame(height: 36)

                // Controls
                controls
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.30), value: appeared)

                Spacer()
            }
        }
        .alert(localizer.localizedString(forKey: "timer_skip_alert_title"), isPresented: $showingSkipConfirmation) {
            Button(localizer.localizedString(forKey: "timer_skip"), role: .destructive) { timerManager.forceComplete() }
            Button(localizer.localizedString(forKey: "timer_cancel"), role: .cancel) { }
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization { granted in
                if !granted { showingNotificationAlert = true }
            }
            notifDelegate.timerManager = timerManager
            notifDelegate.registerCategory()
            UNUserNotificationCenter.current().delegate = notifDelegate
            if timerManager.isRunning {
                notifDelegate.postBanner(
                    isBreak: timerManager.isBreak,
                    timeRemaining: timerManager.timeRemaining,
                    session: timerManager.currentSession,
                    total: sessionsUntilLongBreak
                )
            }
            withAnimation { appeared = true }
        }
        .onChange(of: timerManager.isRunning) { running in
            if running {
                notifDelegate.postBanner(
                    isBreak: timerManager.isBreak,
                    timeRemaining: timerManager.timeRemaining,
                    session: timerManager.currentSession,
                    total: sessionsUntilLongBreak
                )
            } else {
                notifDelegate.cancelBanner()
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                timerManager.syncFromBackground()
            case .background:
                timerManager.saveState()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            if timerManager.isRunning { timerManager.pause() }
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
            Button(localizer.localizedString(forKey: "ok"), role: .cancel) { }
        } message: {
            Text(localizer.localizedString(forKey: "timer_notification_message"))
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(
                        colors: [accentColor.opacity(isDark ? 0.30 : 0.16), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width, height: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.42)
                    .blur(radius: 30)
                    .animation(.easeInOut(duration: 0.6), value: timerManager.isBreak)

                Circle()
                    .fill(RadialGradient(
                        colors: [accentColors[1].opacity(isDark ? 0.18 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.72)
                    .blur(radius: 20)
                    .animation(.easeInOut(duration: 0.6), value: timerManager.isBreak)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Spotify button
            Button(action: openSpotify) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Spotify")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(red: 0.11, green: 0.73, blue: 0.33),
                            in: Capsule())
                .shadow(color: Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            Spacer()

            // Skip button
            Button { showingSkipConfirmation = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(localizer.localizedString(forKey: "timer_skip"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Focus Banner

    private var focusBanner: some View {
        let df = DateFormatter()
        let _ = {
            df.locale = Locale(identifier: localizer.selectedLanguage == "Englisch" ? "en_US" : "de_DE")
            df.dateFormat = "EEEE, d. MMM"
        }()

        return HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
            Text("\(df.string(from: Date()))  ·  \(focusTodayMinutes) \(localizer.localizedString(forKey: "minutes_short")) Fokus")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(LinearGradient(
                colors: [Color.white.opacity(isDark ? 0.12 : 0.65),
                         Color.white.opacity(isDark ? 0.04 : 0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: accentColor.opacity(isDark ? 0.12 : 0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(RadialGradient(
                    colors: [accentColor.opacity(isDark ? 0.18 : 0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 160))
                .frame(width: 320, height: 320)
                .blur(radius: 8)

            // Glass backing
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 260, height: 260)
                .overlay(Circle().strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(isDark ? 0.15 : 0.70),
                                            Color.white.opacity(isDark ? 0.05 : 0.25)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                .shadow(color: Color.black.opacity(isDark ? 0.30 : 0.10), radius: 24, x: 0, y: 8)

            // Track
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 18)
                .frame(width: 220, height: 220)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: accentColors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
                .shadow(color: accentColor.opacity(0.45), radius: 8, x: 0, y: 0)

            // Time display
            VStack(spacing: 6) {
                TimerDisplay(
                    timeRemaining: timerManager.timeRemaining,
                    isRunning: timerManager.isRunning
                )
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)

                // Session dots
                HStack(spacing: 7) {
                    ForEach(0..<sessionsUntilLongBreak, id: \.self) { i in
                        Circle()
                            .fill(i < timerManager.currentSession - 1
                                  ? accentColor
                                  : Color.primary.opacity(0.18))
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.3), value: timerManager.currentSession)
                    }
                }
            }
        }
    }

    // MARK: - Mode Badge

    private var modeBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: timerManager.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accentColor)
            Text(modeLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(accentColor.opacity(isDark ? 0.3 : 0.2), lineWidth: 1))
        .shadow(color: accentColor.opacity(0.15), radius: 8, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.4), value: timerManager.isBreak)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 28) {
            // Reset
            controlButton(icon: "arrow.clockwise", isPrimary: false) { timerManager.reset() }

            // Play / Pause (big)
            controlButton(icon: timerManager.isRunning ? "pause.fill" : "play.fill", isPrimary: true) {
                timerManager.isRunning ? timerManager.pause() : timerManager.resume()
            }

            // Settings
            controlButton(icon: "gearshape.fill", isPrimary: false) { showingSettings = true }
        }
    }

    private func controlButton(icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isPrimary {
                    Circle()
                        .fill(LinearGradient(colors: accentColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: accentColor.opacity(0.5), radius: 16, x: 0, y: 6)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(Circle().strokeBorder(
                            LinearGradient(colors: [Color.white.opacity(isDark ? 0.15 : 0.65),
                                                    Color.white.opacity(isDark ? 0.05 : 0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 10, x: 0, y: 4)
                }

                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 30 : 22, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.4), value: timerManager.isBreak)
    }

    // MARK: - Helpers

    private func openSpotify() {
        guard let url = URL(string: "spotify:"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - TimerManager Background Sync

private extension TimerManager {
    /// Recalculates remaining time from the persisted endDate and resumes the timer.
    /// Called when the app returns to the foreground so that time that elapsed
    /// while the process was suspended is accounted for correctly.
    func syncFromBackground() {
        guard
            let data = UserDefaults.standard.data(forKey: "timerState"),
            let saved = try? JSONDecoder().decode(TimerState.self, from: data),
            saved.isRunning,
            let endDate = saved.endDate
        else { return }

        let remaining = endDate.timeIntervalSinceNow

        if remaining <= 0 {
            // Session finished while the app was suspended
            if isRunning { pause() }
            timeRemaining = 0
            forceComplete()
        } else {
            // Session still running – restart the tick loop with corrected time
            if isRunning { pause() }
            timeRemaining = remaining
            resume()
        }
    }
}

// MARK: - Timer Notification Delegate

final class TimerNotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    private enum ID {
        static let category  = "TIMER_CONTROLS"
        static let banner    = "timer_running_banner"
        static let pause     = "TIMER_PAUSE"
        static let next      = "TIMER_NEXT"
        static let stop      = "TIMER_STOP"
    }

    weak var timerManager: TimerManager?

    // MARK: - Setup

    func registerCategory() {
        UNUserNotificationCenter.current().getNotificationCategories { existing in
            let pauseAction = UNNotificationAction(
                identifier: ID.pause,
                title: "⏸ Pause / Fortsetzen",
                options: []
            )
            let nextAction = UNNotificationAction(
                identifier: ID.next,
                title: "⏭ Nächste Phase",
                options: .destructive
            )
            let stopAction = UNNotificationAction(
                identifier: ID.stop,
                title: "⏹ Beenden",
                options: .destructive
            )
            let timerCategory = UNNotificationCategory(
                identifier: ID.category,
                actions: [pauseAction, nextAction, stopAction],
                intentIdentifiers: [],
                options: .customDismissAction
            )
            var updated = existing.filter { $0.identifier != ID.category }
            updated.insert(timerCategory)
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().setNotificationCategories(updated)
            }
        }
    }

    // MARK: - Banner

    func postBanner(isBreak: Bool, timeRemaining: TimeInterval, session: Int, total: Int) {
        cancelBanner()
        let content = UNMutableNotificationContent()
        content.title = isBreak
            ? "🍃 Pause läuft"
            : "🎯 Fokus-Session \(session)/\(total)"
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        content.body = String(format: "Noch %02d:%02d", mins, secs)
        content.categoryIdentifier = ID.category
        content.sound = nil
        let request = UNNotificationRequest(identifier: ID.banner, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelBanner() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [ID.banner])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ID.banner])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.categoryIdentifier == ID.category {
            DispatchQueue.main.async { [weak self] in
                guard let tm = self?.timerManager else { return }
                switch response.actionIdentifier {
                case ID.pause:
                    tm.isRunning ? tm.pause() : tm.resume()
                case ID.next:
                    tm.forceComplete()
                case ID.stop:
                    tm.pause()
                    tm.reset()
                default:
                    break
                }
            }
            completionHandler()
        } else {
            NotificationManager.shared.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier == ID.banner {
            completionHandler([])
        } else {
            NotificationManager.shared.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
        }
    }
}
