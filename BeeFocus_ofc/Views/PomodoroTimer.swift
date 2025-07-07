//
//  PomodoroTimer.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI
import SwiftData

//Timer "View"
struct PomodoroTimer: View {
    @StateObject private var timer = PomodoroTimerModel()
    @Environment(\.colorScheme) private var colorScheme
    
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
                
                Picker("Timer-Modus", selection: $timer.mode) {
                    Text("Pomodoro").tag(PomodoroMode.work)
                    Text("Kurze Pause").tag(PomodoroMode.shortBreak)
                    Text("Lange Pause").tag(PomodoroMode.longBreak)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
            }
        }
        .navigationTitle("Pomodoro Timer")
    }
}
