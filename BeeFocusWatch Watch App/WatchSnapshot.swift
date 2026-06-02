import Foundation
import SwiftUI

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
    let todayBausteine: [WatchBaustein]
    let waterTodayML: Int
    let waterGoalML: Int
    let habits: [WatchHabit]
    let countdownEvents: [WatchCountdown]

    init(dueTodayCount: Int, overdueCount: Int, completedTodayCount: Int,
         totalOpenCount: Int, focusMinutesToday: Int, topTasks: [WatchTask],
         activeTheme: String, monthTasks: [WatchTask] = [],
         activeMonthLabel: String = "", todayBausteine: [WatchBaustein] = [],
         waterTodayML: Int = 0, waterGoalML: Int = 2000,
         habits: [WatchHabit] = [], countdownEvents: [WatchCountdown] = []) {
        self.dueTodayCount = dueTodayCount
        self.overdueCount = overdueCount
        self.completedTodayCount = completedTodayCount
        self.totalOpenCount = totalOpenCount
        self.focusMinutesToday = focusMinutesToday
        self.topTasks = topTasks
        self.activeTheme = activeTheme
        self.monthTasks = monthTasks
        self.activeMonthLabel = activeMonthLabel
        self.todayBausteine = todayBausteine
        self.waterTodayML = waterTodayML
        self.waterGoalML = waterGoalML
        self.habits = habits
        self.countdownEvents = countdownEvents
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
        todayBausteine      = (try? c.decode([WatchBaustein].self, forKey: .todayBausteine)) ?? []
        waterTodayML        = (try? c.decode(Int.self, forKey: .waterTodayML)) ?? 0
        waterGoalML         = (try? c.decode(Int.self, forKey: .waterGoalML)) ?? 2000
        habits              = (try? c.decode([WatchHabit].self, forKey: .habits)) ?? []
        countdownEvents     = (try? c.decode([WatchCountdown].self, forKey: .countdownEvents)) ?? []
    }

    static let placeholder = WatchSnapshot(
        dueTodayCount: 4, overdueCount: 1, completedTodayCount: 2,
        totalOpenCount: 9, focusMinutesToday: 65,
        topTasks: [
            WatchTask(id: UUID(), title: "Deep Work", isHighPriority: true,
                      dueDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()),
                      endDate: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()),
                      priorityRaw: "high", categoryName: "Arbeit", categoryColorHex: "4A90E2",
                      taskDescription: "", subTasksTotal: 3, subTasksCompleted: 1, isFavorite: true, isOverdue: false),
            WatchTask(id: UUID(), title: "E-Mails", isHighPriority: false,
                      dueDate: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()),
                      endDate: nil, priorityRaw: "medium", categoryName: nil, categoryColorHex: nil,
                      taskDescription: "", subTasksTotal: 0, subTasksCompleted: 0, isFavorite: false, isOverdue: false),
        ],
        activeTheme: "",
        monthTasks: [],
        activeMonthLabel: "Juni 2026",
        todayBausteine: [],
        waterTodayML: 800, waterGoalML: 2000,
        habits: [
            WatchHabit(id: UUID(), name: "Sport", icon: "figure.walk", colorName: "green", isCompletedToday: true, streak: 5),
            WatchHabit(id: UUID(), name: "Lesen", icon: "book.fill", colorName: "blue", isCompletedToday: false, streak: 2),
        ],
        countdownEvents: [
            WatchCountdown(id: UUID(), name: "Urlaub", symbol: "airplane", farbName: "blau", tageVerbleibend: 12),
        ]
    )
}

// MARK: - WatchHabit

struct WatchHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorName: String
    let isCompletedToday: Bool
    let streak: Int

    var color: Color {
        switch colorName {
        case "blue":   return Color(red: 0.3, green: 0.6, blue: 1.0)
        case "green":  return Color(red: 0.2, green: 0.82, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "red":    return Color(red: 1.0, green: 0.3, blue: 0.35)
        case "yellow": return Color(red: 1.0, green: 0.85, blue: 0.2)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "cyan":   return Color(red: 0.2, green: 0.85, blue: 0.95)
        case "teal":   return Color(red: 0.1, green: 0.7, blue: 0.65)
        default:       return Color(red: 0.6, green: 0.3, blue: 1.0)
        }
    }
}

