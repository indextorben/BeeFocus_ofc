import SwiftUI
import UserNotifications

struct BenachrichtigungenView: View {
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared

    @AppStorage("darkModeEnabled")         private var darkModeEnabled = false
    @AppStorage("aktivesStatistikThema")   private var aktivesThema: String = ""

    @AppStorage("notificationsEnabled")    private var notificationsEnabled = true
    @AppStorage("morningSummaryEnabled")   private var morningSummaryEnabled = true
    @AppStorage("morningSummaryTime")      private var morningSummaryTime: Double = 6 * 3600
    @AppStorage("habitReminderEnabled")    private var habitReminderEnabled = false
    @AppStorage("habitReminderTime")       private var habitReminderTime: Double = 8 * 3600
    @AppStorage("waterReminderEnabled")    private var waterReminderEnabled = false
    @AppStorage("waterReminderInterval")   private var waterReminderInterval = 2
    @AppStorage("overdueAlertEnabled")     private var overdueAlertEnabled = false
    @AppStorage("overdueAlertTime")        private var overdueAlertTime: Double = 20 * 3600
    @AppStorage("weeklyReviewEnabled")     private var weeklyReviewEnabled = false
    @AppStorage("weeklyReviewTime")        private var weeklyReviewTime: Double = 19 * 3600
    @AppStorage("moodReminderEnabled")     private var moodReminderEnabled = false
    @AppStorage("moodReminderTime")        private var moodReminderTime: Double = 21 * 3600
    @AppStorage("eveningReminderEnabled")  private var eveningReminderEnabled = false
    @AppStorage("eveningReminderTime")     private var eveningReminderTime: Double = 21 * 3600 + 30 * 60

    @State private var showBannerView = false
    @State private var bannerMessage = ""
    @State private var bannerColor: Color = .green
    @State private var bannerTask: Task<Void, Never>? = nil
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    private var accent: Color { aktivesThema.isEmpty ? .red : appThemaFarben(aktivesThema).0 }
    private var themeColors: (Color, Color, Color) { appThemaFarben(aktivesThema) }

