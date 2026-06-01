import SwiftUI

struct SchlafEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var datum: Date = Date()       // Morgen des Aufwachens
    var schlafenszeit: Date        // Einschlafzeit (Abend)
    var aufwachzeit: Date          // Aufwachzeit (Morgen)
    var qualitaet: Int             // 1–5 Sterne

    var dauerMinuten: Int {
        max(0, Int(aufwachzeit.timeIntervalSince(schlafenszeit) / 60))
    }

    var dauerStunden: Double { Double(dauerMinuten) / 60.0 }
}

@MainActor
final class SchlafStore: ObservableObject {
    static let shared = SchlafStore()

    @Published var eintraege: [SchlafEintrag] = []
    @Published var zielStunden: Double = 8.0 {
        didSet { UserDefaults.standard.set(zielStunden, forKey: "schlafZielStunden") }
    }

    private let key = "schlaf_eintraege_v1"

    private init() {
        zielStunden = UserDefaults.standard.object(forKey: "schlafZielStunden") as? Double ?? 8.0
        load()
    }

    var heutigerEintrag: SchlafEintrag? {
        eintraege.first { Calendar.current.isDateInToday($0.datum) }
    }

    func add(_ eintrag: SchlafEintrag) {
        if let idx = eintraege.firstIndex(where: { Calendar.current.isDate($0.datum, inSameDayAs: eintrag.datum) }) {
            eintraege[idx] = eintrag
        } else {
            eintraege.append(eintrag)
        }
        persist()
    }

    func delete(_ eintrag: SchlafEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        persist()
    }

    func last7Days() -> [(date: Date, stunden: Double?)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset -> (Date, Double?) in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let e = eintraege.first { cal.isDate($0.datum, inSameDayAs: day) }
            return (cal.startOfDay(for: day), e.map { $0.dauerStunden })
        }
    }

    var schnittStunden7Tage: Double {
        let vals = last7Days().compactMap(\.stunden)
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SchlafEintrag].self, from: data) else { return }
        eintraege = decoded
    }
}
