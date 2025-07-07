//
//  AlertModifiers.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData
import UserNotifications

struct AlertModifiers: ViewModifier {
    @Binding var showingDeleteAlert: Bool
    @Binding var todoToDelete: TodoItem?
    var todoStore: TodoStore
    @Binding var showingAddCategory: Bool
    @Binding var newCategoryName: String
    @Binding var editingCategory: Category?           // Category statt String
    @Binding var showingDeleteCategoryAlert: Bool
    @Binding var categoryToDelete: Category?          // Category statt String
    @Binding var selectedCategory: Category?          // Category statt String
    
    private var editCategoryAlertIsPresented: Binding<Bool> {
        Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )
    }
    
    func body(content: Content) -> some View {
        content
            .alert("Aufgabe löschen?", isPresented: $showingDeleteAlert) {
                deleteTodoAlertButtons
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
            .alert("Neue Kategorie", isPresented: $showingAddCategory) {
                addCategoryAlertFields
            } message: {
                Text("Bitte geben Sie einen Namen für die neue Kategorie ein.")
            }
            .alert("Kategorie umbenennen", isPresented: editCategoryAlertIsPresented) {
                editCategoryAlertFields
            } message: {
                Text("Bitte geben Sie einen neuen Namen für die Kategorie ein.")
            }
            .alert("Kategorie löschen?", isPresented: $showingDeleteCategoryAlert) {
                deleteCategoryAlertButtons
            } message: {
                Text("Alle Aufgaben in dieser Kategorie werden in die erste verfügbare Kategorie verschoben.")
            }
    }
    
    private var deleteTodoAlertButtons: some View {
        Group {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                if let todo = todoToDelete {
                    todoStore.deleteTodo(todo)
                }
            }
        }
    }
    
    private var addCategoryAlertFields: some View {
        Group {
            TextField("Kategoriename", text: $newCategoryName)
            Button("Abbrechen", role: .cancel) {
                newCategoryName = ""
            }
            Button("Hinzufügen") {
                if !newCategoryName.isEmpty {
                    // Neue Kategorie mit Standard-Farbe erstellen
                    let newCategory = Category(name: newCategoryName, colorHex: "1E90FF")
                    todoStore.addCategory(newCategory)
                    newCategoryName = ""
                }
            }
        }
    }
    
    private var editCategoryAlertFields: some View {
        Group {
            if let category = editingCategory {
                TextField("Neuer Name", text: Binding(
                    get: { category.name },
                    set: { newName in
                        if !newName.isEmpty {
                            todoStore.renameCategory(from: category, to: newName)
                            editingCategory = nil
                        }
                    }
                ))
                Button("Abbrechen", role: .cancel) {
                    editingCategory = nil
                }
            }
        }
    }
    
    private var deleteCategoryAlertButtons: some View {
        Group {
            Button("Abbrechen", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Löschen", role: .destructive) {
                if let category = categoryToDelete {
                    todoStore.deleteCategory(category)
                    if selectedCategory == category {
                        selectedCategory = nil
                    }
                    categoryToDelete = nil
                }
            }
        }
    }
}
