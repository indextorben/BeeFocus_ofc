//
//  PomodoroSettingsView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI
import SwiftData

//Timer Einstellungen
struct PomodoroSettingsView: View {
    @Binding var focusTime: Int
    @Binding var shortBreakTime: Int
    @Binding var longBreakTime: Int
    @Binding var sessionsUntilLongBreak: Int
    
    // Dismiss-Umgebung, um das Sheet zu schließen
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Stepper("Fokuszeit: \(focusTime) min", value: $focusTime, in: 5...120)
                Stepper("Kurze Pause: \(shortBreakTime) min", value: $shortBreakTime, in: 1...30)
                Stepper("Lange Pause: \(longBreakTime) min", value: $longBreakTime, in: 5...60)
                Stepper("Sessions bis lange Pause: \(sessionsUntilLongBreak)",
                        value: $sessionsUntilLongBreak, in: 2...10)
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}
