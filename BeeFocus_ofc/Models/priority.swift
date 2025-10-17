//
//  priority.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import SwiftUI

enum TodoPriority: String, Codable, Identifiable, CaseIterable {
    case low, medium, high
    var id: Self { self }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value.lowercased() {
        case "low", "niedrig": self = .low
        case "medium", "mittel": self = .medium
        case "high", "hoch": self = .high
        default: self = .medium
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    var displayName: String {
        switch self {
        case .low: return "Niedrig"
        case .medium: return "Mittel"
        case .high: return "Hoch"
        }
    }
}

class TasksByPriority {
    static func group(tasks: [TodoItem]) -> [TodoPriority: [TodoItem]] {
        Dictionary(grouping: tasks, by: { $0.priority })
    }
}

enum TaskPriority: String, CaseIterable, Codable, Identifiable {
    case low, normal, high
    var id: String { self.rawValue }
}
