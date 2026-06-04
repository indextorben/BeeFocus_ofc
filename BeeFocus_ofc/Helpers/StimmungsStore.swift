import SwiftUI

struct StimmungsEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var stufe: Int       // 1–5
    var notiz: String = ""
}

@MainActor
final class StimmungsStore: ObservableObject {
    static let shared = StimmungsStore()

    @Published var eintraege: [StimmungsEintrag] = []

    private let key = "stimmung_eintraege_v1"

    private init() { load() }

    var heutigerEintrag: StimmungsEintrag? {
        eintraege.first { Calendar.current.isDateInToday($0.date) }
    }

    func set(stufe: Int, notiz: String) {
        if let idx = eintraege.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            eintraege[idx].stufe = stufe
            eintraege[idx].notiz = notiz
        } else {
            eintraege.append(StimmungsEintrag(stufe: stufe, notiz: notiz))
        }
        persist()
    }

    func last7Days() -> [(date: Date, stufe: Int?)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset -> (Date, Int?) in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let eintrag = eintraege.first { cal.isDate($0.date, inSameDayAs: day) }
            return (cal.startOfDay(for: day), eintrag?.stufe)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([StimmungsEintrag].self, from: data) else { return }
        eintraege = decoded
    }
}

// MARK: - Helpers

func stimmungsEmoji(_ stufe: Int) -> String {
    switch stufe {
    case 1: return "😞"
    case 2: return "😕"
    case 3: return "😐"
    case 4: return "😊"
    case 5: return "😄"
    default: return "❓"
    }
}

func stimmungsLabel(_ stufe: Int) -> String {
    switch stufe {
    case 1: return "Bad"
    case 2: return "Okay"
    case 3: return "Neutral"
    case 4: return "Good"
    case 5: return "Great"
    default: return ""
    }
}

func stimmungsColor(_ stufe: Int) -> Color {
    switch stufe {
    case 1: return .red
    case 2: return .orange
    case 3: return .yellow
    case 4: return Color(red: 0.3, green: 0.85, blue: 0.5)
    case 5: return Color(red: 0.2, green: 0.75, blue: 1.0)
    default: return .secondary
    }
}
