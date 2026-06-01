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
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
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
    @State private var showingTemplates = false
    @AppStorage("todayHighlightID") private var highlightIDStr: String = ""
    @State private var showingDeleteCompletedByDateSheet = false
    
    @State private var showingConfirmTrashCompleted = false
    @State private var showingDeleteDuplicatesConfirm = false
    @State private var presetRange: Int = 0 // 0: Alle, 1: Letzte 7 Tage, 2: Letzte 30 Tage, 3: Benutzerdefiniert
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    @State private var isResortSuspended = false
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0

    // Tool-Sheets
    @State private var showToolWasser = false
    @State private var showToolSchlaf = false
    @State private var showToolNotizen = false
    @State private var showToolBrainDump = false
    @State private var showToolZeiterfassung = false
    @State private var showToolCountdown = false
    @State private var showToolChallenges = false
    @State private var showToolScore = false
    @State private var showToolMotivation = false
    @State private var showToolGewohnheiten = false
    @State private var showToolJournal = false

    @ObservedObject private var localizer = LocalizationManager.shared
    @ObservedObject private var timerManager = TimerManager.shared
    @StateObject private var mailShare = MailShareService()

    @AppStorage("konfettiEnabled") private var konfettiEnabled: Bool = false
    @AppStorage("fokusSperrmodus") private var fokusSperrmodus: Bool = false
    @State private var showKonfetti = false

    private var isLocked: Bool { fokusSperrmodus && timerManager.isRunning }
    
    @State private var draggingCategoryID: UUID? = nil
    @State private var dropTargetIndex: Int? = nil

    @AppStorage("folderOrder") private var folderOrderString = ""
    @State private var isReorderingFolders = false

    @State private var showingCalendarImport = false
    @StateObject private var calendarImporter = CalendarImporter()

    @AppStorage("autoCalendarSyncEnabled") private var autoCalendarSyncEnabled = false
    @AppStorage("autoCalendarSyncRange") private var autoCalendarSyncRange = 1
    @State private var hasAutoSynced = false

    @AppStorage("collapsedSectionsString") private var collapsedSectionsString: String = ""
    private var collapsedSections: Set<String> {
        Set(collapsedSectionsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }
    private func setCollapsed(_ id: String, collapsed: Bool) {
        var s = collapsedSections
        if collapsed { s.insert(id) } else { s.remove(id) }
        collapsedSectionsString = s.joined(separator: ",")
    }
    @State private var showingAddFolderAlert = false
    @State private var newFolderName = ""

    // MARK: - Ordner-Zuweisung
    @State private var isShowingFolderPicker = false
    @State private var pendingFolderTodoID: UUID? = nil

    // Drag-and-Drop Folder Assignment
    @State private var isDragModeActive = false
    @State private var draggedTodoID: UUID? = nil
    @State private var isDragBgTargeted = false

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
                .sheet(isPresented: $showingTemplates) {
                    TaskTemplatesView().environmentObject(todoStore)
                }
                .alert(localizer.localizedString(forKey: "E-Mail nicht verfügbar"), isPresented: $showMailUnavailableAlert) {
                    Button(localizer.localizedString(forKey: "OK"), role: .cancel) { }
                } message: {
                    Text(mailUnavailableMessage)
                }
                .sheet(isPresented: $showToolWasser)        { NavigationStack { WasserTrackerView() } }
                .sheet(isPresented: $showToolSchlaf)        { SchlafTrackerView() }
                .sheet(isPresented: $showToolNotizen)       { NotizView() }
                .sheet(isPresented: $showToolBrainDump)     { BrainDumpView().environmentObject(todoStore) }
                .sheet(isPresented: $showToolZeiterfassung) { ZeiterfassungView() }
                .sheet(isPresented: $showToolCountdown)     { CountdownView() }
                .sheet(isPresented: $showToolChallenges)    { FokusChallengesView().environmentObject(todoStore) }
                .sheet(isPresented: $showToolScore)         { ProduktivitaetsScoreView().environmentObject(todoStore) }
                .sheet(isPresented: $showToolMotivation)    { TagesMotivationView() }
                .sheet(isPresented: $showToolGewohnheiten)  { HabitTrackerView() }
                .sheet(isPresented: $showToolJournal)       { FokusJournalView() }
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
                .onAppear {
                    withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                        wavePhase1 = .pi * 2
                    }
                    withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                        wavePhase2 = .pi * 2
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
        .task {
            guard autoCalendarSyncEnabled, !hasAutoSynced else { return }
            hasAutoSynced = true
            await calendarImporter.requestAccessIfNeeded()
            guard calendarImporter.isAccessGranted else { return }
            let cal = Calendar.current
            let end: Date
            if autoCalendarSyncRange == 12 {
                end = cal.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            } else {
                // Ende des aktuellen Monats
                let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
                end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? Date()
            }
            calendarImporter.importEvents(from: Date(), to: end, into: todoStore, skipPastEvents: true)
        }
    }
    
    // MARK: - Computed Properties
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }

    private var themeBackground: some View {
        let (c1, c2, c3) = appThemaFarben(aktivesThema)
        let dark = colorScheme == .dark
        return ZStack {
            if dark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(colors: [c1.opacity(dark ? 0.32 : 0.15), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.45))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.12)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [c2.opacity(dark ? 0.24 : 0.12), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.40))
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.60)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [c3.opacity(dark ? 0.16 : 0.09), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
                    .blur(radius: 14)
            }

            GeometryReader { geo in
                WaveShape(phase: wavePhase2, amplitude: 20, frequency: 1.3)
                    .fill(c2.opacity(dark ? 0.10 : 0.07))
                    .frame(width: geo.size.width, height: geo.size.height * 0.40)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.40 * 0.5)
                WaveShape(phase: wavePhase1, amplitude: 13, frequency: 2.1)
                    .fill(c1.opacity(dark ? 0.16 : 0.11))
                    .frame(width: geo.size.width, height: geo.size.height * 0.28)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.28 * 0.5)
            }
            .opacity(["", "Wald", "Eis", "Nordlicht", "Galaxie", "Vulkan", "Herbst", "Nacht", "Solar", "Kirschblüte", "Lavendel", "Sonnenuntergang"].contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)

            if aktivesThema == "Wald" {
                WaldDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Eis" {
                EisDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Nordlicht" {
                NordlichtDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Galaxie" {
                GalaxieDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Vulkan" {
                VulkanDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Herbst" {
                HerbstDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Nacht" {
                NachtDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Solar" {
                SolarDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Kirschblüte" {
                KirschblueteDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Lavendel" {
                LavendelDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
            if aktivesThema == "Sonnenuntergang" {
                SonnenuntergangDecorationLayer()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: aktivesThema)
        .ignoresSafeArea()
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

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let todayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? Date()

        // Aktueller Monat: erster und letzter Tag
        let currentMonthStart: Date = {
            let comps = cal.dateComponents([.year, .month], from: Date())
            return cal.date(from: comps) ?? todayStart
        }()
        let currentMonthEnd: Date = {
            cal.date(byAdding: DateComponents(month: 1, second: -1), to: currentMonthStart) ?? todayEnd
        }()

        let filtered = baseTodos.filter { todo in
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
                return due <= todayEnd
            }()

            // Aktueller-Monat-Filter: Todos mit Datum außerhalb des Monats ausblenden
            let matchesCurrentMonth: Bool = {
                guard filterCurrentMonthOnly else { return true }
                guard let due = todo.dueDate else { return true } // ohne Datum: immer anzeigen
                return due >= currentMonthStart && due <= currentMonthEnd
            }()

            // Completed tasks are always hidden in the main list
            guard !todo.isCompleted else { return false }
            return matchesSearch && matchesCategory && matchesToday && matchesCurrentMonth
        }

        // Deduplicate: keep first occurrence of each unique key
        var seenKeys: Set<String> = []
        return filtered.filter { todo in
            let key = "\(todo.title)|\(todo.description)|\(String(todo.dueDate?.timeIntervalSince1970 ?? -1))|\(todo.category?.name ?? "")|\(todo.priority)"
            guard !seenKeys.contains(key) else { return false }
            seenKeys.insert(key)
            return true
        }
    }
    
    // MARK: - Main View
    private var highlightTodo: TodoItem? {
        guard !highlightIDStr.isEmpty, let uid = UUID(uuidString: highlightIDStr) else { return nil }
        return todoStore.todos.first { $0.id == uid && !$0.isCompleted }
    }

    private var highlightCard: some View {
        Group {
            if let todo = highlightTodo {
                HStack(spacing: 12) {
                    Text("⭐️")
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heutiges Highlight")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                        Text(todo.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        todoStore.complete(todo: todo)
                        highlightIDStr = ""
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.4, blue: 0.0).opacity(0.35),
                                 Color(red: 0.4, green: 0.25, blue: 0.0).opacity(0.25)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.35), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Tools Strip
    private var toolsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                toolChip(icon: "calendar.badge.checkmark",label: "Gewohnheiten",color: Color(red: 0.3, green: 0.82, blue: 0.5)) { showToolGewohnheiten = true }
                toolChip(icon: "book.closed.fill",        label: "Journal",    color: Color(red: 0.65, green: 0.35, blue: 1.0))  { showToolJournal     = true }
                toolChip(icon: "trophy.fill",             label: "Challenges", color: Color(red: 1.0,  green: 0.7,  blue: 0.2))  { showToolChallenges  = true }
                toolChip(icon: "chart.line.uptrend.xyaxis", label: "Score",   color: Color(red: 0.2,  green: 0.85, blue: 0.5))  { showToolScore       = true }
                toolChip(icon: "quote.bubble.fill",      label: "Motivation", color: Color(red: 1.0,  green: 0.5,  blue: 0.8))  { showToolMotivation  = true }
                toolChip(icon: "drop.fill",              label: "Wasser",     color: Color(red: 0.15, green: 0.75, blue: 0.95)) { showToolWasser      = true }
                toolChip(icon: "moon.zzz.fill",          label: "Schlaf",     color: Color(red: 0.4,  green: 0.3,  blue: 0.9))  { showToolSchlaf      = true }

                toolChip(icon: "note.text",              label: "Notizen",    color: Color(red: 1.0,  green: 0.75, blue: 0.2))  { showToolNotizen     = true }
                toolChip(icon: "brain",                  label: "Brain Dump", color: Color(red: 1.0,  green: 0.55, blue: 0.15)) { showToolBrainDump   = true }
                toolChip(icon: "timer.circle.fill",      label: "Zeiterfassung", color: Color(red: 0.3, green: 0.5, blue: 1.0)) { showToolZeiterfassung = true }
                toolChip(icon: "hourglass",              label: "Countdown",  color: Color(red: 0.5,  green: 0.3,  blue: 1.0))  { showToolCountdown   = true }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func toolChip(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }

    private var mainContentView: some View {
        ZStack {
            themeBackground
            VStack(spacing: 0) {
                highlightCard
                categoryBar
                toolsStrip
                contentView
            }
            
            if false {
                // Banner deaktiviert, um Verwirrung zu vermeiden
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

            // Ordner-Zuweisung Overlay
            if isShowingFolderPicker {
                folderPickerOverlay
                    .zIndex(999)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Drag-to-Folder Overlay
            if isDragModeActive {
                dragFolderPickerOverlay
                    .zIndex(998)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Fokus-Sperrmodus Banner
            if isLocked {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.indigo)
                        Text("Fokus aktiv – Bearbeiten gesperrt")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.indigo.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                .zIndex(996)
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }

            // Konfetti Overlay
            if showKonfetti {
                KonfettiOverlayView()
                    .zIndex(1000)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isShowingFolderPicker)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isDragModeActive)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isLocked)
        .animation(.easeInOut(duration: 0.2), value: showKonfetti)
    }

    // MARK: - Ordner-Zuweisung

    private struct FolderTarget: Identifiable {
        let id: String
        let title: String
        let icon: String
        let color: Color
    }

    private var allFolderPickerTargets: [FolderTarget] {
        var targets = todoStore.customFolders.map { name in
            FolderTarget(id: "__custom__\(name)", title: name, icon: "folder.fill", color: .indigo)
        }
        targets.append(FolderTarget(id: "__remove__", title: "Allgemein", icon: "tray.fill", color: Color(.systemGray)))
        return targets
    }

    private func assignToFolder(targetID: String) {
        let folder: String?
        if targetID == "__remove__" {
            folder = nil
        } else if targetID.hasPrefix("__custom__") {
            folder = String(targetID.dropFirst("__custom__".count))
        } else {
            return
        }
        dismissFolderPicker()
        if let singleID = pendingFolderTodoID {
            todoStore.assignTodo(singleID, toFolder: folder)
            pendingFolderTodoID = nil
        } else {
            for id in selectedTodoIDs { todoStore.assignTodo(id, toFolder: folder) }
            selectedTodoIDs.removeAll()
            isSelecting = false
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func dismissFolderPicker() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isShowingFolderPicker = false
        }
        pendingFolderTodoID = nil
    }

    private func assignDragToFolder(targetID: String) {
        let folder: String?
        if targetID == "__remove__" {
            folder = nil
        } else if targetID.hasPrefix("__custom__") {
            folder = String(targetID.dropFirst("__custom__".count))
        } else {
            return
        }
        if let id = draggedTodoID {
            todoStore.assignTodo(id, toFolder: folder)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDragModeActive = false
        }
        draggedTodoID = nil
    }

    private var dragFolderPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onDrop(of: [UTType.plainText.identifier], isTargeted: $isDragBgTargeted) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDragModeActive = false
                    }
                    draggedTodoID = nil
                    return false
                }

            VStack {
                Spacer()
                VStack(spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("In Ordner ziehen")
                                .font(.title3.weight(.bold))
                            if let id = draggedTodoID,
                               let todo = todoStore.todos.first(where: { $0.id == id }) {
                                Text(todo.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDragModeActive = false
                            }
                            draggedTodoID = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    if todoStore.customFolders.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text("Noch keine eigenen Ordner vorhanden.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: min(3, max(1, allFolderPickerTargets.count))),
                        spacing: 12
                    ) {
                        ForEach(allFolderPickerTargets) { target in
                            FolderDropTile(
                                id: target.id,
                                title: target.title,
                                icon: target.icon,
                                color: target.color,
                                onAssign: assignDragToFolder
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 24)
                .padding(.bottom, 36)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private var folderPickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismissFolderPicker() }

            VStack {
                Spacer()
                VStack(spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("In Ordner verschieben")
                                .font(.title3.weight(.bold))
                            if let id = pendingFolderTodoID,
                               let todo = todoStore.todos.first(where: { $0.id == id }) {
                                Text(todo.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("\(selectedTodoIDs.count) Aufgabe(n) ausgewählt")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button { dismissFolderPicker() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    if todoStore.customFolders.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 34))
                                .foregroundStyle(.secondary)
                            Text("Noch keine Ordner vorhanden.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("Erstelle einen Ordner mit dem Ordner-Button oben rechts.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(allFolderPickerTargets) { target in
                            Button { assignToFolder(targetID: target.id) } label: {
                                VStack(spacing: 10) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(target.color.opacity(0.15))
                                            .frame(width: 56, height: 56)
                                        Image(systemName: target.icon)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(target.color)
                                    }
                                    Text(target.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(target.color.opacity(0.07))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(target.color.opacity(0.2), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Button { dismissFolderPicker() } label: {
                        Text("Abbrechen")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemFill)))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 24)
                .padding(.bottom, 32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
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
                    if isSelecting && !selectedTodoIDs.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isShowingFolderPicker = true
                            }
                        } label: {
                            Label("In Ordner verschieben", systemImage: "folder.badge.plus")
                        }
                        Divider()
                    }
                    Button {
                        showingTemplates = true
                    } label: {
                        Label("Aufgaben-Vorlagen", systemImage: "rectangle.stack.fill")
                    }
                    Divider()
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
                                            gradient: Gradient(colors: [appThemaFarben(aktivesThema).0.opacity(0.35), appThemaFarben(aktivesThema).1.opacity(0.35)]),
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
                                            gradient: Gradient(colors: [appThemaFarben(aktivesThema).0, appThemaFarben(aktivesThema).1]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blur(radius: 2)
                                    .opacity(0.7)
                            }
                        )
                        .scaleEffect(isPlusPressed ? 1.05 : 1.0)
                        .shadow(color: appThemaFarben(aktivesThema).0.opacity(0.4), radius: 6, x: 4, y: 3)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.white.opacity(0.5), appThemaFarben(aktivesThema).0.opacity(0.5)]),
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
                        colors: [Color.white.opacity(0.05), appThemaFarben(aktivesThema).0.opacity(0.07)],
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

    // MARK: - Folder Order Helpers

    private var folderOrder: [String] {
        folderOrderString.isEmpty ? [] : folderOrderString.components(separatedBy: ",")
    }

    private func orderedGroups(_ groups: [TodoFolderGroup]) -> [TodoFolderGroup] {
        // "Heute" is always pinned at position 0
        let todayGroup = groups.first(where: { $0.id == "__today__" })
        let rest = groups.filter { $0.id != "__today__" }

        let order = folderOrder
        var ordered: [TodoFolderGroup]
        if order.isEmpty {
            ordered = rest
        } else {
            let dict = Dictionary(uniqueKeysWithValues: rest.map { ($0.id, $0) })
            var result: [TodoFolderGroup] = order.compactMap { dict[$0] }
            for g in rest where !order.contains(g.id) { result.append(g) }
            ordered = result
        }

        if let today = todayGroup { return [today] + ordered }
        return ordered
    }

    private func moveFolderGroup(from source: IndexSet, to destination: Int) {
        var current = orderedGroups(todoGroups)
        current.move(fromOffsets: source, toOffset: destination)
        folderOrderString = current.map { $0.id }.joined(separator: ",")
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

    private func isBirthdayOrHoliday(_ todo: TodoItem) -> Bool {
        let keywords = ["geburtstag", "birthday", "feiertag", "holiday", "feiertage", "birthdays", "holidays"]
        if let catName = todo.category?.name.lowercased(), keywords.contains(where: { catName.contains($0) }) {
            return true
        }
        let titleLower = todo.title.lowercased()
        return keywords.contains(where: { titleLower.hasPrefix($0) })
    }

    private var todoGroups: [TodoFolderGroup] {
        // Tasks in custom folders are excluded from standard date-based groups
        let todos = sortedTodos.filter { $0.customFolder == nil }
        let cal = Calendar.current
        let now = Date()
        let startOfToday    = cal.startOfDay(for: now)
        let endOfToday      = cal.date(bySettingHour: 23, minute: 59, second: 59, of: startOfToday) ?? now
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let endOfTomorrow   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow) ?? now
        let endOfWeek       = cal.date(byAdding: .day, value: 6, to: endOfToday) ?? now
        let endOfMonth      = cal.date(byAdding: .day, value: 29, to: endOfToday) ?? now
        let eng             = localizer.selectedLanguage == "Englisch"

        let specialTodos = todos.filter { isBirthdayOrHoliday($0) }
        let specialIDs   = Set(specialTodos.map { $0.id })
        let remaining    = todos.filter { !specialIDs.contains($0.id) }

        let noDue        = remaining.filter { $0.dueDate == nil }
        let overdue      = remaining.filter { guard let d = $0.dueDate else { return false }; return d < startOfToday && !$0.isCompleted }
        let todayDue     = remaining.filter { guard let d = $0.dueDate else { return false }; return d >= startOfToday && d <= endOfToday && !$0.isCompleted }
        let tomorrowDue  = remaining.filter { guard let d = $0.dueDate else { return false }; return d >= startOfTomorrow && d <= endOfTomorrow }
        let thisWeek     = remaining.filter { guard let d = $0.dueDate else { return false }; return d > endOfTomorrow && d <= endOfWeek }
        let thisMonth    = remaining.filter { guard let d = $0.dueDate else { return false }; return d > endOfWeek && d <= endOfMonth }
        let later        = remaining.filter { guard let d = $0.dueDate else { return false }; return d > endOfMonth }

        var groups: [TodoFolderGroup] = []

        // 0. Heute – immer an erster Stelle, auch wenn leer
        groups.append(TodoFolderGroup(
            id: "__today__",
            title: eng ? "Today" : "Heute",
            icon: "sun.max.fill",
            color: .orange,
            todos: todayDue
        ))

        // 1. Morgen – nur wenn Todos vorhanden
        if !tomorrowDue.isEmpty {
            groups.append(TodoFolderGroup(
                id: "__tomorrow__",
                title: eng ? "Tomorrow" : "Morgen",
                icon: "moon.stars.fill",
                color: .indigo,
                todos: tomorrowDue
            ))
        }

        // 2. Allgemein – keine Fälligkeit
        if !noDue.isEmpty {
            groups.append(TodoFolderGroup(
                id: "__general__",
                title: eng ? "General" : "Allgemein",
                icon: "tray.fill",
                color: Color(.systemGray),
                todos: noDue
            ))
        }

        // 2. Geburtstage & Feiertage
        if !specialTodos.isEmpty {
            let birthdays  = specialTodos.filter { $0.category?.name.lowercased().contains("geburtstag") == true || $0.category?.name.lowercased().contains("birthday") == true }
            let holidays   = specialTodos.filter { $0.category?.name.lowercased().contains("feiertag") == true || $0.category?.name.lowercased().contains("holiday") == true }
            let uncategorized = specialTodos.filter { todo in
                !birthdays.contains(where: { $0.id == todo.id }) && !holidays.contains(where: { $0.id == todo.id })
            }

            if !birthdays.isEmpty && !holidays.isEmpty {
                let bdGroup = TodoFolderGroup(id: "__birthdays__",
                    title: eng ? "Birthdays" : "Geburtstage",
                    icon: "gift.fill", color: .pink, todos: birthdays)
                let hdGroup = TodoFolderGroup(id: "__holidays__",
                    title: eng ? "Holidays" : "Feiertage",
                    icon: "star.fill", color: .yellow, todos: holidays)
                var subs = [bdGroup, hdGroup]
                if !uncategorized.isEmpty {
                    subs.append(TodoFolderGroup(id: "__special_other__",
                        title: eng ? "Other" : "Weitere",
                        icon: "sparkles", color: .orange, todos: uncategorized))
                }
                groups.append(TodoFolderGroup(id: "__special__",
                    title: eng ? "Birthdays & Holidays" : "Geburtstage & Feiertage",
                    icon: "calendar.badge.exclamationmark", color: .pink,
                    subGroups: subs))
            } else {
                groups.append(TodoFolderGroup(id: "__special__",
                    title: eng ? "Birthdays & Holidays" : "Geburtstage & Feiertage",
                    icon: "calendar.badge.exclamationmark", color: .pink,
                    todos: specialTodos))
            }
        }

        // 3. Überfällig
        if !overdue.isEmpty {
            groups.append(TodoFolderGroup(id: "__overdue__",
                title: eng ? "Overdue" : "Überfällig",
                icon: "exclamationmark.circle.fill", color: .red, todos: overdue))
        }

        // 4. Diese Woche
        if !thisWeek.isEmpty {
            groups.append(TodoFolderGroup(id: "__week__",
                title: eng ? "This Week" : "Diese Woche",
                icon: "calendar.badge.clock", color: .blue, todos: thisWeek))
        }

        // 5. Geplant – Dieser Monat + Später als Unterordner (wenn beides vorhanden)
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

        // Custom user-defined folders
        for folderName in todoStore.customFolders {
            let folderTodos = sortedTodos.filter { $0.customFolder == folderName }
            groups.append(TodoFolderGroup(
                id: "__custom__\(folderName)",
                title: folderName,
                icon: "folder.fill",
                color: .indigo,
                todos: folderTodos
            ))
        }

        return groups
    }

    // MARK: - Folder List View

    private var folderListView: some View {
        ZStack(alignment: .topTrailing) {
            if isReorderingFolders {
                List {
                    ForEach(orderedGroups(todoGroups)) { group in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [group.color, group.color.opacity(0.7)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 36, height: 36)
                                Image(systemName: group.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(group.title)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("\(group.totalCount)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(group.color.gradient, in: Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveFolderGroup)
                }
                .listStyle(.insetGrouped)
                .environment(\.editMode, .constant(.active))
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(orderedGroups(todoGroups)) { group in
                            folderSection(group: group)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
            }

            VStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isReorderingFolders.toggle()
                    }
                } label: {
                    Image(systemName: isReorderingFolders ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isReorderingFolders ? Color.green : Color.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    newFolderName = ""
                    showingAddFolderAlert = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.trailing, 20)
        }
        .alert("Neuer Ordner", isPresented: $showingAddFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Erstellen") {
                todoStore.addCustomFolder(newFolderName)
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Gib einen Namen für den neuen Ordner ein.")
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
                            let wasIncomplete = !todo.isCompleted
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { todoStore.toggleTodo(todo) }
                            if wasIncomplete && konfettiEnabled {
                                showKonfetti = true
                                Task {
                                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                                    await MainActor.run { showKonfetti = false }
                                }
                            }
                        } else {
                            if selectedTodoIDs.contains(todo.id) { selectedTodoIDs.remove(todo.id) }
                            else { selectedTodoIDs.insert(todo.id) }
                        }
                    } onEdit: {
                        if isLocked { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                        else if !isSelecting { editingTodo = todo }
                    } onDelete: {
                        if isLocked { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                        else if !isSelecting { todoToDelete = todo; showingDeleteAlert = true }
                    } onShare: {
                        if !isSelecting { TodoShare.share(todo: todo) }
                    } onMoveToFolder: {
                        if !isSelecting && !isLocked {
                            pendingFolderTodoID = todo.id
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isShowingFolderPicker = true
                            }
                        }
                    }
                }
                .contextMenu {
                    if !todo.isCompleted {
                        Button {
                            highlightIDStr = todo.id.uuidString
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label("Als Highlight setzen", systemImage: "star.fill")
                        }
                    }
                    if highlightIDStr == todo.id.uuidString {
                        Button {
                            highlightIDStr = ""
                        } label: {
                            Label("Highlight entfernen", systemImage: "star.slash")
                        }
                    }
                }
                .opacity(todo.isCompleted ? 0.55 : 1.0)
                .strikethrough(todo.isCompleted, color: .gray)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal: .scale(scale: 0.96).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: todo.isCompleted)
                .onDrag {
                    guard !isSelecting else { return NSItemProvider() }
                    let todoID = todo.id
                    DispatchQueue.main.async {
                        draggedTodoID = todoID
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDragModeActive = true
                        }
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    return NSItemProvider(object: todo.id.uuidString as NSString)
                }
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
        let cornerRadius: CGFloat = isSubFolder ? 12 : 16
        let hPad: CGFloat = isSubFolder ? 10 : 14
        let vPad: CGFloat = isSubFolder ? 9 : 12
        let isCustomFolder = group.id.hasPrefix("__custom__")
        let customFolderName = isCustomFolder ? String(group.id.dropFirst("__custom__".count)) : nil

        return AnyView(VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    setCollapsed(group.id, collapsed: !isCollapsed)
                }
            } label: {
                HStack(spacing: 10) {
                    // Farbiger Akzent-Streifen links
                    if !isSubFolder {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(group.color)
                            .frame(width: 3, height: 28)
                    }

                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: isSubFolder ? 7 : 9, style: .continuous)
                            .fill(group.color.opacity(0.15))
                            .frame(width: isSubFolder ? 28 : 34, height: isSubFolder ? 28 : 34)
                        Image(systemName: group.icon)
                            .font(.system(size: isSubFolder ? 13 : 15, weight: .semibold))
                            .foregroundStyle(group.color)
                    }

                    // Titel + optionaler Fortschritt
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title)
                            .font(.system(size: isSubFolder ? 14 : 15, weight: .semibold))
                            .foregroundStyle(.primary)
                        if !isSubFolder && completedCount > 0 {
                            Text("\(completedCount) von \(totalCount) erledigt")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Badge + Chevron + Delete (custom folder only)
                    HStack(spacing: 8) {
                        Text(completedCount > 0 ? "\(totalCount - completedCount)" : "\(totalCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(group.color)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(group.color.opacity(0.12), in: Capsule())

                        if let folderName = customFolderName {
                            Button {
                                todoStore.removeCustomFolder(folderName)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                }
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .dropDestination(for: String.self) { items, _ in
                guard let folderName = customFolderName else { return false }
                for idString in items {
                    if let uuid = UUID(uuidString: idString) {
                        todoStore.assignTodo(uuid, toFolder: folderName)
                    }
                }
                return !items.isEmpty
            }

            // Expanded content
            if !isCollapsed {
                Divider()
                    .padding(.horizontal, hPad)
                    .opacity(0.25)

                if group.subGroups.isEmpty && group.directTodos.isEmpty && group.id == "__today__" {
                    // Freundliche Leerstand-Nachricht für "Heute"
                    VStack(spacing: 10) {
                        Image(systemName: "sun.and.horizon.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.orange.opacity(0.7))
                        Text("Keine Aufgaben für heute – genieße den Tag! ☀️")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                } else if group.subGroups.isEmpty {
                    todoItemsContent(todos: group.directTodos, color: group.color)
                } else {
                    VStack(spacing: 8) {
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
        .themeGlass(cornerRadius: cornerRadius)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCollapsed)
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
                                let wasIncomplete = !todo.isCompleted
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    todoStore.toggleTodo(todo)
                                }
                                if wasIncomplete && konfettiEnabled {
                                    showKonfetti = true
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                                        await MainActor.run { showKonfetti = false }
                                    }
                                }
                            } else {
                                if selectedTodoIDs.contains(todo.id) {
                                    selectedTodoIDs.remove(todo.id)
                                } else {
                                    selectedTodoIDs.insert(todo.id)
                                }
                            }
                        } onEdit: {
                            if isLocked { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                            else if !isSelecting { editingTodo = todo }
                        } onDelete: {
                            if isLocked { UINotificationFeedbackGenerator().notificationOccurred(.error) }
                            else if !isSelecting { todoToDelete = todo; showingDeleteAlert = true }
                        } onShare: {
                            if !isSelecting {
                                TodoShare.share(todo: todo)
                            }
                        }
                    }
                    .contextMenu {
                        if !todo.isCompleted {
                            Button {
                                highlightIDStr = todo.id.uuidString
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Label("Als Highlight setzen", systemImage: "star.fill")
                            }
                        }
                        if highlightIDStr == todo.id.uuidString {
                            Button {
                                highlightIDStr = ""
                            } label: {
                                Label("Highlight entfernen", systemImage: "star.slash")
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
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
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

// MARK: - FolderDropTile

private struct FolderDropTile: View {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let onAssign: (String) -> Void
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isTargeted ? color : color.opacity(0.15))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isTargeted ? .white : color)
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isTargeted)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isTargeted ? color.opacity(0.12) : Color(.systemFill))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isTargeted ? color.opacity(0.6) : color.opacity(0.15), lineWidth: isTargeted ? 2 : 1)
                )
        )
        .scaleEffect(isTargeted ? 1.08 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isTargeted)
        .onDrop(of: [UTType.plainText.identifier], isTargeted: $isTargeted) { _ in
            onAssign(id)
            return true
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

// MARK: - Konfetti

struct KonfettiOverlayView: View {
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<50, id: \.self) { i in
                    KonfettiParticle(
                        color: colors[i % colors.count],
                        startX: geo.size.width * CGFloat(i % 10) / 9,
                        maxY: geo.size.height + 80,
                        delay: Double(i % 15) * 0.06
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct KonfettiParticle: View {
    let color: Color
    let startX: CGFloat
    let maxY: CGFloat
    let delay: Double

    @State private var posY: CGFloat = -20
    @State private var offsetX: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 8, height: 9)
            .rotationEffect(.degrees(rotation))
            .position(x: startX + offsetX, y: posY)
            .opacity(opacity)
            .onAppear {
                let dur = Double.random(in: 1.2...1.9)
                withAnimation(.easeIn(duration: dur).delay(delay)) {
                    posY = maxY
                    offsetX = CGFloat.random(in: -60...60)
                    rotation = Double.random(in: 270...810)
                }
                withAnimation(.linear(duration: 0.5).delay(delay + dur - 0.5)) {
                    opacity = 0
                }
            }
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

    func importEvents(from startDate: Date, to endDate: Date, into todoStore: TodoStore, skipPastEvents: Bool = false) {
        let cals = availableCalendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !cals.isEmpty else { lastImportCount = 0; return }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: cals)
        let events = eventStore.events(matching: predicate)

        let existing = Set(todoStore.todos.compactMap { $0.calendarEventIdentifier })
        let dismissed = Set((UserDefaults.standard.array(forKey: "dismissedCalendarEventIDs") as? [String]) ?? [])
        let skipOverdue = skipPastEvents || UserDefaults.standard.bool(forKey: "skipOverdueOnImport")
        let now = Date()

        var count = 0
        for event in events {
            guard !existing.contains(event.eventIdentifier) else { continue }
            guard !dismissed.contains(event.eventIdentifier) else { continue }
            if skipOverdue && event.startDate < now { continue }
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

