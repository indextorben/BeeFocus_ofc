import SwiftUI
import UserNotifications
import Foundation

struct EinstellungenView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("selectedLanguage") private var selectedLanguage = "Deutsch"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    @State private var showNotificationBanner = false
    @State private var notificationMessage = ""

    let languages = ["Deutsch", "Englisch", "Französisch", "Spanisch"]

    private var localizer: LocalizationManager {
        LocalizationManager.shared
    }

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section(header: Text(localizer.localizedString(forKey: "section_display"))) {
                        Toggle(localizer.localizedString(forKey: "Darkmode"), isOn: $darkModeEnabled)
                    }

                    Section(header: Text(localizer.localizedString(forKey: "section_language"))) {
                        Picker(localizer.localizedString(forKey: "Sprache"), selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { lang in
                                Text(lang)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }

                    Section(header: Text(localizer.localizedString(forKey: "section_notifications"))) {
                        Toggle(localizer.localizedString(forKey: "Benachrichtigungen"), isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) {
                                if notificationsEnabled {
                                    requestNotificationPermission()
                                }
                            }
                    }

                    Section {
                        Button(localizer.localizedString(forKey: "Cache löschen")) {
                            clearCache()
                        }
                        .foregroundColor(.red)
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
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                }
            }
            .onAppear {
                if notificationsEnabled {
                    requestNotificationPermission()
                }
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigung erlaubt"))
                } else {
                    showBanner(message: localizer.localizedString(forKey: "Benachrichtigungen abgelehnt"))
                }
            }
        }
    }

    private func showBanner(message: String) {
        notificationMessage = message
        withAnimation {
            showNotificationBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showNotificationBanner = false
            }
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: "todos")
        UserDefaults.standard.removeObject(forKey: "categories")
        UserDefaults.standard.removeObject(forKey: "dailyStats")
        showBanner(message: localizer.localizedString(forKey: "cache_cleared"))
    }
}
