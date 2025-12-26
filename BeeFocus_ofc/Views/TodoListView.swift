/*
 ToDoListView.swift
 BeeFocus_ofc
 Created by Torben Lehneke on 16.06.25.
 */

import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import MessageUI

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
    @State private var showingSortOptions = false
    @State private var sortOption: SortOption = .dueDateAsc
    @State private var showPastTasks = false
    
    @State private var isSelecting = false
    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var showMailUnavailableAlert = false
    @State private var mailUnavailableMessage = ""
    
    //Fileimporter
    @State private var showingActionSheet = false
    @State private var showingFileImporter = false
    
    @ObservedObject private var localizer = LocalizationManager.shared
    @StateObject private var mailShare = MailShareService()

    let languages = ["Deutsch", "Englisch"]
    
    var body: some View {
        NavigationStack {
            mainContentView
                .toolbar { toolbarContent }
                .overlay(alignment: .bottom) { successToastOverlay }
                .navigationTitle(LocalizedStringKey(localizer.localizedString(forKey: "Aufgaben")))
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text(LocalizedStringKey(localizer.localizedString(forKey: "Aufgaben suchen"))))
                .sheet(isPresented: $showingAddTodo) {
                    // Replace `AddTodoView` with the actual add-task view used in your project if the name differs
                    AddTodoView()
                }
                .sheet(isPresented: $showingSettings) {
                    EinstellungenView()
                }
                .sheet(item: $editingTodo) { item in
                    EditTodoView(todo: item)
                }
                .sheet(item: $mailShare.exportData) { data in
                    ShareActivityView(activityItems: [data.image])
                }
                .sheet(item: $mailShare.mailComposerData) { data in
                    MailComposerWrapperView(subject: data.subject, body: data.body, recipients: data.recipients)
                }
                .alert(localizer.localizedString(forKey: "Löschen"), isPresented: $showingDeleteAlert, presenting: todoToDelete) { todo in
                    Button(role: .destructive) {
                        if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                            todoStore.todos.remove(at: idx)
                        }
                    } label: {
                        Text(localizer.localizedString(forKey: "Löschen"))
                    }
                    Button(role: .cancel) {
                        todoToDelete = nil
                    } label: {
                        Text(localizer.localizedString(forKey: "Abbrechen"))
                    }
                } message: { todo in
                    Text(localizer.localizedString(forKey: "Möchten Sie diese Aufgabe wirklich löschen?"))
                }
                .alert(localizer.localizedString(forKey: "E-Mail nicht verfügbar"), isPresented: $showMailUnavailableAlert) {
                    Button(localizer.localizedString(forKey: "OK"), role: .cancel) { }
                } message: {
                    Text(mailUnavailableMessage)
                }
        }
    }
    
    // MARK: - Computed Properties
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    enum SortOption: CaseIterable, Hashable {
        case dueDateAsc, dueDateDesc, titleAsc, titleDesc, createdDesc, categoryAsc, categoryDesc

        var localizationKey: String {
            switch self {
            case .dueDateAsc: return "sort_due_asc"
            case .dueDateDesc: return "sort_due_desc"
            case .titleAsc: return "sort_title_asc"
            case .titleDesc: return "sort_title_desc"
            case .createdDesc: return "sort_created_desc"
            case .categoryAsc: return "sort_category_asc"
            case .categoryDesc: return "sort_category_desc"
            }
        }

        var displayName: LocalizedStringKey {
            LocalizedStringKey(localizationKey)
        }
    }
    
    var sortedTodos: [TodoItem] {
        let todos = filteredTodos
        let favorites = todos.filter { $0.isFavorite }
        let normal = todos.filter { !$0.isFavorite }
        
        func sort(_ array: [TodoItem]) -> [TodoItem] {
            return array.sorted { a, b in
                let pa = priorityRank(for: a)
                let pb = priorityRank(for: b)
                if pa != pb {
                    return pa < pb // High (0) vor Medium (1) vor Low (2)
                }
                switch sortOption {
                case .dueDateAsc:
                    return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
                case .dueDateDesc:
                    return (a.dueDate ?? .distantPast) > (b.dueDate ?? .distantPast)
                case .titleAsc:
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                case .titleDesc:
                    return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
                case .createdDesc:
                    return (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
                case .categoryAsc:
                    return (a.category?.name ?? "").localizedCaseInsensitiveCompare(b.category?.name ?? "") == .orderedAscending
                case .categoryDesc:
                    return (a.category?.name ?? "").localizedCaseInsensitiveCompare(b.category?.name ?? "") == .orderedDescending
                }
            }
        }
        
        return sort(favorites) + sort(normal)
    }
    
    var filteredTodos: [TodoItem] {
        todoStore.todos.filter { todo in
            // Break down into simpler booleans to help the type checker
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let inTitle = todo.title.localizedCaseInsensitiveContains(searchText)
                let inDescription = todo.description.localizedCaseInsensitiveContains(searchText)
                matchesSearch = inTitle || inDescription
            }

            let matchesCategory: Bool
            if let selected = selectedCategory {
                matchesCategory = (todo.category == selected)
            } else {
                matchesCategory = true
            }

            // Show all (including completed or overdue) when toggled
            if showPastTasks {
                return matchesSearch && matchesCategory
            }

            // Default: hide completed and overdue
            let isNotCompleted = !todo.isCompleted
            let notOverdue = (todo.dueDate == nil) || (todo.dueDate! >= Date())
            return matchesSearch && matchesCategory && isNotCompleted && notOverdue
        }
    }
    
    // MARK: - Main View
    private var mainContentView: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 0) {
                categoryBar
                contentView
            }

            // Bottom toggle button to show/hide past tasks
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { withAnimation(.easeInOut) { showPastTasks.toggle() } }) {
                        HStack(spacing: 8) {
                            Image(systemName: showPastTasks ? "clock.arrow.circlepath" : "clock")
                            Text(LocalizedStringKey(localizer.localizedString(forKey: showPastTasks ? "Vergangene ausblenden" : "Vergangene anzeigen")))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            BlurView(style: .systemMaterial)
                                .clipShape(Capsule())
                        )
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .background(Color.clear.contentShape(Capsule()))
                    .padding(.bottom, 16)
                    .allowsHitTesting(true)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Toolbar & Overlay Helpers
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Navigation links
        ToolbarItemGroup(placement: .navigationBarLeading) {
            HStack(spacing: 1) {
                Button { showingSettings.toggle() } label: { Image(systemName: "gearshape") }

                Button { showingSortOptions = true } label: { Image(systemName: "arrow.up.arrow.down") }
                    .confirmationDialog(localizer.localizedString(forKey: "Sortieren nach"), isPresented: $showingSortOptions) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button(option.displayName) { sortOption = option }
                        }
                    }
                
                Button {
                    withAnimation { isSelecting.toggle() }
                    if !isSelecting { selectedTodoIDs.removeAll() }
                } label: {
                    Image(systemName: isSelecting ? "checkmark.circle" : "checkmark.circle.badge.plus")
                }
            }
        }

        // Navigation right
        ToolbarItemGroup(placement: .primaryAction) {
            HStack(spacing: 8) {
                if isSelecting {
                    Button(action: {
                        let selected = sortedTodos.filter { selectedTodoIDs.contains($0.id) }
                        guard !selected.isEmpty else { return }

                        if MFMailComposeViewController.canSendMail() {
                            let formatter = DateFormatter()
                            formatter.dateStyle = .medium
                            formatter.timeStyle = .short
                            let lines = selected.map { todo in
                                let due = todo.dueDate.map { formatter.string(from: $0) } ?? localizer.localizedString(forKey: "Kein Fälligkeitsdatum")
                                return "• \(todo.title) — \(due)\n\(todo.description)"
                            }
                            let body = lines.joined(separator: "\n\n")

                            mailShare.mailComposerData = MailShareService.MailComposerData(
                                subject: LocalizationManager.shared.localizedString(forKey: "Todos Export"),
                                body: body,
                                recipients: nil
                            )
                        } else {
                            mailUnavailableMessage = localizer.localizedString(forKey: "Bitte richten Sie die Mail-App ein, um E-Mails zu senden.")
                            showMailUnavailableAlert = true
                        }
                    }) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(selectedTodoIDs.isEmpty ? .gray : .blue)
                    }
                    .disabled(selectedTodoIDs.isEmpty)
                }
                
                Button(action: { todoStore.undoLastCompleted() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }

                Button(action: { todoStore.redoLastCompleted() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    isPlusPressed.toggle()
                    showingActionSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
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
                                    .blur(radius: 2)
                                    .opacity(0.3)
                            }
                        )
                        .scaleEffect(isPlusPressed ? 1.05 : 1.0)
                        .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 4, y: 3)
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
                .confirmationDialog("Was möchten Sie tun?", isPresented: $showingActionSheet) {
                    Button(localizer.localizedString(forKey: "Neue Aufgabe hinzufügen")) { showingAddTodo = true }
                    Button(localizer.localizedString(forKey: "Aufgabe importieren")) { showingFileImporter = true }
                    Button(localizer.localizedString(forKey: "Abbrechen"), role: .cancel) { }
                }
                .fileImporter(
                    isPresented: $showingFileImporter,
                    allowedContentTypes: [.json],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            TodoImporter.importTodos(from: url, to: todoStore)
                        }
                    case .failure(let error):
                        print("❌ Fehler beim File Import: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private var successToastOverlay: some View {
        Group {
            if showSuccessToast {
                VStack {
                    Spacer()
                    Text(localizer.localizedString(forKey: "Zum Kalender hinzugefügt"))
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
    }
    
    private var categoryBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryButton(
                        title: LocalizedStringKey(localizer.localizedString(forKey: "Alle")),
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
            title: LocalizedStringKey(category.name),
            isSelected: selectedCategory == category,
            color: .blue
        ) {
            selectedCategory = category
        }
        .contextMenu {
            Button {
                editingCategory = category
            } label: {
                Label(localizer.localizedString(forKey: "category_rename"), systemImage: "pencil")
            }

            Button(role: .destructive) {
                categoryToDelete = category
                showingDeleteCategoryAlert = true
            } label: {
                Label(localizer.localizedString(forKey: "Löschen"), systemImage: "trash")
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
            
            Text(localizer.localizedString(forKey: "Keine Aufgaben"))
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(localizer.localizedString(forKey: "Fügen Sie eine neue Aufgabe hinzu"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var todoListView: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(sortedTodos) { todo in
                    let binding = Binding<TodoItem>(
                        get: {
                            todoStore.todos.first(where: { $0.id == todo.id }) ?? todo
                        },
                        set: { updated in
                            if let idx = todoStore.todos.firstIndex(where: { $0.id == updated.id }) {
                                todoStore.todos[idx] = updated
                            }
                        }
                    )
                    
                    HStack(alignment: .top, spacing: 8) {
                        if isSelecting {
                            Button(action: {
                                if selectedTodoIDs.contains(todo.id) {
                                    selectedTodoIDs.remove(todo.id)
                                } else {
                                    selectedTodoIDs.insert(todo.id)
                                }
                            }) {
                                Image(systemName: selectedTodoIDs.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedTodoIDs.contains(todo.id) ? .blue : .secondary)
                                    .font(.title3)
                                    .padding(.top, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        TodoCard(todo: binding) {
                            if !isSelecting {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    todoStore.complete(todo: todo)
                                }
                            } else {
                                // In selection mode, tap on primary action toggles selection instead of completing
                                if selectedTodoIDs.contains(todo.id) {
                                    selectedTodoIDs.remove(todo.id)
                                } else {
                                    selectedTodoIDs.insert(todo.id)
                                }
                            }
                        } onEdit: {
                            if !isSelecting { editingTodo = todo }
                        } onDelete: {
                            if !isSelecting {
                                todoToDelete = todo
                                showingDeleteAlert = true
                            }
                        } onShare: {
                            if !isSelecting {
                                TodoShare.share(todo: todo)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isSelecting {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    todoStore.complete(todo: todo)
                                }
                            } label: {
                                Label(localizer.localizedString(forKey: "Erledigt"), systemImage: "checkmark")
                            }
                            .tint(.green)
                            
                            Button(role: .destructive) {
                                todoToDelete = todo
                                showingDeleteAlert = true
                            } label: {
                                Label(localizer.localizedString(forKey: "Löschen"), systemImage: "trash")
                            }
                            
                            Button {
                                TodoShare.share(todo: todo)
                            } label: {
                                Label(localizer.localizedString(forKey: "Teilen"), systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                    .strikethrough(todo.isCompleted, color: .gray)
                    .opacity(todo.isCompleted ? 0.6 : 1.0)
                }
            }
            .padding()
            .padding(.bottom, 80)
            .animation(.spring(response: 0.35, dampingFraction: 0.85),
                       value: sortedTodos.map(\.id))
        }
    }
    
    // MARK: - Helpers
    
    private func shareText() -> String {
        let selected = sortedTodos.filter { selectedTodoIDs.contains($0.id) }
        guard !selected.isEmpty else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let lines = selected.map { todo in
            let due = todo.dueDate.map { formatter.string(from: $0) } ?? localizer.localizedString(forKey: "Kein Fälligkeitsdatum")
            return "• \(todo.title) — \(due)\n\(todo.description)"
        }
        return lines.joined(separator: "\n\n")
    }
    
    private func priorityRank(for todo: TodoItem) -> Int {
        switch todo.priority {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        default: return 3
        }
    }
}

// MARK: - ActivityView (UIKit Share Sheet Wrapper)
struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - CategoryButton
struct CategoryButton: View {
    let title: LocalizedStringKey
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

