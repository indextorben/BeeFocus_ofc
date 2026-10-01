//
//  TodoImportLimits.swift
//  BeeFocus_ofc
//
//  Schutzgrenzen für importierte Todo-Dateien.
//
//  Eine Import-Datei ist nicht vertrauenswürdig: BeeFocus ist in der Info.plist
//  als Handler für `public.json` registriert, jede andere App und jeder
//  Mail-Anhang kann also eine beliebige Datei hereingeben. Ohne Grenzen führt
//  das zu Speichererschöpfung und – weil der Import sofort persistiert und
//  nach CloudKit synct – zu einem dauerhaft unbrauchbaren Datenbestand.
//

import Foundation

enum TodoImportLimits {
    /// Maximale Dateigröße, die überhaupt eingelesen wird.
    static let maxFileBytes = 10 * 1024 * 1024
    /// Maximale Anzahl Aufgaben pro Import.
    static let maxTodos = 2_000
    /// Maximale Länge von Titel und Beschreibung.
    static let maxTitleLength = 500
    static let maxDescriptionLength = 5_000
    /// Maximale Anzahl Unteraufgaben pro Aufgabe.
    static let maxSubTasks = 200
    /// Bilder werden beim Import verworfen – sie blähen Datei und CloudKit-Quota
    /// unkontrolliert auf und sind für einen Textimport nicht nötig.
    static let keepImages = false

    enum ImportError: LocalizedError {
        case fileTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let bytes):
                return String(
                    format: LocalizationManager.shared.localizedString(forKey: "import_error_too_large"),
                    bytes / (1024 * 1024)
                )
            }
        }
    }

    /// Liest eine Import-Datei ein und lehnt übergroße Dateien ab,
    /// bevor sie vollständig im Speicher landen.
    static func readData(at url: URL) throws -> Data {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > maxFileBytes {
            throw ImportError.fileTooLarge(maxFileBytes)
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        if data.count > maxFileBytes {
            throw ImportError.fileTooLarge(maxFileBytes)
        }
        return data
    }

    /// Baut aus einem eingelesenen Todo einen sicheren Neueintrag.
    ///
    /// Bewusst **nicht** übernommen wird `calendarEventIdentifier`: sonst könnte
    /// eine präparierte Datei eine neue Aufgabe an ein beliebiges, bereits
    /// existierendes Kalender-Event des Nutzers binden. Beim späteren Löschen der
    /// Aufgabe entfernt `TodoStore.deleteCalendarEvent(for:)` dieses echte Event
    /// aus dem Kalender – fremde Daten würden also eine löschende Aktion steuern.
    static func sanitized(_ todo: TodoItem) -> TodoItem {
        TodoItem(
            title: clamp(todo.title, to: maxTitleLength),
            description: clamp(todo.description, to: maxDescriptionLength),
            isCompleted: false,
            dueDate: todo.dueDate,
            category: todo.category,
            priority: todo.priority,
            subTasks: Array(todo.subTasks.prefix(maxSubTasks)).map {
                SubTask(title: clamp($0.title, to: maxTitleLength), isCompleted: $0.isCompleted)
            },
            createdAt: todo.createdAt,
            completedAt: todo.completedAt,
            lastResetDate: todo.lastResetDate,
            calendarEventIdentifier: nil,
            focusTimeInMinutes: todo.focusTimeInMinutes.map { max(0, $0) },
            imageDataArray: keepImages ? todo.imageDataArray : [],
            calendarEnabled: false,
            isFavorite: todo.isFavorite
        )
    }

    private static func clamp(_ text: String, to limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count <= limit ? trimmed : String(trimmed.prefix(limit))
    }
}
