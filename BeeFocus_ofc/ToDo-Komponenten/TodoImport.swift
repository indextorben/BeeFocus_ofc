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
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

            // Größe prüfen, bevor die Datei im Speicher landet.
            let data = try TodoImportLimits.readData(at: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let importedTodos = try decoder.decode([TodoItem].self, from: data)
                .prefix(TodoImportLimits.maxTodos)

            DispatchQueue.main.async {
                let skipOverdue = UserDefaults.standard.bool(forKey: "skipOverdueOnImport")
                let now = Date()
                var count = 0
                for todo in importedTodos {
                    if skipOverdue, let due = todo.dueDate, due < now { continue }
                    // Fremde Felder bereinigen – insbesondere wird keine
                    // Kalender-Event-ID aus der Datei übernommen.
                    let newTodo = TodoImportLimits.sanitized(todo)
                    todoStore.todos.append(newTodo)
                    count += 1
                }
                todoStore.saveTodos()
                todoStore.writeWidgetSnapshot()
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
