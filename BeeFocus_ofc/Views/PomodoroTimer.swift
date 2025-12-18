//
//  PomodoroTimer.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI
import SwiftData

struct PomodoroTimer: View {
    @StateObject private var timer = PomodoroTimerModel()
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.2, blue: 0.3) : Color(red: 0.9, green: 0.95, blue: 1.0)
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text(timer.timeString)
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    Button(action: timer.startTimer) {
                        Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(timer.isRunning ? .orange : .green)
                    }
                    
                    Button(action: timer.resetTimer) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                }
                
                Picker(localizer.localizedString(forKey: "timer_mode"), selection: $timer.mode) {
                    Text(localizer.localizedString(forKey: "pomodoro")).tag(PomodoroMode.work)
                    Text(localizer.localizedString(forKey: "short_break")).tag(PomodoroMode.shortBreak)
                    Text(localizer.localizedString(forKey: "long_break")).tag(PomodoroMode.longBreak)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "pomodoro_timer"))
    }
}
