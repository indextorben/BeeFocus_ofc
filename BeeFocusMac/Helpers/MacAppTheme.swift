import SwiftUI

// Identische Logik wie iOS AppTheme — liest denselben AppStorage-Key
func appThemaFarben(_ name: String) -> (Color, Color, Color) {
    switch name {
    case "Ozean":          return (.cyan,   .teal,  Color(red: 0.0, green: 0.6, blue: 0.9))
    case "Wald":           return (.green,  Color(red: 0.1, green: 0.5, blue: 0.2), .mint)
    case "Nacht":          return (.indigo, Color(red: 0.1, green: 0.0, blue: 0.3), .purple)
    case "Solar":          return (.orange, .yellow, Color(red: 1.0, green: 0.4, blue: 0.0))
    case "Kirschblüte":    return (.pink,   Color(red: 1.0, green: 0.4, blue: 0.6), .red)
    case "Vulkan":         return (.red,    Color(red: 0.8, green: 0.1, blue: 0.0), .orange)
    case "Eis":            return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan, .white)
    case "Herbst":         return (Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.3, blue: 0.05), .orange)
    case "Lavendel":       return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.85, green: 0.7, blue: 1.0))
    case "Sonnenuntergang":return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink, Color(red: 1.0, green: 0.65, blue: 0.0))
    case "Galaxie":        return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95), Color(red: 0.80, green: 0.58, blue: 1.0))
    case "Nordlicht":      return (.green,  Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 1.0))
    case "Aurora":         return (Color(red: 0.0, green: 0.9, blue: 0.8), Color(red: 0.5, green: 0.0, blue: 1.0), Color(red: 0.9, green: 0.0, blue: 1.0))
    case "Obsidian":       return (Color(red: 0.85, green: 0.65, blue: 0.1), Color(red: 0.6, green: 0.42, blue: 0.04), Color(red: 1.0, green: 0.85, blue: 0.3))
    case "Nebula":         return (Color(red: 1.0, green: 0.15, blue: 0.6), Color(red: 0.45, green: 0.0, blue: 0.85), Color(red: 0.1, green: 0.55, blue: 1.0))
    default:               return (.orange, Color(red: 1.0, green: 0.5, blue: 0.0), .yellow)
    }
}

// Convenience: nur die erste (primäre) Farbe
extension String {
    var themeAccent: Color { appThemaFarben(self).0 }
    var themeGradient: LinearGradient {
        let (c1, c2, _) = appThemaFarben(self)
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - WaveShape (identisch mit iOS AppTheme)

struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.5))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let y = rect.height * 0.5
                + amplitude * sin(frequency * x / rect.width * .pi * 2 + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Environment Key — wird in BeeFocusMacApp gesetzt, in allen Views verfügbar
struct ThemeKey: EnvironmentKey {
    static let defaultValue: String = ""
}
extension EnvironmentValues {
    var activeTheme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
