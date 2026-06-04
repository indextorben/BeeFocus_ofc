import SwiftUI
import UserNotifications

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "star.fill"
    var colorName: String = "purple"
    var completedDates: [String] = []
    var createdAt: Date = Date()

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    static func dateKey(_ date: Date) -> String { df.string(from: date) }

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

    func isCompleted(on date: Date) -> Bool {
        completedDates.contains(Habit.dateKey(date))
    }

    var currentStreak: Int {
        let cal = Calendar.current
        let completedSet = Set(completedDates)
        var check = cal.startOfDay(for: Date())
        if !completedSet.contains(Habit.dateKey(check)) {
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { return 0 }
            check = prev
        }
        var streak = 0
        while completedSet.contains(Habit.dateKey(check)) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    var totalCompletions: Int { completedDates.count }

    func last7Days() -> [(date: Date, done: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> (Date, Bool)? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (d, isCompleted(on: d))
        }
    }
}

@MainActor
final class HabitStore: ObservableObject {
    static let shared = HabitStore()

    @Published var habits: [Habit] = []

    private let key = "habits_v1"

    private init() { load() }

    func toggle(_ habit: Habit, on date: Date = Date()) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let key = Habit.dateKey(date)
        if habits[idx].completedDates.contains(key) {
            habits[idx].completedDates.removeAll { $0 == key }
        } else {
            habits[idx].completedDates.append(key)
        }
        save()
    }

    func add(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func update(_ habit: Habit) {
        guard let idx = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        habits[idx] = habit
        save()
    }

    func delete(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        save()
    }

    func todayProgress() -> (done: Int, total: Int) {
        let today = Date()
        let done = habits.filter { $0.isCompleted(on: today) }.count
        return (done, habits.count)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Habit].self, from: data) else { return }
        habits = decoded
    }
}

// MARK: - Available icons for picker
extension Habit {
    static let availableIcons: [String] = [
        "drop.fill", "figure.walk", "book.fill", "moon.fill", "heart.fill",
        "fork.knife", "dumbbell.fill", "pencil", "sun.max.fill", "music.note",
        "leaf.fill", "star.fill", "trophy.fill", "flame.fill", "bolt.fill",
        "zzz", "pills.fill", "brain.head.profile", "bicycle", "cup.and.saucer.fill",
        "🧘"
    ]

    static let availableColors: [(name: String, label: String)] = [
        ("purple", "Purple"), ("blue", "Blue"), ("green", "Green"),
        ("orange", "Orange"), ("red", "Red"), ("yellow", "Yellow"),
        ("pink", "Pink"), ("cyan", "Cyan"), ("teal", "Teal")
    ]
}
