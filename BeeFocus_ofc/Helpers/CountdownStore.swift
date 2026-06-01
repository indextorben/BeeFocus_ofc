import SwiftUI

struct CountdownEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var datum: Date
    var symbol: String = "calendar.badge.clock"
    var farbName: String = "blau"
    var notiz: String = ""

    var tageVerbleibend: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let target = cal.startOfDay(for: datum)
        return cal.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var istVorbei: Bool { tageVerbleibend < 0 }
    var istHeute: Bool  { tageVerbleibend == 0 }

    var farbe: Color {
        switch farbName {
        case "blau":   return Color(red: 0.2, green: 0.6, blue: 1.0)
        case "gruen":  return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.55, blue: 0.1)
        case "pink":   return Color(red: 1.0, green: 0.4, blue: 0.7)
        case "lila":   return Color(red: 0.6, green: 0.3, blue: 1.0)
        case "teal":   return Color(red: 0.2, green: 0.75, blue: 0.8)
        case "rot":    return Color(red: 1.0, green: 0.25, blue: 0.25)
        case "gelb":   return Color(red: 1.0, green: 0.8, blue: 0.1)
        default:       return Color(red: 0.2, green: 0.6, blue: 1.0)
        }
    }
}

@MainActor
final class CountdownStore: ObservableObject {
    static let shared = CountdownStore()

    @Published var events: [CountdownEvent] = []

    private let key = "countdown_events_v1"
    private init() { load() }

    func add(_ event: CountdownEvent) {
        events.append(event)
        events.sort { $0.tageVerbleibend < $1.tageVerbleibend }
        persist()
    }

    func delete(_ event: CountdownEvent) {
        events.removeAll { $0.id == event.id }
        persist()
    }

    func update(_ event: CountdownEvent) {
        if let i = events.firstIndex(where: { $0.id == event.id }) {
            events[i] = event
            events.sort { $0.tageVerbleibend < $1.tageVerbleibend }
            persist()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CountdownEvent].self, from: data)
        else { return }
        events = decoded.sorted { $0.tageVerbleibend < $1.tageVerbleibend }
    }
}
