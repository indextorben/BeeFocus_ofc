//
//  WidgetDataManager.swift
//  BeeFocus_ofc
//
//  Created on 15.04.26.
//

import Foundation
import WidgetKit

/// Manager für das Teilen von Daten zwischen der Haupt-App und dem Widget
class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // WICHTIG: Ersetzen Sie dies mit Ihrer tatsächlichen App Group ID
    // Sie müssen eine App Group in Xcode erstellen unter:
    // Target > Signing & Capabilities > App Groups
    private let appGroupIdentifier = "group.com.yourcompany.beefocus"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    /// Speichert die Todos und aktualisiert alle Widgets
    func saveTodos(_ todos: [TodoItem]) {
        let encoder = JSONEncoder()
        
        // Speichere in App Group UserDefaults
        if let data = try? encoder.encode(todos) {
            sharedDefaults?.set(data, forKey: "todos")
            
            // Fallback: Auch in Standard UserDefaults speichern
            UserDefaults.standard.set(data, forKey: "todos")
        }
        
        // Widget aktualisieren
        reloadWidgets()
    }
    
    /// Lädt die Todos
    func loadTodos() -> [TodoItem] {
        let decoder = JSONDecoder()
        
        // Versuche aus App Group zu laden
        if let data = sharedDefaults?.data(forKey: "todos"),
           let todos = try? decoder.decode([TodoItem].self, from: data) {
            return todos
        }
        
        // Fallback: Aus Standard UserDefaults laden
        if let data = UserDefaults.standard.data(forKey: "todos"),
           let todos = try? decoder.decode([TodoItem].self, from: data) {
            return todos
        }
        
        return []
    }
    
    /// Aktualisiert alle Widgets
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
