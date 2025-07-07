//
//  TaskCategory.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

//Kategorien
enum TaskCategory: String, CaseIterable, Identifiable {
    case arbeit = "Arbeit"
    case privat = "Privat"
    case einkaufen = "Einkaufen"
    case gesundheit = "Gesundheit"
    case hobby = "Hobby"
    case schule = "Schule"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .arbeit: return .blue
        case .privat: return .green
        case .einkaufen: return .orange
        case .gesundheit: return .red
        case .hobby: return .purple
        case .schule: return .yellow
        }
    }
}
