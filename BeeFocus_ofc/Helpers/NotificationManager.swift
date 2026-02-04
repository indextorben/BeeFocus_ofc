//
//  NotificationManager.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 13.06.25.
//

import Foundation
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let openTodayDueFromNotification = Notification.Name("OpenTodayDueFromNotification")
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let localizer = LocalizationManager.shared
    static let shared = NotificationManager()
    private override init() {}
    
    private let timerNotificationID = "timerNotification"
    private let completionNotificationID = "completionNotification"
    private let morningSummaryNotificationID = "morningSummaryNotification"
    
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
        
        let openCategory = UNNotificationCategory(identifier: "MORNING_SUMMARY", actions: [], intentIdentifiers: [], options: [.customDismissAction])
        center.setNotificationCategories([openCategory])
    }
    
    /// Planen einer Timer-Benachrichtigung nach gegebener Dauer (vorgegebene ID)
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
    
    /// Planen einer Timer-Benachrichtigung mit eigener ID (z. B. für Todos)
    func scheduleTimerNotification(id: String, title: String, body: String, duration: TimeInterval) {
        guard duration > 1 else {
            print("⛔️ Fehler: Dauer zu kurz für Notification (\(duration) Sek.) – keine Benachrichtigung geplant.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    /// Sofortige Notification zum Abschluss, z. B. nach Timer-Ende
    func sendCompletionNotification(isBreak: Bool) {
        let content = UNMutableNotificationContent()
        content.title = localizer.localizedString(forKey: isBreak ? "notification_break_title" : "notification_work_title")
        content.body = localizer.localizedString(forKey: isBreak ? "notification_break_body" : "notification_work_body")
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
    
    /// Abbrechen einer beliebigen Benachrichtigung per ID
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
    
    /// Manuelle Testbenachrichtigung (z. B. über Button)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = localizer.localizedString(forKey: "test_notification_title")
        content.body = localizer.localizedString(forKey: "test_notification_body")
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
    
    /// Plant eine Benachrichtigung für ein Todo mit dueDate
    func scheduleTodoNotification(for todo: TodoItem) {
        guard let dueDate = todo.dueDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📝 \(todo.title)"
        let bodyText = todo.description.isEmpty ? localizer.localizedString(forKey: "todo_default_body") : todo.description
        content.body = bodyText
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: todo.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Fehler beim Planen der Todo-Notification: \(error)")
            } else {
                print("✅ Benachrichtigung geplant für Todo: \(todo.title)")
            }
        }
    }
    
    /// Entfernt geplante Benachrichtigung für ein Todo
    func removeTodoNotification(for todo: TodoItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [todo.id.uuidString])
    }
    
    /// Plant eine tägliche Morgen-Übersicht um eine feste Uhrzeit (Standard 06:00)
    func scheduleDailyMorningSummary(hour: Int = 6, minute: Int = 0, body: String) {
        // Entferne alte Planung, um Duplikate zu vermeiden
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [morningSummaryNotificationID])

        let content = UNMutableNotificationContent()
        content.title = localizer.localizedString(forKey: "morning_summary_title")
        content.body = body
        content.sound = .default
        content.userInfo = ["action": "openToday"]
        content.categoryIdentifier = "MORNING_SUMMARY"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        // Täglich wiederkehrender Trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: morningSummaryNotificationID,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Fehler beim Planen der Morgen-Übersicht: \(error)")
            } else {
                print("✅ Morgen-Übersicht geplant für \(hour):\(String(format: "%02d", minute))")
            }
        }
    }

    /// Entfernt die geplante tägliche Morgen-Übersicht
    func cancelDailyMorningSummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [morningSummaryNotificationID])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let action = info["action"] as? String, action == "openToday" {
            NotificationCenter.default.post(name: .openTodayDueFromNotification, object: nil)
        }
        completionHandler()
    }
}

