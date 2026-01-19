import Foundation
import Combine

struct Category: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String
}

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var categories: [Category] = []
    @Published var dailyStats: [Date: Int] = [:] // Erledigte Aufgaben pro Tag

    @Published var dailyFocusMinutes: [Date: Int] = [:] // Fokus-Minuten pro Tag

    private let focusKey = "dailyFocusMinutes"

    private let todosKey = "todos"
    private let categoriesKey = "categories"
    private let statsKey = "dailyStats"

    private var cancellables = Set<AnyCancellable>()

    init() {
        loadTodos()
        loadCategoriesFromCloud()
        loadCategories()
        loadStats()
        loadFocusMinutes()
        // Cloud: initial fetch for stats
        CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
            _ = self?.mergeDailyStatsFromCloud(cloudDaily)
        }
        CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
            _ = self?.mergeDailyFocusMinutesFromCloud(cloudFocus)
        }
        // Observe focus session completion notifications to accumulate daily focus minutes
        NotificationCenter.default.addObserver(forName: .focusSessionCompleted, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let minutes = (note.userInfo?["minutes"] as? Int) ?? 0
            if minutes > 0 { self.addFocusMinutes(minutes) }
        }
    }

    func complete(todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isCompleted = true
        saveTodos()

        DispatchQueue.main.async {
            self.updateStats(for: todo)
        }

        // Cloud: push daily completion count for today
        let today = Calendar.current.startOfDay(for: Date())
        if let count = dailyStats[today] {
            CloudKitManager.shared.saveDailyStat(date: today, count: count)
        }
    }

    func updateStats(for todo: TodoItem) {
        let today = Calendar.current.startOfDay(for: Date())
        dailyStats[today, default: 0] += 1
        saveStats()
        CloudKitManager.shared.saveDailyStat(date: today, count: dailyStats[today] ?? 0)
    }

    private func saveTodos() {
        if let data = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(data, forKey: todosKey)
        }
    }

    private func loadTodos() {
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let loaded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            self.todos = loaded
        }
    }

    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
    }

    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let loaded = try? JSONDecoder().decode([Category].self, from: data) {
            self.categories = loaded
        }
    }

    private func saveStats() {
        if let data = try? JSONEncoder().encode(dailyStats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }

    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode([Date: Int].self, from: data) {
            self.dailyStats = stats
        }
    }

    private func loadFocusMinutes() {
        if let data = UserDefaults.standard.data(forKey: focusKey),
           let stats = try? JSONDecoder().decode([Date: Int].self, from: data) {
            self.dailyFocusMinutes = stats
        }
    }

    private func saveFocusMinutes() {
        if let data = try? JSONEncoder().encode(dailyFocusMinutes) {
            UserDefaults.standard.set(data, forKey: focusKey)
        }
    }

    func addFocusMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        dailyFocusMinutes[today, default: 0] += minutes
        saveFocusMinutes()
        CloudKitManager.shared.saveFocusStat(date: today, minutes: dailyFocusMinutes[today] ?? 0)
    }

    // Cloud merge helpers
    func mergeFromCloud(_ cloudTodos: [TodoItem]) -> Int {
        var changed = false
        var newTodos = todos

        for cloudTodo in cloudTodos {
            if let index = newTodos.firstIndex(where: { $0.id == cloudTodo.id }) {
                if newTodos[index] != cloudTodo {
                    newTodos[index] = cloudTodo
                    changed = true
                }
            } else {
                newTodos.append(cloudTodo)
                changed = true
            }
        }

        var changeCount = 0
        // Count differences by ID vs previous state
        let oldByID = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        for t in newTodos {
            if let old = oldByID[t.id], old != t { changeCount += 1 }
            if oldByID[t.id] == nil { changeCount += 1 }
        }

        if newTodos != todos {
            todos = newTodos
            saveTodos()
            DispatchQueue.main.async { self.objectWillChange.send() }
            return changeCount
        } else if changed {
            todos = newTodos
            saveTodos()
            return changeCount
        }
        return 0
    }

    func mergeDailyStatsFromCloud(_ cloud: [Date: Int]) -> Int {
        var changed = false
        var changeCount = 0
        for (date, count) in cloud {
            let local = dailyStats[date] ?? 0
            if count != local {
                dailyStats[date] = max(count, local)
                changed = true
                changeCount += 1
            }
        }
        if changed { saveStats(); DispatchQueue.main.async { self.objectWillChange.send() } }
        return changeCount
    }

    func mergeDailyFocusMinutesFromCloud(_ cloud: [Date: Int]) -> Int {
        var changed = false
        var changeCount = 0
        for (date, minutes) in cloud {
            let local = dailyFocusMinutes[date] ?? 0
            if minutes != local {
                dailyFocusMinutes[date] = max(minutes, local)
                changed = true
                changeCount += 1
            }
        }
        if changed { saveFocusMinutes(); DispatchQueue.main.async { self.objectWillChange.send() } }
        return changeCount
    }

    // Additional calendar related methods and other logic below...
}
