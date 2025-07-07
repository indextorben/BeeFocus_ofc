//
//  SheetModifiers.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Modifiers
struct SheetModifiers: ViewModifier {
    @Binding var showingAddTodo: Bool
    @Binding var editingTodo: TodoItem?
    var todoStore: TodoStore
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddTodo) {
                NavigationView {
                    AddTodoView()
                        .environmentObject(todoStore)
                }
            }
            .sheet(item: $editingTodo) { todo in
                NavigationView {
                    EditTodoView(todo: todo)
                        .environmentObject(todoStore)
                }
            }
    }
}
