//
//  ToDoStore.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import Foundation
import SwiftUI
import UIKit

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
            }
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

        // Kategorie aus Todos entfernen (category optional!)
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

            // Aktualisiere Kategorie in Todos
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
        todos.append(todo)
        saveTodos()
    }

    func updateTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
            saveTodos()
        }
    }

    func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        saveTodos()
    }

    func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            var updatedTodo = todo
            updatedTodo.isCompleted.toggle()
            if updatedTodo.isCompleted {
                updatedTodo.completedAt = Date()
                updateStats(for: updatedTodo)
            } else {
                updatedTodo.completedAt = nil
            }
            todos[index] = updatedTodo
            saveTodos()
        }
    }

    func complete(todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        if !todos[index].isCompleted {
            todos[index].isCompleted = true
            todos[index].completedAt = Date()
            updateStats(for: todos[index])
            saveTodos()
        }
    }

    private func saveTodos() {
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
}
