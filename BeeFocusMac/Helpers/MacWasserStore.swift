import SwiftUI

struct MacWasserEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var ml: Int
}

@MainActor
final class MacWasserStore: ObservableObject {
    static let shared = MacWasserStore()

    @Published var entries: [MacWasserEintrag] = []
    @Published var tagesziel: Int = 2000 {
        didSet { UserDefaults.standard.set(tagesziel, forKey: "wasserTagesziel") }
    }

    private let key = "wasser_eintraege_v1"

    private init() {
        tagesziel = UserDefaults.standard.object(forKey: "wasserTagesziel") as? Int ?? 2000
        load()
    }

    var todayEntries: [MacWasserEintrag] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    var todayTotal: Int { todayEntries.reduce(0) { $0 + $1.ml } }

    var todayProgress: Double { min(Double(todayTotal) / Double(tagesziel), 1.0) }

    func add(ml: Int) {
        entries.append(MacWasserEintrag(ml: ml))
        persist()
    }

    func delete(_ entry: MacWasserEintrag) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func last7DaysTotals() -> [(date: Date, ml: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> (Date, Int)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let total = entries.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.ml }
            return (cal.startOfDay(for: day), total)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MacWasserEintrag].self, from: data) else { return }
        entries = decoded
    }
}
