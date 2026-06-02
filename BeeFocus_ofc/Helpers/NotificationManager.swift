import Foundation
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let openTodayDueFromNotification = Notification.Name("OpenTodayDueFromNotification")
    static let focusSessionCompleted        = Notification.Name("FocusSessionCompleted")
    static let showPaywall                  = Notification.Name("ShowPaywall")
}

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let localizer = LocalizationManager.shared
    static let shared = NotificationManager()
    private override init() {}

    private let timerNotificationID    = "timerNotification"
    private let completionNotificationID = "completionNotification"
    private let morningSummaryNotificationID = "morningSummaryNotification"

    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Benachrichtigungsfehler: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion(granted) }
        }
        center.delegate = self

        let openCategory = UNNotificationCategory(
            identifier: "MORNING_SUMMARY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([openCategory])
    }

    // MARK: - Timer Notifications

    /// Countdown-Notification: feuert nach `duration` Sekunden
    func scheduleTimerNotification(title: String, body: String, duration: TimeInterval) {
        guard duration > 1 else { return }
        cancelTimerNotification()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: timerNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Countdown-Notification mit eigener ID (z.B. fuer Todos)
    func scheduleTimerNotification(id: String, title: String, body: String, duration: TimeInterval) {
        guard duration > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Abschluss-Notification nach Timer-Ende (1 s Verzoegerung)
    /// isBreak == true  → Fokuszeit gerade beendet, Pause beginnt
    /// isBreak == false → Pause gerade beendet, Fokus beginnt
    func sendCompletionNotification(isBreak: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isBreak ? "Fokuszeit geschafft! 🎉" : "Pause vorbei!"
        content.body  = isBreak ? "Goenn dir eine kurze Pause." : "Zeit fuer den naechsten Fokus-Block."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: completionNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Nur den Countdown-Timer canceln
    func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [timerNotificationID]
        )
    }

    /// Alle timer-bezogenen Notifications canceln (Countdown + Abschluss)
    func cancelAllTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [timerNotificationID, completionNotificationID]
        )
    }

    /// Beliebige Notification per ID canceln
    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Todo Notifications

    /// Plant eine Notification fuer ein Todo zum faelligen Datum
    func scheduleTodoNotification(for todo: TodoItem) {
        guard let dueDate = todo.dueDate else { return }

        let content = UNMutableNotificationContent()
        content.title = "📝 \(todo.title)"
        content.body  = todo.description.isEmpty
            ? localizer.localizedString(forKey: "todo_default_body")
            : todo.description
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let request = UNNotificationRequest(
            identifier: todo.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Fehler beim Planen der Todo-Notification: \(error)")
            }
        }
    }

    /// Plant eine Todo-Notification an einem bestimmten Datum mit eigener ID
    func scheduleTodoNotification(at date: Date, id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Fehler beim Planen der Todo-Notification (custom): \(error)")
            }
        }
    }

    func removeTodoNotification(for todo: TodoItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [todo.id.uuidString]
        )
    }

    // MARK: - Morning Summary

    func scheduleDailyMorningSummary(hour: Int = 6, minute: Int = 0, body: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [morningSummaryNotificationID]
        )

        let content = UNMutableNotificationContent()
        content.title = localizer.localizedString(forKey: "morning_summary_title")
        content.body  = body
        content.sound = .default
        content.userInfo = ["action": "openToday"]
        content.categoryIdentifier = "MORNING_SUMMARY"

        var dateComponents = DateComponents()
        dateComponents.hour   = hour
        dateComponents.minute = minute

        let request = UNNotificationRequest(
            identifier: morningSummaryNotificationID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Fehler beim Planen der Morgen-Uebersicht: \(error)")
            }
        }
    }

    func cancelDailyMorningSummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [morningSummaryNotificationID]
        )
    }

    // MARK: - Habit Reminder

    private let habitReminderID = "habitReminder"

    func scheduleHabitReminder(hour: Int, minute: Int) {
        cancelHabitReminder()
        let content = UNMutableNotificationContent()
        content.title = "✅ Gewohnheiten-Check"
        content.body  = "Hast du heute deine Gewohnheiten gepflegt?"
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let request = UNNotificationRequest(
            identifier: habitReminderID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    func cancelHabitReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [habitReminderID])
    }

    // MARK: - Water Reminders

    private let waterReminderPrefix = "water_"

    /// Schedules daily water-drink reminders from 8:00 AM to 8:00 PM at `intervalHours` spacing.
    func scheduleWaterReminders(intervalHours: Int) {
        cancelWaterReminders()
        let interval = max(1, intervalHours)
        let center = UNUserNotificationCenter.current()
        var hour = 8
        var index = 0
        while hour <= 20 && index < 13 {
            let content = UNMutableNotificationContent()
            content.title = "💧 Zeit zu trinken"
            content.body  = "Trink ein Glas Wasser – dein Körper dankt es dir!"
            content.sound = .default
            var comps = DateComponents(); comps.hour = hour; comps.minute = 0
            let request = UNNotificationRequest(
                identifier: "\(waterReminderPrefix)\(index)", content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            center.add(request)
            hour  += interval
            index += 1
        }
    }

    func cancelWaterReminders() {
        let ids = (0..<13).map { "\(waterReminderPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Overdue Alert

    private let overdueAlertID = "overdueAlert"

    func scheduleOverdueAlert(hour: Int, minute: Int) {
        cancelOverdueAlert()
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Offene Aufgaben"
        content.body  = "Du hast noch überfällige Aufgaben – ein guter Moment, sie zu erledigen."
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let request = UNNotificationRequest(
            identifier: overdueAlertID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    func cancelOverdueAlert() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [overdueAlertID])
    }

    // MARK: - Weekly Review

    private let weeklyReviewID = "weeklyReview"

    /// weekday: 1 = Sonntag, 2 = Montag, … 7 = Samstag (wie NSCalendar)
    func scheduleWeeklyReview(weekday: Int = 1, hour: Int, minute: Int) {
        cancelWeeklyReview()
        let content = UNMutableNotificationContent()
        content.title = "📋 Wochenrückblick"
        content.body  = "Nimm dir einen Moment und überprüfe deine Wochenziele."
        content.sound = .default
        var comps = DateComponents(); comps.weekday = weekday; comps.hour = hour; comps.minute = minute
        let request = UNNotificationRequest(
            identifier: weeklyReviewID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklyReview() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [weeklyReviewID])
    }

    // MARK: - Mood Reminder

    private let moodReminderID = "moodReminder"

    func scheduleMoodReminder(hour: Int, minute: Int) {
        cancelMoodReminder()
        let content = UNMutableNotificationContent()
        content.title = "😊 Stimmungs-Check"
        content.body  = "Wie fühlst du dich heute? Trag deine Stimmung ein."
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let request = UNNotificationRequest(
            identifier: moodReminderID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    func cancelMoodReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [moodReminderID])
    }

    // MARK: - Evening / Gratitude Reminder

    private let eveningReminderID = "eveningReminder"

    func scheduleEveningReminder(hour: Int, minute: Int) {
        cancelEveningReminder()
        let content = UNMutableNotificationContent()
        content.title = "🌙 Abendreflexion"
        content.body  = "Nimm dir 5 Minuten für dein Tagesjournal oder Dankbarkeits-Eintrag."
        content.sound = .default
        var comps = DateComponents(); comps.hour = hour; comps.minute = minute
        let request = UNNotificationRequest(
            identifier: eveningReminderID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
        UNUserNotificationCenter.current().add(request)
    }

    func cancelEveningReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [eveningReminderID])
    }

    // MARK: - Test

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test-Benachrichtigung"
        content.body  = "Benachrichtigungen funktionieren korrekt."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "testNotification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Delegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let action = info["action"] as? String, action == "openToday" {
            NotificationCenter.default.post(name: .openTodayDueFromNotification, object: nil)
        }
        completionHandler()
    }
}
