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
            name: "Morning Routine", icon: "sun.rise.fill", colorName: "orange",
            tasks: [
                TemplateTask(title: "Exercise / Movement"),
                TemplateTask(title: "Shower & get ready"),
                TemplateTask(title: "Breakfast"),
                TemplateTask(title: "Write down daily plan"),
                TemplateTask(title: "Set today's highlight"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Productive Workday", icon: "briefcase.fill", colorName: "blue",
            tasks: [
                TemplateTask(title: "Check & reply to emails"),
                TemplateTask(title: "Tackle most important task"),
                TemplateTask(title: "Prepare meetings"),
                TemplateTask(title: "Document progress"),
                TemplateTask(title: "Empty inbox"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Study Session", icon: "book.fill", colorName: "purple",
            tasks: [
                TemplateTask(title: "Set learning goals for today"),
                TemplateTask(title: "Work through chapter / material"),
                TemplateTask(title: "Summarize notes"),
                TemplateTask(title: "Solve practice problems"),
                TemplateTask(title: "Review & open questions"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Weekly Planning", icon: "calendar", colorName: "teal",
            tasks: [
                TemplateTask(title: "Review last week"),
                TemplateTask(title: "Set 3 weekly goals"),
                TemplateTask(title: "Check calendar & appointments"),
                TemplateTask(title: "Prioritize tasks"),
                TemplateTask(title: "Shopping / To-Do list"),
            ], isBuiltIn: true
        ),
        TaskTemplate(
            name: "Deep Work Session", icon: "brain.head.profile", colorName: "red",
            tasks: [
                TemplateTask(title: "Put phone on silent / put away"),
                TemplateTask(title: "Note focus goal for session"),
                TemplateTask(title: "Start Pomodoro timer"),
                TemplateTask(title: "Log distractions"),
                TemplateTask(title: "Record result & notes"),
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
