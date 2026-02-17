import Foundation
import SwiftData

@Model
final class WeeklyGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String?
    var weekStart: Date
    var isCompleted: Bool
    var categoryName: String?

    init(id: UUID = UUID(), title: String, weekStart: Date, isCompleted: Bool = false, notes: String? = nil, categoryName: String? = nil) {
        self.id = id
        self.title = title
        self.weekStart = weekStart
        self.isCompleted = isCompleted
        self.notes = notes
        self.categoryName = categoryName
    }
}
