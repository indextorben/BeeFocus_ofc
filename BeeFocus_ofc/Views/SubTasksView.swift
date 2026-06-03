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
    @State private var pendingDeleteIndexSet: IndexSet? = nil
    @State private var showDeleteAlert = false
    @State private var appeared = false

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
                    ForEach(subTasks.indices, id: \.self) { i in
                        subTaskRow(index: i)
                    }
                    .onDelete { indexSet in
                        pendingDeleteIndexSet = indexSet
                        showDeleteAlert = true
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
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            }
            .alert("Teilaufgabe löschen?", isPresented: $showDeleteAlert) {
                Button("Löschen", role: .destructive) {
                    if let indexSet = pendingDeleteIndexSet {
                        subTasks.remove(atOffsets: indexSet)
                        saveChanges()
                        pendingDeleteIndexSet = nil
                    }
                }
                Button("Abbrechen", role: .cancel) { pendingDeleteIndexSet = nil }
            } message: {
                Text("Möchtest du diese Teilaufgabe wirklich löschen?")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(forKey: "done_button")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func subTaskRow(index: Int) -> some View {
        let delay = 0.05 + Double(index) * 0.06
        HStack {
            Button {
                subTasks[index].isCompleted.toggle()
                saveChanges()
            } label: {
                Image(systemName: subTasks[index].isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(subTasks[index].isCompleted ? .green : .gray)
            }
            Text(subTasks[index].title)
                .strikethrough(subTasks[index].isCompleted)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -18)
        .animation(.spring(response: 0.48, dampingFraction: 0.78).delay(delay), value: appeared)
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
