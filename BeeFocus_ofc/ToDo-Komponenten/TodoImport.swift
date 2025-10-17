//  TodoImport.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 17.10.25.
//

import Foundation
import SwiftUI

struct TodoImport {
    static func importFrom(url: URL, todoStore: TodoStore) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let importedTodos = try decoder.decode([TodoItem].self, from: data)

            DispatchQueue.main.async {
                for todo in importedTodos {
                    // Neues Todo mit eigener UUID erzeugen, isCompleted = false
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
                    todoStore.addTodo(newTodo)
                }
            }
        } catch {
            print("Fehler beim Import: \(error.localizedDescription)")
        }
    }
}
