//
//  PomodoroSettings.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

//Einstellungen - Timer
class PomodoroSettings: ObservableObject {
    @Published var workTime: Int = 25 * 60 // 25 Minuten
    @Published var shortBreakTime: Int = 5 * 60 // 5 Minuten
    @Published var longBreakTime: Int = 15 * 60 // 15 Minuten
    @Published var pomodorosUntilLongBreak: Int = 4
}
