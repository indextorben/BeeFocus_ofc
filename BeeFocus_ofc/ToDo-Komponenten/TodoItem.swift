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
    var reminderOffsetMinutes: Int? = nil
    var category: Category?
    var categoryID: UUID?
    var priority: TodoPriority = .medium
    var subTasks: [SubTask]
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var lastResetDate: Date?
    var calendarEventIdentifier: String? // 🗓 Event ID für Synchronisation
    var focusTimeInMinutes: Double? = nil
    var imageDataArray: [Data] = []
    var calendarEnabled: Bool = false // ✅ Schalter für Kalendereintrag
    var isFavorite: Bool = false      // ✅ Lieblingsaufgabe

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        reminderOffsetMinutes: Int? = nil,
        category: Category? = nil,
        categoryID: UUID? = nil,
        priority: TodoPriority = .medium,
        subTasks: [SubTask] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        lastResetDate: Date? = nil,
        calendarEventIdentifier: String? = nil,
        focusTimeInMinutes: Double? = nil,
        imageDataArray: [Data] = [],
        calendarEnabled: Bool = false,
        isFavorite: Bool = false // ✅ hinzugefügt!
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate = dueDate
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.category = category
        self.categoryID = categoryID
        self.priority = priority
        self.subTasks = subTasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.lastResetDate = lastResetDate
        self.calendarEventIdentifier = calendarEventIdentifier
        self.focusTimeInMinutes = focusTimeInMinutes
        self.imageDataArray = imageDataArray
        self.calendarEnabled = calendarEnabled
        self.isFavorite = isFavorite
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
        lhs.id == rhs.id
    }
}

