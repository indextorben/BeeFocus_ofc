import Foundation
import SwiftUI

struct TodoImporter {
    static func importTodos(from url: URL, to store: TodoStore) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importedTodos = try decoder.decode([TodoItem].self, from: data)
            print("✅ \(LocalizationManager.shared.localizedString(forKey: "import_success_count")) \(importedTodos.count)")

            DispatchQueue.main.async {
                let todosWithID = importedTodos.map { todo in
                    TodoItem(
                        title: todo.title,
                        description: todo.description,
                        isCompleted: false,
                        dueDate: todo.dueDate,
                        category: todo.category,
                        priority: todo.priority,
                        subTasks: todo.subTasks,
                        createdAt: todo.createdAt,
                        completedAt: todo.completedAt,
                        lastResetDate: todo.lastResetDate,
                        calendarEventIdentifier: todo.calendarEventIdentifier,
                        focusTimeInMinutes: todo.focusTimeInMinutes,
                        imageDataArray: todo.imageDataArray,
                        calendarEnabled: todo.calendarEnabled,
                        isFavorite: todo.isFavorite
                    )
                }

                print("📦 \(LocalizationManager.shared.localizedString(forKey: "import_new_todos")): \(todosWithID.map(\.title))")
                store.todos.append(contentsOf: todosWithID)
                store.saveTodos()
            }
        } catch {
            print("❌ \(LocalizationManager.shared.localizedString(forKey: "import_error")): \(error)")
        }
    }
}
