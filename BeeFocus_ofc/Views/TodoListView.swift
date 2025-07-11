/*
 ToDoListView.swift
 BeeFocus_ofc
 Created by Torben Lehneke on 16.06.25.
*/

import Foundation
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - BlurView (UIKit Wrapper für SwiftUI)
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct TodoListView: View {
    // MARK: - Properties
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    @State private var searchText = ""
    @State private var selectedCategory: Category? = nil
    @State private var showingAddTodo = false
    @State private var editingTodo: TodoItem? = nil
    @State private var showingDeleteAlert = false
    @State private var todoToDelete: TodoItem? = nil
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var editingCategory: Category? = nil
    @State private var showingDeleteCategoryAlert = false
    @State private var categoryToDelete: Category? = nil
    @State private var showingSettings = false
    @State private var showingCategoryEdit = false
    @State private var isPlusPressed = false
    @State private var showSuccessToast = false

    // MARK: - Computed Properties
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }

    var filteredTodos: [TodoItem] {
        todoStore.todos.filter { todo in
            let matchesSearch = searchText.isEmpty ||
                todo.title.localizedCaseInsensitiveContains(searchText) ||
                todo.description.localizedCaseInsensitiveContains(searchText)

            let matchesCategory = selectedCategory == nil || todo.category == selectedCategory

            let isNotCompleted = !todo.isCompleted

            return matchesSearch && matchesCategory && isNotCompleted
        }
    }

    // MARK: - Main View
    var body: some View {
        mainContentView
            .searchable(text: $searchText, prompt: "Aufgaben suchen...")
            .navigationTitle("Aufgaben")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kategorien") {
                        showingCategoryEdit = true
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 20) {
                        Button(action: {
                            todoStore.undoLastCompleted()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                showingAddTodo = true
                                isPlusPressed.toggle()
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(
                                    ZStack {
                                        BlurView(style: .systemUltraThinMaterialDark)
                                            .clipShape(Circle())
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.red]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .blur(radius: 3)
                                            .opacity(0.3)
                                    }
                                )
                                .scaleEffect(isPlusPressed ? 1.1 : 1.0)
                                .shadow(color: Color.blue.opacity(0.5), radius: 10, x: 0, y: 6)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.white.opacity(0.4), Color.blue.opacity(0.4)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .modifier(SheetModifiers(
                showingAddTodo: $showingAddTodo,
                editingTodo: $editingTodo,
                todoStore: todoStore
            ))
            .modifier(AlertModifiers(
                showingDeleteAlert: $showingDeleteAlert,
                todoToDelete: $todoToDelete,
                todoStore: todoStore,
                showingAddCategory: $showingAddCategory,
                newCategoryName: $newCategoryName,
                editingCategory: $editingCategory,
                showingDeleteCategoryAlert: $showingDeleteCategoryAlert,
                categoryToDelete: $categoryToDelete,
                selectedCategory: $selectedCategory
            ))
            .sheet(isPresented: $showingSettings) {
                EinstellungenView()
            }
            .sheet(isPresented: $showingCategoryEdit) {
                CategoryEditView()
                    .environmentObject(todoStore)
            }
            .overlay(
                Group {
                    if showSuccessToast {
                        VStack {
                            Spacer()
                            Text("Zum Kalender hinzugefügt")
                                .font(.subheadline)
                                .padding()
                                .background(BlurView(style: .systemMaterial))
                                .cornerRadius(12)
                                .padding(.bottom, 50)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .animation(.easeInOut(duration: 0.3), value: showSuccessToast)
                        }
                    }
                }
            )
    }

    private var mainContentView: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                categoryBar
                contentView
            }
        }
    }

    // MARK: - Subviews
    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryButton(
                        title: "Alle",
                        isSelected: selectedCategory == nil,
                        color: .blue
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(todoStore.categories, id: \.self) { category in
                        categoryButton(for: category)
                    }
                    .onMove { source, destination in
                        todoStore.moveCategory(from: source, to: destination)
                    }

                    Button(action: {
                        showingAddCategory = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .shadow(color: .blue.opacity(0.5), radius: 5, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(
                ZStack {
                    BlurView(style: .systemUltraThinMaterial)
                        .background(Color.clear)
                    LinearGradient(
                        colors: [Color.white.opacity(0.05), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private func categoryButton(for category: Category) -> some View {
        CategoryButton(
            title: category.name,
            isSelected: selectedCategory == category,
            color: .blue
        ) {
            selectedCategory = category
        }
        .contextMenu {
            Button(action: {
                editingCategory = category
            }) {
                Label("Umbenennen", systemImage: "pencil")
            }

            Button(role: .destructive, action: {
                categoryToDelete = category
                showingDeleteCategoryAlert = true
            }) {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private var contentView: some View {
        Group {
            if filteredTodos.isEmpty {
                emptyStateView
            } else {
                todoListView
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.5))

            Text("Keine Aufgaben")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Fügen Sie eine neue Aufgabe hinzu")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var todoListView: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(filteredTodos) { todo in
                    TodoCard(todo: todo) {
                        withAnimation {
                            todoStore.complete(todo: todo)
                        }
                    } onEdit: {
                        editingTodo = todo
                    } onDelete: {
                        todoToDelete = todo
                        showingDeleteAlert = true
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            withAnimation {
                                todoStore.complete(todo: todo)
                            }
                        } label: {
                            Label("Erledigt", systemImage: "checkmark")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            todoToDelete = todo
                            showingDeleteAlert = true
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .strikethrough(todo.isCompleted, color: .gray)
                    .opacity(todo.isCompleted ? 0.6 : 1.0)
                }
            }
            .padding()
        }
    }
}

// MARK: - CategoryButton
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.15) : Color.gray.opacity(0.08))
                )
                .foregroundColor(isSelected ? color : .primary)
        }
        .buttonStyle(.plain)
    }
}
