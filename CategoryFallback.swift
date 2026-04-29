//
//  Category.swift
//  BeeFocus_ofc
//
//  Fallback-Datei für Widget-Kompatibilität
//

import Foundation
import SwiftUI

// Falls Category noch nicht existiert, hier ist eine kompatible Version
struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: String // Hex-String oder Color-Name
    
    init(id: UUID = UUID(), name: String, color: String = "blue") {
        self.id = id
        self.name = name
        self.color = color
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}
