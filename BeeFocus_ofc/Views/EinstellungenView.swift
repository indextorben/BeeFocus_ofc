import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore

    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("showPastTasksGlobal") private var showPastTasksGlobal = false
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false
    @AppStorage("autoDeleteCompletedEnabled") private var autoDeleteCompletedEnabled = false
    @AppStorage("autoDeleteCompletedDays") private var autoDeleteCompletedDays = 30
    @AppStorage("skipOverdueOnImport") private var skipOverdueOnImport = false
    @AppStorage("autoCalendarSyncEnabled") private var autoCalendarSyncEnabled = false
    @AppStorage("autoCalendarSyncRange") private var autoCalendarSyncRange = 1

    @AppStorage("morningSummaryEnabled") private var morningSummaryEnabled: Bool = true
    @AppStorage("morningSummaryTime") private var morningSummaryTime: Double = 6 * 3600

    @AppStorage("habitReminderEnabled") private var habitReminderEnabled = false

    @AppStorage("waterReminderEnabled") private var waterReminderEnabled = false
    @AppStorage("waterReminderInterval") private var waterReminderInterval = 2

    @AppStorage("overdueAlertEnabled") private var overdueAlertEnabled = false
    @AppStorage("overdueAlertTime") private var overdueAlertTime: Double = 20 * 3600

    @AppStorage("weeklyReviewEnabled") private var weeklyReviewEnabled = false
    @AppStorage("weeklyReviewTime") private var weeklyReviewTime: Double = 19 * 3600

    @AppStorage("moodReminderEnabled") private var moodReminderEnabled = false
    @AppStorage("moodReminderTime") private var moodReminderTime: Double = 21 * 3600

    @AppStorage("eveningReminderEnabled") private var eveningReminderEnabled = false
    @AppStorage("eveningReminderTime") private var eveningReminderTime: Double = 21 * 3600 + 30 * 60
    @AppStorage("fokuspunktePeak") private var fokuspunktePeak: Int = 0
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    // Shared KI (nur für Statusanzeige in der Card)
    @AppStorage("aiProvider")        private var aiProvider: String = "gemini"
    @AppStorage("floatingAIEnabled") private var floatingAIEnabled: Bool = true

    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    @State private var bannerColor: Color = .green
    @State private var showingCategoryEdit = false
    @State private var showFullAppTutorial = false
    @State private var showResetStatsConfirm = false
    @State private var showResetStatsAlert = false
    @State private var bannerDismissTask: Task<Void, Never>? = nil
    @State private var headerAppeared = false
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0

    @ObservedObject private var localizer = LocalizationManager.shared
    @ObservedObject private var sub = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showAmbientSounds = false
    let languages = ["Deutsch", "Englisch"]

    private var themeColors: (Color, Color, Color) { appThemaFarben(aktivesThema) }



    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        let (tc1, tc2, _) = appThemaFarben(aktivesThema)
        return ZStack {
            if darkModeEnabled {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.14),
                        Color(red: 0.10, green: 0.08, blue: 0.20),
                        Color(red: 0.08, green: 0.06, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.94, green: 0.92, blue: 1.0),
                        Color(red: 0.97, green: 0.95, blue: 1.0),
                        Color(red: 0.92, green: 0.96, blue: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Ambient orbs for depth
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tc1.opacity(darkModeEnabled ? 0.25 : 0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.45
                        )
                    )
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.12)
                    .blur(radius: 10)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tc2.opacity(darkModeEnabled ? 0.20 : 0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.65)
                    .blur(radius: 10)
            }

            // Animated wave decoration
            GeometryReader { geo in
                WaveShape(phase: wavePhase2, amplitude: 18, frequency: 1.5)
                    .fill(tc2.opacity(darkModeEnabled ? 0.10 : 0.07))
                    .frame(width: geo.size.width, height: geo.size.height * 0.38)
                    .position(x: geo.size.width * 0.5,
                               y: geo.size.height - geo.size.height * 0.38 * 0.5)
                WaveShape(phase: wavePhase1, amplitude: 12, frequency: 2.1)
                    .fill(tc1.opacity(darkModeEnabled ? 0.16 : 0.11))
                    .frame(width: geo.size.width, height: geo.size.height * 0.27)
                    .position(x: geo.size.width * 0.5,
                               y: geo.size.height - geo.size.height * 0.27 * 0.5)
            }
            .opacity(["", "Wald", "Eis", "Nordlicht", "Galaxie", "Vulkan", "Herbst", "Nacht", "Solar", "Kirschblüte", "Lavendel", "Sonnenuntergang"].contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)

            if aktivesThema == "Wald" {
                WaldDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Eis" {
                EisDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Nordlicht" {
                NordlichtDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Galaxie" {
                GalaxieDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Vulkan" {
                VulkanDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Herbst" {
                HerbstDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Nacht" {
                NachtDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Solar" {
                SolarDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Kirschblüte" {
                KirschblueteDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Lavendel" {
                LavendelDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Sonnenuntergang" {
                SonnenuntergangDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: aktivesThema)
        .ignoresSafeArea()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        headerHero
                            .padding(.bottom, 8)

                        proCard
                            .padding(.bottom, 4)

                        sectionGroup(icon: "paintbrush.fill", label: localizer.localizedString(forKey: "Displaymodus"), color: .indigo) {
                            darstellungCard
                        }
                        sectionGroup(icon: "rectangle.stack.fill", label: "Widget", color: .blue) {
                            widgetCard
                        }
                        sectionGroup(icon: "bell.badge.fill", label: localizer.localizedString(forKey: "Benachrichtigungen"), color: .red) {
                            benachrichtigungenLinkCard
                        }
                        sectionGroup(icon: "globe", label: localizer.localizedString(forKey: "Sprache"), color: .green) {
                            spracheCard
                        }
                        sectionGroup(icon: "folder.fill", label: "Folders", color: .indigo) {
                            ordnerLinkCard
                        }
                        sectionGroup(icon: "tag.fill", label: localizer.localizedString(forKey: "Kategorien"), color: .purple) {
                            kategorienCard
                        }
                        sectionGroup(icon: "book.fill", label: localizer.localizedString(forKey: "Tutorials"), color: .cyan) {
                            tutorialsCard
                        }
                        sectionGroup(icon: "arrow.triangle.2.circlepath", label: localizer.localizedString(forKey: "Synchronisation"), color: .blue) {
                            synchronisationCard
                        }
                        sectionGroup(icon: "calendar", label: localizer.localizedString(forKey: "calendar_settings_header"), color: .orange) {
                            kalenderCard
                        }
                        sectionGroup(icon: "chart.bar.fill", label: localizer.localizedString(forKey: "Statistik"), color: .pink) {
                            statistikCard
                        }
                        sectionGroup(icon: "trash.fill", label: localizer.localizedString(forKey: "Papierkorb"), color: .gray) {
                            papierkorbCard
                        }
                        sectionGroup(icon: "tray.full.fill", label: localizer.localizedString(forKey: "Papierkorb Einstellungen"), color: .brown) {
                            papierkorbSettingsCard
                        }
                        sectionGroup(icon: "checkmark.circle.fill", label: localizer.localizedString(forKey: "Automatisches Löschen"), color: .mint) {
                            autoDeleteCard
                        }
                        sectionGroup(icon: "sparkles", label: String(localized: "ki_settings_title"), color: .purple) {
                            kiCard
                        }
                        sectionGroup(icon: "headphones", label: "Ambient Sounds", color: Color(red: 0.4, green: 0.6, blue: 1.0)) {
                            ambientSoundsCard
                        }
                        sectionGroup(icon: "envelope.fill", label: localizer.localizedString(forKey: "Feedback / Verbesserungen"), color: .teal) {
                            feedbackCard
                        }
                        sectionGroup(icon: "person.fill", label: "Developer", color: .blue) {
                            profilLinkCard
                        }

                        datenschutzCard
                        versionCard
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 52)
                }

                if showNotificationBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text(notificationMessage)
                            .foregroundStyle(.white)
                            .font(.subheadline.bold())
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(bannerColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: bannerColor.opacity(0.4), radius: 14, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showNotificationBanner)
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizer.localizedString(forKey: "Fertig")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(colors: [themeColors.0, themeColors.1], startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
            .sheet(isPresented: $showPaywall) { ProPaywallView() }
            .sheet(isPresented: $showAmbientSounds) { AmbientSoundView() }
            .sheet(isPresented: $showingCategoryEdit) {
                CategoryEditView().environmentObject(todoStore)
            }
            .sheet(isPresented: $showFullAppTutorial) {
                FullAppTutorialView()
            }
            .alert(localizer.localizedString(forKey: "reset_statistics_done"), isPresented: $showResetStatsAlert) {
                Button(localizer.localizedString(forKey: "ok"), role: .cancel) { }
            }
        }
        .onAppear {
            if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                headerAppeared = true
            }
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                wavePhase1 = .pi * 2
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                wavePhase2 = .pi * 2
            }
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
    }

    // MARK: - Hero Header

    private var themeHeroIcon: String {
        switch aktivesThema {
        case "Ozean":           return "water.waves"
        case "Wald":            return "tree.fill"
        case "Nacht":           return "moon.stars.fill"
        case "Solar":           return "sun.max.fill"
        case "Kirschblüte":     return "camera.macro"
        case "Vulkan":          return "flame.fill"
        case "Eis":             return "snowflake"
        case "Herbst":          return "wind"
        case "Lavendel":        return "sparkles"
        case "Sonnenuntergang": return "sunset.fill"
        case "Galaxie":         return "moon.circle.fill"
        case "Nordlicht":       return "aqi.medium"
        default:                return "gearshape.2.fill"
        }
    }

    private var headerHero: some View {
        let (c1, c2, _) = themeColors
        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(c1.opacity(darkModeEnabled ? 0.15 : 0.08))
                    .frame(width: 84, height: 84)
                    .scaleEffect(headerAppeared ? 1.0 : 0.5)
                    .opacity(headerAppeared ? 1 : 0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [c1, c2.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: c1.opacity(0.45), radius: 16, x: 0, y: 8)

                Image(systemName: themeHeroIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: aktivesThema)
            }
            .scaleEffect(headerAppeared ? 1 : 0.7)
            .opacity(headerAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: aktivesThema)

            VStack(spacing: 4) {
                Text(localizer.localizedString(forKey: "Einstellungen"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [c1, c2],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .animation(.easeInOut(duration: 0.5), value: aktivesThema)

                Text("BeeFocus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .offset(y: headerAppeared ? 0 : 10)
            .opacity(headerAppeared ? 1 : 0)
        }
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    // MARK: - Section Group Wrapper

    private func sectionGroup<Content: View>(icon: String, label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(aktivesThema.isEmpty ? color : themeColors.0.opacity(0.85))
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(aktivesThema.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(themeColors.0.opacity(0.5)))
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.4), value: aktivesThema)

            content()
        }
    }

    // MARK: - Section Cards

    private var ordnerLinkCard: some View {
        glassCard {
            NavigationLink(destination: OrdnerView().environmentObject(todoStore)) {
                HStack(spacing: 12) {
                    iconBadge(icon: "folder.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage folders")
                            .font(.system(size: 16))
                        let customCount = todoStore.customFolders.count
                        Text(customCount == 0 ? "No custom folders" : "\(customCount) custom folders")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var darstellungCard: some View {
        glassCard {
            iconToggleRow(icon: "moon.fill", color: .indigo, label: localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
            cardDivider()
            iconToggleRow(icon: "clock.arrow.circlepath", color: .blue, label: localizer.localizedString(forKey: "Vergangene anzeigen"), isOn: $showPastTasksGlobal)
            cardDivider()
            iconToggleRow(icon: "calendar", color: .orange, label: "Show current month only", isOn: $filterCurrentMonthOnly)
        }
    }

    private var widgetCard: some View {
        glassCard {
            NavigationLink {
                WidgetEinstellungenView()
                    .environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "rectangle.stack.fill", color: .blue, label: "Customize widget")
            }
        }
    }

    private var benachrichtigungenLinkCard: some View {
        glassCard {
            NavigationLink(destination: BenachrichtigungenView().environmentObject(todoStore)) {
                HStack(spacing: 12) {
                    iconBadge(icon: "bell.badge.fill", color: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        let active = activeNotificationCount
                        Text(active == 0 ? "None active" : "\(active) active")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
    }

    private var activeNotificationCount: Int {
        [morningSummaryEnabled, habitReminderEnabled, waterReminderEnabled,
         overdueAlertEnabled, weeklyReviewEnabled, moodReminderEnabled, eveningReminderEnabled]
            .filter { $0 }.count
    }

    private var spracheCard: some View {
        glassCard {
            HStack(spacing: 12) {
                iconBadge(icon: "globe", color: .green)
                Text(localizer.localizedString(forKey: "Sprache"))
                    .font(.system(size: 16))
                Spacer()
                Picker("", selection: $localizer.selectedLanguage) {
                    ForEach(languages, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: localizer.selectedLanguage) { _ in
                    if morningSummaryEnabled {
                        scheduleMorningSummaryNow()
                        bannerColor = .green
                        showBanner(message: localizer.localizedString(forKey: "Morgen-Übersicht aktualisiert"))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var kategorienCard: some View {
        glassCard {
            iconButtonRow(icon: "tag.fill", color: .purple, label: localizer.localizedString(forKey: "Kategorien verwalten")) {
                showingCategoryEdit = true
            }
        }
    }

    private var tutorialsCard: some View {
        glassCard {
            NavigationLink {
                TutorialListView()
            } label: {
                iconNavRow(icon: "book.fill", color: .cyan, label: localizer.localizedString(forKey: "Tutorials anzeigen"))
            }
            cardDivider()
            iconButtonRow(icon: "play.fill", color: .mint, label: localizer.localizedString(forKey: "Gesamtes App-Tutorial starten")) {
                showFullAppTutorial = true
            }
        }
    }

    private var synchronisationCard: some View {
        glassCard {
            iconButtonRow(icon: "arrow.triangle.2.circlepath", color: .blue, label: localizer.localizedString(forKey: "Jetzt synchronisieren")) {
                CloudKitManager.shared.syncNow(todoStore: todoStore) { todosChanged, dailyChanged, focusChanged in
                    bannerColor = .green
                    showBanner(message: String(format: localizer.localizedString(forKey: "Sync: %d Todos, %d Tage, %d Fokus-Tage aktualisiert"), todosChanged, dailyChanged, focusChanged))
                }
            }
            cardDivider()
            iconButtonRow(icon: "arrow.clockwise.circle.fill", color: .teal, label: "Force Full Sync") {
                todoStore.forceFullSync()
                bannerColor = .blue
                showBanner(message: "Force sync started...")
            }
            cardDivider()
            NavigationLink {
                KategorieDedupDetailView()
                    .environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "doc.on.doc", color: .orange, label: localizer.localizedString(forKey: "deduplicate_categories"))
            }
        }
    }

    private var kalenderCard: some View {
        glassCard {
            iconToggleRow(
                icon: "calendar.badge.exclamationmark",
                color: .orange,
                label: "Skip overdue on import",
                isOn: $skipOverdueOnImport
            )
            cardDivider()
            iconToggleRow(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                color: .blue,
                label: "Auto-sync calendar",
                isOn: $autoCalendarSyncEnabled
            )
            if autoCalendarSyncEnabled {
                cardDivider()
                HStack(spacing: 12) {
                    iconBadge(icon: "clock.arrow.2.circlepath", color: .teal)
                    Text("Sync range")
                        .font(.system(size: 16))
                    Spacer()
                    Picker("", selection: $autoCalendarSyncRange) {
                        Text("Cur. month").tag(1)
                        Text("1 Year").tag(12)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            cardDivider()
            NavigationLink {
                KalenderImporteDetailView()
                    .environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "calendar.badge.minus", color: .red, label: "Delete calendar imports")
            }
        }
    }

    private var statistikCard: some View {
        glassCard {
            Button {
                showResetStatsConfirm = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "trash.slash.fill", color: .red)
                    Text(localizer.localizedString(forKey: "reset_statistics"))
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            #if DEBUG
            cardDivider()
            Button {
                fokuspunktePeak += 1000
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "plus.circle.fill", color: .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TEST: +1000 Fokuspunkte")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Text("Aktuell: \(fokuspunktePeak) FP")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            #endif
        }
    }

    private var papierkorbCard: some View {
        glassCard {
            NavigationLink {
                TrashView().environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "trash.fill", color: .gray, label: localizer.localizedString(forKey: "Papierkorb öffnen"))
            }
            if !todoStore.deletedTodos.isEmpty {
                cardDivider()
                Button {
                    todoStore.emptyTrash()
                } label: {
                    HStack(spacing: 12) {
                        iconBadge(icon: "trash.slash.fill", color: .red)
                        Text(localizer.localizedString(forKey: "Papierkorb leeren"))
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            cardDivider()
            NavigationLink {
                UeberfaelligeDetailView()
                    .environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "calendar.badge.minus", color: .orange, label: "Delete overdue")
            }
            cardDivider()
            NavigationLink {
                DuplikateDetailView()
                    .environmentObject(todoStore)
            } label: {
                iconNavRow(icon: "doc.on.doc.fill", color: .purple, label: "Delete duplicates")
            }
            cardDivider()
            NavigationLink {
                KalenderLoeschenView()
            } label: {
                iconNavRow(icon: "calendar.badge.minus", color: .teal, label: "Delete calendar entries")
            }
        }
    }

    private var papierkorbSettingsCard: some View {
        glassCard {
            HStack(spacing: 12) {
                iconBadge(icon: "tray.full.fill", color: .brown)
                Stepper(
                    "\(localizer.localizedString(forKey: "Max. Einträge")): \(UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"))",
                    onIncrement: {
                        let cur = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                        let val = min(1000, max(10, cur + 10))
                        UserDefaults.standard.set(val, forKey: "trashMaxCount")
                        todoStore.updateTrashSettings(maxCount: val, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                    },
                    onDecrement: {
                        let cur = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                        let val = min(1000, max(10, cur - 10))
                        UserDefaults.standard.set(val, forKey: "trashMaxCount")
                        todoStore.updateTrashSettings(maxCount: val, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            cardDivider()
            HStack(spacing: 12) {
                iconBadge(icon: "calendar.badge.minus", color: .orange)
                Stepper(
                    "\(localizer.localizedString(forKey: "Automatisch löschen nach (Tagen)")): \(UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))",
                    onIncrement: {
                        let cur = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                        let val = min(365, max(1, cur + 1))
                        UserDefaults.standard.set(val, forKey: "trashMaxDays")
                        todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: val)
                    },
                    onDecrement: {
                        let cur = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                        let val = min(365, max(1, cur - 1))
                        UserDefaults.standard.set(val, forKey: "trashMaxDays")
                        todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: val)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var autoDeleteCard: some View {
        glassCard {
            iconToggleRow(icon: "checkmark.circle.fill", color: .mint, label: localizer.localizedString(forKey: "Abgeschlossene automatisch löschen"), isOn: $autoDeleteCompletedEnabled)
                .onChange(of: autoDeleteCompletedEnabled) { enabled in
                    if enabled { performAutoDeleteIfNeeded() }
                }
            cardDivider()
            HStack(spacing: 12) {
                iconBadge(icon: "calendar.badge.clock", color: .purple)
                Stepper(
                    "\(localizer.localizedString(forKey: "Löschen nach (Tagen)")): \(autoDeleteCompletedDays)",
                    onIncrement: {
                        autoDeleteCompletedDays = min(365, max(1, autoDeleteCompletedDays + 1))
                        if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
                    },
                    onDecrement: {
                        autoDeleteCompletedDays = min(365, max(1, autoDeleteCompletedDays - 1))
                        if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
                    }
                )
                .disabled(!autoDeleteCompletedEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var feedbackCard: some View {
        glassCard {
            iconButtonRow(icon: "envelope.fill", color: .blue, label: localizer.localizedString(forKey: "Verbesserungen")) {
                sendFeedbackEmail()
            }
        }
    }

    // MARK: - Ambient Sounds Card

    private var ambientSoundsCard: some View {
        let manager = AmbientSoundManager.shared
        return glassCard {
            Button {
                if sub.isPro { showAmbientSounds = true } else { showPaywall = true }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.4, green: 0.6, blue: 1.0),
                                         Color(red: 0.55, green: 0.35, blue: 1.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 38, height: 38)
                        Image(systemName: "headphones")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Ambient Sounds")
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                            if !sub.isPro {
                                Text("Pro")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(red: 0.55, green: 0.35, blue: 1.0), in: Capsule())
                            }
                        }
                        Text(manager.isPlaying ? manager.currentSound.label : "White noise · Binaural beats · more")
                            .font(.system(size: 12))
                            .foregroundStyle(manager.isPlaying
                                             ? manager.currentSound.color
                                             : Color.secondary)
                            .animation(.easeInOut(duration: 0.2), value: manager.isPlaying)
                    }

                    Spacer()

                    if manager.isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundStyle(manager.currentSound.color)
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var profilLinkCard: some View {
        glassCard {
            NavigationLink(destination: ProfilView()) {
                HStack(spacing: 12) {
                    iconBadge(icon: "person.fill", color: .blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Profile")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Text("Instagram, Email & more")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - KI Card

    private var proCard: some View {
        VStack(spacing: 0) {
            Button { if !sub.isPro { showPaywall = true } } label: {
                HStack(spacing: 14) {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.55, green: 0.35, blue: 1.0),
                                                Color(red: 0.3, green: 0.6, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(width: 38, height: 38)
                        Image(systemName: sub.isPro ? "crown.fill" : "crown")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.isPro ? "BeeFocus Pro ✓" : "BeeFocus Pro")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(darkModeEnabled ? .white : .primary)
                        if sub.isPro {
                            if let exp = sub.expirationDate {
                                Text("Active until \(exp.formatted(.dateTime.day().month().year()))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Active – thank you for your support!")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Unlock all features")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !sub.isPro {
                        Text("Upgrade")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [Color(red: 0.55, green: 0.35, blue: 1.0),
                                                        Color(red: 0.3, green: 0.6, blue: 1.0)],
                                               startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Abo verwalten (nur wenn Pro aktiv und kein Lifetime)
            if sub.isPro && sub.expirationDate != nil {
                Divider().padding(.horizontal, 16)
                Button {
                    sub.manageSubscriptions()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13))
                        Text("Manage / cancel subscription")
                            .font(.system(size: 14))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(colors: [Color(red: 0.55, green: 0.35, blue: 1.0).opacity(0.5),
                                            Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.3)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
        )
    }

    private var kiCard: some View {
        glassCard {
            NavigationLink(destination: KIEinstellungenView()) {
                HStack(spacing: 12) {
                    iconBadge(icon: "sparkles", color: .purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "ki_settings_title"))
                            .font(.system(size: 16))
                            .foregroundStyle(darkModeEnabled ? .white : .primary)
                        Text(providerSubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var providerSubtitle: String {
        switch aiProvider {
        case "openai": return "OpenAI"
        case "groq":   return "Groq"
        default:       return "Google Gemini"
        }
    }

    private var datenschutzCard: some View {
        HStack(spacing: 20) {
            Link(destination: URL(string: "https://www.torbenlehneke.de/apps/beefocus/datenschutz.html")!) {
                Text("Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .underline()
            }
            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Link(destination: URL(string: "https://www.torbenlehneke.de/apps/beefocus/nutzungsbedingungen.html")!) {
                Text("Terms of Use")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var versionCard: some View {
        VStack(spacing: 4) {
            Text(Bundle.main.versionAndBuild)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Design Helpers

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> AnyView {
        let hasTema = !aktivesThema.isEmpty
        let (c1, c2, _) = themeColors
        return AnyView(VStack(spacing: 0) {
            content()
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [c1.opacity(darkModeEnabled ? 0.14 : 0.09),
                             c2.opacity(darkModeEnabled ? 0.07 : 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
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
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(darkModeEnabled ? 0.25 : 0.08), radius: 16, x: 0, y: 6)
        .shadow(color: c1.opacity(darkModeEnabled ? 0.18 : 0.09), radius: 20, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.5), value: aktivesThema))
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private func iconToggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: color)
            Text(label)
                .font(.system(size: 16))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func iconButtonRow(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBadge(icon: icon, color: color)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func iconNavRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: color)
            Text(label)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func cardDivider() -> some View {
        Divider()
            .padding(.leading, 58)
            .opacity(0.5)
    }

    // MARK: - Banner
    private func showBanner(message: String) {
        notificationMessage = message
        bannerDismissTask?.cancel()
        withAnimation(.spring()) { showNotificationBanner = true }
        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut) { showNotificationBanner = false }
            }
        }
    }

    // MARK: - Auto Delete Completed
    private func performAutoDeleteIfNeeded() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -autoDeleteCompletedDays, to: Date()) ?? Date.distantPast
        let toDelete = todoStore.todos.filter { $0.isCompleted && $0.createdAt < cutoff }
        guard !toDelete.isEmpty else { return }
        for todo in toDelete {
            CloudKitManager.shared.deleteTodo(todo)
            if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                todoStore.todos.remove(at: idx)
            }
        }
    }

    // MARK: - Feedback Email
    private func sendFeedbackEmail() {
        let email = "lehneketorben@gmail.com"
        let subject = "Feedback for BeeFocus"
        let body = "Hello,\n\nHere is my feedback or suggestion:\n"

        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Morning Summary Scheduling
    private func scheduleMorningSummaryNow() {
        NotificationManager.shared.requestAuthorization { granted in
            guard granted else {
                DispatchQueue.main.async {
                    bannerColor = .red
                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigungen abgelehnt"))
                }
                return
            }
            DispatchQueue.main.async {
                let today = Calendar.current.startOfDay(for: Date())
                let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? Date()
                let dueTodayOrOverdueNotCompleted = todoStore.todos.filter { todo in
                    guard !todo.isCompleted else { return false }
                    guard let due = todo.dueDate else { return false }
                    return due <= endOfDay
                }
                let count = dueTodayOrOverdueNotCompleted.count

                let body: String
                if count == 0 {
                    body = localizer.localizedString(forKey: "morning_summary_body_none")
                } else if count == 1 {
                    body = localizer.localizedString(forKey: "morning_summary_body_one")
                } else {
                    body = String(format: localizer.localizedString(forKey: "morning_summary_body_many"), count)
                }

                print("🧪 MorningSummary body resolved: \(body)")

                let seconds = Int(morningSummaryTime)
                let hour = max(0, min(23, seconds / 3600))
                let minute = max(0, min(59, (seconds % 3600) / 60))

                print("🧪 MorningSummary schedule at \(hour):\(String(format: "%02d", minute)) with title-key=morning_summary_title")

                NotificationManager.shared.scheduleDailyMorningSummary(hour: hour, minute: minute, body: body)
                bannerColor = .green
                showBanner(message: localizer.localizedString(forKey: "Morgen-Übersicht aktualisiert"))
            }
        }
    }

}

// MARK: - Detail Views

struct KategorieDedupDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared
    @State private var showConfirm = false
    @State private var result: String? = nil

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What happens?")
                        .font(.headline)
                    Text("Duplicate categories in the CloudKit database are merged. Tasks are assigned to the remaining category.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Clean up duplicate categories")
            }

            Section {
                Text("This function fixes sync errors where the same category exists multiple times in CloudKit. Only category data is affected; no tasks are deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } header: {
                Text("When useful?")
            }

            Section {
                Button {
                    showConfirm = true
                } label: {
                    Label(localizer.localizedString(forKey: "deduplicate_confirm_proceed"), systemImage: "wand.and.stars")
                        .foregroundStyle(.orange)
                }
            }

            if let result = result {
                Section {
                    Label(result, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "deduplicate_categories"))
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            localizer.localizedString(forKey: "deduplicate_confirm_title"),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(localizer.localizedString(forKey: "deduplicate_confirm_proceed"), role: .destructive) {
                CloudKitManager.shared.deduplicateCategories { deletedCats, updatedTodos in
                    result = String(format: localizer.localizedString(forKey: "deduplicate_done"), deletedCats, updatedTodos)
                }
            }
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {}
        } message: {
            Text(localizer.localizedString(forKey: "deduplicate_confirm_message"))
        }
    }
}

struct KalenderImporteDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showConfirm = false
    @State private var result: String? = nil

    private var importCount: Int {
        todoStore.todos.filter { $0.calendarEventIdentifier != nil }.count
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What happens?")
                        .font(.headline)
                    Text("All tasks imported from the calendar will be deleted. They won't be re-imported on the next sync since their calendar IDs remain stored.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Delete calendar imports")
            }

            Section {
                Label("\(importCount) calendar task\(importCount == 1 ? "" : "s") found",
                      systemImage: "calendar")
                    .foregroundStyle(importCount > 0 ? .primary : .secondary)
            } header: {
                Text("Current")
            }

            Section {
                Text("Useful when imported calendar entries should no longer appear in the task list. The original calendar events remain untouched.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } header: {
                Text("Note")
            }

            Section {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label("Delete all calendar imports", systemImage: "calendar.badge.minus")
                }
                .disabled(importCount == 0)
            }

            if let result = result {
                Section {
                    Label(result, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Calendar Imports")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Delete Calendar Imports", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) {
                let toDelete = todoStore.todos.filter { $0.calendarEventIdentifier != nil }
                for todo in toDelete { todoStore.deleteTodo(todo) }
                let count = toDelete.count
                result = count > 0 ? "\(count) calendar task\(count == 1 ? "" : "s") deleted" : "No calendar imports found"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All tasks imported from the calendar will be deleted and won't be re-imported on the next sync.")
        }
    }
}

struct UeberfaelligeDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showConfirm = false
    @State private var result: String? = nil

    private var overdueCount: Int {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due < oneMonthAgo
        }.count
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What happens?")
                        .font(.headline)
                    Text("Incomplete tasks whose due date is more than 1 month in the past will be moved to the trash. Tasks from the last 30 days are kept.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Delete overdue tasks")
            }

            Section {
                Label("\(overdueCount) overdue task\(overdueCount == 1 ? "" : "s") affected",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(overdueCount > 0 ? .orange : .secondary)
            } header: {
                Text("Current")
            }

            Section {
                Text("Completed tasks are not affected. Tasks without a due date will also not be deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } header: {
                Text("Exceptions")
            }

            Section {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label("Delete overdue now", systemImage: "trash")
                }
                .disabled(overdueCount == 0)
            }

            if let result = result {
                Section {
                    Label(result, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Delete Overdue")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Delete Overdue Tasks", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                let toDelete = todoStore.todos.filter { todo in
                    guard !todo.isCompleted, let due = todo.dueDate else { return false }
                    return due < oneMonthAgo
                }
                for todo in toDelete {
                    todoStore.deleteTodo(todo)
                }
                let count = toDelete.count
                result = count > 0 ? "\(count) overdue task\(count == 1 ? "" : "s") deleted" : "No overdue tasks found"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All incomplete tasks with a due date more than 1 month ago will be deleted.")
        }
    }
}

struct DuplikateDetailView: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showConfirm = false
    @State private var result: String? = nil

    private var duplicateCount: Int {
        var seenKeys: Set<String> = []
        var count = 0
        for todo in todoStore.todos {
            let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
            if seenKeys.contains(key) { count += 1 }
            else { seenKeys.insert(key) }
        }
        return count
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What happens?")
                        .font(.headline)
                    Text("Tasks that share the same title, description, due date, category, and priority are considered duplicates. One copy of each duplicate is deleted; the first one is kept.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Delete duplicates")
            }

            Section {
                Label("\(duplicateCount) duplicate\(duplicateCount == 1 ? "" : "s") found",
                      systemImage: "doc.on.doc")
                    .foregroundStyle(duplicateCount > 0 ? .purple : .secondary)
            } header: {
                Text("Current")
            }

            Section {
                Text("Duplicates often arise from multiple calendar imports or sync errors. The cleanup is permanent and cannot be undone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } header: {
                Text("Cause & Note")
            }

            Section {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    Label("Remove duplicates now", systemImage: "doc.on.doc.fill")
                }
                .disabled(duplicateCount == 0)
            }

            if let result = result {
                Section {
                    Label(result, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Delete Duplicates")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Delete Duplicates", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Remove duplicates", role: .destructive) {
                var seenKeys: Set<String> = []
                var toDelete: [TodoItem] = []
                for todo in todoStore.todos {
                    let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
                    if seenKeys.contains(key) { toDelete.append(todo) }
                    else { seenKeys.insert(key) }
                }
                for todo in toDelete { todoStore.deleteTodo(todo) }
                let count = toDelete.count
                result = count > 0 ? "\(count) duplicate\(count == 1 ? "" : "s") deleted" : "No duplicates found"
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Identical tasks (same title, description, date, category and priority) will be permanently deleted.")
        }
    }
}

// MARK: - Bundle Extension für Version/Build
extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
    var versionAndBuild: String {
        "v\(appVersion) (\(buildNumber))"
    }
}
