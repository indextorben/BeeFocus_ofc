import Foundation
import WidgetKit

// MARK: - Shared Widget Models (main app side)

struct WidgetSnapshot: Codable {
    let dueTodayCount: Int
    let overdueCount: Int
    let completedTodayCount: Int
    let totalOpenCount: Int
    let focusMinutesToday: Int
    let topTasks: [WidgetTask]
    let activeTheme: String
    let monthTasks: [WidgetTask]
    let activeMonthLabel: String
    let todayBausteine: [WatchBaustein]
}

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
    // Rich fields (optional for backward compatibility)
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
}

// MARK: - TodoStore Widget Extension

let beeFocusAppGroup = "group.com.TorbenLehneke.BeeFocus-ofc"

extension TodoStore {
    func writeWidgetSnapshot() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let todayTodos = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= today && due < tomorrow
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        let filterMonthOnly = UserDefaults.standard.bool(forKey: "filterCurrentMonthOnly")
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? today
        let monthEnd   = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? today

        let firstDayOfNextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) ?? today
        let daysUntilNextMonth = cal.dateComponents([.day], from: today, to: firstDayOfNextMonth).day ?? 31
        let showNextMonth = daysUntilNextMonth <= 10
        let activeMonthStart = showNextMonth ? firstDayOfNextMonth : monthStart
        let activeMonthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: activeMonthStart) ?? today

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "MMMM yyyy"
        let activeMonthLabel = fmt.string(from: activeMonthStart).capitalized

        let overdueCount = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            guard due < today else { return false }
            if filterMonthOnly { return due >= monthStart && due <= monthEnd }
            return true
        }.count

        let completedToday = todos.filter { todo in
            guard todo.isCompleted, let done = todo.completedAt else { return false }
            return cal.isDate(done, inSameDayAs: Date())
        }.count

        let focusToday = dailyFocusMinutes[today] ?? 0
        let activeTheme = UserDefaults.standard.string(forKey: "aktivesStatistikThema") ?? ""

        let topTasks = Array(todayTodos.prefix(8)).map { makeWidgetTask($0, today: today) }

        let monthTasks = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= activeMonthStart && due <= activeMonthEnd
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        .prefix(12)
        .map { makeWidgetTask($0, today: today) }

        // Build today's Baustein plan
        let bausteine = buildTodayBausteine()

        let snapshot = WidgetSnapshot(
            dueTodayCount: todayTodos.count,
            overdueCount: overdueCount,
            completedTodayCount: completedToday,
            totalOpenCount: todos.filter { !$0.isCompleted }.count,
            focusMinutesToday: focusToday,
            topTasks: topTasks,
            activeTheme: activeTheme,
            monthTasks: Array(monthTasks),
            activeMonthLabel: activeMonthLabel,
            todayBausteine: bausteine
        )

        if let defaults = UserDefaults(suiteName: beeFocusAppGroup),
           let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: "widgetSnapshot")
            PhoneSessionManager.shared.sendSnapshotData(data)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func makeWidgetTask(_ todo: TodoItem, today: Date) -> WidgetTask {
        WidgetTask(
            id: todo.id,
            title: todo.title,
            isHighPriority: todo.priority == .high,
            dueDate: todo.dueDate,
            endDate: todo.endDate,
            priorityRaw: todo.priority.rawValue,
            categoryName: todo.category?.name,
            categoryColorHex: todo.category?.colorHex,
            taskDescription: todo.description,
            subTasksTotal: todo.subTasks.count,
            subTasksCompleted: todo.subTasks.filter { $0.isCompleted }.count,
            isFavorite: todo.isFavorite,
            isOverdue: todo.isOverdue
        )
    }

    private func buildTodayBausteine() -> [WatchBaustein] {
        guard let data = UserDefaults.standard.data(forKey: "tagesplanBausteine"),
              let decoded = try? JSONDecoder().decode([TagesplanBaustein].self, from: data)
        else { return [] }

        let cal = Calendar.current
        let raw = cal.component(.weekday, from: Date())
        let wochentag = raw == 1 ? 7 : raw - 1  // 1=Mo…7=So

        return decoded
            .filter { b in b.wochentage.isEmpty || b.wochentage.contains(wochentag) }
            .sorted { a, b in
                if a.startStunde != b.startStunde { return a.startStunde < b.startStunde }
                return a.startMinute < b.startMinute
            }
            .prefix(15)
            .map { b in
                WatchBaustein(
                    id: b.id,
                    titel: b.titel,
                    symbol: b.symbol,
                    farbeName: b.farbe.rawValue,
                    zeitLabel: b.zeitLabel,
                    beschreibung: b.beschreibung,
                    isHighPriority: b.isHighPriority,
                    startStunde: b.startStunde,
                    startMinute: b.startMinute
                )
            }
    }
}
