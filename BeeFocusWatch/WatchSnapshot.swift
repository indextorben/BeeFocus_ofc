import Foundation

// Mirrors WidgetSnapshot from the main app — must stay in sync.
struct WatchSnapshot: Codable {
    let dueTodayCount: Int
    let overdueCount: Int
    let completedTodayCount: Int
    let totalOpenCount: Int
    let focusMinutesToday: Int
    let topTasks: [WatchTask]
    let activeTheme: String

    static let placeholder = WatchSnapshot(
        dueTodayCount: 3, overdueCount: 1, completedTodayCount: 1,
        totalOpenCount: 8, focusMinutesToday: 0,
        topTasks: [
            WatchTask(id: UUID(), title: "Meeting vorbereiten", isHighPriority: true),
            WatchTask(id: UUID(), title: "Arzt anrufen", isHighPriority: false),
            WatchTask(id: UUID(), title: "Einkaufen", isHighPriority: false),
        ],
        activeTheme: ""
    )
}

struct WatchTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
}
