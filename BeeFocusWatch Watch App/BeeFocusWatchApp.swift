//
//  BeeFocusWatchApp.swift
//  BeeFocusWatch Watch App
//
//  Created by Torben Lehneke on 25.05.26.
//

import SwiftUI
import UserNotifications

@main
struct BeeFocusWatch_Watch_AppApp: App {
    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
