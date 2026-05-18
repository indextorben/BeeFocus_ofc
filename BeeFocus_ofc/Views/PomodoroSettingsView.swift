//
//  PomodoroSettingsView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Pomodoro Timer Einstellungen
struct PomodoroSettingsView: View {
    
    // 🔗 Bindings aus der Hauptview / AppStorage
    @Binding var focusTime: Int
    @Binding var shortBreakTime: Int
    @Binding var longBreakTime: Int
    @Binding var sessionsUntilLongBreak: Int
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60

    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]

    // Sheet schließen
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(localizer.localizedString(forKey: "focus"))) {
                    Stepper("\(localizer.localizedString(forKey: "focus_time")): \(focusTime) min",
                            value: $focusTime, in: 5...120)
                }

                Section(header: Text(localizer.localizedString(forKey: "breaks"))) {
                    Stepper("\(localizer.localizedString(forKey: "short_break")): \(shortBreakTime) min",
                            value: $shortBreakTime, in: 1...30)
                    Stepper("\(localizer.localizedString(forKey: "long_break")): \(longBreakTime) min",
                            value: $longBreakTime, in: 5...60)
                }

                Section(header: Text(localizer.localizedString(forKey: "cycles"))) {
                    Stepper("\(localizer.localizedString(forKey: "sessions_until_long_break")): \(sessionsUntilLongBreak)",
                            value: $sessionsUntilLongBreak, in: 2...10)
                }

                Section(header: Text("Tagesziel"), footer: Text("Tage, an denen du dein Tagesziel erreichst, zählen für die Serie.")) {
                    Stepper("Tagesziel: \(dailyGoal) min", value: $dailyGoal, in: 0...480, step: 5)
                    if dailyGoal == 0 {
                        Text("Kein Tagesziel gesetzt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "settings"))
            
            // 🔥 MAGIC: Auto-Reload sobald sich irgendwas ändert
            .onChange(of: focusTime) { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
            .onChange(of: shortBreakTime) { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
            .onChange(of: longBreakTime) { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
            .onChange(of: sessionsUntilLongBreak) { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
            
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.localizedString(forKey: "done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
