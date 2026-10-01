import Foundation
import SwiftUI

struct TodoImporter {
    static func importTodos(from url: URL, to store: TodoStore) {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }

        do {
            // Größe prüfen, bevor die Datei im Speicher landet.
            let data = try TodoImportLimits.readData(at: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let decoded = try decoder.decode([TodoItem].self, from: data)
            let importedTodos = decoded.prefix(TodoImportLimits.maxTodos)
            print("✅ \(LocalizationManager.shared.localizedString(forKey: "import_success_count")) \(importedTodos.count)")

            DispatchQueue.main.async {
                // Fremde Felder werden hier bereinigt – insbesondere wird keine
                // Kalender-Event-ID aus der Datei übernommen.
                let todosWithID = importedTodos.map(TodoImportLimits.sanitized)
                store.todos.append(contentsOf: todosWithID)
                store.saveTodos()
            }
        } catch {
            print("❌ \(LocalizationManager.shared.localizedString(forKey: "import_error")): \(error)")
        }
    }
}
