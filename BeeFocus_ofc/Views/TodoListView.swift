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
import EventKit

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
    @AppStorage("showPastTasksGlobal") private var showPastTasksStorage = true
    private var showPastTasks: Bool {
        get { showPastTasksStorage }
        set { showPastTasksStorage = newValue }
    }
    
    @State private var isSelecting = false
    @State private var selectedTodoIDs: Set<UUID> = []
    @State private var showMailUnavailableAlert = false
    @State private var mailUnavailableMessage = ""
    
    // New state for today-only filter from notification
    @State private var showOnlyTodayFromNotification = false
    
    // New states for delete snackbar
    @State private var showDeleteSnackbar = false
    @State private var lastDeletedTitle: String = ""
    @State private var snackbarDismissTask: Task<Void, Never>? = nil
    
    //Fileimporter
    @State private var showingActionSheet = false
    @State private var showingFileImporter = false
    @State private var showingDeleteCompletedByDateSheet = false
    
    @State private var showingConfirmTrashCompleted = false
    @State private var showingDeleteDuplicatesConfirm = false
    @State private var presetRange: Int = 0 // 0: Alle, 1: Letzte 7 Tage, 2: Letzte 30 Tage, 3: Benutzerdefiniert
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var isResortSuspended = false
    
    @ObservedObject private var localizer = LocalizationManager.shared
    @StateObject private var mailShare = MailShareService()
    
    @State private var draggingCategoryID: UUID? = nil
    @State private var dropTargetIndex: Int? = nil

    @State private var showingCalendarImport = false
    @StateObject private var calendarImporter = CalendarImporter()

    @State private var collapsedSections: Set<String> = []

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
                .alert("Duplikate entfernen", isPresented: $showingDeleteDuplicatesConfirm) {
                    Button(role: .destructive) {
                        removeDuplicateTodos()
                    } label: {
                        Text("Entfernen")
                    }
                    Button(role: .cancel) { } label: {
                        Text(localizer.localizedString(forKey: "Abbrechen"))
                    }
                } message: {
                    let count = duplicateTodos.count
                    Text(count > 0 ? "\(count) doppelte Aufgabe(n) gefunden. Möchten Sie diese entfernen?" : "Keine Duplikate gefunden.")
                }
                .overlay(alignment: .bottom) { successToastOverlay }
                .navigationTitle(localizer.localizedString(forKey: "tasks_title"))
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text(localizer.localizedString(forKey: "search_tasks")))
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
                .sheet(isPresented: $showingCalendarImport) {
                    CalendarImportSheet(importer: calendarImporter)
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
                    // Cancel any existing timer
                    snackbarDismissTask?.cancel()
                    
                    if newValue {
                        // Create a new Task that can be cancelled
                        snackbarDismissTask = Task {
                            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds
                            
                            // Check if task wasn't cancelled
                            guard !Task.isCancelled else { return }
                            
                            await MainActor.run {
                                withAnimation {
                                    showDeleteSnackbar = false
                                }
                            }
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .openTodayDueFromNotification)) { _ in
                    // Reset category to all and enable today filter
                    selectedCategory = nil
                    showOnlyTodayFromNotification = true
                }
                .onDisappear {
                    // Cancel the snackbar timer when view disappears
                    snackbarDismissTask?.cancel()
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
                let aHasDue = a.dueDate != nil
                let bHasDue = b.dueDate != nil
                if aHasDue != bHasDue {
                    return aHasDue && !bHasDue // Items with dueDate first
                }
                if aHasDue && bHasDue {
                    // Both have due dates: earliest first
                    return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
                }
                // Neither has due: sort by priority High > Medium > Low
                let pa = priorityRank(for: a)
                let pb = priorityRank(for: b)
                if pa != pb { return pa < pb }
                // Tie-breaker: newer createdAt first
                return a.createdAt > b.createdAt
            }
        }
        
        return sort(favorites) + sort(normal)
    }
    
    var filteredTodos: [TodoItem] {
        let baseTodos = todoStore.todos.isEmpty ? readLocalTodosFallback() : todoStore.todos

        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? Date()

        return baseTodos.filter { todo in
            // Search
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let inTitle = todo.title.localizedCaseInsensitiveContains(searchText)
                let inDescription = todo.description.localizedCaseInsensitiveContains(searchText)
                matchesSearch = inTitle || inDescription
            }

            // Category
            let matchesCategory: Bool = {
                if let selected = selectedCategory {
                    return (todo.category == selected)
                } else {
                    return true
                }
            }()

            // Today filter (if triggered by notification)
            let matchesToday: Bool = {
                guard showOnlyTodayFromNotification else { return true }
                guard let due = todo.dueDate else { return false }
                return due <= todayEnd // heute fällig oder überfällig
            }()

            // Show all when toggled
            if showPastTasks {
                return matchesSearch && matchesCategory && matchesToday
            }

            // Default: hide completed
            let isNotCompleted = !todo.isCompleted
            return matchesSearch && matchesCategory && matchesToday && isNotCompleted
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
                            // Cancel the auto-dismiss timer
                            snackbarDismissTask?.cancel()
                            
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showDeleteSnackbar = false
                                todoStore.undo()
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
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        todoStore.undo()
                    }
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(todoStore.canUndo ? .blue : .gray)
                }
                .disabled(!todoStore.canUndo)

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        todoStore.redo()
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
                        Label(localizer.localizedString(forKey: "Nach Zeitraum löschen"), systemImage: "calendar")
                    }
                    Button(role: .destructive) {
                        showingConfirmTrashCompleted = true
                    } label: {
                        Label(localizer.localizedString(forKey: "Abgeschlossene in Papierkorb"), systemImage: "trash")
                    }
                    Button(role: .destructive) {
                        showingDeleteDuplicatesConfirm = true
                    } label: {
                        Label("Duplikate entfernen", systemImage: "doc.on.doc")
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
                    Button("Aus Kalender importieren") { showingCalendarImport = true }
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
                        title: LocalizedStringKey(localizer.localizedString(forKey: "all")),
                        isSelected: selectedCategory == nil,
                        color: .blue
                    ) {
                        selectedCategory = nil
                        showOnlyTodayFromNotification = false
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
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private func categoryButton(for category: Category) -> some View {
        CategoryButton(
            title: LocalizedStringKey(category.name),
            isSelected: selectedCategory == category,
            color: category.color
        ) {
            selectedCategory = category
            showOnlyTodayFromNotification = false
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
            } else if selectedCategory == nil && searchText.isEmpty {
                folderListView
            } else {
                todoListView
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Folder Group Model

    private struct TodoFolderGroup: Identifiable {
        let id: String
        let title: String
        let icon: String
        let color: Color
        var directTodos: [TodoItem]
        var subGroups: [TodoFolderGroup]

        init(id: String, title: String, icon: String, color: Color,
             todos: [TodoItem] = [], subGroups: [TodoFolderGroup] = []) {
            self.id = id; self.title = title; self.icon = icon; self.color = color
            self.directTodos = todos; self.subGroups = subGroups
        }

        var allTodos: [TodoItem] { directTodos + subGroups.flatMap(\.directTodos) }
        var totalCount: Int { allTodos.count }
        var completedCount: Int { allTodos.filter { $0.isCompleted }.count }
    }

    private var todoGroups: [TodoFolderGroup] {
        let todos = sortedTodos
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let endOfToday   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: startOfToday) ?? now
        let endOfWeek    = cal.date(byAdding: .day, value: 6, to: endOfToday) ?? now
        let endOfMonth   = cal.date(byAdding: .day, value: 29, to: endOfToday) ?? now
        let eng          = localizer.selectedLanguage == "Englisch"

        let noDue     = todos.filter { $0.dueDate == nil }
        let overdue   = todos.filter { guard let d = $0.dueDate else { return false }; return d < startOfToday && !$0.isCompleted }
        let todayDue  = todos.filter { guard let d = $0.dueDate else { return false }; return d >= startOfToday && d <= endOfToday && !$0.isCompleted }
        let thisWeek  = todos.filter { guard let d = $0.dueDate else { return false }; return d > endOfToday && d <= endOfWeek }
        let thisMonth = todos.filter { guard let d = $0.dueDate else { return false }; return d > endOfWeek && d <= endOfMonth }
        let later     = todos.filter { guard let d = $0.dueDate else { return false }; return d > endOfMonth }

        var groups: [TodoFolderGroup] = []

        // 1. Allgemein – immer ganz oben (keine Fälligkeit)
        if !noDue.isEmpty {
            groups.append(TodoFolderGroup(
                id: "__general__",
                title: eng ? "General" : "Allgemein",
                icon: "tray.fill",
                color: Color(.systemGray),
                todos: noDue
            ))
        }

        // 2. Dringend – Überfällig + Heute als Unterordner (wenn beides vorhanden)
        if !overdue.isEmpty && !todayDue.isEmpty {
            let overdueGroup = TodoFolderGroup(id: "__overdue__",
                title: eng ? "Overdue" : "Überfällig",
                icon: "exclamationmark.circle.fill", color: .red, todos: overdue)
            let todayGroup = TodoFolderGroup(id: "__today__",
                title: eng ? "Today" : "Heute",
                icon: "sun.max.fill", color: .orange, todos: todayDue)
            groups.append(TodoFolderGroup(id: "__urgent__",
                title: eng ? "Urgent" : "Dringend",
                icon: "flame.fill", color: .red,
                subGroups: [overdueGroup, todayGroup]))
        } else if !overdue.isEmpty {
            groups.append(TodoFolderGroup(id: "__overdue__",
                title: eng ? "Overdue" : "Überfällig",
                icon: "exclamationmark.circle.fill", color: .red, todos: overdue))
        } else if !todayDue.isEmpty {
            groups.append(TodoFolderGroup(id: "__today__",
                title: eng ? "Today" : "Heute",
                icon: "sun.max.fill", color: .orange, todos: todayDue))
        }

        // 3. Diese Woche
        if !thisWeek.isEmpty {
            groups.append(TodoFolderGroup(id: "__week__",
                title: eng ? "This Week" : "Diese Woche",
                icon: "calendar.badge.clock", color: .blue, todos: thisWeek))
        }

        // 4. Geplant – Dieser Monat + Später als Unterordner (wenn beides vorhanden)
        if !thisMonth.isEmpty && !later.isEmpty {
            let monthGroup = TodoFolderGroup(id: "__month__",
                title: eng ? "This Month" : "Dieser Monat",
                icon: "calendar", color: .purple, todos: thisMonth)
            let laterGroup = TodoFolderGroup(id: "__later__",
                title: eng ? "Later" : "Später",
                icon: "arrow.forward.circle.fill", color: .teal, todos: later)
            groups.append(TodoFolderGroup(id: "__planned__",
                title: eng ? "Planned" : "Geplant",
                icon: "calendar.badge.plus", color: .indigo,
                subGroups: [monthGroup, laterGroup]))
        } else if !thisMonth.isEmpty {
            groups.append(TodoFolderGroup(id: "__month__",
                title: eng ? "This Month" : "Dieser Monat",
                icon: "calendar", color: .purple, todos: thisMonth))
        } else if !later.isEmpty {
            groups.append(TodoFolderGroup(id: "__later__",
                title: eng ? "Later" : "Später",
                icon: "arrow.forward.circle.fill", color: .teal, todos: later))
        }

        return groups
    }

    // MARK: - Folder List View

    private var folderListView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(todoGroups) { group in
                    folderSection(group: group)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 90)
        }
    }

    // Renders todo items list shared between main folders and sub-folders
    @ViewBuilder
    private func todoItemsContent(todos: [TodoItem], color: Color) -> some View {
        VStack(spacing: 10) {
            ForEach(todos) { todo in
                let binding = Binding<TodoItem>(
                    get: { todoStore.todos.first(where: { $0.id == todo.id }) ?? todo },
                    set: { updated in
                        if let idx = todoStore.todos.firstIndex(where: { $0.id == updated.id }) {
                            todoStore.todos[idx] = updated
                        }
                    }
                )
                HStack(alignment: .top, spacing: 8) {
                    if isSelecting {
                        Button(action: {
                            if selectedTodoIDs.contains(todo.id) { selectedTodoIDs.remove(todo.id) }
                            else { selectedTodoIDs.insert(todo.id) }
                        }) {
                            Image(systemName: selectedTodoIDs.contains(todo.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedTodoIDs.contains(todo.id) ? color : .secondary)
                                .font(.title3)
                                .padding(.top, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    TodoCard(todo: binding) {
                        if !isSelecting {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { todoStore.toggleTodo(todo) }
                        } else {
                            if selectedTodoIDs.contains(todo.id) { selectedTodoIDs.remove(todo.id) }
                            else { selectedTodoIDs.insert(todo.id) }
                        }
                    } onEdit: {
                        if !isSelecting { editingTodo = todo }
                    } onDelete: {
                        if !isSelecting { todoToDelete = todo; showingDeleteAlert = true }
                    } onShare: {
                        if !isSelecting { TodoShare.share(todo: todo) }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !isSelecting {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { todoStore.toggleTodo(todo) }
                        } label: { Label(localizer.localizedString(forKey: "Erledigt"), systemImage: "checkmark") }
                        .tint(.green)

                        Button(role: .destructive) {
                            categoryToDelete = nil; todoToDelete = todo; showingDeleteAlert = true
                        } label: { Label(localizer.localizedString(forKey: "Löschen"), systemImage: "trash") }

                        Button { TodoShare.share(todo: todo) } label: {
                            Label(localizer.localizedString(forKey: "Teilen"), systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
                .strikethrough(todo.isCompleted, color: .gray)
                .opacity(todo.isCompleted ? 0.55 : 1.0)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: todo.isCompleted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func folderSection(group: TodoFolderGroup, isSubFolder: Bool = false) -> AnyView {
        let isCollapsed = collapsedSections.contains(group.id)
        let totalCount = group.totalCount
        let completedCount = group.completedCount
        let iconSize: CGFloat = isSubFolder ? 12 : 16
        let circleSize: CGFloat = isSubFolder ? 28 : 36
        let cornerRadius: CGFloat = isSubFolder ? 14 : 22
        let hPad: CGFloat = isSubFolder ? 12 : 16
        let vPad: CGFloat = isSubFolder ? 10 : 14

        return AnyView(VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    if isCollapsed { collapsedSections.remove(group.id) }
                    else { collapsedSections.insert(group.id) }
                }
            } label: {
                HStack(spacing: isSubFolder ? 10 : 13) {
                    ZStack {
                        if !isSubFolder {
                            Circle()
                                .fill(group.color.opacity(0.15))
                                .frame(width: 42, height: 42)
                                .blur(radius: isCollapsed ? 0 : 4)
                        }
                        Circle()
                            .fill(LinearGradient(
                                colors: [group.color, group.color.opacity(0.7)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: circleSize, height: circleSize)
                            .shadow(
                                color: group.color.opacity(isCollapsed ? 0.3 : 0.6),
                                radius: isCollapsed ? 4 : 12, x: 0, y: isCollapsed ? 2 : 5)
                        Image(systemName: group.icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title)
                            .font(.system(size: isSubFolder ? 14 : 16, weight: .semibold))
                            .foregroundStyle(.primary)

                        if !isSubFolder {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.08)).frame(height: 3)
                                    Capsule()
                                        .fill(group.color.gradient)
                                        .frame(
                                            width: totalCount == 0 ? 0 : geo.size.width * CGFloat(completedCount) / CGFloat(totalCount),
                                            height: 3)
                                        .shadow(color: group.color.opacity(0.5), radius: 3)
                                }
                            }
                            .frame(width: 80, height: 3)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        if completedCount > 0 {
                            Text("\(completedCount)/\(totalCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(group.color)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(group.color.opacity(0.12), in: Capsule())
                        } else {
                            Text("\(totalCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(group.color.gradient, in: Capsule())
                                .shadow(color: group.color.opacity(0.4), radius: 4, x: 0, y: 2)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if !isCollapsed {
                Divider().padding(.horizontal, hPad).opacity(0.4)

                if group.subGroups.isEmpty {
                    // Leaf folder: show todos directly
                    todoItemsContent(todos: group.directTodos, color: group.color)
                } else {
                    // Parent folder: show sub-folder cards
                    VStack(spacing: 10) {
                        if !group.directTodos.isEmpty {
                            todoItemsContent(todos: group.directTodos, color: group.color)
                        }
                        ForEach(group.subGroups) { sub in
                            folderSection(group: sub, isSubFolder: true)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background {
            if isSubFolder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            group.color.opacity(isCollapsed ? (isSubFolder ? 0.18 : 0.2) : (isSubFolder ? 0.35 : 0.45)),
                            group.color.opacity(isCollapsed ? 0.04 : 0.12)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isSubFolder ? 0.8 : 1.2)
        )
        .shadow(
            color: isSubFolder ? .clear : group.color.opacity(isCollapsed ? 0.1 : 0.3),
            radius: isCollapsed ? 6 : 18, x: 0, y: isCollapsed ? 3 : 8)
        .shadow(
            color: isSubFolder ? .clear : group.color.opacity(isCollapsed ? 0.0 : 0.15),
            radius: 30, x: 0, y: 4)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isCollapsed)
        )
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
                                // Smooth animation for toggle
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    todoStore.toggleTodo(todo)
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
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    todoStore.toggleTodo(todo)
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
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: todo.isCompleted)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: sortedTodos.map { $0.id })
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

    private var duplicateTodos: [TodoItem] {
        var seen: Set<String> = []
        var dupes: [TodoItem] = []
        for todo in todoStore.todos {
            let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
            if seen.contains(key) {
                dupes.append(todo)
            } else {
                seen.insert(key)
            }
        }
        return dupes
    }

    private func removeDuplicateTodos() {
        for todo in duplicateTodos {
            todoStore.deleteTodo(todo)
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

// MARK: - CalendarImporter
@MainActor
class CalendarImporter: ObservableObject {
    private let eventStore = EKEventStore()

    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var lastImportCount: Int? = nil

    var isAccessGranted: Bool {
        if #available(iOS 17.0, *) {
            return authStatus == .fullAccess
        }
        return authStatus == .authorized
    }

    func requestAccessIfNeeded() async {
        if isAccessGranted {
            loadCalendars()
            return
        }
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await eventStore.requestAccess(to: .event)
            }
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if granted { loadCalendars() }
        } catch {
            print("❌ Kalender-Zugriff Fehler: \(error)")
        }
    }

    private func loadCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
        selectedCalendarIDs = Set(availableCalendars.map { $0.calendarIdentifier })
    }

    func importEvents(from startDate: Date, to endDate: Date, into todoStore: TodoStore) {
        let cals = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !cals.isEmpty else { lastImportCount = 0; return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        let events = eventStore.events(matching: predicate)

        let existing = Set(todoStore.todos.compactMap { $0.calendarEventIdentifier })

        var count = 0
        for event in events {
            guard !existing.contains(event.eventIdentifier) else { continue }
            let todo = TodoItem(
                title: event.title ?? "Kalendereintrag",
                description: event.notes ?? "",
                dueDate: event.startDate,
                calendarEventIdentifier: event.eventIdentifier,
                calendarEnabled: false
            )
            todoStore.addTodo(todo)
            count += 1
        }
        lastImportCount = count
    }
}

// MARK: - CalendarImportSheet
struct CalendarImportSheet: View {
    @ObservedObject var importer: CalendarImporter
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                if !importer.isAccessGranted {
                    Section {
                        Button("Kalender-Zugriff erlauben") {
                            Task { await importer.requestAccessIfNeeded() }
                        }
                    } footer: {
                        Text("BeeFocus benötigt Lesezugriff auf den Kalender, um Einträge zu importieren.")
                    }
                } else {
                    Section("Zeitraum") {
                        DatePicker("Von", selection: $startDate, displayedComponents: [.date])
                        DatePicker("Bis", selection: $endDate, in: startDate..., displayedComponents: [.date])
                    }

                    Section("Kalender auswählen") {
                        ForEach(importer.availableCalendars, id: \.calendarIdentifier) { cal in
                            let calID = cal.calendarIdentifier
                            Toggle(isOn: Binding(
                                get: { importer.selectedCalendarIDs.contains(calID) },
                                set: { on in
                                    if on { importer.selectedCalendarIDs.insert(calID) }
                                    else { importer.selectedCalendarIDs.remove(calID) }
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 12, height: 12)
                                    Text(cal.title)
                                }
                            }
                        }
                    }

                    if let count = importer.lastImportCount {
                        Section {
                            Label(
                                count > 0 ? "\(count) Einträge importiert" : "Keine neuen Einträge gefunden",
                                systemImage: count > 0 ? "checkmark.circle.fill" : "info.circle"
                            )
                            .foregroundColor(count > 0 ? .green : .secondary)
                        }
                    }
                }
            }
            .navigationTitle("Aus Kalender importieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                if importer.isAccessGranted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Importieren") {
                            importer.importEvents(from: startDate, to: endDate, into: todoStore)
                        }
                    }
                }
            }
            .task {
                await importer.requestAccessIfNeeded()
            }
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
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(color.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .strokeBorder(color.opacity(0.4), lineWidth: 1)
                            )
                    } else {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                    }
                }
                .foregroundStyle(isSelected ? color : .primary)
                .shadow(color: isSelected ? color.opacity(0.45) : .clear, radius: 8, x: 0, y: 3)
                .scaleEffect(isSelected ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

