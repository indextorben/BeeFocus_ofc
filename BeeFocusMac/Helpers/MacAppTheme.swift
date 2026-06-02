import SwiftUI

// MARK: - Environment Key für aktives Theme

struct ThemeKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var activeTheme: String {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension String {
    var themeAccent: Color { appThemaFarben(self).0 }
    var themeGradient: LinearGradient {
        let (c1, c2, _) = appThemaFarben(self)
        return LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
