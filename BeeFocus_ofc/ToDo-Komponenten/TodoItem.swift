//
//  TodoItem.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var category: Category?
    var priority: TodoPriority = .medium
    var subTasks: [SubTask]
    let createdAt: Date
    var completedAt: Date?
    var lastResetDate: Date?
    var calendarEventIdentifier: String? // 🗓 Event ID für Synchronisation
    var focusTimeInMinutes: Double? = nil
    var imageDataArray: [Data] = []

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        category: Category? = nil,
        priority: TodoPriority = .medium,
        subTasks: [SubTask] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        lastResetDate: Date? = nil,
        calendarEventIdentifier: String? = nil,
        imageDataArray: [Data] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.category = category
        self.priority = priority
        self.subTasks = subTasks
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.lastResetDate = lastResetDate
        self.calendarEventIdentifier = calendarEventIdentifier
        self.imageDataArray = imageDataArray
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }

    var progress: Double {
        guard !subTasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        return Double(subTasks.filter { $0.isCompleted }.count) / Double(subTasks.count)
    }

    static func == (lhs: TodoItem, rhs: TodoItem) -> Bool {
        return lhs.id == rhs.id
    }
}
