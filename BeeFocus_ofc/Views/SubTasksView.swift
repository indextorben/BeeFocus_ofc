//
//  SubTasksView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - SubTasksView
struct SubTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    let todo: TodoItem
    @State private var subTasks: [SubTask]
    @State private var newSubTaskTitle = ""
    
    @ObservedObject private var localizer = LocalizationManager.shared
            let languages = ["Deutsch", "Englisch"]
    
    init(todo: TodoItem) {
        self.todo = todo
        _subTasks = State(initialValue: todo.subTasks)
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach($subTasks) { $subTask in
                        HStack {
                            Button(action: {
                                subTask.isCompleted.toggle()
                                saveChanges()
                            }) {
                                Image(systemName: subTask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subTask.isCompleted ? .green : .gray)
                            }
                            
                            Text(subTask.title)
                                .strikethrough(subTask.isCompleted)
                        }
                    }
                    .onDelete { indexSet in
                        subTasks.remove(atOffsets: indexSet)
                        saveChanges()
                    }
                }
                
                Section {
                    HStack {
                        TextField("Neue Unteraufgabe", text: $newSubTaskTitle)
                        Button(action: addSubTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Unteraufgaben")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addSubTask() {
        guard !newSubTaskTitle.isEmpty else { return } // ✅
        
        let newSubTask = SubTask(title: newSubTaskTitle)
        subTasks.append(newSubTask)
        newSubTaskTitle = ""
        saveChanges()
    }
    
    private func saveChanges() {
        var updatedTodo = todo
        updatedTodo.subTasks = subTasks
        todoStore.updateTodo(updatedTodo)
    }
}
