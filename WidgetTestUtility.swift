//
//  WidgetTestUtility.swift
//  BeeFocus_ofc
//
//  Hilfs-Tools zum Testen der Widgets
//  Created on 15.04.26.
//

import Foundation
import WidgetKit

#if DEBUG

/// Utility-Klasse für Widget-Tests während der Entwicklung
class WidgetTestUtility {
    
    static let shared = WidgetTestUtility()
    
    private init() {}
    
    // MARK: - Test-Daten Generator
    
    /// Erstellt Test-Todos für verschiedene Szenarien
    enum TestScenario {
        case empty              // Keine Aufgaben
        case fewTasks          // Wenige Aufgaben (3-5)
        case normalDay         // Normaler Tag (5-10)
        case busyDay           // Viel zu tun (15-20)
        case manyOverdue       // Viele überfällige Aufgaben
        case allDone           // Alles erledigt
        case custom(today: Int, overdue: Int, future: Int)
    }
    
    /// Generiert Test-Todos für ein Szenario
    func generateTestTodos(scenario: TestScenario) -> [TodoItem] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        switch scenario {
        case .empty:
            return []
            
        case .fewTasks:
            return [
                TodoItem(title: "Einkaufen", dueDate: today.addingTimeInterval(3600)),
                TodoItem(title: "Meeting", dueDate: today.addingTimeInterval(7200)),
                TodoItem(title: "Email schreiben", dueDate: calendar.date(byAdding: .day, value: 1, to: today))
            ]
            
        case .normalDay:
            return [
                TodoItem(title: "Morgensport", dueDate: today.addingTimeInterval(28800)), // 8:00
                TodoItem(title: "Projekt abschließen", dueDate: today.addingTimeInterval(32400)), // 9:00
                TodoItem(title: "Mittagessen vorbereiten", dueDate: today.addingTimeInterval(43200)), // 12:00
                TodoItem(title: "Telefonat mit Team", dueDate: today.addingTimeInterval(50400)), // 14:00
                TodoItem(title: "Code Review", dueDate: today.addingTimeInterval(54000)), // 15:00
                TodoItem(title: "Dokumentation", dueDate: calendar.date(byAdding: .day, value: 1, to: today)),
                TodoItem(title: "Überfällig gestern", dueDate: calendar.date(byAdding: .day, value: -1, to: today))
            ]
            
        case .busyDay:
            var todos: [TodoItem] = []
            // Heute
            for i in 1...12 {
                todos.append(TodoItem(
                    title: "Aufgabe heute \(i)",
                    dueDate: today.addingTimeInterval(Double(i * 3600))
                ))
            }
            // Überfällig
            for i in 1...5 {
                todos.append(TodoItem(
                    title: "Überfällig \(i)",
                    dueDate: calendar.date(byAdding: .day, value: -i, to: today)
                ))
            }
            // Zukunft
            for i in 1...3 {
                todos.append(TodoItem(
                    title: "Später \(i)",
                    dueDate: calendar.date(byAdding: .day, value: i, to: today)
                ))
            }
            return todos
            
        case .manyOverdue:
            var todos: [TodoItem] = []
            todos.append(TodoItem(title: "Heute 1", dueDate: today.addingTimeInterval(3600)))
            todos.append(TodoItem(title: "Heute 2", dueDate: today.addingTimeInterval(7200)))
            
            for i in 1...10 {
                todos.append(TodoItem(
                    title: "Überfällig seit \(i) Tag(en)",
                    dueDate: calendar.date(byAdding: .day, value: -i, to: today)
                ))
            }
            return todos
            
        case .allDone:
            var todos = [
                TodoItem(title: "Erledigt 1", isCompleted: true, dueDate: today),
                TodoItem(title: "Erledigt 2", isCompleted: true, dueDate: today),
                TodoItem(title: "Erledigt 3", isCompleted: true, dueDate: today)
            ]
            todos[0].completedAt = today
            todos[1].completedAt = today
            todos[2].completedAt = today
            return todos
            
        case .custom(let today, let overdue, let future):
            var todos: [TodoItem] = []
            
            // Heute
            for i in 1...today {
                todos.append(TodoItem(
                    title: "Heute \(i)",
                    dueDate: calendar.startOfDay(for: now).addingTimeInterval(Double(i * 1800))
                ))
            }
            
            // Überfällig
            for i in 1...overdue {
                todos.append(TodoItem(
                    title: "Überfällig \(i)",
                    dueDate: calendar.date(byAdding: .day, value: -i, to: calendar.startOfDay(for: now))
                ))
            }
            
            // Zukunft
            for i in 1...future {
                todos.append(TodoItem(
                    title: "Zukunft \(i)",
                    dueDate: calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: now))
                ))
            }
            
            return todos
        }
    }
    
    // MARK: - Widget Daten setzen
    
    /// Setzt Test-Daten und aktualisiert das Widget
    func loadTestScenario(_ scenario: TestScenario) {
        let todos = generateTestTodos(scenario: scenario)
        WidgetDataManager.shared.saveTodos(todos)
        print("✅ Test-Szenario geladen: \(scenario)")
        print("   - Todos gesamt: \(todos.count)")
        print("   - Heute: \(todos.filter { isDueToday($0) }.count)")
        print("   - Überfällig: \(todos.filter { $0.isOverdue }.count)")
    }
    
    private func isDueToday(_ todo: TodoItem) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(dueDate)
    }
    
    // MARK: - Widget Force Reload
    
    /// Erzwingt eine Widget-Aktualisierung
    func forceReloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Widget neu geladen")
    }
    
    /// Gibt Debug-Informationen über gespeicherte Widget-Daten aus
    func printWidgetData() {
        let todos = WidgetDataManager.shared.loadTodos()
        print("\n📊 Widget Daten:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Gesamt Todos: \(todos.count)")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let dueTodayCount = todos.filter { todo in
            guard !todo.isCompleted, let dueDate = todo.dueDate else { return false }
            return dueDate >= today && dueDate < tomorrow
        }.count
        
        let overdueCount = todos.filter { todo in
            guard !todo.isCompleted, let dueDate = todo.dueDate else { return false }
            return dueDate < today
        }.count
        
        let totalOpenCount = todos.filter { !$0.isCompleted }.count
        
        print("Heute fällig: \(dueTodayCount)")
        print("Überfällig: \(overdueCount)")
        print("Offen gesamt: \(totalOpenCount)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    // MARK: - Schnelltest-Funktionen
    
    /// Testet alle Szenarien nacheinander (für Screenshots)
    func runAllScenarios(delay: TimeInterval = 2.0) {
        let scenarios: [(String, TestScenario)] = [
            ("Leer", .empty),
            ("Wenige Aufgaben", .fewTasks),
            ("Normaler Tag", .normalDay),
            ("Viel zu tun", .busyDay),
            ("Viele überfällig", .manyOverdue),
            ("Alles erledigt", .allDone)
        ]
        
        print("\n🎬 Starte Test-Sequenz...\n")
        
        for (index, (name, scenario)) in scenarios.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * delay) {
                print("[\(index + 1)/\(scenarios.count)] \(name)")
                self.loadTestScenario(scenario)
            }
        }
    }
}

