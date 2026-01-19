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
    var todoStore: BeeFocus_ofc.TodoStore
    @Binding var showingAddCategory: Bool
    @Binding var newCategoryName: String
    @Binding var editingCategory: BeeFocus_ofc.Category?
    @Binding var showingDeleteCategoryAlert: Bool
    @Binding var categoryToDelete: BeeFocus_ofc.Category?
    @Binding var selectedCategory: BeeFocus_ofc.Category?
    
    @ObservedObject private var localizer = LocalizationManager.shared
    
    private var editCategoryAlertIsPresented: Binding<Bool> {
        Binding(
            get: { editingCategory != nil },
            set: { if !$0 { editingCategory = nil } }
        )
    }
    
    func body(content: Content) -> some View {
        content
            .alert(localizer.localizedString(forKey: "alert_delete_task"), isPresented: $showingDeleteAlert) {
                deleteTodoAlertButtons
            } message: {
                Text(localizer.localizedString(forKey: "alert_delete_task_message"))
            }
            .alert(localizer.localizedString(forKey: "alert_new_category"), isPresented: $showingAddCategory) {
                addCategoryAlertFields
            } message: {
                Text(localizer.localizedString(forKey: "alert_new_category_message"))
            }
            .alert(localizer.localizedString(forKey: "alert_rename_category"), isPresented: editCategoryAlertIsPresented) {
                editCategoryAlertFields
            } message: {
                Text(localizer.localizedString(forKey: "alert_rename_category_message"))
            }
            .alert(localizer.localizedString(forKey: "alert_delete_category"), isPresented: $showingDeleteCategoryAlert) {
                deleteCategoryAlertButtons
            } message: {
                Text(localizer.localizedString(forKey: "alert_delete_category_message"))
            }
    }
    
    private var deleteTodoAlertButtons: some View {
        Group {
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {}
            Button(localizer.localizedString(forKey: "delete"), role: .destructive) {
                if let todo = todoToDelete {
                    todoStore.deleteTodo(todo)
                }
            }
        }
    }
    
    private var addCategoryAlertFields: some View {
        Group {
            TextField(localizer.localizedString(forKey: "category_name"), text: $newCategoryName)
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {
                newCategoryName = ""
            }
            Button(localizer.localizedString(forKey: "add")) {
                if !newCategoryName.isEmpty {
                    let newCategory = BeeFocus_ofc.Category(name: newCategoryName, colorHex: "1E90FF")
                    todoStore.addCategory(newCategory)
                    newCategoryName = ""
                }
            }
        }
    }
    
    private var editCategoryAlertFields: some View {
        Group {
            if let category = editingCategory {
                TextField(localizer.localizedString(forKey: "new_name"), text: Binding(
                    get: { newCategoryName.isEmpty ? category.name : newCategoryName },
                    set: { newCategoryName = $0 }
                ))
                Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {
                    newCategoryName = ""
                    editingCategory = nil
                }
                Button(localizer.localizedString(forKey: "save_button")) {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalName = trimmed.isEmpty ? category.name : trimmed
                    if !finalName.isEmpty {
                        todoStore.renameCategory(from: category, to: finalName)
                    }
                    newCategoryName = ""
                    editingCategory = nil
                }
            }
        }
    }
    
    private var deleteCategoryAlertButtons: some View {
        Group {
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) {
                categoryToDelete = nil
            }
            Button(localizer.localizedString(forKey: "delete"), role: .destructive) {
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

