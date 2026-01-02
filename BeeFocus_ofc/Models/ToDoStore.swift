//
//  TodoStore.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import Foundation
import SwiftUI
import UIKit
import EventKit

struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    
    var color: Color {
        Color(hex: colorHex)
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

extension UIColor {
    var toHex: String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard self.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var categories: [Category] = []
    @Published var dailyStats: [Date: Int] = [:] // Erledigte Aufgaben pro Tag
    
    private let saveKey = "todos"
    private let categoriesKey = "categories"
    private let statsKey = "dailyStats"
    
    private let eventStore = EKEventStore()
    
    var lastDeletedTodo: TodoItem?
    var lastDeletedIndex: Int?
    
    // Für Undo/Redo merken wir uns die letzte rückgängig gemachte Aufgabe
    private var lastUndoneTodoID: UUID?
    
    init() {
        loadTodos()
        loadCategories()
        loadStats()
    }
    
    func setCompleted(todo: TodoItem, completed: Bool) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted = completed
            todos[index].completedAt = completed ? Date() : nil
        }
    }
    
    func undoLastCompleted() {
        if let last = todos.last(where: { $0.isCompleted }) {
            if let index = todos.firstIndex(where: { $0.id == last.id }) {
                todos[index].isCompleted = false
                todos[index].completedAt = nil
                todos[index].updatedAt = Date()
                lastUndoneTodoID = last.id   // merken für Redo
                saveTodos()
                CloudKitManager.shared.saveTodo(todos[index])
            }
        }
    }
    
    func redoLastCompleted() {
        if let id = lastUndoneTodoID,
           let index = todos.firstIndex(where: { $0.id == id }) {
            todos[index].isCompleted = true
            todos[index].completedAt = Date()
            todos[index].updatedAt = Date()
            lastUndoneTodoID = nil // nur einmal Redo möglich
            saveTodos()
            CloudKitManager.shared.saveTodo(todos[index])
        }
    }
    
    // MARK: - Kategorie-Methoden
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let categories = try? JSONDecoder().decode([Category].self, from: data) {
            self.categories = categories
        }
    }
    
    private func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
    }
    
    func addCategory(_ category: Category) {
        guard !category.name.isEmpty,
              !categories.contains(where: { $0.name == category.name }) else { return }
        categories.append(category)
        saveCategories()
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
        
        todos.indices.forEach { index in
            if todos[index].category == category {
                todos[index].category = nil
            }
        }
        saveTodos()
    }
    
    func renameCategory(from oldCategory: Category, to newName: String) {
        guard !newName.isEmpty else { return }
        if let index = categories.firstIndex(where: { $0.id == oldCategory.id }) {
            categories[index].name = newName
            saveCategories()
            
            todos.indices.forEach { i in
                if todos[i].category == oldCategory {
                    todos[i].category = categories[index]
                }
            }
            saveTodos()
        }
    }
    
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        saveCategories()
    }
    
    // MARK: - Todo-Methoden
    
    func addTodo(_ todo: TodoItem) {
        var todo = todo
        todo.updatedAt = Date()
        todos.append(todo)
        saveTodos()

        // CloudKit speichern
        CloudKitManager.shared.saveTodo(todo)

        if todo.calendarEnabled { addCalendarEvent(for: todo) }
        if let dueDate = todo.dueDate {
            let timeInterval = dueDate.timeIntervalSinceNow
            if timeInterval > 0 {
                let title = "Fällige Aufgabe: \(todo.title)"
                let body = todo.description.isEmpty ? "Deine Aufgabe ist fällig." : todo.description
                NotificationManager.shared.scheduleTimerNotification(
                    id: todo.id.uuidString,
                    title: title,
                    body: body,
                    duration: timeInterval
                )
            }
        }
    }
    
    func updateTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
            todos[index].updatedAt = Date()
            saveTodos()

            // Kalender aktualisieren
            deleteCalendarEvent(for: todo)
            if todo.calendarEnabled { addCalendarEvent(for: todo) }

            // Notifications aktualisieren
            NotificationManager.shared.cancelNotification(id: todo.id.uuidString)
            if let dueDate = todo.dueDate {
                let timeInterval = dueDate.timeIntervalSinceNow
                if timeInterval > 0 {
                    let title = "Fällige Aufgabe: \(todo.title)"
                    let body = todo.description.isEmpty ? "Deine Aufgabe ist fällig." : todo.description
                    NotificationManager.shared.scheduleTimerNotification(
                        id: todo.id.uuidString,
                        title: title,
                        body: body,
                        duration: timeInterval
                    )
                }
            }

            // CloudKit upsert (einfach erneut speichern)
            CloudKitManager.shared.saveTodo(todos[index])
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }

        // CloudKit löschen
        CloudKitManager.shared.deleteTodo(todo)

        // Notification & Calendar
        deleteCalendarEvent(for: todo)
        NotificationManager.shared.cancelNotification(id: todo.id.uuidString)

        // Gelöschtes Todo merken
        lastDeletedTodo = todos[index]
        lastDeletedIndex = index

        // Löschen
        todos.remove(at: index)
        saveTodos()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    /// Entfernt alle lokalen Test-Todos, deren Titel "cloudkit" (case-insensitive) enthält.
    func removeLocalTestTodos() {
        let before = todos.count
        todos.removeAll { $0.title.lowercased().contains("cloudkit") }
        if todos.count != before {
            saveTodos()
            DispatchQueue.main.async { self.objectWillChange.send() }
            print("🧹 Lokal: Test-Todos entfernt: \(before - todos.count)")
        } else {
            print("ℹ️ Lokal: Keine Test-Todos gefunden.")
        }
    }
    
    func undoLastDeleted() {
        if let todo = lastDeletedTodo, let index = lastDeletedIndex {
            todos.insert(todo, at: index)
            if let insertedIndex = todos.firstIndex(where: { $0.id == todo.id }) {
                todos[insertedIndex].updatedAt = Date()
            }
            saveTodos()
            DispatchQueue.main.async { self.objectWillChange.send() }
            // 🔁 In CloudKit wiederherstellen (erneut speichern)
            CloudKitManager.shared.saveTodo(todo)
            // ❌ NICHT resetten, damit redoLastDeleted weiterhin möglich ist
        }
    }

    func redoLastDeleted() {
        if let todo = lastDeletedTodo {
            todos.removeAll { $0.id == todo.id }
            saveTodos()
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
    
    func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            var updatedTodo = todo
            updatedTodo.isCompleted.toggle()
            if updatedTodo.isCompleted {
                updatedTodo.completedAt = Date()
                updateStats(for: updatedTodo)
                
                // 🔹 Notification abbrechen
                NotificationManager.shared.cancelNotification(id: updatedTodo.id.uuidString)
            } else {
                updatedTodo.completedAt = nil
            }
            updatedTodo.updatedAt = Date()
            todos[index] = updatedTodo
            saveTodos()
        }
    }
    
    func complete(todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        // ✅ Todo direkt im Array mutieren, nicht als Kopie
        todos[index].isCompleted = true
        todos[index].completedAt = Date()
        todos[index].updatedAt = Date()
        
        // ✅ Statistik aktualisieren
        updateStats(for: todos[index])
        
        // ✅ Notification abbrechen
        NotificationManager.shared.cancelNotification(id: todos[index].id.uuidString)
        
        // ✅ Sofort speichern (ohne race conditions)
        DispatchQueue.main.async {
            self.saveTodos()
            self.objectWillChange.send() // zwingt SwiftUI zur Neurenderung
        }
    }
    
    func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadTodos() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = decoded
        }
    }
    
    // MARK: - Statistik-Methoden
    
    private func loadStats() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let stats = try? JSONDecoder().decode([Date: Int].self, from: data) {
            self.dailyStats = stats
        }
    }
    
    private func saveStats() {
        if let data = try? JSONEncoder().encode(dailyStats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    func resetDailyStats() {
        dailyStats.removeAll()
        saveStats()
    }
    
    func updateStats(for todo: TodoItem) {
        if todo.isCompleted {
            let today = Calendar.current.startOfDay(for: Date())
            dailyStats[today, default: 0] += 1
            saveStats()
        }
    }
    
    // MARK: - Kalender-Integration
    
    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func addCalendarEvent(for todo: TodoItem) {
        requestCalendarAccess { granted in
            guard granted else { return }
            
            let event = EKEvent(eventStore: self.eventStore)
            event.title = todo.title
            event.notes = todo.description
            event.startDate = todo.dueDate ?? Date()
            event.endDate = event.startDate.addingTimeInterval(60 * 60)
            event.calendar = self.eventStore.defaultCalendarForNewEvents
            
            do {
                try self.eventStore.save(event, span: .thisEvent)
                self.todos = self.todos.map {
                    var t = $0
                    if t.id == todo.id {
                        t.calendarEventIdentifier = event.eventIdentifier
                    }
                    return t
                }
                self.saveTodos()
            } catch {
                print("Fehler beim Speichern des Kalendereintrags: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteCalendarEvent(for todo: TodoItem) {
        guard let eventID = todo.calendarEventIdentifier else { return }
        
        requestCalendarAccess { granted in
            guard granted else { return }
            
            if let event = self.eventStore.event(withIdentifier: eventID) {
                do {
                    try self.eventStore.remove(event, span: .thisEvent)
                } catch {
                    print("Fehler beim Löschen des Kalendereintrags: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cloud Merge
    /// Mergt Todos aus der Cloud in den lokalen Store. Favorisiert Cloud-Daten.
    func mergeFromCloud(_ cloudTodos: [TodoItem]) {
        var localByID = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })
        var changed = false

        // Cloud → Lokal: Einfügen/Aktualisieren
        for cloud in cloudTodos {
            if let local = localByID[cloud.id] {
                if local != cloud {
                    // Bevorzuge neuere Version
                    let chosen = (cloud.updatedAt >= local.updatedAt) ? cloud : local
                    localByID[cloud.id] = chosen
                    changed = true
                }
            } else {
                localByID[cloud.id] = cloud
                changed = true
            }
        }

        // Optional: Lokal → Cloud pushen (für Einträge, die es nur lokal gibt)
        // Hier pushen wir sie hoch, damit Geräte konsistent werden.
        for (id, local) in localByID {
            if !cloudTodos.contains(where: { $0.id == id }) {
                CloudKitManager.shared.saveTodo(local)
            }
        }

        let newTodos = Array(localByID.values)
        if newTodos != todos {
            todos = newTodos
            saveTodos()
            DispatchQueue.main.async { self.objectWillChange.send() }
        } else if changed {
            // Falls Reihenfolge geändert wurde, trotzdem speichern
            todos = newTodos
            saveTodos()
        }
    }
}

