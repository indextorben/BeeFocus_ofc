//
//  TodoAppEntity.swift
//  BeeFocus_ofc
//
//  Macht Aufgaben für Siri, Kurzbefehle und Spotlight sichtbar.
//

import AppIntents
import Foundation

struct TodoAppEntity: AppEntity, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: String
    let categoryName: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Aufgabe", numericFormat: "\(placeholder: .int) Aufgaben")
    }

    var displayRepresentation: DisplayRepresentation {
        var subtitleParts: [String] = []
        if let dueDate {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            subtitleParts.append(f.string(from: dueDate))
        }
        if let categoryName { subtitleParts.append(categoryName) }
        if isCompleted { subtitleParts.append("erledigt") }

        return DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitleParts.isEmpty ? nil : LocalizedStringResource(stringLiteral: subtitleParts.joined(separator: " · ")),
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }

    static var defaultQuery = TodoEntityQuery()

    init(_ todo: TodoItem, categoryName: String? = nil) {
        self.id = todo.id
        self.title = todo.title
        self.isCompleted = todo.isCompleted
        self.dueDate = todo.dueDate
        self.priority = todo.priority.rawValue
        self.categoryName = categoryName ?? todo.category?.name
    }
}

struct TodoEntityQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TodoAppEntity] {
        TodoStore.shared.todos
            .filter { identifiers.contains($0.id) && !$0.isDeleted }
            .map { TodoAppEntity($0) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TodoAppEntity] {
        TodoStore.shared.todos
            .filter { !$0.isCompleted && !$0.isDeleted }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .prefix(10)
            .map { TodoAppEntity($0) }
    }
}

extension TodoEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [TodoAppEntity] {
        TodoStore.shared.todos
            .filter { !$0.isDeleted && $0.title.localizedCaseInsensitiveContains(string) }
            .map { TodoAppEntity($0) }
    }
}
