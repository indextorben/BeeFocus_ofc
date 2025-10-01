import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""
    @State private var bannerColor: Color = .green
    @State private var showingCategoryEdit = false

    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch", "Französisch", "Spanisch"]

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    // Anzeige
                    Section(header: Text(localizer.localizedString(forKey: "Displaymodus"))) {
                        Toggle(localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
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
            .onAppear {
                if notificationsEnabled {
                    requestNotificationPermission()
                }
            }
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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
}
