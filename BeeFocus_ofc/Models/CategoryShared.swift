//
//  Category.swift
//  BeeFocus_ofc
//
//  Category-Model (geteilt zwischen App und Widget)
//  Created on 15.04.26.
//

import Foundation
import SwiftUI
import UIKit

struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String

    /// Genmoji als Kategorie-Symbol. Enthält die Bilddaten eines
    /// `NSAdaptiveImageGlyph` (HEIC). `nil`, wenn kein Symbol gesetzt ist.
    var iconData: Data? = nil

    /// Kurzbeschreibung des Genmoji, z. B. für VoiceOver.
    var iconDescription: String? = nil

    var color: Color {
        Color(hex: colorHex)
    }

    var hasIcon: Bool { iconData != nil }

    /// Das Genmoji als Bild zum Anzeigen.
    var iconImage: UIImage? {
        guard let iconData else { return nil }
        return UIImage(data: iconData)
    }

    // Gleichheit bewusst ohne die Symboldaten: Todos halten eine Kopie ihrer
    // Kategorie, und Vergleiche wie `todo.category == category` müssen weiterhin
    // greifen, auch wenn nur das Symbol geändert wurde.
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.colorHex == rhs.colorHex
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(colorHex)
    }
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgbValue)
        
        let r, g, b: Double
        if hexSanitized.count == 6 {
            r = Double((rgbValue & 0xFF0000) >> 16) / 255
            g = Double((rgbValue & 0x00FF00) >> 8) / 255
            b = Double(rgbValue & 0x0000FF) / 255
        } else {
            r = 0; g = 0; b = 0
        }
        
        self.init(red: r, green: g, blue: b)
    }
    
    var toHex: String {
        UIColor(self).toHex ?? "#000000"
    }
}
