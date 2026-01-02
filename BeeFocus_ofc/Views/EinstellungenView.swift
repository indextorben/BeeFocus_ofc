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
                            CloudKitManager.shared.syncNow(todoStore: todoStore)
                            bannerColor = .green
                            showBanner(message: localizer.localizedString(forKey: "Synchronisation abgeschlossen"))
                        }
                        Button(localizer.localizedString(forKey: "Cloud-Testdaten löschen")) {
                            CloudKitManager.shared.deleteAllTestTodos { deletedCount in
                                bannerColor = .green
                                showBanner(message: String(format: localizer.localizedString(forKey: "Gelöschte Testeinträge: %d"), deletedCount))
                            }
                        }
                        Button(role: .destructive) {
                            showingDeleteCompletedSheet = true
                        } label: {
                            Label(localizer.localizedString(forKey: "Abgeschlossene im Zeitraum löschen"), systemImage: "trash")
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

