import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore

    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @AppStorage("showPastTasksGlobal") private var showPastTasksGlobal = false
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false
    @AppStorage("autoDeleteCompletedEnabled") private var autoDeleteCompletedEnabled = false
    @AppStorage("autoDeleteCompletedDays") private var autoDeleteCompletedDays = 30
    @AppStorage("skipOverdueOnImport") private var skipOverdueOnImport = false
    @AppStorage("autoCalendarSyncEnabled") private var autoCalendarSyncEnabled = false
    @AppStorage("autoCalendarSyncRange") private var autoCalendarSyncRange = 1

    @AppStorage("morningSummaryEnabled") private var morningSummaryEnabled: Bool = true
    @AppStorage("morningSummaryTime") private var morningSummaryTime: Double = 6 * 3600

    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    @State private var bannerColor: Color = .green
    @State private var showingCategoryEdit = false
    @State private var showFullAppTutorial = false
    @State private var showDeduplicateConfirm = false
    @State private var showResetStatsConfirm = false
    @State private var showResetStatsAlert = false
    @State private var showDeleteOverdueConfirm = false
    @State private var showDeleteCalendarImportsConfirm = false
    @State private var bannerDismissTask: Task<Void, Never>? = nil
    @State private var headerAppeared = false

    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]

    // MARK: - Background Gradient

    private var backgroundGradient: some View {
        ZStack {
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
                                Color.purple.opacity(darkModeEnabled ? 0.25 : 0.12),
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
                                Color.blue.opacity(darkModeEnabled ? 0.20 : 0.10),
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
        }
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

                        sectionGroup(icon: "paintbrush.fill", label: localizer.localizedString(forKey: "Displaymodus"), color: .indigo) {
                            darstellungCard
                        }
                        sectionGroup(icon: "bell.badge.fill", label: localizer.localizedString(forKey: "Benachrichtigungen"), color: .red) {
                            benachrichtigungenCard
                        }
                        sectionGroup(icon: "globe", label: localizer.localizedString(forKey: "Sprache"), color: .green) {
                            spracheCard
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
                        sectionGroup(icon: "envelope.fill", label: localizer.localizedString(forKey: "Feedback / Verbesserungen"), color: .teal) {
                            feedbackCard
                        }

                        versionCard
                            .padding(.top, 8)
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
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                }
            }
            .sheet(isPresented: $showingCategoryEdit) {
                CategoryEditView().environmentObject(todoStore)
            }
            .sheet(isPresented: $showFullAppTutorial) {
                FullAppTutorialView()
            }
            .confirmationDialog(
                localizer.localizedString(forKey: "deduplicate_confirm_title"),
                isPresented: $showDeduplicateConfirm,
                titleVisibility: .visible
            ) {
                Button(localizer.localizedString(forKey: "deduplicate_confirm_proceed"), role: .destructive) {
                    CloudKitManager.shared.deduplicateCategories { deletedCategories, updatedTodos in
                        bannerColor = .green
                        let msg = String(format: localizer.localizedString(forKey: "deduplicate_done"), deletedCategories, updatedTodos)
                        showBanner(message: msg)
                    }
                }
                Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
            } message: {
                Text(localizer.localizedString(forKey: "deduplicate_confirm_message"))
            }
            .alert(localizer.localizedString(forKey: "reset_statistics_done"), isPresented: $showResetStatsAlert) {
                Button(localizer.localizedString(forKey: "ok"), role: .cancel) { }
            }
            .confirmationDialog(
                "Überfällige Aufgaben löschen",
                isPresented: $showDeleteOverdueConfirm,
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    let count = deleteOverdueTasks()
                    bannerColor = count > 0 ? .orange : .gray
                    showBanner(message: count > 0 ? "\(count) überfällige Aufgabe\(count == 1 ? "" : "n") gelöscht" : "Keine überfälligen Aufgaben gefunden")
                }
                Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
            } message: {
                Text("Alle nicht erledigten Aufgaben, deren Fälligkeitsdatum mehr als 1 Monat zurückliegt, werden gelöscht. Aufgaben der letzten 30 Tage bleiben erhalten.")
            }
            .confirmationDialog(
                "Kalender-Importe löschen",
                isPresented: $showDeleteCalendarImportsConfirm,
                titleVisibility: .visible
            ) {
                Button("Alle löschen", role: .destructive) {
                    let count = deleteAllCalendarImports()
                    bannerColor = count > 0 ? .orange : .gray
                    showBanner(message: count > 0 ? "\(count) Kalender-Aufgabe\(count == 1 ? "" : "n") gelöscht" : "Keine Kalender-Importe gefunden")
                }
                Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
            } message: {
                Text("Alle aus dem Kalender importierten Aufgaben werden gelöscht und beim nächsten Sync nicht wieder importiert.")
            }
        }
        .onAppear {
            if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                headerAppeared = true
            }
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
    }

    // MARK: - Hero Header

    private var headerHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .purple.opacity(0.4), radius: 16, x: 0, y: 8)

                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(headerAppeared ? 1 : 0.7)
            .opacity(headerAppeared ? 1 : 0)

            VStack(spacing: 4) {
                Text(localizer.localizedString(forKey: "Einstellungen"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

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
                    .foregroundStyle(color)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)

            content()
        }
    }

    // MARK: - Section Cards

    private var darstellungCard: some View {
        glassCard {
            iconToggleRow(icon: "moon.fill", color: .indigo, label: localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
            cardDivider()
            iconToggleRow(icon: "clock.arrow.circlepath", color: .blue, label: localizer.localizedString(forKey: "Vergangene anzeigen"), isOn: $showPastTasksGlobal)
            cardDivider()
            iconToggleRow(icon: "calendar", color: .orange, label: "Nur aktuellen Monat anzeigen", isOn: $filterCurrentMonthOnly)
        }
    }

    private var benachrichtigungenCard: some View {
        glassCard {
            iconToggleRow(icon: "bell.badge.fill", color: .red, label: localizer.localizedString(forKey: "Benachrichtigungen"), isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { enabled in
                    if enabled { requestNotificationPermission() }
                    else { bannerColor = .red; showBanner(message: localizer.localizedString(forKey: "Benachrichtigungen deaktiviert")) }
                }
            cardDivider()
            iconToggleRow(icon: "sun.max.fill", color: .orange, label: localizer.localizedString(forKey: "morning_summary_toggle"), isOn: $morningSummaryEnabled)
                .onChange(of: morningSummaryEnabled) { enabled in
                    if enabled { scheduleMorningSummaryNow() }
                    else {
                        NotificationManager.shared.cancelDailyMorningSummary()
                        bannerColor = .red
                        showBanner(message: localizer.localizedString(forKey: "Morgen-Übersicht deaktiviert"))
                    }
                }
            if morningSummaryEnabled {
                cardDivider()
                HStack(spacing: 12) {
                    iconBadge(icon: "clock.fill", color: .teal)
                    Text(localizer.localizedString(forKey: "time"))
                        .font(.system(size: 16))
                    Spacer()
                    DatePicker("", selection: Binding<Date>(
                        get: {
                            let today = Calendar.current.startOfDay(for: Date())
                            return today.addingTimeInterval(morningSummaryTime)
                        },
                        set: { newDate in
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                            morningSummaryTime = Double((comps.hour ?? 6) * 3600 + (comps.minute ?? 0) * 60)
                            scheduleMorningSummaryNow()
                        }
                    ), displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
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
                showBanner(message: "Force Sync gestartet...")
            }
            cardDivider()
            iconButtonRow(icon: "doc.on.doc", color: .orange, label: localizer.localizedString(forKey: "deduplicate_categories")) {
                showDeduplicateConfirm = true
            }
            HStack(spacing: 12) {
                Color.clear.frame(width: 30)
                Text(localizer.localizedString(forKey: "deduplicate_explainer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 16)
        }
    }

    private var kalenderCard: some View {
        glassCard {
            HStack(spacing: 12) {
                iconBadge(icon: "calendar", color: .red)
                Text(localizer.localizedString(forKey: "calendar_settings_info"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            cardDivider()
            iconToggleRow(
                icon: "calendar.badge.exclamationmark",
                color: .orange,
                label: "Überfällige beim Import überspringen",
                isOn: $skipOverdueOnImport
            )
            cardDivider()
            iconToggleRow(
                icon: "arrow.triangle.2.circlepath.circle.fill",
                color: .blue,
                label: "Kalender automatisch synchronisieren",
                isOn: $autoCalendarSyncEnabled
            )
            if autoCalendarSyncEnabled {
                cardDivider()
                HStack(spacing: 12) {
                    iconBadge(icon: "clock.arrow.2.circlepath", color: .teal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Synchronisationszeitraum")
                            .font(.system(size: 16))
                        Text("Vergangene Events werden nie importiert")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $autoCalendarSyncRange) {
                        Text("Akt. Monat").tag(1)
                        Text("1 Jahr").tag(12)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            cardDivider()
            Button {
                showDeleteCalendarImportsConfirm = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "calendar.badge.minus", color: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kalender-Importe löschen")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                        Text("Gelöschte werden nicht erneut importiert")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
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
            Button {
                showDeleteOverdueConfirm = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "calendar.badge.minus", color: .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Überfällige löschen")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Text("Nicht erledigt, fällig seit > 1 Monat")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            cardDivider()
            DeleteDuplicatesRow()
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

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(darkModeEnabled ? 0.12 : 0.6),
                            Color.white.opacity(darkModeEnabled ? 0.04 : 0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(darkModeEnabled ? 0.25 : 0.08), radius: 16, x: 0, y: 6)
        .shadow(color: Color.purple.opacity(darkModeEnabled ? 0.08 : 0.04), radius: 20, x: 0, y: 2)
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

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    bannerColor = .green
                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigung erlaubt"))
                } else {
                    bannerColor = .red
                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigungen abgelehnt"))
                }
            }
        }
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

    // MARK: - Delete Overdue Tasks (older than 1 month)
    @discardableResult
    private func deleteOverdueTasks() -> Int {
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let toDelete = todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due < oneMonthAgo
        }
        for todo in toDelete {
            CloudKitManager.shared.deleteTodo(todo)
            todoStore.todos.removeAll { $0.id == todo.id }
        }
        todoStore.saveTodos()
        return toDelete.count
    }

    // MARK: - Delete All Calendar Imports
    @discardableResult
    private func deleteAllCalendarImports() -> Int {
        let toDelete = todoStore.todos.filter { $0.calendarEventIdentifier != nil }
        for todo in toDelete {
            todoStore.deleteTodo(todo)
        }
        return toDelete.count
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
        let subject = "Feedback zur Todo-App"
        let body = "Hallo,\n\nHier ist mein Feedback oder Verbesserungsvorschlag:\n"

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

// MARK: - DeleteDuplicatesRow
private struct DeleteDuplicatesRow: View {
    @EnvironmentObject var todoStore: TodoStore
    @State private var showConfirm = false

    var body: some View {
        Button { showConfirm = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(colors: [.purple, .purple.opacity(0.75)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .shadow(color: Color.purple.opacity(0.35), radius: 4, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duplikate löschen")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Text("Identische Aufgaben permanent entfernen")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .confirmationDialog("Duplikate löschen", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Duplikate entfernen", role: .destructive) { deleteDuplicates() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Identische Aufgaben (gleicher Titel, Beschreibung, Datum, Kategorie und Priorität) werden permanent gelöscht.")
        }
    }

    private func deleteDuplicates() {
        var seenKeys: Set<String> = []
        var toDelete: [TodoItem] = []
        for todo in todoStore.todos {
            let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
            if seenKeys.contains(key) { toDelete.append(todo) }
            else { seenKeys.insert(key) }
        }
        for todo in toDelete { todoStore.deleteTodo(todo) }
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
