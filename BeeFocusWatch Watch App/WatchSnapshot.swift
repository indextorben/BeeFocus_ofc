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
    let monthTasks: [WatchTask]
    let activeMonthLabel: String

    init(dueTodayCount: Int, overdueCount: Int, completedTodayCount: Int,
         totalOpenCount: Int, focusMinutesToday: Int, topTasks: [WatchTask],
         activeTheme: String, monthTasks: [WatchTask] = [], activeMonthLabel: String = "") {
        self.dueTodayCount = dueTodayCount
        self.overdueCount = overdueCount
        self.completedTodayCount = completedTodayCount
        self.totalOpenCount = totalOpenCount
        self.focusMinutesToday = focusMinutesToday
        self.topTasks = topTasks
        self.activeTheme = activeTheme
        self.monthTasks = monthTasks
        self.activeMonthLabel = activeMonthLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dueTodayCount       = try c.decode(Int.self, forKey: .dueTodayCount)
        overdueCount        = try c.decode(Int.self, forKey: .overdueCount)
        completedTodayCount = try c.decode(Int.self, forKey: .completedTodayCount)
        totalOpenCount      = try c.decode(Int.self, forKey: .totalOpenCount)
        focusMinutesToday   = try c.decode(Int.self, forKey: .focusMinutesToday)
        topTasks            = try c.decode([WatchTask].self, forKey: .topTasks)
        activeTheme         = try c.decode(String.self, forKey: .activeTheme)
        monthTasks          = (try? c.decode([WatchTask].self, forKey: .monthTasks)) ?? []
        activeMonthLabel    = (try? c.decode(String.self, forKey: .activeMonthLabel)) ?? ""
    }

    static let placeholder = WatchSnapshot(
        dueTodayCount: 3, overdueCount: 1, completedTodayCount: 1,
        totalOpenCount: 8, focusMinutesToday: 0,
        topTasks: [
            WatchTask(id: UUID(), title: "Meeting vorbereiten", isHighPriority: true),
            WatchTask(id: UUID(), title: "Arzt anrufen", isHighPriority: false),
            WatchTask(id: UUID(), title: "Einkaufen", isHighPriority: false),
        ],
        activeTheme: "",
        monthTasks: [
            WatchTask(id: UUID(), title: "Projektbericht", isHighPriority: true),
            WatchTask(id: UUID(), title: "Zahnarzt Termin", isHighPriority: false),
            WatchTask(id: UUID(), title: "Steuererklärung", isHighPriority: false),
        ],
        activeMonthLabel: "Mai 2026"
    )
}

struct WatchTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
}
