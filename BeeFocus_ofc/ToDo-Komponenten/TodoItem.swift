//
//  TodoItem.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 16.06.25.
//

import Foundation
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    enum RecurrenceRule: Codable, Equatable {
        case none
        case daily(interval: Int)
        case weekly(interval: Int, weekdays: [Int]?)
        case monthly(interval: Int)
        
        var isNone: Bool {
            switch self {
            case .none:
                return true
            default:
                return false
            }
        }
        
        // Codable implementation for associated values enum
        private enum CodingKeys: String, CodingKey {
            case type
            case interval
            case weekdays
        }
        
        private enum RecurrenceType: String, Codable {
            case none
            case daily
            case weekly
            case monthly
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(RecurrenceType.self, forKey: .type)
            switch type {
            case .none:
                self = .none
            case .daily:
                let interval = try container.decode(Int.self, forKey: .interval)
                self = .daily(interval: interval)
            case .weekly:
                let interval = try container.decode(Int.self, forKey: .interval)
                let weekdays = try container.decodeIfPresent([Int].self, forKey: .weekdays)
                self = .weekly(interval: interval, weekdays: weekdays)
            case .monthly:
                let interval = try container.decode(Int.self, forKey: .interval)
                self = .monthly(interval: interval)
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                try container.encode(RecurrenceType.none, forKey: .type)
            case .daily(let interval):
                try container.encode(RecurrenceType.daily, forKey: .type)
                try container.encode(interval, forKey: .interval)
            case .weekly(let interval, let weekdays):
                try container.encode(RecurrenceType.weekly, forKey: .type)
                try container.encode(interval, forKey: .interval)
                try container.encodeIfPresent(weekdays, forKey: .weekdays)
            case .monthly(let interval):
                try container.encode(RecurrenceType.monthly, forKey: .type)
                try container.encode(interval, forKey: .interval)
            }
        }
    }

    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var reminderOffsetMinutes: Int? = nil
    var reminderTitle: String? = nil
    var reminderBody: String? = nil
    
    var recurrenceEnabled: Bool = false
    var recurrenceRule: RecurrenceRule = .none
    var lastCompletionDate: Date? = nil
    var nextResetDate: Date? = nil
    
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
        reminderTitle: String? = nil,
        reminderBody: String? = nil,
        recurrenceEnabled: Bool = false,
        recurrenceRule: RecurrenceRule = .none,
        lastCompletionDate: Date? = nil,
        nextResetDate: Date? = nil,
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
        self.reminderTitle = reminderTitle
        self.reminderBody = reminderBody
        self.recurrenceEnabled = recurrenceEnabled
        self.recurrenceRule = recurrenceRule
        self.lastCompletionDate = lastCompletionDate
        self.nextResetDate = nextResetDate
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

extension TodoItem {
    func nextReset(after date: Date = Date()) -> Date? {
        guard recurrenceEnabled else { return nil }
        let cal = Calendar.current
        switch recurrenceRule {
        case .none:
            return nil
        case .daily(let interval):
            let base = (lastCompletionDate ?? dueDate ?? date)
            return cal.date(byAdding: .day, value: max(1, interval), to: cal.startOfDay(for: base))?.addingTimeInterval(60*60*8)
        case .weekly(let interval, let weekdays):
            let base = lastCompletionDate ?? dueDate ?? date
            var next: Date
            if let weekdays, !weekdays.isEmpty {
                // Find next matching weekday >= tomorrow
                var candidate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: base)) ?? base
                for _ in 0..<(7*max(1, interval)+7) {
                    let wd = cal.component(.weekday, from: candidate) // 1=Sun..7=Sat
                    if weekdays.contains(wd) { next = candidate; return next.addingTimeInterval(60*60*8) }
                    candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
                }
                next = cal.date(byAdding: .weekOfYear, value: max(1, interval), to: base) ?? base
            } else {
                next = cal.date(byAdding: .weekOfYear, value: max(1, interval), to: base) ?? base
            }
            return next
        case .monthly(let interval):
            let base = lastCompletionDate ?? dueDate ?? date
            let n = max(1, interval)
            return cal.date(byAdding: .month, value: n, to: base)
        }
    }
    var isRecurring: Bool { recurrenceEnabled && !recurrenceRule.isNone }
}