// MARK: - WatchCountdown

struct WatchCountdown: Codable, Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let farbName: String
    let tageVerbleibend: Int

    var farbe: Color {
        switch farbName {
        case "blau":   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":  return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "lila":   return Color(red: 0.6, green: 0.3, blue: 1.0)
        case "teal":   return Color(red: 0.2, green: 0.75, blue: 0.8)
        case "rot":    return Color(red: 1.0, green: 0.25, blue: 0.25)
        case "gelb":   return Color(red: 1.0, green: 0.8, blue: 0.1)
        default:       return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }
}

// MARK: - WatchTask

struct WatchTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
    let dueDate: Date?
    let endDate: Date?
    let priorityRaw: String
    let categoryName: String?
    let categoryColorHex: String?
    let taskDescription: String
    let subTasksTotal: Int
    let subTasksCompleted: Int
    let isFavorite: Bool
    let isOverdue: Bool

    init(id: UUID, title: String, isHighPriority: Bool,
         dueDate: Date? = nil, endDate: Date? = nil,
         priorityRaw: String = "medium",
         categoryName: String? = nil, categoryColorHex: String? = nil,
         taskDescription: String = "",
         subTasksTotal: Int = 0, subTasksCompleted: Int = 0,
         isFavorite: Bool = false, isOverdue: Bool = false) {
        self.id = id
        self.title = title
        self.isHighPriority = isHighPriority
        self.dueDate = dueDate
        self.endDate = endDate
        self.priorityRaw = priorityRaw
        self.categoryName = categoryName
        self.categoryColorHex = categoryColorHex
        self.taskDescription = taskDescription
        self.subTasksTotal = subTasksTotal
        self.subTasksCompleted = subTasksCompleted
        self.isFavorite = isFavorite
        self.isOverdue = isOverdue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        title            = try c.decode(String.self, forKey: .title)
        isHighPriority   = try c.decode(Bool.self, forKey: .isHighPriority)
        dueDate          = try? c.decode(Date.self, forKey: .dueDate)
        endDate          = try? c.decode(Date.self, forKey: .endDate)
        priorityRaw      = (try? c.decode(String.self, forKey: .priorityRaw)) ?? "medium"
        categoryName     = try? c.decode(String.self, forKey: .categoryName)
        categoryColorHex = try? c.decode(String.self, forKey: .categoryColorHex)
        taskDescription  = (try? c.decode(String.self, forKey: .taskDescription)) ?? ""
        subTasksTotal    = (try? c.decode(Int.self, forKey: .subTasksTotal)) ?? 0
        subTasksCompleted = (try? c.decode(Int.self, forKey: .subTasksCompleted)) ?? 0
        isFavorite       = (try? c.decode(Bool.self, forKey: .isFavorite)) ?? false
        isOverdue        = (try? c.decode(Bool.self, forKey: .isOverdue)) ?? false
    }

    var priorityColor: Color {
        switch priorityRaw {
        case "high": return .red
        case "low":  return .green
        default:     return .blue
        }
    }

    var categoryColor: Color {
        guard let hex = categoryColorHex else { return .secondary }
        return Color(hexString: hex)
    }
}

// MARK: - WatchBaustein

struct WatchBaustein: Codable, Identifiable {
    let id: UUID
    let titel: String
    let symbol: String
    let farbeName: String
    let zeitLabel: String
    let beschreibung: String
    let isHighPriority: Bool
    let startStunde: Int
    let startMinute: Int

    var farbe: Color {
        switch farbeName {
        case "blau":   return .blue
        case "gruen":  return .green
        case "orange": return .orange
        case "pink":   return .pink
        case "lila":   return .purple
        case "teal":   return .teal
        case "rot":    return .red
        case "gelb":   return .yellow
        case "cyan":   return .cyan
        case "indigo": return .indigo
        case "mint":   return .mint
        default:       return .blue
        }
    }
}

// MARK: - Color from hex

extension Color {
    init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
