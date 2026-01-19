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
    @Published var dailyFocusMinutes: [Date: Int] = [:] // Fokus-Minuten pro Tag
    @Published var deletedTodos: [TrashEntry] = []
    
    private let saveKey = "todos"
    private let categoriesKey = "categories"
    private let statsKey = "dailyStats"
    private let focusStatsKey = "dailyFocusMinutes"
    private let trashKey = "deletedTodos"
    private let trashMaxCountKey = "trashMaxCount"
    private let trashMaxDaysKey = "trashMaxDays"
    
    private var trashMaxCount: Int {
        let v = UserDefaults.standard.integer(forKey: trashMaxCountKey)
        return v > 0 ? v : 100
    }
    
    private var trashMaxDays: Int {
        let v = UserDefaults.standard.integer(forKey: trashMaxDaysKey)
        return v > 0 ? v : 30
    }
    
    private let eventStore = EKEventStore()
    
    var lastDeletedTodo: TodoItem?
    var lastDeletedIndex: Int?
    
    // Für Undo/Redo merken wir uns die letzte rückgängig gemachte Aufgabe
    private var lastUndoneTodoID: UUID?
    
    // Periodic Cloud Sync
    private let syncInterval: TimeInterval = 10 // alle 10 Sekunden (anpassbar)
    private var syncTimer: Timer?
    private var isSyncInProgress = false

    // MARK: - Undo/Redo Engine
    private enum Action: Codable {
        case create(todo: TodoItem)
        case delete(todo: TodoItem, originalIndex: Int)
        case complete(todoID: UUID, previousCompletedAt: Date?)
        case uncomplete(todoID: UUID)
        case update(old: TodoItem, new: TodoItem)
    }

    private var undoStack: [Action] = []
    private var redoStack: [Action] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let action = undoStack.popLast() else { return }
        applyInverse(of: action, pushTo: &redoStack)
    }

    func redo() {
        guard let action = redoStack.popLast() else { return }
        apply(action, pushTo: &undoStack)
    }

    private func pushUndo(_ action: Action) {
        undoStack.append(action)
        // Neue Aktion macht Redo hinfällig
        redoStack.removeAll()
    }

    private func apply(_ action: Action, pushTo stack: inout [Action]) {
        switch action {
        case .create(let todo):
            // Re-anwenden von Create => wirklich erstellen
            var t = todo
            t.updatedAt = Date()
            let insertIndex = todos.count
            todos.insert(t, at: insertIndex)
            saveTodos()
            CloudKitManager.shared.saveTodo(t)
            DispatchQueue.main.async { self.objectWillChange.send() }
            stack.append(.delete(todo: t, originalIndex: insertIndex))

        case .delete(let todo, let originalIndex):
            if let idx = todos.firstIndex(where: { $0.id == todo.id }) {
                deleteCalendarEvent(for: todos[idx])
                NotificationManager.shared.cancelNotification(id: todos[idx].id.uuidString)
                let removed = todos.remove(at: idx)
                saveTodos()
                DispatchQueue.main.async { self.objectWillChange.send() }
                CloudKitManager.shared.deleteTodo(removed)
                stack.append(.create(todo: removed))
            } else {
                // Falls lokal nicht vorhanden, nichts tun
                stack.append(.create(todo: todo))
            }

        case .complete(let todoID, _):
            if let idx = todos.firstIndex(where: { $0.id == todoID }) {
                if !todos[idx].isCompleted {
                    todos[idx].isCompleted = true
                    todos[idx].completedAt = Date()
                    todos[idx].updatedAt = Date()
                    updateStats(for: todos[idx])
                    NotificationManager.shared.cancelNotification(id: todos[idx].id.uuidString)
                    saveTodos()
                    CloudKitManager.shared.saveTodo(todos[idx])
                    DispatchQueue.main.async { self.objectWillChange.send() }
                }
                stack.append(.uncomplete(todoID: todoID))
            }
        case .uncomplete(let todoID):
            if let idx = todos.firstIndex(where: { $0.id == todoID }) {
                let oldCompletedAt = todos[idx].completedAt
                if todos[idx].isCompleted {
                    todos[idx].isCompleted = false
                    todos[idx].completedAt = nil
                    todos[idx].updatedAt = Date()
                    // Statistik korrigieren
                    if let comp = oldCompletedAt {
                        let day = Calendar.current.startOfDay(for: comp)
                        let current = dailyStats[day] ?? 0
                        dailyStats[day] = max(0, current - 1)
                        saveStats()
                        CloudKitManager.shared.saveDailyStat(date: day, count: dailyStats[day] ?? 0)
                    }
                    saveTodos()
                    CloudKitManager.shared.saveTodo(todos[idx])
                    DispatchQueue.main.async { self.objectWillChange.send() }
                }
                stack.append(.complete(todoID: todoID, previousCompletedAt: oldCompletedAt))
            }
        case .update(let old, let new):
            if let idx = todos.firstIndex(where: { $0.id == old.id }) {
                todos[idx] = new
                todos[idx].updatedAt = Date()
                saveTodos()
                CloudKitManager.shared.saveTodo(todos[idx])
                DispatchQueue.main.async { self.objectWillChange.send() }
                stack.append(.update(old: new, new: old))
            }
        }
    }

    private func applyInverse(of action: Action, pushTo stack: inout [Action]) {
        switch action {
        case .create(let todo):
            // Inverse von Create = Delete
            apply(.delete(todo: todo, originalIndex: todos.firstIndex(where: { $0.id == todo.id }) ?? todos.count), pushTo: &stack)
        case .delete(let todo, let originalIndex):
            // Inverse von Delete = Create (wiederherstellen an originalIndex)
            var t = todo
            t.updatedAt = Date()
            let insertIndex = min(max(0, originalIndex), todos.count)
            if !todos.contains(where: { $0.id == t.id }) {
                todos.insert(t, at: insertIndex)
                saveTodos()
                CloudKitManager.shared.saveTodo(t)
                DispatchQueue.main.async { self.objectWillChange.send() }
            }
            stack.append(.delete(todo: t, originalIndex: insertIndex))
        case .complete(let todoID, let prev):
            // Inverse von Complete = Uncomplete (mit Stats-Korrektur)
            if let idx = todos.firstIndex(where: { $0.id == todoID }) {
                if todos[idx].isCompleted {
                    todos[idx].isCompleted = false
                    todos[idx].completedAt = nil
                    todos[idx].updatedAt = Date()
                    if let comp = prev ?? Date() as Date? {
                        let day = Calendar.current.startOfDay(for: comp)
                        let current = dailyStats[day] ?? 0
                        dailyStats[day] = max(0, current - 1)
                        saveStats()
                        CloudKitManager.shared.saveDailyStat(date: day, count: dailyStats[day] ?? 0)
                    }
                    saveTodos()
                    CloudKitManager.shared.saveTodo(todos[idx])
                    DispatchQueue.main.async { self.objectWillChange.send() }
                }
                stack.append(.complete(todoID: todoID, previousCompletedAt: prev))
            }
        case .uncomplete(let todoID):
            // Inverse von Uncomplete = Complete
            apply(.complete(todoID: todoID, previousCompletedAt: nil), pushTo: &stack)
        case .update(let old, let new):
            // Inverse = zurück auf old
            apply(.update(old: new, new: old), pushTo: &stack)
        }
    }
    
    struct TrashEntry: Codable {
        let todo: TodoItem
        let originalIndex: Int
        let deletedAt: Date
    }
    
    init() {
        loadTodos()
        loadCategoriesFromCloud()
        loadCategories()
        loadStats()
        loadFocusMinutes()
        loadTrash()
        CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
            self?.applyDailyStatsFromCloud(cloudDaily)
        }
        CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
            self?.applyFocusStatsFromCloud(cloudFocus)
        }
        // Beobachte abgeschlossene Fokus-Sessions aus dem Timer
        NotificationCenter.default.addObserver(forName: .focusSessionCompleted, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let minutes = (note.userInfo?["minutes"] as? Int) ?? 0
            self.addFocusMinutes(minutes, on: Date())
        }
        
        // Starte periodischen Cloud-Sync
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.performPeriodicSync()
        }
        syncTimer?.tolerance = syncInterval * 0.1
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
                let oldCompletedAt = todos[index].completedAt
                todos[index].isCompleted = false
                todos[index].completedAt = nil
                todos[index].updatedAt = Date()
                lastUndoneTodoID = last.id   // merken für Redo
                saveTodos()
                CloudKitManager.shared.saveTodo(todos[index])
                if let comp = oldCompletedAt {
                    let day = Calendar.current.startOfDay(for: comp)
                    let current = dailyStats[day] ?? 0
                    dailyStats[day] = max(0, current - 1)
                    saveStats()
                    CloudKitManager.shared.saveDailyStat(date: day, count: dailyStats[day] ?? 0)
                    DispatchQueue.main.async { self.objectWillChange.send() }
                }
                print("↩️ undoLastCompleted synced: id=\(todos[index].id) isCompleted=\(todos[index].isCompleted) updatedAt=\(todos[index].updatedAt)")
            }
        }
    }
    
    func redoLastCompleted() {
        if let id = lastUndoneTodoID,
           let index = todos.firstIndex(where: { $0.id == id }) {
            todos[index].isCompleted = true
            todos[index].completedAt = Date()
            todos[index].updatedAt = Date()
            updateStats(for: todos[index])
            lastUndoneTodoID = nil // nur einmal Redo möglich
            saveTodos()
            CloudKitManager.shared.saveTodo(todos[index])
            print("↪️ redoLastCompleted synced: id=\(todos[index].id) isCompleted=\(todos[index].isCompleted) updatedAt=\(todos[index].updatedAt)")
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
        CloudKitManager.shared.saveCategory(category)
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveCategories()
        CloudKitManager.shared.deleteCategory(category)
        
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
            CloudKitManager.shared.saveCategory(categories[index])
            
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
    
    func loadCategoriesFromCloud() {
        CloudKitManager.shared.fetchCategories { cloudCategories in
            self.applyCategoriesFromCloud(cloudCategories)
        }
    }
    
    /// Wendet Kategorien aus der Cloud an (Cloud als Quelle), speichert lokal und triggert UI-Update
    func applyCategoriesFromCloud(_ cloudCategories: [Category]) {
        self.categories = cloudCategories
        self.saveCategories()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    // MARK: - Todo-Methoden
    
    func addTodo(_ todo: TodoItem) {
        var todo = todo
        todo.updatedAt = Date()
        todos.append(todo)
        saveTodos()
        pushUndo(.create(todo: todo))

        // CloudKit speichern
        CloudKitManager.shared.saveTodo(todo)

        if todo.calendarEnabled { addCalendarEvent(for: todo) }
        if let dueDate = todo.dueDate {
            let timeInterval = dueDate.timeIntervalSinceNow
            if timeInterval > 0 {
                let title = "Fällige Aufgabe: \(todo.title)"
                let body = todo.description.isEmpty ? "Deine Aufgabe ist fällig." : todo.description
                let duration: TimeInterval
                if let offset = todo.reminderOffsetMinutes, offset >= 0 {
                    duration = max(1, dueDate.addingTimeInterval(TimeInterval(-offset * 60)).timeIntervalSinceNow)
                } else {
                    duration = timeInterval
                }
                NotificationManager.shared.scheduleTimerNotification(
                    id: todo.id.uuidString,
                    title: title,
                    body: body,
                    duration: duration
                )
            }
        }
    }
    
    func updateTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let old = todos[index]
            var newTodo = todo
            newTodo.updatedAt = Date()
            todos[index] = newTodo
            saveTodos()
            pushUndo(.update(old: old, new: newTodo))

            // Kalender aktualisieren
            deleteCalendarEvent(for: newTodo)
            if newTodo.calendarEnabled { addCalendarEvent(for: newTodo) }

            // Notifications aktualisieren
            NotificationManager.shared.cancelNotification(id: newTodo.id.uuidString)
            if !newTodo.isCompleted, let dueDate = newTodo.dueDate {
                let timeInterval = dueDate.timeIntervalSinceNow
                if timeInterval > 0 {
                    let title = "Fällige Aufgabe: \(newTodo.title)"
                    let body = newTodo.description.isEmpty ? "Deine Aufgabe ist fällig." : newTodo.description
                    let duration: TimeInterval
                    if let offset = newTodo.reminderOffsetMinutes, offset >= 0 {
                        duration = max(1, dueDate.addingTimeInterval(TimeInterval(-offset * 60)).timeIntervalSinceNow)
                    } else {
                        duration = timeInterval
                    }
                    NotificationManager.shared.scheduleTimerNotification(
                        id: newTodo.id.uuidString,
                        title: title,
                        body: body,
                        duration: duration
                    )
                }
            }

            // Statistik bei Statuswechsel aktualisieren
            if newTodo.isCompleted && !old.isCompleted {
                updateStats(for: newTodo)
            } else if !newTodo.isCompleted && old.isCompleted {
                let day = Calendar.current.startOfDay(for: old.completedAt ?? Date())
                let current = dailyStats[day] ?? 0
                dailyStats[day] = max(0, current - 1)
                saveStats()
                CloudKitManager.shared.saveDailyStat(date: day, count: dailyStats[day] ?? 0)
                DispatchQueue.main.async { self.objectWillChange.send() }
            }

            // CloudKit upsert
            CloudKitManager.shared.saveTodo(newTodo)
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        
        pushUndo(.delete(todo: todos[index], originalIndex: index))

        // CloudKit löschen
        CloudKitManager.shared.deleteTodo(todo)

        // Notification & Calendar
        deleteCalendarEvent(for: todo)
        NotificationManager.shared.cancelNotification(id: todo.id.uuidString)

        // Gelöschtes Todo merken
        lastDeletedTodo = todos[index]
        lastDeletedIndex = index
        deletedTodos.append(TrashEntry(todo: todos[index], originalIndex: index, deletedAt: Date()))
        
        // Cleanup deletedTodos entries older than trashMaxDays
        let cutoff = Calendar.current.date(byAdding: .day, value: -trashMaxDays, to: Date()) ?? Date().addingTimeInterval(TimeInterval(-trashMaxDays * 24 * 3600))
        deletedTodos = deletedTodos.filter { $0.deletedAt >= cutoff }
        
        if deletedTodos.count > trashMaxCount {
            // Keep newest trashMaxCount entries
            deletedTodos = Array(deletedTodos.suffix(trashMaxCount))
        }
        saveTrash()

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
        DispatchQueue.main.async {
            if let last = self.deletedTodos.last {
                // Compute safe insert index and avoid duplicates
                let insertIndex = min(max(0, last.originalIndex), self.todos.count)
                if !self.todos.contains(where: { $0.id == last.todo.id }) {
                    self.todos.insert(last.todo, at: insertIndex)
                    self.lastDeletedTodo = last.todo
                    self.lastDeletedIndex = insertIndex
                    self.saveTodos()
                    self.objectWillChange.send()
                    // Restore in CloudKit
                    CloudKitManager.shared.saveTodo(last.todo)
                }
                // Remove from trash history
                _ = self.deletedTodos.popLast()
                self.saveTrash()
            } else if let todo = self.lastDeletedTodo, let index = self.lastDeletedIndex {
                let safeIndex = min(max(0, index), self.todos.count)
                if !self.todos.contains(where: { $0.id == todo.id }) {
                    self.todos.insert(todo, at: safeIndex)
                    self.lastDeletedIndex = safeIndex
                    if let insertedIndex = self.todos.firstIndex(where: { $0.id == todo.id }) {
                        self.todos[insertedIndex].updatedAt = Date()
                    }
                    self.saveTodos()
                    self.objectWillChange.send()
                    CloudKitManager.shared.saveTodo(todo)
                }
                // Reset flags to avoid repeated stale reinsertions
                self.lastDeletedTodo = nil
                self.lastDeletedIndex = nil
            }
        }
    }

    func redoLastDeleted() {
        DispatchQueue.main.async {
            if let todo = self.lastDeletedTodo {
                if let idx = self.todos.firstIndex(where: { $0.id == todo.id }) {
                    // Only add to trash if it's not already the last entry for same id
                    if self.deletedTodos.last?.todo.id != todo.id {
                        self.deletedTodos.append(TrashEntry(todo: todo, originalIndex: idx, deletedAt: Date()))
                        self.saveTrash()
                    }
                    self.todos.remove(at: idx)
                    self.saveTodos()
                    self.objectWillChange.send()
                }
                // Reset flags to avoid repeated redoes on stale state
                self.lastDeletedTodo = nil
                self.lastDeletedIndex = nil
            } else if let last = self.deletedTodos.last {
                if let idx = self.todos.firstIndex(where: { $0.id == last.todo.id }) {
                    self.todos.remove(at: idx)
                    self.saveTodos()
                    self.objectWillChange.send()
                }
            }
        }
    }
    
    func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let wasCompleted = todo.isCompleted
            let previousCompletedAt = todo.completedAt
            
            var updatedTodo = todo
            updatedTodo.isCompleted.toggle()
            if updatedTodo.isCompleted {
                updatedTodo.completedAt = Date()
                updateStats(for: updatedTodo)
                
                // 🔹 Notification abbrechen
                NotificationManager.shared.cancelNotification(id: updatedTodo.id.uuidString)
                pushUndo(.complete(todoID: updatedTodo.id, previousCompletedAt: previousCompletedAt))
            } else {
                updatedTodo.completedAt = nil
                if wasCompleted {
                    let day = Calendar.current.startOfDay(for: previousCompletedAt ?? Date())
                    let current = dailyStats[day] ?? 0
                    dailyStats[day] = max(0, current - 1)
                    saveStats()
                    CloudKitManager.shared.saveDailyStat(date: day, count: dailyStats[day] ?? 0)
                    pushUndo(.uncomplete(todoID: updatedTodo.id))
                }
            }
            updatedTodo.updatedAt = Date()
            todos[index] = updatedTodo
            saveTodos()
            CloudKitManager.shared.saveTodo(updatedTodo)
            print("🔔 toggleTodo synced: id=\(updatedTodo.id) isCompleted=\(updatedTodo.isCompleted) updatedAt=\(updatedTodo.updatedAt)")
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
        
        pushUndo(.complete(todoID: todos[index].id, previousCompletedAt: todos[index].completedAt))
        
        // ✅ Sofort speichern (ohne race conditions)
        DispatchQueue.main.async {
            self.saveTodos()
            self.objectWillChange.send() // zwingt SwiftUI zur Neurenderung
        }
        CloudKitManager.shared.saveTodo(todos[index])
        print("✅ complete synced: id=\(todos[index].id) isCompleted=\(todos[index].isCompleted) updatedAt=\(String(describing: todos[index].updatedAt)) completedAt=\(String(describing: todos[index].completedAt))")
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
    
    // MARK: - Fokus-Minuten
    private func loadFocusMinutes() {
        if let data = UserDefaults.standard.data(forKey: focusStatsKey),
           let map = try? JSONDecoder().decode([Date: Int].self, from: data) {
            self.dailyFocusMinutes = map
        }
    }

    private func saveFocusMinutes() {
        if let data = try? JSONEncoder().encode(dailyFocusMinutes) {
            UserDefaults.standard.set(data, forKey: focusStatsKey)
        }
    }

    func addFocusMinutes(_ minutes: Int, on date: Date) {
        guard minutes > 0 else { return }
        let day = Calendar.current.startOfDay(for: date)
        let newTotal = (dailyFocusMinutes[day] ?? 0) + minutes
        dailyFocusMinutes[day] = newTotal
        saveFocusMinutes()
        CloudKitManager.shared.saveFocusStat(date: day, minutes: newTotal)
        DispatchQueue.main.async { self.objectWillChange.send() }
    }

    func applyFocusStatsFromCloud(_ map: [Date: Int]) {
        var changed = false
        for (date, minutes) in map {
            let localDay = Calendar.current.startOfDay(for: date)
            let existing = dailyFocusMinutes[localDay] ?? 0
            let merged = max(existing, minutes)
            if dailyFocusMinutes[localDay] != merged {
                dailyFocusMinutes[localDay] = merged
                changed = true
            }
        }
        if changed {
            saveFocusMinutes()
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
    
    func applyDailyStatsFromCloud(_ map: [Date: Int]) {
        var changed = false
        for (date, count) in map {
            let localDay = Calendar.current.startOfDay(for: date)
            let existing = dailyStats[localDay] ?? 0
            let merged = max(existing, count)
            if dailyStats[localDay] != merged {
                dailyStats[localDay] = merged
                changed = true
            }
        }
        if changed {
            saveStats()
            DispatchQueue.main.async { self.objectWillChange.send() }
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
            CloudKitManager.shared.saveDailyStat(date: today, count: dailyStats[today] ?? 0)
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
    
    /// Führt einen periodischen Sync mit CloudKit durch: Todos, DailyStats und FocusStats.
    private func performPeriodicSync() {
        guard !isSyncInProgress else { return }
        isSyncInProgress = true

        let group = DispatchGroup()

        group.enter()
        CloudKitManager.shared.fetchTodos { [weak self] cloudTodos in
            self?.mergeFromCloud(cloudTodos)
            group.leave()
        }

        group.enter()
        CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
            self?.applyDailyStatsFromCloud(cloudDaily)
            group.leave()
        }

        group.enter()
        CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
            self?.applyFocusStatsFromCloud(cloudFocus)
            group.leave()
        }

        group.enter()
        CloudKitManager.shared.fetchCategories { [weak self] cloudCategories in
            self?.applyCategoriesFromCloud(cloudCategories)
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            self?.isSyncInProgress = false
            print("⏱️ Periodic Cloud sync completed")
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
        // Deduplicate local todos by id (keep latest updatedAt) to avoid fatal error on duplicate keys
        var dedupedLocal: [UUID: TodoItem] = [:]
        for item in todos {
            if let existing = dedupedLocal[item.id] {
                // keep the more recent one
                if item.updatedAt > existing.updatedAt {
                    dedupedLocal[item.id] = item
                }
            } else {
                dedupedLocal[item.id] = item
            }
        }
        var localByID = dedupedLocal

        var changed = false

        // Cloud → Lokal: Einfügen/Aktualisieren
        for cloud in cloudTodos {
            if let local = localByID[cloud.id] {
                // Last-Writer-Wins anhand updatedAt
                let pickingCloud = cloud.updatedAt >= local.updatedAt
                let chosen = pickingCloud ? cloud : local

                // Debug: Log Konflikt & Entscheidung
                if cloud.updatedAt != local.updatedAt {
                    print("🔁 Merge LWW for todo \(cloud.id): cloud.updatedAt=\(cloud.updatedAt), local.updatedAt=\(local.updatedAt) -> chosen=\(pickingCloud ? "cloud" : "local") (isCompleted: \(chosen.isCompleted))")
                } else if cloud.isCompleted != local.isCompleted {
                    // Gleiches updatedAt, aber unterschiedliche Completion-States – Cloud bevorzugen
                    print("⚠️ Merge tie on updatedAt for \(cloud.id). Different completion states. Preferring cloud.isCompleted=\(cloud.isCompleted)")
                }

                if chosen.updatedAt != local.updatedAt || cloud.isCompleted != local.isCompleted {
                    changed = true
                }

                // Side-effect: Notification abbrechen, wenn durch Merge abgeschlossen wurde
                if chosen.isCompleted && !local.isCompleted {
                    NotificationManager.shared.cancelNotification(id: chosen.id.uuidString)
                }

                localByID[cloud.id] = chosen
            } else {
                localByID[cloud.id] = cloud
                changed = true
                if cloud.isCompleted {
                    NotificationManager.shared.cancelNotification(id: cloud.id.uuidString)
                }
            }
        }

        // Optional: Lokal → Cloud pushen (für Einträge, die es nur lokal gibt)
        // Hier pushen wir sie hoch, damit Geräte konsistent werden.
        for (id, local) in localByID {
            if !cloudTodos.contains(where: { $0.id == id }) {
                CloudKitManager.shared.saveTodo(local)
            }
        }

        // Resolve categories by ID when category is nil
        let resolvedTodosUnsorted: [TodoItem] = Array(localByID.values).map { item in
            var t = item
            if t.category == nil, let cid = t.categoryID {
                if let match = self.categories.first(where: { $0.id == cid }) {
                    t.category = match
                }
            }
            return t
        }
        // Deduplicate again defensively and create a stable order (newest first)
        var finalByID: [UUID: TodoItem] = [:]
        for item in resolvedTodosUnsorted {
            if let existing = finalByID[item.id] {
                if item.updatedAt > existing.updatedAt {
                    finalByID[item.id] = item
                }
            } else {
                finalByID[item.id] = item
            }
        }
        let newTodos = finalByID.values.sorted { $0.updatedAt > $1.updatedAt }

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
    
    func restoreDeleted(at index: Int) {
        guard deletedTodos.indices.contains(index) else { return }
        let entry = deletedTodos.remove(at: index)
        let insertIndex = min(max(0, entry.originalIndex), todos.count)
        todos.insert(entry.todo, at: insertIndex)
        saveTodos()
        DispatchQueue.main.async { self.objectWillChange.send() }
        CloudKitManager.shared.saveTodo(entry.todo)
        saveTrash()
    }
    
    func removeFromTrash(at index: Int) {
        guard deletedTodos.indices.contains(index) else { return }
        let entry = deletedTodos.remove(at: index)
        saveTrash()
        // Already removed from local todos; ensure Cloud is deleted as well
        CloudKitManager.shared.deleteTodo(entry.todo)
    }
    
    func emptyTrash() {
        for entry in deletedTodos { CloudKitManager.shared.deleteTodo(entry.todo) }
        deletedTodos.removeAll()
        saveTrash()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    private func saveTrash() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(deletedTodos) {
            UserDefaults.standard.set(data, forKey: trashKey)
        }
    }

    private func loadTrash() {
        if let data = UserDefaults.standard.data(forKey: trashKey),
           let entries = try? JSONDecoder().decode([TrashEntry].self, from: data) {
            self.deletedTodos = entries
            
            // Cleanup deletedTodos entries older than trashMaxDays
            let cutoff = Calendar.current.date(byAdding: .day, value: -trashMaxDays, to: Date()) ?? Date().addingTimeInterval(TimeInterval(-trashMaxDays * 24 * 3600))
            self.deletedTodos = self.deletedTodos.filter { $0.deletedAt >= cutoff }
            
            if self.deletedTodos.count > trashMaxCount {
                self.deletedTodos = Array(self.deletedTodos.suffix(trashMaxCount))
                saveTrash()
            }
        }
    }
    
    func updateTrashSettings(maxCount: Int, maxDays: Int) {
        let count = max(1, maxCount)
        let days = max(1, maxDays)
        UserDefaults.standard.set(count, forKey: trashMaxCountKey)
        UserDefaults.standard.set(days, forKey: trashMaxDaysKey)
        // Re-apply constraints immediately
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        deletedTodos = deletedTodos.filter { $0.deletedAt >= cutoff }
        if deletedTodos.count > count {
            deletedTodos = Array(deletedTodos.suffix(count))
        }
        saveTrash()
    }
}
