//
//  TodoStore+Widget.swift
//  BeeFocus_ofc
//
//  Widget-Integration für TodoStore
//  Created on 15.04.26.
//

import Foundation
import WidgetKit

// MARK: - Widget-Integration Extension für TodoStore
/*
 
 Fügen Sie diese Methoden zu Ihrem bestehenden TodoStore hinzu:
 
 */

extension TodoStore {
    
    /// Speichert Todos und aktualisiert das Widget
    func saveAndUpdateWidget() {
        // Ihre normale Save-Logik hier
        saveTodos()
        
        // Widget aktualisieren
        WidgetDataManager.shared.saveTodos(self.todos)
    }
    
    /// Aufgabe als erledigt/unerledigt markieren und Widget aktualisieren
    func toggleCompletion(for todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            
            if todos[index].isCompleted {
                todos[index].completedAt = Date()
            } else {
                todos[index].completedAt = nil
            }
            
            saveAndUpdateWidget()
        }
    }
}

// MARK: - Beispiel-Verwendung

/*
 
 // In Ihrer View oder ViewModel:
 
 // 1. Neue Aufgabe hinzufügen
 let newTodo = TodoItem(
     title: "Einkaufen gehen",
     description: "Milch und Brot kaufen",
     dueDate: Date()
 )
 todoStore.addTodo(newTodo)
 // Widget wird automatisch aktualisiert!
 
 // 2. Aufgabe als erledigt markieren
 todoStore.toggleCompletion(for: someTodo)
 // Widget wird automatisch aktualisiert!
 
 // 3. Aufgabe löschen
 todoStore.deleteTodo(someTodo)
 // Widget wird automatisch aktualisiert!
 
 // 4. Manuell Widget aktualisieren (falls nötig)
 WidgetDataManager.shared.reloadWidgets()
 
 */

// MARK: - Alternative: Automatische Aktualisierung mit Combine/ObservableObject

/*
 
 Falls Ihr TodoStore bereits ein ObservableObject ist, können Sie
 automatisch das Widget aktualisieren, wenn sich `todos` ändert:
 
 */

import Combine

class TodoStoreWithAutoWidgetUpdate: ObservableObject {
    @Published var todos: [TodoItem] = [] {
        didSet {
            // Automatisch Widget aktualisieren bei jeder Änderung
            WidgetDataManager.shared.saveTodos(todos)
        }
    }
    
    // Ihre anderen Methoden hier...
}

// MARK: - Deep Links (Optional)

/*
 
 Um aus dem Widget direkt zur App zu springen:
 
 1. Fügen Sie in TodoWidget.swift zu den Views hinzu:
 
    .widgetURL(URL(string: "beefocus://open")!)
 
 2. In Ihrer App (z.B. in der Haupt-View):
 
    .onOpenURL { url in
        if url.scheme == "beefocus" {
            switch url.host {
            case "open":
                // Öffne die Todo-Liste
                break
            case "add":
                // Öffne "Neue Aufgabe hinzufügen"
                break
            default:
                break
            }
        }
    }
 
 3. Verschiedene URLs für verschiedene Aktionen:
    - "beefocus://open" - Öffne die App
    - "beefocus://add" - Öffne "Neue Aufgabe"
    - "beefocus://today" - Zeige nur heute fällige Aufgaben
 
 */

// MARK: - Info.plist Konfiguration (Optional für Deep Links)

/*
 
 Für Deep Links müssen Sie in Ihrer Info.plist hinzufügen:
 
 <key>CFBundleURLTypes</key>
 <array>
     <dict>
         <key>CFBundleURLSchemes</key>
         <array>
             <string>beefocus</string>
         </array>
         <key>CFBundleURLName</key>
         <string>com.yourcompany.beefocus</string>
     </dict>
 </array>
 
 */
