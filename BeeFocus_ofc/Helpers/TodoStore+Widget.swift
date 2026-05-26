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
}

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
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

        // Active month for Watch: switch to next month if ≤10 days until month end
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

        let topTasks = Array(todayTodos.prefix(5)).map {
            WidgetTask(id: $0.id, title: $0.title, isHighPriority: $0.priority == .high)
        }

        let monthTasks = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= activeMonthStart && due <= activeMonthEnd
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        .prefix(10)
        .map { WidgetTask(id: $0.id, title: $0.title, isHighPriority: $0.priority == .high) }

        let snapshot = WidgetSnapshot(
            dueTodayCount: todayTodos.count,
            overdueCount: overdueCount,
            completedTodayCount: completedToday,
            totalOpenCount: todos.filter { !$0.isCompleted }.count,
            focusMinutesToday: focusToday,
            topTasks: topTasks,
            activeTheme: activeTheme,
            monthTasks: Array(monthTasks),
            activeMonthLabel: activeMonthLabel
        )

        if let defaults = UserDefaults(suiteName: beeFocusAppGroup),
           let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: "widgetSnapshot")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
