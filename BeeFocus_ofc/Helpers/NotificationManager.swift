//
//  NotificationManager.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 13.06.25.
//

import Foundation
import SwiftUI
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private override init() {}

    private let timerNotificationID = "timerNotification"
    private let completionNotificationID = "completionNotification"

    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Benachrichtigungsfehler: \(error.localizedDescription)")
            }
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        center.delegate = self
    }

    /// Planen einer Timer-Benachrichtigung nach gegebener Dauer
    func scheduleTimerNotification(title: String, body: String, duration: TimeInterval) {
        guard duration > 1 else {
            print("⛔️ Fehler: Dauer zu kurz für Notification (\(duration) Sek.) – keine Benachrichtigung geplant.")
            return
        }

        cancelTimerNotification()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)

        let request = UNNotificationRequest(
            identifier: timerNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Sofortige Notification zum Abschluss, z. B. nach Timer-Ende
    func sendCompletionNotification(isBreak: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isBreak ? "Pause starten!" : "Zeit für eine Pause!"
        content.body = isBreak ? "Die Fokuszeit ist vorbei. Entspann dich kurz!" : "Die Pause ist vorbei. Zeit zum Arbeiten!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: completionNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Abbrechen laufender Timer-Benachrichtigung
    func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerNotificationID])
    }

    /// Manuelle Testbenachrichtigung (z. B. über Button)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Testbenachrichtigung"
        content.body = "Dies ist eine Testnachricht von BeeFocus"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)

        let request = UNNotificationRequest(
            identifier: "testNotification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Anzeige auch im Vordergrund (Banner + Ton)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
