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

    init(dueTodayCount: Int, overdueCount: Int, completedTodayCount: Int,
         totalOpenCount: Int, focusMinutesToday: Int, topTasks: [WatchTask],
         activeTheme: String, monthTasks: [WatchTask] = [],
         activeMonthLabel: String = "", todayBausteine: [WatchBaustein] = []) {
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
    }

    static let placeholder = WatchSnapshot(
        dueTodayCount: 4, overdueCount: 1, completedTodayCount: 2,
        totalOpenCount: 9, focusMinutesToday: 65,
        topTasks: [
            WatchTask(id: UUID(), title: "Deep Work", isHighPriority: true,
                      dueDate: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()),
                      endDate: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()),
                      priorityRaw: "high", categoryName: "Arbeit", categoryColorHex: "4A90E2",
                      taskDescription: "Tiefe Konzentration, Handy weg",
                      subTasksTotal: 3, subTasksCompleted: 1, isFavorite: true, isOverdue: false),
            WatchTask(id: UUID(), title: "E-Mails & Nachrichten", isHighPriority: false,
                      dueDate: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()),
                      endDate: Calendar.current.date(bySettingHour: 11, minute: 30, second: 0, of: Date()),
                      priorityRaw: "medium", categoryName: "Kommunikation", categoryColorHex: "50C878",
                      taskDescription: "", subTasksTotal: 0, subTasksCompleted: 0, isFavorite: false, isOverdue: false),
            WatchTask(id: UUID(), title: "Zahnarzt Termin", isHighPriority: false,
                      dueDate: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()),
                      endDate: nil,
                      priorityRaw: "low", categoryName: nil, categoryColorHex: nil,
                      taskDescription: "", subTasksTotal: 0, subTasksCompleted: 0, isFavorite: false, isOverdue: true),
        ],
        activeTheme: "",
        monthTasks: [
            WatchTask(id: UUID(), title: "Projektbericht abgeben", isHighPriority: true,
                      dueDate: nil, endDate: nil, priorityRaw: "high",
                      categoryName: "Arbeit", categoryColorHex: "4A90E2",
                      taskDescription: "", subTasksTotal: 5, subTasksCompleted: 2,
                      isFavorite: false, isOverdue: false),
            WatchTask(id: UUID(), title: "Steuererklärung", isHighPriority: false,
                      dueDate: nil, endDate: nil, priorityRaw: "medium",
                      categoryName: nil, categoryColorHex: nil,
                      taskDescription: "", subTasksTotal: 0, subTasksCompleted: 0,
                      isFavorite: false, isOverdue: false),
        ],
        activeMonthLabel: "Juni 2026",
        todayBausteine: [
            WatchBaustein(id: UUID(), titel: "Morgenroutine", symbol: "sun.max.fill",
                          farbeName: "gelb", zeitLabel: "07:00 – 07:30",
                          beschreibung: "Frühstück, Körperpflege, Tag starten",
                          isHighPriority: false, startStunde: 7, startMinute: 0),
            WatchBaustein(id: UUID(), titel: "Deep Work", symbol: "brain.head.profile",
                          farbeName: "indigo", zeitLabel: "09:00 – 11:00",
                          beschreibung: "Tiefe Konzentration, Handy weg",
                          isHighPriority: true, startStunde: 9, startMinute: 0),
            WatchBaustein(id: UUID(), titel: "Mittagspause", symbol: "fork.knife",
                          farbeName: "gruen", zeitLabel: "12:00 – 13:00",
                          beschreibung: "Essen, kurze Auszeit",
                          isHighPriority: false, startStunde: 12, startMinute: 0),
        ]
    )
}

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
        case "high":   return .red
        case "low":    return .green
        default:       return .blue
        }
    }

    var categoryColor: Color {
        guard let hex = categoryColorHex else { return .secondary }
        return Color(hexString: hex)
    }

    var accentColor: Color {
        if let _ = categoryColorHex { return categoryColor }
        return priorityColor
    }
}

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
