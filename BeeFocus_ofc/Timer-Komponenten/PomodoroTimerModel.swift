//
//  PomodoroTimerModel.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

class PomodoroTimerModel: ObservableObject {
    @Published var timeRemaining: Int = 25 * 60 // 25 Minuten in Sekunden
    @Published var isRunning: Bool = false
    @Published var mode: PomodoroMode = .work
    private var timer: Timer?
    
    var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func startTimer() {
        isRunning.toggle()
        if isRunning {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                } else {
                    self.isRunning = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func resetTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        switch mode {
        case .work:
            timeRemaining = 25 * 60
        case .shortBreak:
            timeRemaining = 5 * 60
        case .longBreak:
            timeRemaining = 15 * 60
        }
    }
}
