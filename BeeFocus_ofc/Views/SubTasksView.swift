//
//  SubTasksView.swift
//  BeeFocus_ofc
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
    
    init(todo: TodoItem) {
        self.todo = todo
        _subTasks = State(initialValue: todo.subTasks)
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: Subtasks Liste
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
                
                // MARK: Neue Subtask hinzufügen
                Section {
                    HStack {
                        TextField(localizer.localizedString(forKey: "new_subtask_placeholder"), text: $newSubTaskTitle)
                        Button(action: addSubTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "subtasks_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(forKey: "done_button")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addSubTask() {
        guard !newSubTaskTitle.isEmpty else { return }
        
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
