import SwiftUI

struct TemplateTask: Codable {
    var title: String
    var description: String = ""
}

struct TaskTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var colorName: String = "purple"
    var tasks: [TemplateTask]
    var isBuiltIn: Bool = false

    var color: Color {
        switch colorName {
        case "blue":   return Color(red: 0.3, green: 0.6, blue: 1.0)
        case "green":  return Color(red: 0.2, green: 0.82, blue: 0.5)
        case "orange": return Color(red: 1.0, green: 0.6, blue: 0.2)
        case "red":    return Color(red: 1.0, green: 0.35, blue: 0.35)
        case "yellow": return Color(red: 1.0, green: 0.85, blue: 0.2)
        case "cyan":   return Color(red: 0.2, green: 0.85, blue: 0.95)
        case "teal":   return Color(red: 0.1, green: 0.7, blue: 0.65)
        default:       return Color(red: 0.6, green: 0.3, blue: 1.0)
        }
    }

    static let builtIn: [TaskTemplate] = [
        TaskTemplate(
            name: "Morgenroutine", icon: "sun.rise.fill", colorName: "orange",
            tasks: [
                TemplateTask(title: "Sport / Bewegung"),
                TemplateTask(title: "Duschen & fertigmachen"),
                TemplateTask(title: "Frühstück"),
                TemplateTask(title: "Tagesplan aufschreiben"),
                TemplateTask(title: "Heutiges Highlight setzen"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Produktiver Arbeitstag", icon: "briefcase.fill", colorName: "blue",
            tasks: [
                TemplateTask(title: "E-Mails checken & beantworten"),
                TemplateTask(title: "Wichtigste Aufgabe angehen"),
                TemplateTask(title: "Meetings vorbereiten"),
                TemplateTask(title: "Fortschritt dokumentieren"),
                TemplateTask(title: "Posteingang leeren"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Lerneinheit", icon: "book.fill", colorName: "purple",
            tasks: [
                TemplateTask(title: "Lernziele für heute setzen"),
                TemplateTask(title: "Kapitel / Material durcharbeiten"),
                TemplateTask(title: "Notizen zusammenfassen"),
                TemplateTask(title: "Übungsaufgaben lösen"),
                TemplateTask(title: "Wiederholung & offene Fragen"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Wochenplanung", icon: "calendar", colorName: "teal",
            tasks: [
                TemplateTask(title: "Rückblick letzte Woche"),
                TemplateTask(title: "3 Wochenziele setzen"),
                TemplateTask(title: "Kalender & Termine prüfen"),
                TemplateTask(title: "Aufgaben priorisieren"),
                TemplateTask(title: "Einkaufs- / To-Do-Liste"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Deep Work Session", icon: "brain.head.profile", colorName: "red",
            tasks: [
                TemplateTask(title: "Handy auf lautlos / wegräumen"),
                TemplateTask(title: "Fokusziel für Session notieren"),
                TemplateTask(title: "Pomodoro-Timer starten"),
                TemplateTask(title: "Ablenkungen protokollieren"),
                TemplateTask(title: "Ergebnis & Notizen festhalten"),
            ], isBuiltIn: true
        ),
    ]
}

@MainActor
final class TaskTemplateStore: ObservableObject {
    static let shared = TaskTemplateStore()

    @Published var customTemplates: [TaskTemplate] = []

    var allTemplates: [TaskTemplate] { TaskTemplate.builtIn + customTemplates }

    private let key = "custom_task_templates_v1"

    private init() { load() }

    func save(_ template: TaskTemplate) {
        if let idx = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[idx] = template
        } else {
            customTemplates.append(template)
        }
        persist()
    }

    func delete(_ template: TaskTemplate) {
        customTemplates.removeAll { $0.id == template.id }
        persist()
    }

    func apply(_ template: TaskTemplate, to store: TodoStore) {
        let today = Date()
        for t in template.tasks {
            let item = TodoItem(title: t.title, description: t.description, dueDate: today)
            store.addTodo(item)
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TaskTemplate].self, from: data) else { return }
        customTemplates = decoded
    }
}
