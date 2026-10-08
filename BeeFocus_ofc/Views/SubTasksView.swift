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
    @State private var pendingDeleteIndex: Int? = nil
    @State private var showDeleteAlert = false
    @State private var appeared = false
    @State private var showAISubtasks = false
    @FocusState private var inputFocused: Bool

    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private var completedCount: Int { subTasks.filter(\.isCompleted).count }
    private var progress: Double { subTasks.isEmpty ? 0 : Double(completedCount) / Double(subTasks.count) }

    init(todo: TodoItem) {
        self.todo = todo
        _subTasks = State(initialValue: todo.subTasks)
    }

    var body: some View {
        NavigationStack {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    progressCard
                    subTasksList
                    addSubTaskCard

                    // Apple Intelligence zerlegt die Aufgabe in Schritte.
                    if AIFeature.isReady {
                        Button {
                            showAISubtasks = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text(localizer.localizedString(forKey: "ai_subtasks_button"))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(AIPalette.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "subtasks_title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAISubtasks) {
            if #available(iOS 26.0, *) {
                AISubtaskSheet(todoTitle: todo.title, todoDetails: todo.description) { steps in
                    let existing = Set(subTasks.map(\.title))
                    for step in steps where !existing.contains(step) {
                        subTasks.append(SubTask(title: step))
                    }
                    saveChanges()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(localizer.localizedString(forKey: "done_button")) {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(themeC1)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
        }
        .alert("Delete subtask?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let idx = pendingDeleteIndex {
                    subTasks.remove(at: idx)
                    saveChanges()
                    pendingDeleteIndex = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteIndex = nil }
        } message: {
            Text("Are you sure you want to delete this subtask?")
        }
        } // NavigationStack
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todo.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.92) : .primary)
                        .lineLimit(2)
                    Text("\(completedCount) / \(subTasks.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeC1)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(themeC1.opacity(0.18), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: progress)
                    Image(systemName: progress >= 1.0 ? "checkmark" : "checklist")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(themeC1)
                }
                .frame(width: 52, height: 52)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeC1.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(18)
        .themeGlass(cornerRadius: 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: appeared)
    }

    // MARK: - Subtasks List

    private var subTasksList: some View {
        VStack(spacing: 0) {
            ForEach(subTasks.indices, id: \.self) { i in
                subTaskRow(index: i)
                if i < subTasks.count - 1 {
                    Divider()
                        .padding(.horizontal, 14)
                        .opacity(0.18)
                }
            }
        }
        .themeGlass(cornerRadius: 18)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.10), value: appeared)
    }

    @ViewBuilder
    private func subTaskRow(index: Int) -> some View {
        let delay = 0.12 + Double(index) * 0.05
        let task = subTasks[index]

        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    subTasks[index].isCompleted.toggle()
                    saveChanges()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(task.isCompleted ? themeC1.opacity(0.15) : .clear)
                        .frame(width: 30, height: 30)
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(task.isCompleted ? themeC1 : .secondary.opacity(0.55))
                        .scaleEffect(task.isCompleted ? 1.08 : 1.0)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.65), value: task.isCompleted)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(task.isCompleted
                    ? AnyShapeStyle(.secondary)
                    : AnyShapeStyle(isDark ? Color.white.opacity(0.88) : Color.primary))
                .strikethrough(task.isCompleted, color: .secondary)
                .animation(.easeInOut(duration: 0.2), value: task.isCompleted)

            Spacer()

            Button {
                pendingDeleteIndex = index
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red.opacity(0.65))
                    .frame(width: 28, height: 28)
                    .background(.red.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -16)
        .animation(.spring(response: 0.48, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    // MARK: - Add Subtask Card

    private var addSubTaskCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            TextField(localizer.localizedString(forKey: "new_subtask_placeholder"), text: $newSubTaskTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.88) : .primary)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit { addSubTask() }

            if !newSubTaskTitle.isEmpty {
                Button(action: addSubTask) {
                    Text(localizer.localizedString(forKey: "done_button"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .themeGlass(cornerRadius: 18)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: newSubTaskTitle.isEmpty)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.18), value: appeared)
    }

    // MARK: - Actions

    private func addSubTask() {
        guard !newSubTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let newSubTask = SubTask(title: newSubTaskTitle.trimmingCharacters(in: .whitespaces))
            subTasks.append(newSubTask)
            newSubTaskTitle = ""
            saveChanges()
        }
    }

    private func saveChanges() {
        var updatedTodo = todo
        updatedTodo.subTasks = subTasks
        todoStore.updateTodo(updatedTodo)
    }
}
