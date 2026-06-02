import Foundation
import CloudKit

// MARK: - MacTodoPriority

enum MacTodoPriority: String, CaseIterable, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var label: String {
        switch self {
        case .low:    return "Niedrig"
        case .medium: return "Mittel"
        case .high:   return "Hoch"
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

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        isCompleted: Bool = false,
        dueDate: Date? = nil,
        priority: MacTodoPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isFavorite: Bool = false
    ) {
        self.id          = id
        self.title       = title
        self.description = description
        self.isCompleted = isCompleted
        self.dueDate     = dueDate
        self.priority    = priority
        self.createdAt   = createdAt
        self.updatedAt   = updatedAt
        self.isFavorite  = isFavorite
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
        self.isFavorite  = record["isFavorite"] as? Bool ?? false

        let rawPriority  = record["priority"] as? String ?? "medium"
        self.priority    = MacTodoPriority(rawValue: rawPriority) ?? .medium
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
        if let due = dueDate { record["dueDate"] = due as CKRecordValue }
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
