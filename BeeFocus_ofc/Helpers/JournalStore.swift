import SwiftUI

struct JournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var moodScore: Int = 3        // 1–5
    var energyScore: Int = 3      // 1–5
    var wentWell: String = ""
    var distraction: String = ""
    var tomorrowPriority: String = ""
    var focusMinutes: Int = 0

    static let moods: [(emoji: String, label: String, color: Color)] = [
        ("😩", "Sehr schlecht", Color(red: 0.9, green: 0.3, blue: 0.3)),
        ("😕", "Schlecht",      Color(red: 0.9, green: 0.6, blue: 0.2)),
        ("😐", "Neutral",       Color(red: 0.7, green: 0.7, blue: 0.3)),
        ("🙂", "Gut",           Color(red: 0.3, green: 0.8, blue: 0.4)),
        ("😁", "Super",         Color(red: 0.2, green: 0.7, blue: 1.0))
    ]

    var moodEmoji: String { JournalEntry.moods[max(0, min(4, moodScore - 1))].emoji }
    var moodColor: Color { JournalEntry.moods[max(0, min(4, moodScore - 1))].color }
    var moodLabel: String { JournalEntry.moods[max(0, min(4, moodScore - 1))].label }
}

@MainActor
final class JournalStore: ObservableObject {
    static let shared = JournalStore()

    @Published var entries: [JournalEntry] = []

    private let key = "journal_entries_v1"

    private init() { load() }

    func save(_ entry: JournalEntry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        } else {
            entries.insert(entry, at: 0)
        }
        persist()
    }

    func delete(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func todayEntry() -> JournalEntry? {
        let cal = Calendar.current
        return entries.first { cal.isDateInToday($0.date) }
    }

    func hasTodayEntry() -> Bool { todayEntry() != nil }

    func averageMood(last days: Int = 7) -> Double {
        let recent = recentEntries(days: days)
        guard !recent.isEmpty else { return 0 }
        return Double(recent.map(\.moodScore).reduce(0, +)) / Double(recent.count)
    }

    func recentEntries(days: Int) -> [JournalEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.date >= cutoff }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = decoded
    }
}
