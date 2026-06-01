import SwiftUI

struct DankbarkeitEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var datum: Date = Date()
    var eintraege: [String] = []   // bis zu 3 Dinge
}

@MainActor
final class DankbarkeitStore: ObservableObject {
    static let shared = DankbarkeitStore()

    @Published var eintraege: [DankbarkeitEintrag] = []

    private let key = "dankbarkeit_eintraege_v1"

    private init() { load() }

    var heutigerEintrag: DankbarkeitEintrag? {
        eintraege.first { Calendar.current.isDateInToday($0.datum) }
    }

    var streak: Int {
        let cal = Calendar.current
        var count = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let hat = eintraege.contains { cal.isDate($0.datum, inSameDayAs: day) && !$0.eintraege.isEmpty }
            if !hat { break }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    func save(texte: [String]) {
        let filtered = texte.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let idx = eintraege.firstIndex(where: { Calendar.current.isDateInToday($0.datum) }) {
            eintraege[idx].eintraege = filtered
        } else {
            eintraege.append(DankbarkeitEintrag(eintraege: filtered))
        }
        persist()
    }

    func last7Days() -> [(date: Date, hatEintrag: Bool)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let hat = eintraege.contains { cal.isDate($0.datum, inSameDayAs: day) && !$0.eintraege.isEmpty }
            return (cal.startOfDay(for: day), hat)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([DankbarkeitEintrag].self, from: data) else { return }
        eintraege = decoded
    }
}
