import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("selectedLanguage") var selectedLanguage = "Deutsch" {
        didSet {
            objectWillChange.send() // UI neu rendern
        }
    }
    
    private init() {}
    
    /// Sprachcode für die `.lproj`-Ordner
    var currentLanguageCode: String {
        switch selectedLanguage {
        case "Englisch": return "en"
        case "Französisch": return "fr"
        case "Spanisch": return "es"
        default: return "de"
        }
    }

    /// Holt den übersetzten String aus der richtigen `.lproj`
    func localizedString(forKey key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        
        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}
