//
//  priority.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import SwiftUI

enum TodoPriority: String, CaseIterable, Codable, Identifiable {
    case low = "Niedrig"
    case medium = "Mittel"
    case high = "Hoch"
    
    var id: Self { self }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var symbol: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "arrow.right"
        case .high: return "arrow.up"
        }
    }
    
    var rawValueShort: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
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