// MARK: - Einfache Zugriffsfunktionen

/// Schnelle Test-Funktionen für die Konsole oder Button-Actions
extension WidgetTestUtility {
    
    /// Lädt "Wenige Aufgaben" Szenario
    static func testFewTasks() {
        shared.loadTestScenario(.fewTasks)
    }
    
    /// Lädt "Normaler Tag" Szenario
    static func testNormalDay() {
        shared.loadTestScenario(.normalDay)
    }
    
    /// Lädt "Viel zu tun" Szenario
    static func testBusyDay() {
        shared.loadTestScenario(.busyDay)
    }
    
    /// Lädt "Viele überfällig" Szenario
    static func testManyOverdue() {
        shared.loadTestScenario(.manyOverdue)
    }
    
    /// Lädt "Alles erledigt" Szenario
    static func testAllDone() {
        shared.loadTestScenario(.allDone)
    }
    
    /// Leert alle Todos
    static func testEmpty() {
        shared.loadTestScenario(.empty)
    }
    
    /// Custom Szenario
    static func testCustom(today: Int, overdue: Int, future: Int) {
        shared.loadTestScenario(.custom(today: today, overdue: overdue, future: future))
    }
}

// MARK: - SwiftUI Debug View (Optional)

#if canImport(SwiftUI)
import SwiftUI

