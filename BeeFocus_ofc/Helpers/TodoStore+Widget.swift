import Foundation
import WidgetKit

// MARK: - Shared Widget Models (main app side)

struct WatchHabit: Codable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let colorName: String
    let isCompletedToday: Bool
    let streak: Int
}

struct WatchCountdown: Codable, Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let farbName: String
    let tageVerbleibend: Int
}

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
    let waterTodayML: Int
    let waterGoalML: Int
    let habits: [WatchHabit]
    let countdownEvents: [WatchCountdown]
    let isPro: Bool
    let planTasks: [WidgetTask]
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
    func performWidgetSnapshot() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let filterMonthOnly = UserDefaults.standard.bool(forKey: "filterCurrentMonthOnly")

        let widgetDefaults = UserDefaults(suiteName: beeFocusAppGroup)
        let widgetTaskFilter = widgetDefaults?.string(forKey: "widgetTaskFilter") ?? "today"
        let widgetMaxTasks: Int = {
            let v = widgetDefaults?.integer(forKey: "widgetMaxTasks") ?? 0
            return v == 0 ? 5 : v
        }()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? today
        let monthEnd   = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) ?? today

        // "Heute": heute fällig + datumlose immer; überfällige nur im akt. Monat wenn Filter aktiv
        let todayTodos = todos.filter { todo in
            guard !todo.isCompleted else { return false }
            guard let due = todo.dueDate else { return true }
            guard due < tomorrow else { return false }
            if filterMonthOnly && due < today { return due >= monthStart }
            return true
        }.sorted {
            switch ($0.dueDate, $1.dueDate) {
            case (nil, nil):   return false
            case (nil, _):     return false
            case (_, nil):     return true
            default:           return $0.dueDate! < $1.dueDate!
            }
        }

        // "Planer": alle offenen Aufgaben nach Datum sortiert
        let allOpenSorted = todos.filter { !$0.isCompleted }
            .sorted { a, b in
                switch (a.dueDate, b.dueDate) {
                case (nil, nil):   return false
                case (nil, _):     return false
                case (_, nil):     return true
                default:           return a.dueDate! < b.dueDate!
                }
            }

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

        let filteredForWidget: [TodoItem]
        switch widgetTaskFilter {
        case "priority":
            filteredForWidget = todos
                .filter { !$0.isCompleted && $0.priority == .high }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case "all":
            filteredForWidget = allOpenSorted
        default:
            filteredForWidget = todayTodos
        }
        let topTasks = Array(filteredForWidget.prefix(widgetMaxTasks)).map { makeWidgetTask($0, today: today) }

        // planTasks für Watch "Alle": immer aktueller Monat + datumlose (kein Overdue aus Vorjahren)
        let planFiltered = allOpenSorted.filter { todo in
            guard let due = todo.dueDate else { return true }  // datumlose immer zeigen
            return due >= monthStart && due <= monthEnd
        }
        let planTasks = Array(planFiltered.prefix(50)).map { makeWidgetTask($0, today: today) }

        let monthTasks = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= activeMonthStart && due <= activeMonthEnd
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        .prefix(12)
        .map { makeWidgetTask($0, today: today) }

        // Build today's Baustein plan
        let bausteine = buildTodayBausteine()

        // Water
        let waterData = UserDefaults.standard.data(forKey: "wasser_eintraege_v1")
        let waterEntries = (try? JSONDecoder().decode([WasserEintrag].self, from: waterData ?? Data())) ?? []
        let waterToday = waterEntries.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.ml }
        let waterGoal = UserDefaults.standard.object(forKey: "wasserTagesziel") as? Int ?? 2000

        // Habits
        let habitData = UserDefaults.standard.data(forKey: "habits_v1")
        let habitList = (try? JSONDecoder().decode([Habit].self, from: habitData ?? Data())) ?? []
        let watchHabits = habitList.map { h in
            WatchHabit(id: h.id, name: h.name, icon: h.icon, colorName: h.colorName,
                       isCompletedToday: h.isCompleted(on: Date()),
                       streak: h.currentStreak)
        }

        // Countdowns
        let cdData = UserDefaults.standard.data(forKey: "countdown_events_v1")
        let cdEvents = (try? JSONDecoder().decode([CountdownEvent].self, from: cdData ?? Data())) ?? []
        let watchCountdowns = cdEvents
            .filter { $0.tageVerbleibend >= 0 }
            .sorted { $0.tageVerbleibend < $1.tageVerbleibend }
            .prefix(10)
            .map { e in WatchCountdown(id: e.id, name: e.name, symbol: e.symbol,
                                       farbName: e.farbName, tageVerbleibend: e.tageVerbleibend) }

        let isPro = NSUbiquitousKeyValueStore.default.bool(forKey: "beefocus_isPro")

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
            todayBausteine: bausteine,
            waterTodayML: waterToday,
            waterGoalML: waterGoal,
            habits: watchHabits,
            countdownEvents: Array(watchCountdowns),
            isPro: isPro,
            planTasks: planTasks
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
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"

        // Alle offenen Todos für heute — identisch zu TagesplanerView auf dem iPhone
        let todayTodos = todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= today && due < tomorrow
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }

        if !todayTodos.isEmpty {
            return todayTodos.prefix(20).map { todo in
                let due = todo.dueDate ?? today
                let startH = cal.component(.hour, from: due)
                let startM = cal.component(.minute, from: due)
                let hasTime = startH != 0 || startM != 0
                let zeitLabel: String
                if let end = todo.endDate {
                    let endH = cal.component(.hour, from: end)
                    let endM = cal.component(.minute, from: end)
                    zeitLabel = String(format: "%02d:%02d – %02d:%02d", startH, startM, endH, endM)
                } else if hasTime {
                    zeitLabel = String(format: "%02d:%02d", startH, startM)
                } else {
                    zeitLabel = "Ganztägig"
                }
                let farbeName: String
                switch todo.priority {
                case .high:   farbeName = "rot"
                case .medium: farbeName = "blau"
                case .low:    farbeName = "gruen"
                }
                return WatchBaustein(
                    id: todo.id,
                    titel: todo.title,
                    symbol: todo.category != nil ? "tag.fill" : "checklist",
                    farbeName: farbeName,
                    zeitLabel: zeitLabel,
                    beschreibung: todo.description,
                    isHighPriority: todo.priority == .high,
                    startStunde: startH,
                    startMinute: startM
                )
            }
        }

        return []
    }
}
