//
//  File.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    @AppStorage("selectedLanguage") var selectedLanguage = "Deutsch"
    
    static let shared = LocalizationManager()
    
    var currentLanguageCode: String {
        switch selectedLanguage {
        case "Englisch": return "en"
        case "Französisch": return "fr"
        case "Spanisch": return "es"
        default: return "de"
        }
    }

    func localizedString(forKey key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return NSLocalizedString(key, comment: "")
        }

        return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
    }
}
