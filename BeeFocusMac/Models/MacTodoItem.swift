import Foundation
import CloudKit

// MARK: - MacTodoPriority

enum MacTodoPriority: String, CaseIterable, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var label: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var color: (Double, Double, Double) {
        switch self {
        case .low:    return (0.2, 0.8, 0.3)
        case .medium: return (1.0, 0.6, 0.1)
        case .high:   return (1.0, 0.25, 0.25)
        }
    }
}

// MARK: - MacSubTask

struct MacSubTask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - MacRecurrenceRule

enum MacRecurrenceRule: Codable, Equatable {
    case none
    case daily(interval: Int)
    case weekly(interval: Int, weekdays: [Int]?)
    case monthly(interval: Int)

    var isNone: Bool { if case .none = self { return true }; return false }

    var label: String {
        switch self {
        case .none:              return "Keine"
        case .daily(let i):     return i == 1 ? "Täglich" : "Alle \(i) Tage"
        case .weekly(let i, _): return i == 1 ? "Wöchentlich" : "Alle \(i) Wochen"
        case .monthly(let i):   return i == 1 ? "Monatlich" : "Alle \(i) Monate"
        }
    }

    private enum CodingKeys: String, CodingKey { case type, interval, weekdays }
    private enum RType: String, Codable { case none, daily, weekly, monthly }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(RType.self, forKey: .type) {
        case .none:    self = .none
        case .daily:   self = .daily(interval: try c.decode(Int.self, forKey: .interval))
        case .weekly:  self = .weekly(interval: try c.decode(Int.self, forKey: .interval),
                                      weekdays: try c.decodeIfPresent([Int].self, forKey: .weekdays))
        case .monthly: self = .monthly(interval: try c.decode(Int.self, forKey: .interval))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try c.encode(RType.none, forKey: .type)
        case .daily(let i):
            try c.encode(RType.daily, forKey: .type); try c.encode(i, forKey: .interval)
        case .weekly(let i, let wd):
            try c.encode(RType.weekly, forKey: .type); try c.encode(i, forKey: .interval)
            try c.encodeIfPresent(wd, forKey: .weekdays)
        case .monthly(let i):
            try c.encode(RType.monthly, forKey: .type); try c.encode(i, forKey: .interval)
        }
    }
}

// MARK: - MacTodoItem

struct MacTodoItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var dueDate: Date?
    var priority: MacTodoPriority
    var createdAt: Date
    var updatedAt: Date
    var isFavorite: Bool

    // Extended fields
    var customFolder: String?
    var subTasks: [MacSubTask]
    var endTime: Date?
    var reminderOffsetMinutes: Int?          // nil = no reminder, 0 = at due time, >0 = minutes before
    var recurrenceEnabled: Bool
    var recurrenceRule: MacRecurrenceRule

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: MacTodoPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false,
        customFolder: String? = nil,
        subTasks: [MacSubTask] = [],
        endTime: Date? = nil,
        reminderOffsetMinutes: Int? = nil,
        recurrenceEnabled: Bool = false,
        recurrenceRule: MacRecurrenceRule = .none
    ) {
        self.id                    = id
        self.title                 = title
        self.description           = description
        self.isCompleted           = isCompleted
        self.dueDate               = dueDate
        self.priority              = priority
        self.createdAt             = createdAt
        self.updatedAt             = updatedAt
        self.isFavorite            = isFavorite
        self.customFolder          = customFolder
        self.subTasks              = subTasks
        self.endTime               = endTime
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.recurrenceEnabled     = recurrenceEnabled
        self.recurrenceRule        = recurrenceRule
    }

    // MARK: - CloudKit Mapping

    init?(record: CKRecord) {
        guard
            let idString = record["id"] as? String,
            let id = UUID(uuidString: idString),
            let title = record["title"] as? String
        else { return nil }

        self.id          = id
        self.title       = title
        self.description = record["description"] as? String ?? ""
        self.isCompleted = record["isCompleted"] as? Bool ?? false
        self.dueDate     = record["dueDate"] as? Date
        self.createdAt   = record["createdAt"] as? Date ?? Date()
        self.updatedAt   = record["updatedAt"] as? Date ?? Date()
        self.isFavorite   = record["isFavorite"] as? Bool ?? false
        self.customFolder = record["customFolder"] as? String
        self.priority     = MacTodoPriority(rawValue: record["priority"] as? String ?? "medium") ?? .medium
        self.endTime               = record["endTime"] as? Date
        self.reminderOffsetMinutes = record["reminderOffsetMinutes"] as? Int
        self.recurrenceEnabled     = record["recurrenceEnabled"] as? Bool ?? false

        // Primary: iOS-compatible Data field; fallback: legacy Mac String field
        if let data = record["subTasks"] as? Data, data.count > 0,
           let decoded = try? JSONDecoder().decode([MacSubTask].self, from: data) {
            self.subTasks = decoded
        } else if let jsonStr = record["subTasksJSON"] as? String,
                  let data = jsonStr.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([MacSubTask].self, from: data) {
            self.subTasks = decoded
        } else {
            self.subTasks = []
        }

        if let jsonStr = record["recurrenceRuleJSON"] as? String,
           let data = jsonStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(MacRecurrenceRule.self, from: data) {
            self.recurrenceRule = decoded
        } else {
            self.recurrenceRule = .none
        }
    }

    func toRecord(existingRecord: CKRecord? = nil) -> CKRecord {
        let record = existingRecord ?? CKRecord(recordType: "Todo")
        record["id"]          = id.uuidString as CKRecordValue
        record["title"]       = title as CKRecordValue
        record["description"] = description as CKRecordValue
        record["isCompleted"] = isCompleted as CKRecordValue
        record["priority"]    = priority.rawValue as CKRecordValue
        record["createdAt"]   = createdAt as CKRecordValue
        record["updatedAt"]   = Date() as CKRecordValue
        record["isFavorite"]  = isFavorite as CKRecordValue
        record["recurrenceEnabled"] = recurrenceEnabled as CKRecordValue
        if let folder = customFolder { record["customFolder"] = folder as CKRecordValue }
        if let due = dueDate { record["dueDate"] = due as CKRecordValue }
        if let end = endTime { record["endTime"] = end as CKRecordValue }
        if let rem = reminderOffsetMinutes { record["reminderOffsetMinutes"] = rem as CKRecordValue }
        if let data = try? JSONEncoder().encode(subTasks) {
            record["subTasks"] = data as CKRecordValue
        }
        if let data = try? JSONEncoder().encode(recurrenceRule),
           let str = String(data: data, encoding: .utf8) {
            record["recurrenceRuleJSON"] = str as CKRecordValue
        }
        return record
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return Calendar.current.isDateInToday(due)
    }
}
