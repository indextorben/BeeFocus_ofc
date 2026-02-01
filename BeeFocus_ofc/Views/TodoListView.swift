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
import UniformTypeIdentifiers

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
    @AppStorage("showPastTasksGlobal") private var showPastTasksStorage = true
    private var showPastTasks: Bool {
        get { showPastTasksStorage }
        set { showPastTasksStorage = newValue }
    }
    
    @State private var isSelecting = false
    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var showMailUnavailableAlert = false
    @State private var mailUnavailableMessage = ""
    
    // New states for delete snackbar
    @State private var showDeleteSnackbar = false
    @State private var lastDeletedTitle: String = ""
    
    //Fileimporter
    @State private var showingActionSheet = false
    @State private var showingFileImporter = false
    @State private var showingDeleteCompletedByDateSheet = false
    
    @State private var showingConfirmTrashCompleted = false
    @State private var presetRange: Int = 0 // 0: Alle, 1: Letzte 7 Tage, 2: Letzte 30 Tage, 3: Benutzerdefiniert
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var isResortSuspended = false
    
    @ObservedObject private var localizer = LocalizationManager.shared
    @StateObject private var mailShare = MailShareService()
    
    @State private var draggingCategoryID: UUID? = nil
    @State private var dropTargetIndex: Int? = nil
    
    let languages = ["Deutsch", "Englisch"]
    
    private func readLocalTodosFallback() -> [TodoItem] {
        let key = "todos"
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }
    
    private var isUsingLocalFallback: Bool {
        todoStore.todos.isEmpty && !readLocalTodosFallback().isEmpty
    }
    
    var body: some View {
        NavigationStack {
            mainContentView
                .toolbar { toolbarContent }
                .alert(localizer.localizedString(forKey: "Bestätigen"), isPresented: $showingConfirmTrashCompleted) {
                    Button(role: .destructive) {
                        let completed = todoStore.todos.filter { $0.isCompleted }
                        for t in completed { todoStore.deleteTodo(t) }
                    } label: {
                        Text(localizer.localizedString(forKey: "In Papierkorb verschieben"))
                    }
                    Button(role: .cancel) { } label: {
                        Text(localizer.localizedString(forKey: "Abbrechen"))
                    }
                } message: {
                    Text(localizer.localizedString(forKey: "Möchten Sie wirklich alle erledigten Aufgaben in den Papierkorb verschieben?"))
                }
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
                .sheet(isPresented: $showingCategoryEdit) {
                    CategoryEditView()
                        .environmentObject(todoStore)
                }
                .alert(localizer.localizedString(forKey: "Löschen"), isPresented: $showingDeleteAlert, presenting: todoToDelete) { todo in
                    Button(role: .destructive) {
                        todoStore.deleteTodo(todo)
                        lastDeletedTitle = todo.title
                        withAnimation { showDeleteSnackbar = true }
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
                .onChange(of: showDeleteSnackbar) { newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation { showDeleteSnackbar = false }
                        }
                    }
                }
        }
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
    }
    
    // MARK: - Computed Properties
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    enum SortOption: CaseIterable, Hashable {
        case dueDateAsc, dueDateDesc, titleAsc, titleDesc, createdDesc, categoryAsc, categoryDesc, priorityHighToLow, priorityLowToHigh

        var localizationKey: String {
            switch self {
            case .dueDateAsc: return "sort_due_asc"
            case .dueDateDesc: return "sort_due_desc"
            case .titleAsc: return "sort_title_asc"
            case .titleDesc: return "sort_title_desc"
            case .createdDesc: return "sort_created_desc"
            case .categoryAsc: return "sort_category_asc"
            case .categoryDesc: return "sort_category_desc"
            case .priorityHighToLow: return "sort_priority_high_to_low"
            case .priorityLowToHigh: return "sort_priority_low_to_high"
            }
        }

        var displayName: LocalizedStringKey {
            LocalizedStringKey(localizationKey)
        }
    }
    
    var sortedTodos: [TodoItem] {
        if isResortSuspended {
            // Return current filtered order without resorting to avoid janky moves during animations
            return filteredTodos
        }
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
                    return a.createdAt > b.createdAt
                case .categoryAsc:
                    return (a.category?.name ?? "").localizedCaseInsensitiveCompare(b.category?.name ?? "") == .orderedAscending
                case .categoryDesc:
                    return (a.category?.name ?? "").localizedCaseInsensitiveCompare(b.category?.name ?? "") == .orderedDescending
                case .priorityHighToLow:
                    return priorityRank(for: a) < priorityRank(for: b)
                case .priorityLowToHigh:
                    return priorityRank(for: a) > priorityRank(for: b)
                }
            }
        }
        
        return sort(favorites) + sort(normal)
    }
    
    var filteredTodos: [TodoItem] {
        let baseTodos = todoStore.todos.isEmpty ? readLocalTodosFallback() : todoStore.todos
        return baseTodos.filter { todo in
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

            // Default: hide only completed; keep overdue but not completed visible
            let isNotCompleted = !todo.isCompleted
            return matchesSearch && matchesCategory && isNotCompleted
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
            
            if false {
                // Banner deaktiviert, um Verwirrung zu vermeiden
            }

            // Bottom toggle button to show/hide past tasks
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { toggleShowPastTasks() }) {
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
            
            // Delete snackbar
            VStack {
                Spacer()
                if showDeleteSnackbar {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                        Text("Aufgabe gelöscht – Rückgängig")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            withAnimation { showDeleteSnackbar = false }
                            isResortSuspended = true
                            todoStore.undo()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                isResortSuspended = false
                            }
                        }) {
                            Text("Rückgängig")
                                .font(.subheadline).bold()
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showDeleteSnackbar)
        }
    }
    
    // MARK: - Toolbar & Overlay Helpers
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Navigation links
        ToolbarItemGroup(placement: .navigationBarLeading) {
            HStack(spacing: 1) {
                Button { showingSettings.toggle() } label: { Image(systemName: "gearshape") }

                Menu {
                    // Standard
                    Button(localizer.localizedString(forKey: "Standard wiederherstellen")) { sortOption = .dueDateAsc }

                    // Fälligkeit
                    Section(header: Text(localizer.localizedString(forKey: "Fälligkeit"))) {
                        Button(action: { sortOption = .dueDateAsc }) {
                            Label(String(localizer.localizedString(forKey: "sort_due_asc")), systemImage: sortOption == .dueDateAsc ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .dueDateDesc }) {
                            Label(String(localizer.localizedString(forKey: "sort_due_desc")), systemImage: sortOption == .dueDateDesc ? "checkmark" : "")
                        }
                    }

                    // Titel
                    Section(header: Text(localizer.localizedString(forKey: "Titel"))) {
                        Button(action: { sortOption = .titleAsc }) {
                            Label(String(localizer.localizedString(forKey: "sort_title_asc")), systemImage: sortOption == .titleAsc ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .titleDesc }) {
                            Label(String(localizer.localizedString(forKey: "sort_title_desc")), systemImage: sortOption == .titleDesc ? "checkmark" : "")
                        }
                    }

                    // Kategorie
                    Section(header: Text(localizer.localizedString(forKey: "Kategorie"))) {
                        Button(action: { sortOption = .categoryAsc }) {
                            Label(String(localizer.localizedString(forKey: "sort_category_asc")), systemImage: sortOption == .categoryAsc ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .categoryDesc }) {
                            Label(String(localizer.localizedString(forKey: "sort_category_desc")), systemImage: sortOption == .categoryDesc ? "checkmark" : "")
                        }
                    }

                    // Priorität
                    Section(header: Text(localizer.localizedString(forKey: "Priorität"))) {
                        Button(action: { sortOption = .priorityHighToLow }) {
                            Label(String(localizer.localizedString(forKey: "sort_priority_high_to_low")), systemImage: sortOption == .priorityHighToLow ? "checkmark" : "")
                        }
                        Button(action: { sortOption = .priorityLowToHigh }) {
                            Label(String(localizer.localizedString(forKey: "sort_priority_low_to_high")), systemImage: sortOption == .priorityLowToHigh ? "checkmark" : "")
                        }
                    }

                    // Erstellung
                    Section(header: Text(localizer.localizedString(forKey: "Erstellung"))) {
                        Button(action: { sortOption = .createdDesc }) {
                            Label(String(localizer.localizedString(forKey: "sort_created_desc")), systemImage: sortOption == .createdDesc ? "checkmark" : "")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
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
                
                Button(action: {
                    isResortSuspended = true
                    todoStore.undo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        isResortSuspended = false
                    }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(todoStore.canUndo ? .blue : .gray)
                }
                .disabled(!todoStore.canUndo)

                Button(action: {
                    isResortSuspended = true
                    todoStore.redo()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        isResortSuspended = false
                    }
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(todoStore.canRedo ? .blue : .gray)
                }
                .disabled(!todoStore.canRedo)
                
                Menu {
                    Button {
                        showingDeleteCompletedByDateSheet = true
                    } label: {
                        Label(localizer.localizedString(forKey: "Abgeschlossene nach Zeitraum…"), systemImage: "calendar")
                    }
                    Button(role: .destructive) {
                        showingConfirmTrashCompleted = true
                    } label: {
                        Label(localizer.localizedString(forKey: "Abgeschlossene in Papierkorb"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(
                            ZStack {
                                BlurView(style: .systemUltraThinMaterial)
                                    .clipShape(Circle())
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.35), Color.purple.opacity(0.35)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blur(radius: 2)
                                    .opacity(0.35)
                            }
                        )
                        .overlay(
                            Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
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
                .sheet(isPresented: $showingDeleteCompletedByDateSheet) {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(localizer.localizedString(forKey: "Abgeschlossene nach Zeitraum löschen"))
                                .font(.headline)

                            Picker(localizer.localizedString(forKey: "Zeitraum"), selection: $presetRange) {
                                Text(localizer.localizedString(forKey: "Alle")).tag(0)
                                Text(localizer.localizedString(forKey: "Letzte 7 Tage")).tag(1)
                                Text(localizer.localizedString(forKey: "Letzte 30 Tage")).tag(2)
                                Text(localizer.localizedString(forKey: "Benutzerdefiniert")).tag(3)
                            }
                            .pickerStyle(.segmented)

                            if presetRange == 3 {
                                VStack(alignment: .leading, spacing: 8) {
                                    DatePicker(localizer.localizedString(forKey: "Von"), selection: $customStartDate, displayedComponents: [.date])
                                    DatePicker(localizer.localizedString(forKey: "Bis"), selection: $customEndDate, in: customStartDate...Date(), displayedComponents: [.date])
                                }
                            }

                            // Preview count
                            let dateBounds: (Date?, Date?) = {
                                switch presetRange {
                                case 0: return (nil, nil)
                                case 1: return (Calendar.current.date(byAdding: .day, value: -7, to: Date()), Date())
                                case 2: return (Calendar.current.date(byAdding: .day, value: -30, to: Date()), Date())
                                default: return (customStartDate, customEndDate)
                                }
                            }()
                            let toDelete = todoStore.todos.filter { todo in
                                guard todo.isCompleted else { return false }
                                if let (startOpt, endOpt) = Optional(dateBounds) {
                                    if let start = startOpt, let end = endOpt, let completedAt = todo.completedAt {
                                        return completedAt >= Calendar.current.startOfDay(for: start) && completedAt <= Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: end)!
                                    } else {
                                        // "Alle" case
                                        return true
                                    }
                                }
                                return false
                            }

                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                Text("\(toDelete.count) " + localizer.localizedString(forKey: "abgeschlossene Aufgaben gefunden"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)

                            Spacer()

                            HStack {
                                Button {
                                    showingDeleteCompletedByDateSheet = false
                                } label: {
                                    Text(localizer.localizedString(forKey: "Abbrechen"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)

                                Button(role: .destructive) {
                                    for t in toDelete { todoStore.deleteTodo(t) }
                                    showingDeleteCompletedByDateSheet = false
                                } label: {
                                    Text(localizer.localizedString(forKey: "Löschen"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(toDelete.isEmpty)
                            }
                        }
                        .padding()
                        .navigationTitle(LocalizedStringKey(localizer.localizedString(forKey: "Bereinigen")))
                        .navigationBarTitleDisplayMode(.inline)
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
                    
                    ForEach(Array(todoStore.categories.enumerated()), id: \.element) { index, category in
                        categoryButton(for: category)
                            .overlay(alignment: .leading) {
                                // Insertion indicator before this item
                                if let target = dropTargetIndex, target == index {
                                    InsertionIndicator()
                                        .frame(height: 28)
                                        .offset(x: -6)
                                        .transition(.opacity)
                                }
                            }
                            .draggable(category.id.uuidString)
                            .onDrag {
                                draggingCategoryID = category.id
                                return NSItemProvider(object: category.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text.identifier], isTargeted: Binding(
                                get: { dropTargetIndex == index },
                                set: { hovering in
                                    if hovering {
                                        dropTargetIndex = index
                                    } else if dropTargetIndex == index {
                                        dropTargetIndex = nil
                                    }
                                }
                            )) { providers in
                                if let provider = providers.first {
                                    _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                                        if let nsString = object as? NSString {
                                            let idString = nsString as String
                                            if let uuid = UUID(uuidString: idString), let fromIndex = todoStore.categories.firstIndex(where: { $0.id == uuid }), fromIndex != index {
                                                DispatchQueue.main.async {
                                                    let source = IndexSet(integer: fromIndex)
                                                    let destination = index > fromIndex ? index + 1 : index
                                                    todoStore.moveCategory(from: source, to: destination)
                                                    dropTargetIndex = nil
                                                }
                                            }
                                        }
                                    }
                                    return true
                                }
                                dropTargetIndex = nil
                                return false
                            }
                    }
                    
                    // End drop target spacer with preview indicator
                    ZStack(alignment: .trailing) {
                        Color.clear.frame(width: 1, height: 1)
                        if let target = dropTargetIndex, target == todoStore.categories.endIndex {
                            InsertionIndicator()
                                .frame(height: 28)
                                .offset(x: 6)
                                .transition(.opacity)
                        }
                    }
                    .onDrop(of: [UTType.text.identifier], isTargeted: Binding(
                        get: { dropTargetIndex == todoStore.categories.endIndex },
                        set: { hovering in
                            dropTargetIndex = hovering ? todoStore.categories.endIndex : nil
                        }
                    )) { providers in
                        if let provider = providers.first {
                            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                                if let nsString = object as? NSString {
                                    let idString = nsString as String
                                    if let uuid = UUID(uuidString: idString), let fromIndex = todoStore.categories.firstIndex(where: { $0.id == uuid }) {
                                        DispatchQueue.main.async {
                                            let source = IndexSet(integer: fromIndex)
                                            let destination = todoStore.categories.endIndex
                                            todoStore.moveCategory(from: source, to: destination)
                                            dropTargetIndex = nil
                                        }
                                    }
                                }
                            }
                            return true
                        }
                        dropTargetIndex = nil
                        return false
                    }
                    
                    Button(action: {
                        showingCategoryEdit = true
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
                showingCategoryEdit = true
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
                                isResortSuspended = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    todoStore.toggleTodo(todo)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                    isResortSuspended = false
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
                                // Replace direct removal with delete + alert flow
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
                                isResortSuspended = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    todoStore.toggleTodo(todo)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                                    isResortSuspended = false
                                }
                            } label: {
                                Label(localizer.localizedString(forKey: "Erledigt"), systemImage: "checkmark")
                            }
                            .tint(.green)
                            
                            Button(role: .destructive) {
                                categoryToDelete = nil
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
                    .animation(.easeInOut(duration: 0.2), value: todo.isCompleted)
                }
            }
            .padding()
            .padding(.bottom, 80)
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
    
    private func toggleShowPastTasks() {
        withAnimation(.easeInOut) {
            showPastTasksStorage.toggle()
        }
    }
}

// MARK: - InsertionIndicator
struct InsertionIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 2)
                .cornerRadius(1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 2)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.15), value: UUID())
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