    var body: some View {
        ZStack(alignment: .top) {
            background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Permission status
                    if authStatus == .denied {
                        permissionDeniedBanner
                            .padding(.top, 8)
                    }

                    // Master toggle
                    sectionCard(header: "Allgemein", icon: "bell.fill", color: accent) {
                        toggleRow(
                            icon: "bell.badge.fill", color: accent,
                            label: "Benachrichtigungen aktiv",
                            isOn: $notificationsEnabled
                        )
                        .onChange(of: notificationsEnabled) { enabled in
                            if enabled {
                                requestPermission()
                            } else {
                                showBanner("Benachrichtigungen deaktiviert", color: .red)
                            }
                        }
                    }

                    // Tagesstruktur
                    sectionCard(header: "Tagesstruktur", icon: "sun.max.fill", color: .orange) {
                        toggleRow(icon: "sun.max.fill", color: .orange,
                                  label: "Morgen-Übersicht",
                                  isOn: $morningSummaryEnabled)
                            .onChange(of: morningSummaryEnabled) { enabled in
                                if enabled { scheduleMorningSummary() }
                                else { NotificationManager.shared.cancelDailyMorningSummary() }
                            }
                        if morningSummaryEnabled {
                            timeRow(time: $morningSummaryTime) { scheduleMorningSummary() }
                        }

                        divider()
                        toggleRow(icon: "exclamationmark.circle.fill", color: .red.opacity(0.9),
                                  label: "Überfällige Aufgaben",
                                  isOn: $overdueAlertEnabled)
                            .onChange(of: overdueAlertEnabled) { enabled in
                                if enabled { scheduleOverdueAlert() }
                                else { NotificationManager.shared.cancelOverdueAlert() }
                            }
                        if overdueAlertEnabled {
                            timeRow(time: $overdueAlertTime) { scheduleOverdueAlert() }
                        }

                        divider()
                        toggleRow(icon: "calendar.badge.clock", color: .indigo,
                                  label: "Wochenrückblick (Sonntags)",
                                  isOn: $weeklyReviewEnabled)
                            .onChange(of: weeklyReviewEnabled) { enabled in
                                if enabled { scheduleWeeklyReview() }
                                else { NotificationManager.shared.cancelWeeklyReview() }
                            }
                        if weeklyReviewEnabled {
                            timeRow(time: $weeklyReviewTime) { scheduleWeeklyReview() }
                        }
                    }

                    // Wohlbefinden
                    sectionCard(header: "Wohlbefinden", icon: "heart.fill", color: .pink) {
                        toggleRow(icon: "drop.fill", color: .cyan,
                                  label: "Wasser-Erinnerung",
                                  isOn: $waterReminderEnabled)
                            .onChange(of: waterReminderEnabled) { enabled in
                                if enabled { NotificationManager.shared.scheduleWaterReminders(intervalHours: waterReminderInterval) }
                                else { NotificationManager.shared.cancelWaterReminders() }
                            }
                        if waterReminderEnabled {
                            divider()
                            HStack(spacing: 12) {
                                iconBadge(icon: "clock.arrow.circlepath", color: .cyan)
                                Text("Interval")
                                    .font(.system(size: 16))
                                Spacer()
                                Picker("", selection: $waterReminderInterval) {
                                    Text("1 Std").tag(1)
                                    Text("2 Std").tag(2)
                                    Text("3 Std").tag(3)
                                    Text("4 Std").tag(4)
                                }
                                .pickerStyle(.menu)
                                .onChange(of: waterReminderInterval) { _ in
                                    NotificationManager.shared.scheduleWaterReminders(intervalHours: waterReminderInterval)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }

                        divider()
                        toggleRow(icon: "face.smiling", color: .yellow,
                                  label: "Stimmungs-Check",
                                  isOn: $moodReminderEnabled)
                            .onChange(of: moodReminderEnabled) { enabled in
                                if enabled { scheduleMoodReminder() }
                                else { NotificationManager.shared.cancelMoodReminder() }
                            }
                        if moodReminderEnabled {
                            timeRow(time: $moodReminderTime) { scheduleMoodReminder() }
                        }

                        divider()
                        toggleRow(icon: "moon.stars.fill", color: .purple,
                                  label: "Abendreflexion",
                                  isOn: $eveningReminderEnabled)
                            .onChange(of: eveningReminderEnabled) { enabled in
                                if enabled { scheduleEveningReminder() }
                                else { NotificationManager.shared.cancelEveningReminder() }
                            }
                        if eveningReminderEnabled {
                            timeRow(time: $eveningReminderTime) { scheduleEveningReminder() }
                        }
                    }

                    // Gewohnheiten
                    sectionCard(header: "Gewohnheiten", icon: "calendar.badge.checkmark", color: .green) {
                        toggleRow(icon: "calendar.badge.checkmark", color: .green,
                                  label: "Gewohnheiten-Erinnerung",
                                  isOn: $habitReminderEnabled)
                            .onChange(of: habitReminderEnabled) { enabled in
                                if enabled { scheduleHabitReminder() }
                                else { NotificationManager.shared.cancelHabitReminder() }
                            }
                        if habitReminderEnabled {
                            timeRow(time: $habitReminderTime) { scheduleHabitReminder() }
                        }
                    }

                    // Test
                    sectionCard(header: "Test", icon: "paperplane.fill", color: .teal) {
                        Button {
                            NotificationManager.shared.sendTestNotification()
                            showBanner("Test-Benachrichtigung gesendet")
                        } label: {
                            HStack(spacing: 12) {
                                iconBadge(icon: "paperplane.fill", color: .teal)
                                Text("Jetzt testen")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            // Banner
            if showBannerView {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text(bannerMessage).foregroundStyle(.white).font(.subheadline.bold())
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(bannerColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: bannerColor.opacity(0.4), radius: 14, x: 0, y: 6)
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showBannerView)
            }
        }
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { checkAuthStatus() }
    }

    // MARK: - Permission Banner

    private var permissionDeniedBanner: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Benachrichtigungen blockiert")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("In den Systemeinstellungen aktivieren")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .padding(14)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var background: some View {
        let (c1, c2, _) = themeColors
        return ZStack {
            if darkModeEnabled {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [Color(red: 0.94, green: 0.92, blue: 1.0),
                             Color(red: 0.97, green: 0.95, blue: 1.0),
                             Color(red: 0.92, green: 0.96, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            Circle()
                .fill(RadialGradient(
                    colors: [c1.opacity(darkModeEnabled ? 0.18 : 0.12), .clear],
                    center: .center, startRadius: 0, endRadius: 200
                ))
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -80)
                .blur(radius: 30)
            Circle()
                .fill(RadialGradient(
                    colors: [c2.opacity(darkModeEnabled ? 0.12 : 0.08), .clear],
                    center: .center, startRadius: 0, endRadius: 160
                ))
                .frame(width: 300, height: 300)
                .offset(x: 120, y: 200)
                .blur(radius: 25)
        }
        .animation(.easeInOut(duration: 0.6), value: aktivesThema)
    }

    // MARK: - UI Helpers

    private func sectionCard<Content: View>(
        header: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let hasTema = !aktivesThema.isEmpty
        let (c1, c2, _) = themeColors
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(hasTema ? c1.opacity(0.85) : color)
                Text(header.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(hasTema ? AnyShapeStyle(c1.opacity(0.5)) : AnyShapeStyle(.secondary))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)

            VStack(spacing: 0) { content() }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [c1.opacity(darkModeEnabled ? 0.14 : 0.09),
                                     c2.opacity(darkModeEnabled ? 0.07 : 0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .opacity(hasTema ? 1.0 : 0.0)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: hasTema
                                    ? [c1.opacity(darkModeEnabled ? 0.50 : 0.32), c2.opacity(darkModeEnabled ? 0.22 : 0.16)]
                                    : [Color.white.opacity(darkModeEnabled ? 0.12 : 0.60), Color.white.opacity(darkModeEnabled ? 0.04 : 0.20)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(darkModeEnabled ? 0.25 : 0.08), radius: 16, x: 0, y: 6)
        }
    }

    private func toggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: color)
            Text(label).font(.system(size: 16))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(colors: [color, color.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private func divider() -> some View {
        Divider().padding(.leading, 58).opacity(0.5)
    }

    private func timeRow(time: Binding<Double>, onSet: @escaping () -> Void) -> some View {
        Group {
            divider()
            HStack(spacing: 12) {
                iconBadge(icon: "clock.fill", color: .teal)
                Text(localizer.localizedString(forKey: "time")).font(.system(size: 16))
                Spacer()
                DatePicker("", selection: Binding<Date>(
                    get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(time.wrappedValue) },
                    set: { newDate in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        time.wrappedValue = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
                        onSet()
                    }
                ), displayedComponents: [.hourAndMinute])
                .labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    // MARK: - Banner

    private func showBanner(_ message: String, color: Color = .green) {
        bannerMessage = message
        bannerColor = color
        bannerTask?.cancel()
        withAnimation(.spring()) { showBannerView = true }
        bannerTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut) { showBannerView = false }
            }
        }
    }

    // MARK: - Permission

    private func checkAuthStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { authStatus = settings.authorizationStatus }
        }
    }

    private func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                authStatus = granted ? .authorized : .denied
                if granted {
                    showBanner(localizer.localizedString(forKey: "Benachrichtigung erlaubt"))
                } else {
                    showBanner(localizer.localizedString(forKey: "Benachrichtigungen abgelehnt"), color: .red)
                }
            }
        }
    }

    // MARK: - Scheduling

    private func scheduleMorningSummary() {
        NotificationManager.shared.requestAuthorization { granted in
            guard granted else { return }
            DispatchQueue.main.async {
                let today = Calendar.current.startOfDay(for: Date())
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? Date()
                let count = todoStore.todos.filter {
                    !$0.isCompleted && ($0.dueDate.map { $0 <= endOfDay } ?? false)
                }.count
                let body: String
                if count == 0 { body = localizer.localizedString(forKey: "morning_summary_body_none") }
                else if count == 1 { body = localizer.localizedString(forKey: "morning_summary_body_one") }
                else { body = String(format: localizer.localizedString(forKey: "morning_summary_body_many"), count) }
                let s = Int(morningSummaryTime)
                NotificationManager.shared.scheduleDailyMorningSummary(
                    hour: max(0, min(23, s / 3600)),
                    minute: max(0, min(59, (s % 3600) / 60)),
                    body: body
                )
                showBanner(localizer.localizedString(forKey: "Morgen-Übersicht aktualisiert"))
            }
        }
    }

    private func scheduleHabitReminder() {
        let s = Int(habitReminderTime)
        NotificationManager.shared.scheduleHabitReminder(
            hour: max(0, min(23, s / 3600)), minute: max(0, min(59, (s % 3600) / 60))
        )
    }

    private func scheduleOverdueAlert() {
        let s = Int(overdueAlertTime)
        NotificationManager.shared.scheduleOverdueAlert(
            hour: max(0, min(23, s / 3600)), minute: max(0, min(59, (s % 3600) / 60))
        )
    }

    private func scheduleWeeklyReview() {
        let s = Int(weeklyReviewTime)
        NotificationManager.shared.scheduleWeeklyReview(
            weekday: 1,
            hour: max(0, min(23, s / 3600)), minute: max(0, min(59, (s % 3600) / 60))
        )
    }

    private func scheduleMoodReminder() {
        let s = Int(moodReminderTime)
        NotificationManager.shared.scheduleMoodReminder(
            hour: max(0, min(23, s / 3600)), minute: max(0, min(59, (s % 3600) / 60))
        )
    }

    private func scheduleEveningReminder() {
        let s = Int(eveningReminderTime)
        NotificationManager.shared.scheduleEveningReminder(
            hour: max(0, min(23, s / 3600)), minute: max(0, min(59, (s % 3600) / 60))
        )
    }
}