struct WidgetTestView: View {
    var body: some View {
        List {
            Section("Test-Szenarien") {
                Button("📭 Leer") {
                    WidgetTestUtility.testEmpty()
                }
                
                Button("📝 Wenige Aufgaben (3-5)") {
                    WidgetTestUtility.testFewTasks()
                }
                
                Button("📋 Normaler Tag (5-10)") {
                    WidgetTestUtility.testNormalDay()
                }
                
                Button("🔥 Viel zu tun (15-20)") {
                    WidgetTestUtility.testBusyDay()
                }
                
                Button("⚠️ Viele überfällig") {
                    WidgetTestUtility.testManyOverdue()
                }
                
                Button("✅ Alles erledigt") {
                    WidgetTestUtility.testAllDone()
                }
            }
            
            Section("Custom") {
                NavigationLink("Custom Szenario") {
                    CustomScenarioView()
                }
            }
            
            Section("Widget") {
                Button("🔄 Widget neu laden") {
                    WidgetTestUtility.shared.forceReloadWidget()
                }
                
                Button("📊 Daten anzeigen") {
                    WidgetTestUtility.shared.printWidgetData()
                }
            }
            
            Section("Alle Szenarien") {
                Button("🎬 Alle durchlaufen (für Screenshots)") {
                    WidgetTestUtility.shared.runAllScenarios()
                }
            }
        }
        .navigationTitle("Widget Tests")
    }
}

struct CustomScenarioView: View {
    @State private var todayCount = 5
    @State private var overdueCount = 2
    @State private var futureCount = 3
    
    var body: some View {
        Form {
            Section("Anzahl Aufgaben") {
                Stepper("Heute: \(todayCount)", value: $todayCount, in: 0...50)
                Stepper("Überfällig: \(overdueCount)", value: $overdueCount, in: 0...50)
                Stepper("Zukunft: \(futureCount)", value: $futureCount, in: 0...50)
            }
            
            Section {
                Button("Test starten") {
                    WidgetTestUtility.testCustom(
                        today: todayCount,
                        overdue: overdueCount,
                        future: futureCount
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("Custom Szenario")
    }
}

#Preview("Widget Test View") {
    NavigationStack {
        WidgetTestView()
    }
}

#endif

#endif // DEBUG

// MARK: - Verwendung

/*
 
 VERWENDUNG IN DER HAUPT-APP:
 ════════════════════════════
 
 1. In der Xcode-Konsole (Debug):
 
    WidgetTestUtility.testNormalDay()
    WidgetTestUtility.testBusyDay()
    WidgetTestUtility.testManyOverdue()
 
 
 2. In einer SwiftUI View (z.B. Settings):
 
    #if DEBUG
    NavigationLink("Widget Tests") {
        WidgetTestView()
    }
    #endif
 
 
 3. Als Button in Ihrer Todo-Liste:
 
    #if DEBUG
    Button("Test Widget") {
        WidgetTestUtility.testNormalDay()
    }
    #endif
 
 
 4. Automatisch beim App-Start (für schnelle Tests):
 
    #if DEBUG
    WidgetTestUtility.testNormalDay()
    #endif
 
 
 5. In der Konsole während der Laufzeit:
 
    // Drücken Sie den Pause-Button in Xcode
    // Geben Sie in der Konsole ein:
    po WidgetTestUtility.testBusyDay()
    po WidgetTestUtility.shared.printWidgetData()
 
 */
