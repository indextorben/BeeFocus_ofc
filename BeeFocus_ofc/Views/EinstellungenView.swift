import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    @AppStorage("showPastTasksGlobal") private var showPastTasksGlobal = false
    @AppStorage("autoDeleteCompletedEnabled") private var autoDeleteCompletedEnabled = false
    @AppStorage("autoDeleteCompletedDays") private var autoDeleteCompletedDays = 30
    
    @AppStorage("morningSummaryEnabled") private var morningSummaryEnabled: Bool = true
    @AppStorage("morningSummaryTime") private var morningSummaryTime: Double = 6 * 3600 // seconds from midnight (default 06:00)
    
    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    @State private var bannerColor: Color = .green
    @State private var showingCategoryEdit = false
    @State private var showFullAppTutorial = false  // Neu für das Full-App-Tutorial
    @State private var showDeduplicateConfirm = false
    @State private var showResetStatsConfirm = false
    @State private var showResetStatsAlert = false

    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    // MARK: - Darstellung
                    Section(header: Text(localizer.localizedString(forKey: "Displaymodus"))) {
                        Toggle(localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
                    }

                    // MARK: - Sichtbarkeit
                    Section(header: Text(localizer.localizedString(forKey: "Sichtbarkeit"))) {
                        Toggle(localizer.localizedString(forKey: "Vergangene anzeigen"), isOn: $showPastTasksGlobal)
                    }

                    // MARK: - Benachrichtigungen
                    Section(header: Text(localizer.localizedString(forKey: "Benachrichtigungen"))) {
                        Toggle(localizer.localizedString(forKey: "Benachrichtigungen"), isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { enabled in
                                if enabled {
                                    requestNotificationPermission()
                                } else {
                                    bannerColor = .red
                                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigungen deaktiviert"))
                                }
                            }

                        Toggle(localizer.localizedString(forKey: "morning_summary_toggle"), isOn: $morningSummaryEnabled)
                            .onChange(of: morningSummaryEnabled) { enabled in
                                if enabled {
                                    scheduleMorningSummaryNow()
                                } else {
                                    NotificationManager.shared.cancelDailyMorningSummary()
                                    bannerColor = .red
                                    showBanner(message: localizer.localizedString(forKey: "Morgen-Übersicht deaktiviert"))
                                }
                            }

                        if morningSummaryEnabled {
                            HStack {
                                Text(localizer.localizedString(forKey: "time"))
                                Spacer()
                                // Simple time picker using DatePicker in hour/minute, bound via a computed Date from seconds since midnight
                                DatePicker("", selection: Binding<Date>(
                                    get: {
                                        let seconds = morningSummaryTime
                                        let today = Calendar.current.startOfDay(for: Date())
                                        return today.addingTimeInterval(seconds)
                                    },
                                    set: { newDate in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                        let h = comps.hour ?? 6
                                        let m = comps.minute ?? 0
                                        morningSummaryTime = Double(h * 3600 + m * 60)
                                        scheduleMorningSummaryNow()
                                    }
                                ), displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                            }
                        }
                    }

                    // MARK: - Sprache
                    Section(header: Text(localizer.localizedString(forKey: "Sprache"))) {
                        Picker(localizer.localizedString(forKey: "Sprache"), selection: $localizer.selectedLanguage) {
                            ForEach(languages, id: \.self) { lang in
                                Text(lang)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    // MARK: - Kategorien
                    Section(header: Text(localizer.localizedString(forKey: "Kategorien"))) {
                        Button(localizer.localizedString(forKey: "Kategorien verwalten")) {
                            showingCategoryEdit = true
                        }
                    }

                    // MARK: - Tutorials
                    Section(header: Text(localizer.localizedString(forKey: "Tutorials"))) {
                        NavigationLink(localizer.localizedString(forKey: "Tutorials anzeigen")) {
                            TutorialListView()
                        }

                        Button(localizer.localizedString(forKey: "Gesamtes App-Tutorial starten")) {
                            showFullAppTutorial = true
                        }
                    }

                    // MARK: - Synchronisation
                    Section(header: Text(localizer.localizedString(forKey: "Synchronisation"))) {
                        Button(localizer.localizedString(forKey: "Jetzt synchronisieren")) {
                            CloudKitManager.shared.syncNow(todoStore: todoStore) { todosChanged, dailyChanged, focusChanged in
                                bannerColor = .green
                                let message = String(
                                    format: localizer.localizedString(forKey: "Sync: %d Todos, %d Tage, %d Fokus-Tage aktualisiert"),
                                    todosChanged, dailyChanged, focusChanged
                                )
                                showBanner(message: message)
                            }
                        }
                        Button(localizer.localizedString(forKey: "deduplicate_categories")) {
                            showDeduplicateConfirm = true
                        }
                        Text(localizer.localizedString(forKey: "deduplicate_explainer"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Statistik
                    Section(header: Text(localizer.localizedString(forKey: "Statistik"))) {
                        Button(role: .destructive) {
                            showResetStatsConfirm = true
                        } label: {
                            Label(localizer.localizedString(forKey: "reset_statistics"), systemImage: "trash.slash")
                        }
                    }

                    // MARK: - Papierkorb
                    Section(header: Text(localizer.localizedString(forKey: "Papierkorb"))) {
                        NavigationLink(localizer.localizedString(forKey: "Papierkorb öffnen")) {
                            TrashView()
                                .environmentObject(todoStore)
                        }
                        if !todoStore.deletedTodos.isEmpty {
                            Button(role: .destructive) {
                                todoStore.emptyTrash()
                            } label: {
                                Label(localizer.localizedString(forKey: "Papierkorb leeren"), systemImage: "trash.slash")
                            }
                        }
                    }

                    // MARK: - Papierkorb Einstellungen
                    Section(header: Text(localizer.localizedString(forKey: "Papierkorb Einstellungen"))) {
                        Stepper("\(localizer.localizedString(forKey: "Max. Einträge")): \((UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")))", onIncrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                            let newValue = min(1000, max(10, current + 10))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxCount")
                            todoStore.updateTrashSettings(maxCount: newValue, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                        }, onDecrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                            let newValue = min(1000, max(10, current - 10))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxCount")
                            todoStore.updateTrashSettings(maxCount: newValue, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                        })

                        Stepper("\(localizer.localizedString(forKey: "Automatisch löschen nach (Tagen)")): \((UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")))", onIncrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                            let newValue = min(365, max(1, current + 1))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxDays")
                            todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: newValue)
                        }, onDecrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                            let newValue = min(365, max(1, current - 1))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxDays")
                            todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: newValue)
                        })
                    }

                    // MARK: - Automatisches Löschen (Abgeschlossene)
                    Section(header: Text(localizer.localizedString(forKey: "Automatisches Löschen"))) {
                        Toggle(localizer.localizedString(forKey: "Abgeschlossene automatisch löschen"), isOn: $autoDeleteCompletedEnabled)
                            .onChange(of: autoDeleteCompletedEnabled) { enabled in
                                if enabled { performAutoDeleteIfNeeded() }
                            }
                        Stepper("\(localizer.localizedString(forKey: "Löschen nach (Tagen)")): \(autoDeleteCompletedDays)", onIncrement: {
                            autoDeleteCompletedDays = min(365, max(1, autoDeleteCompletedDays + 1))
                            if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
                        }, onDecrement: {
                            autoDeleteCompletedDays = min(365, max(1, autoDeleteCompletedDays - 1))
                            if autoDeleteCompletedEnabled { performAutoDeleteIfNeeded() }
                        })
                        .disabled(!autoDeleteCompletedEnabled)
                    }

                    // MARK: - Feedback
                    Section(header: Text(localizer.localizedString(forKey: "Feedback / Verbesserungen"))) {
                        Button(action: sendFeedbackEmail) {
                            HStack {
                                Image(systemName: "envelope")
                                Text(localizer.localizedString(forKey: "Verbesserungen"))
                            }
                            .foregroundColor(.blue)
                        }
                    }

                    // MARK: - Version
                    Section {
                        HStack {
                            Spacer()
                            Text(Bundle.main.versionAndBuild)
                                .font(.footnote)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                }
                .navigationTitle(localizer.localizedString(forKey: "Einstellungen"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(localizer.localizedString(forKey: "Fertig")) {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingCategoryEdit) {
                    CategoryEditView()
                        .environmentObject(todoStore)
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
                            let msg = String(
                                format: localizer.localizedString(forKey: "deduplicate_done"),
                                deletedCategories, updatedTodos
                            )
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

                // Banner
                if showNotificationBanner {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(notificationMessage)
                                .foregroundColor(.white)
                                .bold()
                        }
                        .padding()
                        .background(bannerColor)
                        .cornerRadius(12)
                        .shadow(radius: 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)
                    .zIndex(1)
                }
            }
        }
        .onAppear {
            if autoDeleteCompletedEnabled {
                performAutoDeleteIfNeeded()
            }
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
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
        withAnimation(.spring()) { showNotificationBanner = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) { showNotificationBanner = false }
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
        bannerColor = .green
        showBanner(message: localizer.localizedString(forKey: "deletion_done"))
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
                
                let seconds = Int(morningSummaryTime)
                let hour = max(0, min(23, seconds / 3600))
                let minute = max(0, min(59, (seconds % 3600) / 60))
                NotificationManager.shared.scheduleDailyMorningSummary(hour: hour, minute: minute, body: body)
                bannerColor = .green
                showBanner(message: localizer.localizedString(forKey: "Morgen-Übersicht aktualisiert"))
            }
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
