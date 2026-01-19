import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    @AppStorage("showPastTasksGlobal") private var showPastTasksGlobal = false
    @State private var showingDeleteCompletedSheet = false
    @State private var deleteStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var deleteEndDate: Date = Date()

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
                    // Anzeige
                    Section(header: Text(localizer.localizedString(forKey: "Displaymodus"))) {
                        Toggle(localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
                    }
                    
                    Section(header: Text(localizer.localizedString(forKey: "Sichtbarkeit"))) {
                        Toggle(localizer.localizedString(forKey: "Vergangene anzeigen"), isOn: $showPastTasksGlobal)
                    }

                    // Sprache
                    Section(header: Text(localizer.localizedString(forKey: "Sprache"))) {
                        Picker(localizer.localizedString(forKey: "Sprache"), selection: $localizer.selectedLanguage) {
                            ForEach(languages, id: \.self) { lang in
                                Text(lang)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    // Benachrichtigungen
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
                    }

                    // Kategorien verwalten
                    Section(header: Text(localizer.localizedString(forKey: "Kategorien"))) {
                        Button(localizer.localizedString(forKey: "Kategorien verwalten")) {
                            showingCategoryEdit = true
                        }
                    }

                    // Tutorials
                    Section(header: Text(localizer.localizedString(forKey: "Tutorials"))) {
                        NavigationLink(localizer.localizedString(forKey: "Tutorials anzeigen")) {
                            TutorialListView()
                        }

                        Button(localizer.localizedString(forKey: "Gesamtes App-Tutorial starten")) {
                            showFullAppTutorial = true
                        }
                    }

                    // Feedback / Verbesserungen
                    Section {
                        Button(action: sendFeedbackEmail) {
                            HStack {
                                Image(systemName: "envelope")
                                Text(localizer.localizedString(forKey: "Verbesserungen")) }
                            .foregroundColor(.blue)
                        }
                    }

                    // Synchronisation
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
                        Button(localizer.localizedString(forKey: "Cloud-Testdaten löschen")) {
                            CloudKitManager.shared.deleteAllTestTodos { deletedCount in
                                bannerColor = .green
                                showBanner(message: String(format: localizer.localizedString(forKey: "Gelöschte Testeinträge: %d"), deletedCount))
                            }
                        }
                        Button(localizer.localizedString(forKey: "deduplicate_categories")) {
                            showDeduplicateConfirm = true
                        }
                        Text(localizer.localizedString(forKey: "deduplicate_explainer"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Button(role: .destructive) {
                            showingDeleteCompletedSheet = true
                        } label: {
                            Label(localizer.localizedString(forKey: "Abgeschlossene im Zeitraum löschen"), systemImage: "trash")
                        }
                        Button(role: .destructive) {
                            showResetStatsConfirm = true
                        } label: {
                            Label(localizer.localizedString(forKey: "reset_statistics"), systemImage: "trash.slash")
                        }
                        .confirmationDialog(
                            localizer.localizedString(forKey: "reset_statistics_confirm_title"),
                            isPresented: $showResetStatsConfirm,
                            titleVisibility: .visible
                        ) {
                            Button(localizer.localizedString(forKey: "reset"), role: .destructive) {
                                // Lokal leeren
                                todoStore.resetDailyStats()
                                todoStore.dailyFocusMinutes.removeAll()
                                // Persistieren
                                // saveDailyStats is encapsulated in resetDailyStats; focus minutes saved explicitly
                                // (reuse existing save function)
                                // Save focus minutes
                                let encoder = JSONEncoder()
                                if let data = try? encoder.encode(todoStore.dailyFocusMinutes) {
                                    UserDefaults.standard.set(data, forKey: "dailyFocusMinutes")
                                }
                                // Cloud löschen
                                CloudKitManager.shared.deleteAllStats { dailyDeleted, focusDeleted in
                                    bannerColor = .green
                                    showBanner(message: localizer.localizedString(forKey: "reset_statistics_done"))
                                    showResetStatsAlert = true
                                }
                            }
                            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
                        } message: {
                            Text(localizer.localizedString(forKey: "reset_statistics_confirm_message"))
                        }
                    }

                    // Papierkorb
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
                    
                    Section(header: Text(localizer.localizedString(forKey: "Papierkorb Einstellungen"))) {
                        HStack {
                            Text(localizer.localizedString(forKey: "Max. Einträge"))
                            Spacer()
                            Text("\(UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"))")
                                .foregroundColor(.secondary)
                        }
                        Stepper("") {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                            let newValue = min(1000, max(10, current + 10))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxCount")
                            todoStore.updateTrashSettings(maxCount: newValue, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                        } onDecrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount")
                            let newValue = min(1000, max(10, current - 10))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxCount")
                            todoStore.updateTrashSettings(maxCount: newValue, maxDays: UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))
                        }

                        HStack {
                            Text(localizer.localizedString(forKey: "Automatisch löschen nach (Tagen)"))
                            Spacer()
                            Text("\(UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays"))")
                                .foregroundColor(.secondary)
                        }
                        Stepper("") {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                            let newValue = min(365, max(1, current + 1))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxDays")
                            todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: newValue)
                        } onDecrement: {
                            let current = UserDefaults.standard.integer(forKey: "trashMaxDays") == 0 ? 30 : UserDefaults.standard.integer(forKey: "trashMaxDays")
                            let newValue = min(365, max(1, current - 1))
                            UserDefaults.standard.set(newValue, forKey: "trashMaxDays")
                            todoStore.updateTrashSettings(maxCount: UserDefaults.standard.integer(forKey: "trashMaxCount") == 0 ? 100 : UserDefaults.standard.integer(forKey: "trashMaxCount"), maxDays: newValue)
                        }
                    }

                    // Version / Build anzeigen
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
                .sheet(isPresented: $showingDeleteCompletedSheet) {
                    NavigationStack {
                        Form {
                            Section(header: Text(localizer.localizedString(forKey: "Zeitraum"))) {
                                DatePicker(localizer.localizedString(forKey: "Von"), selection: $deleteStartDate, displayedComponents: [.date])
                                DatePicker(localizer.localizedString(forKey: "Bis"), selection: $deleteEndDate, in: deleteStartDate...Date(), displayedComponents: [.date])
                            }
                            Section(footer: Text(localizer.localizedString(forKey: "Alle abgeschlossenen Todos im Zeitraum werden endgültig gelöscht."))) {
                                Button(role: .destructive) {
                                    let start = min(deleteStartDate, deleteEndDate)
                                    let end = max(deleteStartDate, deleteEndDate)
                                    let toDelete = todoStore.todos.filter { $0.isCompleted && $0.createdAt >= start && $0.createdAt <= end }
                                    for todo in toDelete {
                                        CloudKitManager.shared.deleteTodo(todo)
                                        if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                                            todoStore.todos.remove(at: idx)
                                        }
                                    }
                                    showingDeleteCompletedSheet = false
                                    bannerColor = .green
                                    showBanner(message: localizer.localizedString(forKey: "Löschung abgeschlossen"))
                                } label: {
                                    Label(localizer.localizedString(forKey: "Löschen"), systemImage: "trash")
                                }
                            }
                        }
                        .navigationTitle(localizer.localizedString(forKey: "Abgeschlossene löschen"))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button(localizer.localizedString(forKey: "Abbrechen")) { showingDeleteCompletedSheet = false } }
                        }
                    }
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
