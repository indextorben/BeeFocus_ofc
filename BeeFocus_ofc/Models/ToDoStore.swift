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

// Category is defined in CategoryShared.swift

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
    private var syncTask: Task<Void, Never>?

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
                // Cancel calendar and notifications
                deleteCalendarEvent(for: todos[idx])
                NotificationManager.shared.cancelNotification(id: todos[idx].id.uuidString)

                // Remove from list
                let removed = todos.remove(at: idx)
                saveTodos()
                DispatchQueue.main.async { self.objectWillChange.send() }

                // Cloud delete
                CloudKitManager.shared.deleteTodo(removed)

                // Append to trash
                deletedTodos.append(TrashEntry(todo: removed, originalIndex: idx, deletedAt: Date()))

                // Enforce trash policies
                let cutoff = Calendar.current.date(byAdding: .day, value: -trashMaxDays, to: Date()) ?? Date().addingTimeInterval(TimeInterval(-trashMaxDays * 24 * 3600))
                deletedTodos = deletedTodos.filter { $0.deletedAt >= cutoff }
                if deletedTodos.count > trashMaxCount {
                    deletedTodos = Array(deletedTodos.suffix(trashMaxCount))
                }
                saveTrash()

                // Push inverse
                stack.append(.create(todo: removed))
            } else {
                // If not present locally, still push inverse create to allow redo
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
            // Remove any matching trash entries for restored todo
            let beforeCount = deletedTodos.count
            deletedTodos.removeAll { $0.todo.id == t.id }
            if deletedTodos.count != beforeCount { saveTrash() }

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
        
        // Initial sync beim App-Start
        print("🚀 Initial CloudKit sync beim App-Start...")
        CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
            self?.applyDailyStatsFromCloud(cloudDaily)
        }
        CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
            self?.applyFocusStatsFromCloud(cloudFocus)
        }
        
        // IMPORTANT: Force full todo sync on startup to resolve conflicts
        CloudKitManager.shared.fetchTodos { [weak self] cloudTodos in
            print("📥 Initial fetch: \(cloudTodos.count) todos from CloudKit")
            self?.mergeFromCloud(cloudTodos)
        }
        
        // Beobachte abgeschlossene Fokus-Sessions aus dem Timer
        NotificationCenter.default.addObserver(forName: .focusSessionCompleted, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            let minutes = (note.userInfo?["minutes"] as? Int) ?? 0
            print("📥 focusSessionCompleted received: minutes=\(minutes)")
            let before = self.dailyFocusMinutes[Calendar.current.startOfDay(for: Date())] ?? 0
            self.addFocusMinutes(minutes, on: Date())
            let after = self.dailyFocusMinutes[Calendar.current.startOfDay(for: Date())] ?? 0
            print("📊 Focus minutes updated: before=\(before) after=\(after)")
        }
        
        // Beobachte Tageswechsel, um Wiederholungen um 00:00 zu aktualisieren
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            self?.refreshRecurrencesForToday()
        }
        // Beim Start einmal prüfen
        refreshRecurrencesForToday()
        
        // Starte periodischen Cloud-Sync (verbesserte Version mit Swift Concurrency)
        startPeriodicSync()
    }
    
    // MARK: - Periodic Sync Management
    
    /// Force-synct alle Daten aus CloudKit (nützlich bei Problemen)
    func forceFullSync() {
        print("🔄 Force Full Sync gestartet...")
        
        isSyncInProgress = false // Reset flag falls hängengeblieben
        
        let group = DispatchGroup()
        
        group.enter()
        CloudKitManager.shared.fetchTodos { [weak self] cloudTodos in
            print("  📥 Fetched \(cloudTodos.count) todos from CloudKit")
            self?.mergeFromCloud(cloudTodos)
            group.leave()
        }
        
        group.enter()
        CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
            print("  📥 Fetched \(cloudDaily.count) daily stats from CloudKit")
            self?.applyDailyStatsFromCloud(cloudDaily)
            group.leave()
        }
        
        group.enter()
        CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
            print("  📥 Fetched \(cloudFocus.count) focus stats from CloudKit")
            self?.applyFocusStatsFromCloud(cloudFocus)
            group.leave()
        }
        
        group.enter()
        CloudKitManager.shared.fetchCategories { [weak self] cloudCategories in
            print("  📥 Fetched \(cloudCategories.count) categories from CloudKit")
            self?.applyCategoriesFromCloud(cloudCategories)
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("✅ Force Full Sync abgeschlossen")
            // Trigger UI update
            self.objectWillChange.send()
        }
    }
    
    /// Startet den periodischen Cloud-Sync mit Swift Concurrency
    private func startPeriodicSync() {
        // Cancel any existing task
        syncTask?.cancel()
        
        // Create a new repeating task
        syncTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                // Perform sync
                await self.performPeriodicSyncAsync()
                
                // Wait for the interval (check for cancellation)
                try? await Task.sleep(nanoseconds: UInt64(self.syncInterval * 1_000_000_000))
                
                // Check if cancelled
                if Task.isCancelled {
                    break
                }
            }
        }
    }
    
    /// Async wrapper for periodic sync
    private func performPeriodicSyncAsync() async {
        guard !isSyncInProgress else { return }
        
        await MainActor.run {
            self.isSyncInProgress = true
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                await withCheckedContinuation { continuation in
                    CloudKitManager.shared.fetchTodos { [weak self] cloudTodos in
                        self?.mergeFromCloud(cloudTodos)
                        continuation.resume()
                    }
                }
            }
            
            group.addTask { [weak self] in
                await withCheckedContinuation { continuation in
                    CloudKitManager.shared.fetchDailyStats { [weak self] cloudDaily in
                        self?.applyDailyStatsFromCloud(cloudDaily)
                        continuation.resume()
                    }
                }
            }
            
            group.addTask { [weak self] in
                await withCheckedContinuation { continuation in
                    CloudKitManager.shared.fetchFocusStats { [weak self] cloudFocus in
                        self?.applyFocusStatsFromCloud(cloudFocus)
                        continuation.resume()
                    }
                }
            }
            
            group.addTask { [weak self] in
                await withCheckedContinuation { continuation in
                    CloudKitManager.shared.fetchCategories { [weak self] cloudCategories in
                        self?.applyCategoriesFromCloud(cloudCategories)
                        continuation.resume()
                    }
                }
            }
        }
        
        await MainActor.run {
            self.isSyncInProgress = false
            print("⏱️ Periodic Cloud sync completed")
        }
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
                // Determine if this is a reminder before due, or at due time
                let hasReminder = (todo.reminderOffsetMinutes ?? -1) >= 0
                let isReminderBeforeDue: Bool
                let duration: TimeInterval
                if let offset = todo.reminderOffsetMinutes, offset >= 0 {
                    let reminderFire = dueDate.addingTimeInterval(TimeInterval(-offset * 60))
                    duration = max(1, reminderFire.timeIntervalSinceNow)
                    isReminderBeforeDue = reminderFire < dueDate
                } else {
                    duration = timeInterval
                    isReminderBeforeDue = false
                }

                // Build title/body with personalization fallback
                let loc = LocalizationManager.shared
                let isGerman = (loc.selectedLanguage == "Deutsch" || loc.selectedLanguage == "German" || Locale.current.language.languageCode?.identifier == "de")

                // Personalized override if provided
                let personalizedTitle = todo.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                let personalizedBody = todo.reminderBody?.trimmingCharacters(in: .whitespacesAndNewlines)

                let defaultReminderTitle = {
                    let key = isGerman ? "reminder_default_title_de" : "reminder_default_title_en"
                    let template = loc.localizedString(forKey: key)
                    return template.replacingOccurrences(of: "%@", with: todo.title)
                }()
                let defaultDueTitle = {
                    let key = isGerman ? "due_default_title_de" : "due_default_title_en"
                    let template = loc.localizedString(forKey: key)
                    return template.replacingOccurrences(of: "%@", with: todo.title)
                }()

                let defaultReminderBody: String = {
                    let key = isGerman ? "reminder_default_body_de" : "reminder_default_body_en"
                    var template = loc.localizedString(forKey: key)
                    let desc = todo.description.isEmpty ? (isGerman ? loc.localizedString(forKey: "reminder_default_body_fallback_de") : loc.localizedString(forKey: "reminder_default_body_fallback_en")) : todo.description
                    template = template.replacingOccurrences(of: "%@", with: desc)
                    return template
                }()

                let defaultDueBody: String = {
                    let key = isGerman ? "due_default_body_de" : "due_default_body_en"
                    var template = loc.localizedString(forKey: key)
                    let desc = todo.description.isEmpty ? (isGerman ? loc.localizedString(forKey: "due_default_body_fallback_de") : loc.localizedString(forKey: "due_default_body_fallback_en")) : todo.description
                    template = template.replacingOccurrences(of: "%@", with: desc)
                    return template
                }()

                let title: String
                let body: String
                if hasReminder && isReminderBeforeDue {
                    title = (personalizedTitle?.isEmpty == false ? personalizedTitle! : defaultReminderTitle)
                    body = (personalizedBody?.isEmpty == false ? personalizedBody! : defaultReminderBody)
                } else {
                    title = defaultDueTitle
                    body = defaultDueBody
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
                    let hasReminder = (newTodo.reminderOffsetMinutes ?? -1) >= 0
                    let isReminderBeforeDue: Bool
                    let duration: TimeInterval
                    if let offset = newTodo.reminderOffsetMinutes, offset >= 0 {
                        let reminderFire = dueDate.addingTimeInterval(TimeInterval(-offset * 60))
                        duration = max(1, reminderFire.timeIntervalSinceNow)
                        isReminderBeforeDue = reminderFire < dueDate
                    } else {
                        duration = timeInterval
                        isReminderBeforeDue = false
                    }

                    // Build title/body with personalization fallback
                    let loc = LocalizationManager.shared
                    let isGerman = (loc.selectedLanguage == "Deutsch" || loc.selectedLanguage == "German" || Locale.current.language.languageCode?.identifier == "de")

                    // Personalized override if provided
                    let personalizedTitle = newTodo.reminderTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let personalizedBody = newTodo.reminderBody?.trimmingCharacters(in: .whitespacesAndNewlines)

                    let defaultReminderTitle = {
                        let key = isGerman ? "reminder_default_title_de" : "reminder_default_title_en"
                        let template = loc.localizedString(forKey: key)
                        return template.replacingOccurrences(of: "%@", with: newTodo.title)
                    }()
                    let defaultDueTitle = {
                        let key = isGerman ? "due_default_title_de" : "due_default_title_en"
                        let template = loc.localizedString(forKey: key)
                        return template.replacingOccurrences(of: "%@", with: newTodo.title)
                    }()

                    let defaultReminderBody: String = {
                        let key = isGerman ? "reminder_default_body_de" : "reminder_default_body_en"
                        var template = loc.localizedString(forKey: key)
                        let desc = newTodo.description.isEmpty ? (isGerman ? loc.localizedString(forKey: "reminder_default_body_fallback_de") : loc.localizedString(forKey: "reminder_default_body_fallback_en")) : newTodo.description
                        template = template.replacingOccurrences(of: "%@", with: desc)
                        return template
                    }()

                    let defaultDueBody: String = {
                        let key = isGerman ? "due_default_body_de" : "due_default_body_en"
                        var template = loc.localizedString(forKey: key)
                        let desc = newTodo.description.isEmpty ? (isGerman ? loc.localizedString(forKey: "due_default_body_fallback_de") : loc.localizedString(forKey: "due_default_body_fallback_en")) : newTodo.description
                        template = template.replacingOccurrences(of: "%@", with: desc)
                        return template
                    }()

                    let title: String
                    let body: String
                    if hasReminder && isReminderBeforeDue {
                        title = (personalizedTitle?.isEmpty == false ? personalizedTitle! : defaultReminderTitle)
                        body = (personalizedBody?.isEmpty == false ? personalizedBody! : defaultReminderBody)
                    } else {
                        title = defaultDueTitle
                        body = defaultDueBody
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
        let before = dailyFocusMinutes[day] ?? 0
        let newTotal = before + minutes
        dailyFocusMinutes[day] = newTotal
        print("➕ Adding focus minutes: +\(minutes) (before=\(before) -> after=\(newTotal)) on \(day)")
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
    /// Mergt Todos aus der Cloud in den lokalen Store mit verbesserter Conflict Resolution.
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

        // Cloud → Lokal: Einfügen/Aktualisieren mit verbesserter Conflict Resolution
        for cloud in cloudTodos {
            if let local = localByID[cloud.id] {
                // IMPROVED: Smart conflict resolution
                let chosen = resolveConflict(local: local, cloud: cloud)
                
                if chosen.updatedAt != local.updatedAt || chosen.isCompleted != local.isCompleted {
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
    
    // MARK: - Smart Conflict Resolution
    
    /// Intelligente Konfliktauflösung zwischen lokalem und Cloud-Todo
    /// Regeln:
    /// 1. Neuestes updatedAt gewinnt (Last Writer Wins)
    /// 2. Bei gleichem updatedAt: completedAt entscheidet (neueste Completion gewinnt)
    /// 3. Bei gleichem updatedAt UND keinem completedAt: Completed = true gewinnt (defensiv)
    /// 4. Logging für Debugging
    private func resolveConflict(local: TodoItem, cloud: TodoItem) -> TodoItem {
        // Case 1: Different updatedAt → Newest wins
        if cloud.updatedAt > local.updatedAt {
            print("🔁 Merge: Cloud newer → cloud.updatedAt=\(cloud.updatedAt) > local.updatedAt=\(local.updatedAt) (isCompleted: \(cloud.isCompleted))")
            return cloud
        } else if local.updatedAt > cloud.updatedAt {
            print("🔁 Merge: Local newer → local.updatedAt=\(local.updatedAt) > cloud.updatedAt=\(cloud.updatedAt) (isCompleted: \(local.isCompleted))")
            return local
        }
        
        // Case 2: Same updatedAt → need tiebreaker
        print("⚖️ Merge tie: same updatedAt=\(local.updatedAt)")
        
        // Tiebreaker 1: Different completion states
        if cloud.isCompleted != local.isCompleted {
            // Check completedAt to see which one was marked completed more recently
            let cloudCompletedAt = cloud.completedAt ?? Date.distantPast
            let localCompletedAt = local.completedAt ?? Date.distantPast
            
            if cloudCompletedAt > localCompletedAt {
                print("  ↪️ Cloud has newer completedAt → choosing cloud.isCompleted=\(cloud.isCompleted)")
                return cloud
            } else if localCompletedAt > cloudCompletedAt {
                print("  ↪️ Local has newer completedAt → choosing local.isCompleted=\(local.isCompleted)")
                return local
            } else {
                // Same completedAt (or both nil) but different completion states
                // Defensive: prefer completed=true to avoid losing work
                if cloud.isCompleted {
                    print("  ↪️ Tie on completedAt, but cloud is completed → choosing cloud")
                    return cloud
                } else {
                    print("  ↪️ Tie on completedAt, but local is completed → choosing local")
                    return local
                }
            }
        }
        
        // Case 3: Same updatedAt AND same completion state
        // Check other fields for differences
        let hasDifferences = 
            cloud.title != local.title ||
            cloud.description != local.description ||
            cloud.priority != local.priority ||
            cloud.isFavorite != local.isFavorite ||
            cloud.dueDate != local.dueDate
        
        if hasDifferences {
            // Tiebreaker 2: Use createdAt (older item wins as "authoritative")
            if cloud.createdAt < local.createdAt {
                print("  ↪️ Content differs, cloud is older → choosing cloud")
                return cloud
            } else {
                print("  ↪️ Content differs, local is older → choosing local")
                return local
            }
        }
        
        // Case 4: Completely identical → doesn't matter, return cloud
        print("  ↪️ Completely identical → choosing cloud")
        return cloud
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
        syncTask?.cancel()
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
    
    /// Aktualisiert wiederkehrende Todos so, dass sie am Wiederholungstag um 00:00 Uhr erscheinen.
    /// Diese Methode setzt das Fälligkeitsdatum auf den heutigen Tagesanfang und markiert die Aufgabe als nicht erledigt,
    /// wenn laut Wiederholungsregel heute ein neuer Zyklus beginnt.
    func refreshRecurrencesForToday() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        var itemsToUpdate: [TodoItem] = []
        for item in todos {
            guard item.recurrenceEnabled else { continue }
            // Nur wieder erscheinen lassen, wenn zuvor erledigt, um keine doppelten offenen Einträge zu erzeugen
            guard item.isCompleted else { continue }
            // Schon heute zurückgesetzt?
            if let last = item.lastResetDate, cal.isDate(last, inSameDayAs: todayStart) { continue }

            // Bestimme nächstes Reset-Datum basierend auf der vorhandenen Logik.
            if let next = item.nextReset(after: yesterday), cal.isDate(next, inSameDayAs: todayStart) {
                var updated = item
                updated.dueDate = todayStart
                updated.isCompleted = false
                updated.completedAt = nil
                updated.lastResetDate = todayStart
                updated.updatedAt = Date()
                itemsToUpdate.append(updated)
            }
        }

        // Anwenden über updateTodo, damit Notifications/CloudKit korrekt aktualisiert werden
        for updated in itemsToUpdate {
            self.updateTodo(updated)
        }
    }
}

