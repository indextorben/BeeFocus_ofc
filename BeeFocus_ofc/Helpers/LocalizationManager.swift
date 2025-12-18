import Foundation
import SwiftUI

final class LocalizationManager: ObservableObject {

    // MARK: - Singleton
    static let shared = LocalizationManager()

    // MARK: - Persisted Language
    @AppStorage("selectedLanguage")
    var selectedLanguage: String = "Deutsch" {
        didSet {
            objectWillChange.send() // 🔄 UI neu rendern
        }
    }

    private init() {}

    // MARK: - Language Code (.lproj)
    var currentLanguageCode: String {
        switch selectedLanguage {
        case "Englisch":
            return "en"
        case "Französisch":
            return "fr"
        case "Spanisch":
            return "es"
        default:
            return "de"
        }
    }

    // MARK: - Locale
    var currentLocale: Locale {
        Locale(identifier: currentLanguageCode)
    }

    // MARK: - String Localization
    func localizedString(forKey key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(
            key,
            tableName: nil,
            bundle: bundle,
            value: key, // fallback = key (besser als leer)
            comment: ""
        )
    }

    // MARK: - Day Abbreviation (Mo / Mon etc.)
    func localizedDayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }

    // MARK: - Full Day Name (optional, aber stark)
    func localizedDayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Date Formatting Helper
    func localizedDate(
        _ date: Date,
        dateStyle: DateFormatter.Style = .medium,
        timeStyle: DateFormatter.Style = .none
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
