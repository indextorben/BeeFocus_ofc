//  TodoImport.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 17.10.25.
//

import Foundation
import SwiftUI

struct TodoImport {
    @discardableResult
    static func importFrom(url: URL, todoStore: TodoStore, completion: ((Result<Int, Error>) -> Void)? = nil) -> Void {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let importedTodos = try decoder.decode([TodoItem].self, from: data)

            DispatchQueue.main.async {
                let skipOverdue = UserDefaults.standard.bool(forKey: "skipOverdueOnImport")
                let now = Date()
                var count = 0
                for todo in importedTodos {
                    if skipOverdue, let due = todo.dueDate, due < now { continue }
                    let newTodo = TodoItem(
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
                    todoStore.todos.append(newTodo)
                    count += 1
                }
                todoStore.saveTodos()
                WidgetDataManager.shared.saveTodos(todoStore.todos)
                completion?(.success(count))
            }
        } catch {
            print("Fehler beim Import: \(error.localizedDescription)")
            DispatchQueue.main.async {
                completion?(.failure(error))
            }
        }
    }
}
