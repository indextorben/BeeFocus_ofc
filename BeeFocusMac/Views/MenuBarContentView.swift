import SwiftUI
import AppKit
import Charts

// MARK: - Time Filter enum

private enum MacTodoTimeFilter: CaseIterable {
    case alle, heute, morgen, dieseWoche, ueberfaellig

    var label: String {
        switch self {
        case .alle:         return "Alle"
        case .heute:        return "Heute"
        case .morgen:       return "Morgen"
        case .dieseWoche:   return "Woche"
        case .ueberfaellig: return "Überfällig"
        }
    }

    var icon: String {
        switch self {
        case .alle:         return "list.bullet"
        case .heute:        return "sun.max.fill"
        case .morgen:       return "moon.stars.fill"
        case .dieseWoche:   return "calendar.badge.clock"
        case .ueberfaellig: return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .alle:         return .blue
        case .heute:        return .orange
        case .morgen:       return .indigo
        case .dieseWoche:   return .teal
        case .ueberfaellig: return .red
        }
    }
}

// MARK: - Tab enum

private enum MenuBarTab: CaseIterable {
    case tasks, planner, timer, stats, brain, wasser

    var icon: String {
        switch self {
        case .tasks:   return "checklist"
        case .planner: return "calendar.day.timeline.left"
        case .timer:   return "timer"
        case .stats:   return "chart.bar.fill"
        case .brain:   return "brain"
        case .wasser:  return "drop.fill"
        }
    }

    var label: String {
        switch self {
        case .tasks:   return "Aufgaben"
        case .planner: return "Tag"
        case .timer:   return "Timer"
        case .stats:   return "Statistik"
        case .brain:   return "Brain"
        case .wasser:  return "Wasser"
        }
    }
}

// MARK: - Main View

struct MenuBarContentView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager
    @AppStorage("aktivesStatistikThema") private var activeTheme: String = ""
    @State private var activeTab:   MenuBarTab = .tasks
    @Namespace private var tabNS

    // Inline add form
    @State private var showingAddForm  = false
    @State private var newTitle        = ""
    @State private var newPriority     = MacTodoPriority.medium
    @State private var newHasDueDate   = false
    @State private var newDueDate      = Date()
    @State private var newReminderOffset: Int? = nil

    // AI quick input
    @State private var smartInputText  = ""
    @State private var isParsing       = false
    @State private var parseError: String? = nil
    @State private var aiDidFill       = false
    @AppStorage("mac_ai_provider") private var aiProviderRaw: String = MacAIProvider.groq.rawValue
    private var aiProvider: MacAIProvider { MacAIProvider(rawValue: aiProviderRaw) ?? .groq }

    // Settings panel
    @State private var showingSettings       = false
    @State private var showAutoDeleteConfirm = false

    // Shared settings
    @AppStorage("autoDeleteCompletedEnabled") private var autoDeleteCompletedEnabled   = false
    @AppStorage("autoDeleteCompletedDays")    private var autoDeleteCompletedDays: Int = 30
    @AppStorage("mac_dailyGoalMinutes")       private var dailyGoalMinutes: Int        = 60

    // Subtask expansion
    @State private var expandedTaskID: UUID? = nil

    // Inline form subtasks
    @State private var newSubTasks: [MacSubTask] = []
    @State private var newSubTaskInput: String = ""

    // Tasks filters
    @State private var searchText      = ""
    @State private var timeFilter: MacTodoTimeFilter = .alle
    @State private var showCompleted   = false

    // Tasks: Today highlight
    @AppStorage("todayHighlightID") private var highlightIDStr: String = ""

    // Tasks: Collapsible sections
    @AppStorage("mac_collapsedSections") private var collapsedSectionsString: String = ""

    // Tasks: Delete snackbar
    @State private var showDeleteSnackbar = false
    @State private var snackbarDismissTask: Task<Void, Never>? = nil

    // Tasks: Multi-select
    @State private var isSelecting = false
    @State private var selectedTaskIDs: Set<UUID> = []

    // Tasks: Folder management
    @State private var showAddFolderAlert = false
    @State private var newFolderName = ""
    @State private var showFolderPicker = false
    @State private var pendingFolderTaskID: UUID? = nil

    // Timer task picker
    @State private var showTimerTaskPicker = false

    // Command palette
    @State private var showingCommandPalette = false

    // Hotkeys
    @ObservedObject private var hotkeyMgr = GlobalHotkeyManager.shared

    // Task list keyboard navigation
    @State private var selectedTaskID: UUID? = nil

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }
    private var themeC1: Color { appThemaFarben(activeTheme).0 }
    private var themeC2: Color { appThemaFarben(activeTheme).1 }

    private let allThemes: [(id: String, label: String)] = [
        ("", "Standard"), ("Ocean", "Ocean"), ("Forest", "Forest"),
        ("Night", "Night"), ("Solar", "Solar"), ("Cherry Blossom", "Cherry"), // gekürzt wegen Platz
        ("Volcano", "Volcano"), ("Ice", "Ice"), ("Autumn", "Autumn"),
        ("Lavender", "Lavender"), ("Sunset", "Sunset"), ("Galaxy", "Galaxy"),
        ("Northern Lights", "Nordlichter"), ("Aurora", "Aurora"),
        ("Obsidian", "Obsidian"), ("Nebula", "Nebula"),
    ]

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            VStack(spacing: 0) {
                if showingAddForm {
                    inlineAddFormHeader
                    Divider().opacity(0.2)
                    ScrollView(.vertical, showsIndicators: false) { inlineAddForm }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if showingSettings {
                    settingsHeader
                    Divider().opacity(0.2)
                    ScrollView(.vertical, showsIndicators: false) { settingsPanel }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    header
                    Divider().opacity(0.2)
                    ScrollView(.vertical, showsIndicators: false) {
                        switch activeTab {
                        case .tasks:   tasksTab
                        case .planner: plannerTab
                        case .timer:   timerTab
                        case .stats:   statsTab
                        case .brain:   MacBrainDumpView().environmentObject(todoStore)
                        case .wasser:  MacWasserTrackerView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Divider().opacity(0.2)
                    bottomTabBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(commandPaletteOverlay)
        .overlay(folderPickerOverlay)
        .overlay(alignment: .bottom) { deleteSnackbar }
        .animation(.easeInOut(duration: 0.25), value: showDeleteSnackbar)
        .background(keyboardShortcutLayer)
        .alert("Neuer Ordner", isPresented: $showAddFolderAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Erstellen") {
                if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                    todoStore.addCustomFolder(newFolderName)
                }
                newFolderName = ""
            }
            Button("Abbrechen", role: .cancel) { newFolderName = "" }
        } message: { Text("Gib einen Namen für den neuen Ordner ein.") }
        .onReceive(NotificationCenter.default.publisher(for: .beeFocusToggleTimer)) { _ in
            timerMgr.startPause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .beeFocusOpenNewTask)) { _ in
            MacAddTodoWindow.open(todoStore: todoStore)
        }
    }

    // MARK: - Command Palette Overlay

    @ViewBuilder
    private var commandPaletteOverlay: some View {
        if showingCommandPalette {
            ZStack(alignment: .top) {
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.22)) { showingCommandPalette = false }
                    }
                MacCommandPaletteView(
                    isPresented: $showingCommandPalette,
                    actions: paletteActions
                )
                .frame(maxWidth: 336)
                .padding(.top, 4)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        }
    }

    private var paletteActions: [MacPaletteAction] {
        [
            MacPaletteAction(
                title: timerMgr.isRunning ? "Timer pausieren" : "Timer starten",
                subtitle: timerMgr.mode.displayName,
                icon: timerMgr.isRunning ? "pause.fill" : "play.fill",
                shortcut: "⌥⌘T"
            ) {
                timerMgr.startPause()
                withAnimation { activeTab = .timer }
            },
            MacPaletteAction(title: "Timer zurücksetzen",  subtitle: nil, icon: "arrow.counterclockwise", shortcut: nil) {
                timerMgr.reset()
                withAnimation { activeTab = .timer }
            },
            MacPaletteAction(title: "Nächste Phase",       subtitle: nil, icon: "forward.end.fill",      shortcut: nil) {
                timerMgr.skipToNext()
                withAnimation { activeTab = .timer }
            },
            MacPaletteAction(title: "Neue Aufgabe",        subtitle: "Schnelleingabe",  icon: "plus.circle.fill", shortcut: "⌘N") {
                withAnimation(.spring(response: 0.3)) {
                    showingCommandPalette = false
                    activeTab = .tasks
                    showingAddForm = true
                }
            },
            MacPaletteAction(title: "Aufgaben",            subtitle: "Tab wechseln",   icon: "checklist",                   shortcut: "⌘1") {
                withAnimation { activeTab = .tasks }
            },
            MacPaletteAction(title: "Tagesplaner",         subtitle: "Tab wechseln",   icon: "calendar.day.timeline.left",  shortcut: "⌘2") {
                withAnimation { activeTab = .planner }
            },
            MacPaletteAction(title: "Timer",               subtitle: "Tab wechseln",   icon: "timer",                       shortcut: "⌘3") {
                withAnimation { activeTab = .timer }
            },
            MacPaletteAction(title: "Statistik",           subtitle: "Tab wechseln",   icon: "chart.bar.fill",              shortcut: "⌘4") {
                withAnimation { activeTab = .stats }
            },
            MacPaletteAction(title: "Einstellungen",       subtitle: nil,              icon: "gearshape.fill",              shortcut: nil) {
                withAnimation(.spring(response: 0.28)) { showingSettings = true }
            },
            MacPaletteAction(title: "BeeFocus beenden",    subtitle: nil,              icon: "power",                       shortcut: nil) {
                NSApp.terminate(nil)
            },
        ]
    }

    // MARK: - Keyboard shortcut layer (hidden buttons)

    private var keyboardShortcutLayer: some View {
        Group {
            // ⌘N → neue Aufgabe
            Button("") {
                guard !showingAddForm && !showingSettings else { return }
                withAnimation(.spring(response: 0.3)) {
                    activeTab = .tasks
                    showingAddForm = true
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            .opacity(0)

            // ⌘K → Command Palette
            Button("") {
                guard !showingAddForm && !showingSettings else { return }
                withAnimation(.spring(response: 0.25)) { showingCommandPalette.toggle() }
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)

            // ⌘1-4 → Tab switching
            Button("") { withAnimation { activeTab = .tasks } }
                .keyboardShortcut("1", modifiers: .command).opacity(0)
            Button("") { withAnimation { activeTab = .planner } }
                .keyboardShortcut("2", modifiers: .command).opacity(0)
            Button("") { withAnimation { activeTab = .timer } }
                .keyboardShortcut("3", modifiers: .command).opacity(0)
            Button("") { withAnimation { activeTab = .stats } }
                .keyboardShortcut("4", modifiers: .command).opacity(0)

            // Space → Timer starten/pausieren (nur im Timer-Tab)
            Button("") {
                guard activeTab == .timer else { return }
                timerMgr.startPause()
            }
            .keyboardShortcut(.space, modifiers: [])
            .opacity(0)

            // Arrow keys → Task-Navigation
            Button("") { navigateTask(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: []).opacity(0)
            Button("") { navigateTask(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: []).opacity(0)
            Button("") { toggleSelectedTask() }
                .keyboardShortcut(.return, modifiers: []).opacity(0)
            Button("") { deleteSelectedTask() }
                .keyboardShortcut(.delete, modifiers: .command).opacity(0)
        }
    }

    // MARK: - Task keyboard navigation helpers

    private func navigateTask(by delta: Int) {
        guard activeTab == .tasks, !showingAddForm, !showingSettings else { return }
        let tasks = timeFilteredTasks
        guard !tasks.isEmpty else { return }
        if let current = selectedTaskID, let idx = tasks.firstIndex(where: { $0.id == current }) {
            let newIdx = max(0, min(tasks.count - 1, idx + delta))
            selectedTaskID = tasks[newIdx].id
        } else {
            selectedTaskID = delta >= 0 ? tasks.first?.id : tasks.last?.id
        }
    }

    private func toggleSelectedTask() {
        guard activeTab == .tasks, !showingAddForm else { return }
        guard let id = selectedTaskID, let task = timeFilteredTasks.first(where: { $0.id == id }) else { return }
        todoStore.toggle(task)
    }

    private func deleteSelectedTask() {
        guard activeTab == .tasks, !showingAddForm else { return }
        guard let id = selectedTaskID, let task = timeFilteredTasks.first(where: { $0.id == id }) else { return }
        let tasks = timeFilteredTasks
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            let nextID = tasks.count > 1 ? tasks[idx > 0 ? idx - 1 : 1].id : nil
            selectedTaskID = nextID
        }
        deleteWithSnackbar(task)
    }


    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(0.30), themeC2.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 34, height: 34)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("BeeFocus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text(todayHeaderString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(themeC1.opacity(0.8))
            }
            Spacer()
            Button { withAnimation(.spring(response: 0.28)) { showingSettings = true } } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Einstellungen")

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .help("BeeFocus beenden")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [themeC1.opacity(0.07), themeC2.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    private var todayHeaderString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMM"
        return f.string(from: Date())
    }

    // MARK: - Settings Panel

    private var settingsHeader: some View {
        HStack {
            Button { withAnimation(.spring(response: 0.28)) { showingSettings = false } } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Zurück").font(.system(size: 13))
                }
                .foregroundStyle(themeC1)
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Einstellungen")
                    .font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                Text("Zurück").font(.system(size: 13))
            }
            .opacity(0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [themeC1.opacity(0.06), themeC2.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Theme picker
            settingsSectionLabel("Design", icon: "paintbrush.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allThemes, id: \.id) { theme in
                        let (c1, c2, _) = appThemaFarben(theme.id)
                        let selected    = activeTheme == theme.id
                        let col1 = theme.id.isEmpty ? Color.gray : c1
                        let col2 = theme.id.isEmpty ? Color.gray.opacity(0.6) : c2
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { activeTheme = theme.id }
                            NSUbiquitousKeyValueStore.default.set(theme.id, forKey: "aktivesStatistikThema")
                            NSUbiquitousKeyValueStore.default.synchronize()
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [col1, col2],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 32, height: 32)
                                        .shadow(color: col1.opacity(selected ? 0.5 : 0.15),
                                                radius: selected ? 6 : 2)
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else if theme.id.isEmpty {
                                        Image(systemName: "circle.slash")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .overlay(Circle().stroke(selected ? col1 : Color.clear, lineWidth: 2).scaleEffect(1.2))
                                Text(theme.label)
                                    .font(.system(size: 8, weight: selected ? .bold : .regular))
                                    .foregroundStyle(selected ? col1 : Color.secondary)
                                    .lineLimit(1).frame(width: 48)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.2), value: activeTheme)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 72)
            .themeGlass(cornerRadius: 12)

            // Timer settings
            settingsSectionLabel("Timer-Zeiten", icon: "timer")
            VStack(spacing: 0) {
                timerSettingRow("Fokuszeit", value: $timerMgr.focusDuration, range: 1...90, unit: "min")
                Divider().opacity(0.12).padding(.leading, 14)
                timerSettingRow("Kurze Pause", value: $timerMgr.shortBreak, range: 1...30, unit: "min")
                Divider().opacity(0.12).padding(.leading, 14)
                timerSettingRow("Lange Pause", value: $timerMgr.longBreak, range: 1...60, unit: "min")
                Divider().opacity(0.12).padding(.leading, 14)
                timerSettingRow("Sessions bis Pause", value: $timerMgr.sessionsUntilLong, range: 1...10, unit: "")
            }
            .themeGlass(cornerRadius: 12)

            // Behaviour toggles
            settingsSectionLabel("Verhalten", icon: "slider.horizontal.3")
            VStack(spacing: 0) {
                settingsToggleRow("Auto-Start (Pause/Fokus)", icon: "play.circle", binding: $timerMgr.autoStart)
                Divider().opacity(0.12).padding(.leading, 14)
                settingsToggleRow("Sound & Benachrichtigungen", icon: "bell.fill", binding: $timerMgr.soundEnabled)
            }
            .themeGlass(cornerRadius: 12)

            // AI settings
            settingsSectionLabel("KI Quick Input", icon: "sparkles")
            aiSettingsPanel

            // Auto-Delete
            settingsSectionLabel("Automatisches Löschen", icon: "checkmark.circle.fill")
            VStack(spacing: 0) {
                HStack {
                    Label("Auto-Delete erledigte", systemImage: "trash.circle")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $autoDeleteCompletedEnabled)
                        .toggleStyle(.switch).tint(themeC1).labelsHidden()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)

                Divider().opacity(0.12).padding(.leading, 14)

                HStack {
                    Label("Nach \(autoDeleteCompletedDays) Tagen", systemImage: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            if autoDeleteCompletedDays > 1 { autoDeleteCompletedDays -= 1 }
                        } label: {
                            Image(systemName: "minus").font(.system(size: 11, weight: .semibold))
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain).disabled(!autoDeleteCompletedEnabled)
                        Button {
                            if autoDeleteCompletedDays < 365 { autoDeleteCompletedDays += 1 }
                        } label: {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain).disabled(!autoDeleteCompletedEnabled)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .opacity(autoDeleteCompletedEnabled ? 1 : 0.4)

                Divider().opacity(0.12).padding(.leading, 14)

                let completedCount = todoStore.todos.filter(\.isCompleted).count
                Button { showAutoDeleteConfirm = true } label: {
                    HStack {
                        Label("Jetzt löschen (\(completedCount))", systemImage: "trash.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .disabled(completedCount == 0)
            }
            .themeGlass(cornerRadius: 12)
            .alert("Erledigte Aufgaben löschen?", isPresented: $showAutoDeleteConfirm) {
                Button("Löschen", role: .destructive) { todoStore.deleteCompleted() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Alle abgeschlossenen Aufgaben werden unwiderruflich gelöscht.")
            }

            // Sync
            settingsSectionLabel("Synchronisation", icon: "arrow.triangle.2.circlepath")
            VStack(spacing: 0) {
                Button {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    MacCloudSettingsSync.shared.forceSync()
                } label: {
                    HStack {
                        Label("Einstellungen syncen", systemImage: "icloud.and.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "arrow.up.right.square").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider().opacity(0.12).padding(.leading, 14)

                Button {
                    Task { await todoStore.fetchTodos() }
                } label: {
                    HStack {
                        Label("Aufgaben neu laden", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .themeGlass(cornerRadius: 12)

            // Shortcuts
            settingsSectionLabel("Tastaturkürzel", icon: "keyboard")
            VStack(spacing: 0) {
                HotkeyRecorderRow(
                    label: "App öffnen / schließen",
                    icon: "menubar.rectangle",
                    accent: themeC1,
                    config: hotkeyMgr.panelHotkey,
                    conflictLabel: hotkeyConflict(for: hotkeyMgr.panelHotkey, others: [
                        ("Timer starten / pausieren", hotkeyMgr.timerHotkey),
                        ("Neue Aufgabe",              hotkeyMgr.newTaskHotkey)
                    ]),
                    onUpdate: { hotkeyMgr.updatePanel($0) }
                )
                Divider().opacity(0.12).padding(.leading, 14)
                HotkeyRecorderRow(
                    label: "Timer starten / pausieren",
                    icon: "timer",
                    accent: themeC1,
                    config: hotkeyMgr.timerHotkey,
                    conflictLabel: hotkeyConflict(for: hotkeyMgr.timerHotkey, others: [
                        ("App öffnen / schließen", hotkeyMgr.panelHotkey),
                        ("Neue Aufgabe",            hotkeyMgr.newTaskHotkey)
                    ]),
                    onUpdate: { hotkeyMgr.updateTimer($0) }
                )
                Divider().opacity(0.12).padding(.leading, 14)
                HotkeyRecorderRow(
                    label: "Neue Aufgabe",
                    icon: "plus.circle",
                    accent: themeC1,
                    config: hotkeyMgr.newTaskHotkey,
                    conflictLabel: hotkeyConflict(for: hotkeyMgr.newTaskHotkey, others: [
                        ("App öffnen / schließen",    hotkeyMgr.panelHotkey),
                        ("Timer starten / pausieren", hotkeyMgr.timerHotkey)
                    ]),
                    onUpdate: { hotkeyMgr.updateNewTask($0) }
                )
            }
            .themeGlass(cornerRadius: 12)

            // Apply button
            Button {
                timerMgr.applySettings()
                withAnimation(.spring(response: 0.28)) { showingSettings = false }
            } label: {
                Text("Übernehmen")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .shadow(color: themeC1.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // Returns the label of the first OTHER action that uses the same key combo.
    private func hotkeyConflict(for config: HotkeyConfig,
                                 others: [(label: String, config: HotkeyConfig)]) -> String? {
        guard !config.isNone else { return nil }
        return others.first { $0.config.conflictsWith(config) }?.label
    }

    private func timerSettingRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            HStack(spacing: 8) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .frame(minWidth: 52, alignment: .center)
                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func settingsToggleRow(_ label: String, icon: String, binding: Binding<Bool>) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .tint(themeC1)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - AI Settings Panel

    @State private var aiKeyInput: String = ""
    @State private var aiKeyVisible: Bool = false
    @State private var aiKeySaved: Bool   = false

    private var aiSettingsPanel: some View {
        VStack(spacing: 0) {
            // Provider picker
            HStack {
                Text("Anbieter").font(.system(size: 13, weight: .medium))
                Spacer()
                Picker("", selection: $aiProviderRaw) {
                    ForEach(MacAIProvider.allCases, id: \.rawValue) { p in
                        Text(p.label).tag(p.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)

            Divider().opacity(0.12).padding(.leading, 14)

            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Group {
                        if aiKeyVisible {
                            TextField("API Key", text: $aiKeyInput)
                        } else {
                            SecureField("API Key", text: $aiKeyInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .onAppear {
                        aiKeyInput = MacKeychain.load(for: aiProvider.keychainKey) ?? ""
                    }
                    .onChange(of: aiProviderRaw) { _ in
                        aiKeyInput = MacKeychain.load(for: aiProvider.keychainKey) ?? ""
                        aiKeySaved = false
                    }

                    Button {
                        aiKeyVisible.toggle()
                    } label: {
                        Image(systemName: aiKeyVisible ? "eye.slash" : "eye")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        MacKeychain.save(aiKeyInput.trimmingCharacters(in: .whitespaces), for: aiProvider.keychainKey)
                        aiKeySaved = true
                    } label: {
                        Text(aiKeySaved ? "✓" : "Speichern")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(aiKeySaved ? .green : themeC1)
                    }
                    .buttonStyle(.plain)
                    .disabled(aiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)

                // Hint
                Text(aiProvider == .groq
                    ? "Groq: kostenlos unter console.groq.com → API Keys"
                    : "OpenAI: platform.openai.com → API Keys")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .themeGlass(cornerRadius: 12)
    }

    private func settingsSectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(themeC1.opacity(0.9))
            .textCase(.uppercase)
            .tracking(0.4)
    }

    // MARK: - Inline Add Form Header

    private var inlineAddFormHeader: some View {
        HStack {
            Button { dismissAddForm() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Zurück").font(.system(size: 13))
                }
                .foregroundStyle(themeC1)
            }
            .buttonStyle(.plain)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Neue Aufgabe").font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Button("Speichern") { saveInlineTask() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : themeC1)
                .buttonStyle(.plain)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [themeC1.opacity(0.06), themeC2.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Inline Add Form Body

    private var inlineAddForm: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Smart AI Input
            smartInputSection

            VStack(alignment: .leading, spacing: 6) {
                formLabel("Titel", icon: "pencil.line")
                TextField("Aufgabenname", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .themeGlass(cornerRadius: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                formLabel("Priorität", icon: "flag.fill")
                HStack(spacing: 8) {
                    ForEach(MacTodoPriority.allCases, id: \.self) { inlinePriorityChip($0) }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                formLabel("Fälligkeitsdatum", icon: "calendar")
                VStack(spacing: 0) {
                    Toggle(isOn: $newHasDueDate.animation(.spring(response: 0.3))) {
                        Text("Datum festlegen").font(.system(size: 13, weight: .medium))
                    }
                    .tint(themeC1)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    if newHasDueDate {
                        Divider().opacity(0.12).padding(.horizontal, 12)
                        DatePicker("", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(themeC1)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .themeGlass(cornerRadius: 10)
            }

            VStack(alignment: .leading, spacing: 6) {
                formLabel("Teilaufgaben", icon: "checklist")
                VStack(spacing: 0) {
                    ForEach($newSubTasks) { $sub in
                        HStack(spacing: 8) {
                            Button { withAnimation { sub.isCompleted.toggle() } } label: {
                                ZStack {
                                    Circle().stroke(sub.isCompleted ? themeC1 : Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 16, height: 16)
                                    if sub.isCompleted {
                                        Circle().fill(themeC1).frame(width: 16, height: 16)
                                        Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                            }.buttonStyle(.plain)
                            TextField("Teilaufgabe", text: $sub.title)
                                .textFieldStyle(.plain).font(.system(size: 13))
                                .strikethrough(sub.isCompleted, color: .secondary)
                            Spacer()
                            Button { withAnimation { newSubTasks.removeAll { $0.id == sub.id } } } label: {
                                Image(systemName: "minus.circle.fill").font(.system(size: 14)).foregroundStyle(Color.red.opacity(0.5))
                            }.buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        if sub.id != newSubTasks.last?.id { Divider().opacity(0.08).padding(.leading, 10) }
                    }
                    if !newSubTasks.isEmpty { Divider().opacity(0.08) }
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle").font(.system(size: 14)).foregroundStyle(themeC1)
                        TextField("Neue Teilaufgabe…", text: $newSubTaskInput, onCommit: addInlineSubTask)
                            .textFieldStyle(.plain).font(.system(size: 13))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                .themeGlass(cornerRadius: 10)
            }

            // Alle Optionen Button
            Button {
                dismissAddForm()
                MacAddTodoWindow.open(todoStore: todoStore)
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 12))
                    Text("Alle Optionen (Teilaufgaben, Wiederholung…)")
                        .font(.system(size: 12))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 11))
                }
                .foregroundStyle(themeC1.opacity(0.85))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .themeGlass(cornerRadius: 10)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Smart AI Input

    private var smartInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("KI Quick Input", icon: "sparkles")

            HStack(spacing: 8) {
                TextField("z.B. Zahnarzt Mittwoch 15 Uhr hohe Prio", text: $smartInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit { runSmartParse() }

                Button {
                    if isParsing { return }
                    runSmartParse()
                } label: {
                    Group {
                        if isParsing {
                            ProgressView().controlSize(.small).frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(smartInputText.isEmpty ? Color.secondary : themeC1)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(themeC1.opacity(smartInputText.isEmpty ? 0.06 : 0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(smartInputText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                .help("Mit KI ausfüllen (Return)")
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .themeGlass(cornerRadius: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(aiDidFill ? themeC1.opacity(0.5) : Color.clear, lineWidth: aiDidFill ? 1.5 : 0)
            )

            if let err = parseError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
            if aiDidFill {
                Label("Felder automatisch ausgefüllt", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(themeC1)
            }

            if MacKeychain.load(for: aiProvider.keychainKey) == nil {
                Button {
                    withAnimation { showingAddForm = false; showingSettings = true }
                } label: {
                    Label("API-Key in Einstellungen hinterlegen →", systemImage: "key.fill")
                        .font(.system(size: 11)).foregroundStyle(themeC1.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func runSmartParse() {
        let input = smartInputText.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }
        parseError = nil
        aiDidFill  = false
        isParsing  = true
        Task {
            do {
                let result = try await MacAIQuickInputService.parse(input: input, provider: aiProvider)
                await MainActor.run {
                    if !result.title.isEmpty       { newTitle    = result.title }
                    if !result.description.isEmpty { /* description not in inline form */ }
                    newPriority = result.priority
                    if let date = result.date      { newDueDate = date; newHasDueDate = true }
                    if let rem = result.reminderOffset { newReminderOffset = rem }
                    aiDidFill = true
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    parseError = error.localizedDescription
                    isParsing  = false
                }
            }
        }
    }

    // MARK: - Priority chips

    private func inlinePriorityChip(_ p: MacTodoPriority) -> some View {
        let rgb = p.color
        let color = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
        let selected = newPriority == p
        return Button {
            withAnimation(.spring(response: 0.25)) { newPriority = p }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(p.label)
                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? color : Color.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(selected ? color.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? color.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func formLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(themeC1.opacity(0.9))
            .textCase(.uppercase)
            .tracking(0.4)
    }

    private func saveInlineTask() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Flush any unconfirmed subtask input
        let pendingTitle = newSubTaskInput.trimmingCharacters(in: .whitespaces)
        var subTasks = newSubTasks
        if !pendingTitle.isEmpty { subTasks.append(MacSubTask(title: pendingTitle)) }
        todoStore.addTodo(MacTodoItem(
            title:                 trimmed,
            dueDate:               newHasDueDate ? newDueDate : nil,
            priority:              newPriority,
            subTasks:              subTasks,
            reminderOffsetMinutes: newReminderOffset
        ))
        dismissAddForm()
    }

    private func addInlineSubTask() {
        let t = newSubTaskInput.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation { newSubTasks.append(MacSubTask(title: t)) }
        newSubTaskInput = ""
    }

    private func dismissAddForm() {
        withAnimation(.spring(response: 0.3)) { showingAddForm = false }
        newTitle = ""; newPriority = .medium; newHasDueDate = false; newDueDate = Date()
        newReminderOffset = nil; smartInputText = ""; aiDidFill = false; parseError = nil
        newSubTasks = []; newSubTaskInput = ""
    }

    // MARK: - Timer Tab

    private var timerTab: some View {
        VStack(spacing: 12) {
            // Timer Ring Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: timerMgr.mode == .focus ? "brain.head.profile" : "cup.and.saucer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeC1)
                    Text(timerMgr.mode.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .kerning(1.2)
                    Spacer()
                    if timerMgr.isRunning {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                    }
                }

                ZStack {
                    Circle()
                        .stroke(themeC1.opacity(0.10), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: 1 - timerMgr.progress)
                        .stroke(
                            LinearGradient(colors: [themeC1, themeC2],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerMgr.progress)

                    VStack(spacing: 6) {
                        Text(timerMgr.timeString)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                        HStack(spacing: 5) {
                            ForEach(0..<4, id: \.self) { i in
                                let filled = i < (timerMgr.sessionCount % 4 == 0 && timerMgr.sessionCount > 0 ? 4 : timerMgr.sessionCount % 4)
                                Circle()
                                    .fill(filled
                                          ? LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing)
                                          : LinearGradient(colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 5, height: 5)
                                    .animation(.easeInOut(duration: 0.3), value: timerMgr.sessionCount)
                            }
                        }
                    }
                }
                .frame(width: 150, height: 150)

                HStack(spacing: 20) {
                    Button { timerMgr.reset() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.primary.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain).help("Zurücksetzen")

                    Button { timerMgr.startPause() } label: {
                        Image(systemName: timerMgr.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(
                                LinearGradient(colors: [themeC1, themeC2],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                            .shadow(color: themeC1.opacity(0.45), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.space, modifiers: [])
                    .help(timerMgr.isRunning ? "Pause" : "Start")

                    Button { timerMgr.skipToNext() } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color.primary.opacity(0.07), in: Circle())
                    }
                    .buttonStyle(.plain).help("Überspringen")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .themeGlass(cornerRadius: 18)
            .padding(.horizontal, 14)
            .padding(.top, 14)

            // Sessions card
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeC2)
                Text("Sessions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(timerMgr.sessionCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(themeC1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .themeGlass(cornerRadius: 14)
            .padding(.horizontal, 14)

            // Linked task
            timerLinkedTask
                .padding(.horizontal, 14)

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerLinkedTask: some View {
        VStack(spacing: 8) {
            if let taskID = timerMgr.linkedTaskID,
               let task = todoStore.activeTodos.first(where: { $0.id == taskID }) {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(themeC1)
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button { timerMgr.linkedTaskID = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .themeGlass(cornerRadius: 12)
            } else {
                Button { withAnimation(.spring(response: 0.25)) { showTimerTaskPicker.toggle() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(themeC1)
                        Text("Fokusaufgabe verknüpfen")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: showTimerTaskPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .themeGlass(cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }

            if showTimerTaskPicker {
                VStack(spacing: 0) {
                    ForEach(todoStore.activeTodos.prefix(5)) { task in
                        Button {
                            timerMgr.linkedTaskID = task.id
                            withAnimation { showTimerTaskPicker = false }
                        } label: {
                            HStack {
                                Text(task.title)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if task.id != todoStore.activeTodos.prefix(5).last?.id {
                            Divider().opacity(0.08).padding(.leading, 12)
                        }
                    }
                    if todoStore.activeTodos.isEmpty {
                        Text("Keine offenen Aufgaben")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(12)
                    }
                }
                .themeGlass(cornerRadius: 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: showTimerTaskPicker)
    }

    // MARK: - Tasks Tab

    // MARK: Folder group model
    private struct MacTodoFolderGroup: Identifiable {
        let id: String
        let title: String
        let icon: String
        let color: Color
        var todos: [MacTodoItem]
    }

    // MARK: Collapsed sections helpers
    private var collapsedSections: Set<String> {
        Set(collapsedSectionsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }
    private func setCollapsed(_ id: String, collapsed: Bool) {
        var s = collapsedSections
        if collapsed { s.insert(id) } else { s.remove(id) }
        collapsedSectionsString = s.joined(separator: ",")
    }

    // MARK: Filtered tasks
    private var timeFilteredTasks: [MacTodoItem] {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? now
        let tomStart   = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let tomEnd     = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomStart) ?? now
        let weekEnd    = cal.date(byAdding: .day, value: 6, to: todayEnd) ?? now

        let base = todoStore.activeTodos
        let searched = searchText.isEmpty ? base : base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

        switch timeFilter {
        case .alle:
            return searched
        case .heute:
            return searched.filter { guard let d = $0.dueDate else { return false }; return d >= todayStart && d <= todayEnd }
        case .morgen:
            return searched.filter { guard let d = $0.dueDate else { return false }; return d >= tomStart && d <= tomEnd }
        case .dieseWoche:
            return searched.filter { guard let d = $0.dueDate else { return false }; return d >= todayStart && d <= weekEnd }
        case .ueberfaellig:
            return searched.filter { $0.isOverdue }
        }
    }

    // MARK: Folder groups
    private var macTodoGroups: [MacTodoFolderGroup] {
        let tasks = timeFilteredTasks.filter { $0.customFolder == nil }
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? now
        let tomStart   = cal.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let tomEnd     = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomStart) ?? now
        let weekEnd    = cal.date(byAdding: .day, value: 6, to: todayEnd) ?? now

        let noDue      = tasks.filter { $0.dueDate == nil }
        let overdue    = tasks.filter { $0.isOverdue }
        let todayDue   = tasks.filter { guard let d = $0.dueDate else { return false }; return d >= todayStart && d <= todayEnd && !$0.isCompleted }
        let tomorrowDue = tasks.filter { guard let d = $0.dueDate else { return false }; return d >= tomStart && d <= tomEnd }
        let thisWeek   = tasks.filter { guard let d = $0.dueDate else { return false }; return d > tomEnd && d <= weekEnd }
        let later      = tasks.filter { guard let d = $0.dueDate else { return false }; return d > weekEnd }

        var groups: [MacTodoFolderGroup] = []
        // Heute – always shown
        groups.append(MacTodoFolderGroup(id: "__today__",    title: "Heute",       icon: "sun.max.fill",              color: .orange,  todos: todayDue))
        if !tomorrowDue.isEmpty {
            groups.append(MacTodoFolderGroup(id: "__tomorrow__", title: "Morgen",       icon: "moon.stars.fill",           color: .indigo,  todos: tomorrowDue))
        }
        if !noDue.isEmpty {
            groups.append(MacTodoFolderGroup(id: "__general__",  title: "Allgemein",    icon: "tray.fill",                 color: .secondary, todos: noDue))
        }
        if !overdue.isEmpty {
            groups.append(MacTodoFolderGroup(id: "__overdue__",  title: "Überfällig",   icon: "exclamationmark.circle.fill", color: .red,    todos: overdue))
        }
        if !thisWeek.isEmpty {
            groups.append(MacTodoFolderGroup(id: "__week__",     title: "Diese Woche",  icon: "calendar.badge.clock",      color: .blue,    todos: thisWeek))
        }
        if !later.isEmpty {
            groups.append(MacTodoFolderGroup(id: "__later__",    title: "Später",       icon: "arrow.forward.circle.fill", color: .teal,    todos: later))
        }
        // Custom folders
        for folderName in todoStore.customFolders {
            let folderTasks = timeFilteredTasks.filter { $0.customFolder == folderName }
            groups.append(MacTodoFolderGroup(id: "__custom__\(folderName)", title: folderName, icon: "folder.fill", color: .indigo, todos: folderTasks))
        }
        return groups
    }

    // MARK: Highlight card
    private var highlightCard: some View {
        Group {
            if let uid = UUID(uuidString: highlightIDStr),
               let todo = todoStore.activeTodos.first(where: { $0.id == uid }) {
                HStack(spacing: 10) {
                    Text("⭐️").font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Highlight").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                        Text(todo.title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    }
                    Spacer()
                    Button {
                        todoStore.toggle(todo)
                        highlightIDStr = ""
                    } label: {
                        Image(systemName: "checkmark.circle").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.4, blue: 0).opacity(0.35), Color(red: 0.4, green: 0.25, blue: 0).opacity(0.25)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 1.0, green: 0.85, blue: 0.2).opacity(0.35), lineWidth: 1.5))
                .padding(.horizontal, 14).padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.35), value: highlightIDStr)
    }

    // MARK: Delete snackbar
    @ViewBuilder
    private var deleteSnackbar: some View {
        if showDeleteSnackbar {
            HStack(spacing: 10) {
                Image(systemName: "trash").foregroundStyle(.white).font(.system(size: 13))
                Text("Aufgabe gelöscht").font(.system(size: 13)).foregroundStyle(.white).lineLimit(1)
                Spacer()
                Button {
                    snackbarDismissTask?.cancel()
                    withAnimation { showDeleteSnackbar = false; todoStore.undo() }
                } label: {
                    Text("Rückgängig").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.black.opacity(0.85), in: Capsule())
            .padding(.horizontal, 14).padding(.bottom, 52)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: showDeleteSnackbar)
        }
    }

    // MARK: Folder picker overlay
    @ViewBuilder
    private var folderPickerOverlay: some View {
        if showFolderPicker {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                    .onTapGesture { withAnimation { showFolderPicker = false; pendingFolderTaskID = nil } }

                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("In Ordner verschieben").font(.system(size: 15, weight: .bold))
                                if let id = pendingFolderTaskID,
                                   let todo = todoStore.todos.first(where: { $0.id == id }) {
                                    Text(todo.title).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            Button {
                                withAnimation { showFolderPicker = false; pendingFolderTaskID = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        if todoStore.customFolders.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "folder.badge.questionmark").font(.system(size: 28)).foregroundStyle(.secondary)
                                Text("Noch keine Ordner.\nOrdner im + Menü anlegen.")
                                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 10)
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                Button {
                                    if let id = pendingFolderTaskID { todoStore.assignTodo(id, toFolder: nil) }
                                    withAnimation { showFolderPicker = false; pendingFolderTaskID = nil }
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)).frame(width: 44, height: 44)
                                            Image(systemName: "tray.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.secondary)
                                        }
                                        Text("Allgemein").font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                ForEach(todoStore.customFolders, id: \.self) { folder in
                                    Button {
                                        if let id = pendingFolderTaskID { todoStore.assignTodo(id, toFolder: folder) }
                                        withAnimation { showFolderPicker = false; pendingFolderTaskID = nil }
                                    } label: {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.1)).frame(width: 44, height: 44)
                                                Image(systemName: "folder.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.indigo)
                                            }
                                            Text(folder).font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(Color.indigo.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 20).padding(.bottom, 20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 8).padding(.bottom, 8)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showFolderPicker)
        }
    }

    // MARK: Delete with snackbar
    private func deleteWithSnackbar(_ todo: MacTodoItem) {
        snackbarDismissTask?.cancel()
        todoStore.delete(todo)
        withAnimation { showDeleteSnackbar = true }
        snackbarDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showDeleteSnackbar = false } }
        }
    }

    // MARK: Folder section
    private func macFolderSection(_ group: MacTodoFolderGroup) -> some View {
        let isCollapsed = collapsedSections.contains(group.id)
        let isCustom = group.id.hasPrefix("__custom__")
        let folderName = isCustom ? String(group.id.dropFirst("__custom__".count)) : nil

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    setCollapsed(group.id, collapsed: !isCollapsed)
                }
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(group.color).frame(width: 3, height: 24)

                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(group.color.opacity(0.15)).frame(width: 28, height: 28)
                        Image(systemName: group.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(group.color)
                    }

                    Text(group.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 6) {
                        if !group.todos.isEmpty {
                            Text("\(group.todos.count)")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(group.color)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(group.color.opacity(0.12), in: Capsule())
                        }
                        if let name = folderName {
                            Button {
                                todoStore.removeCustomFolder(name)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.red.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                if group.todos.isEmpty && group.id == "__today__" {
                    VStack(spacing: 6) {
                        Image(systemName: "sun.and.horizon.fill").font(.system(size: 22)).foregroundStyle(Color.orange.opacity(0.6))
                        Text("Heute keine Aufgaben").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                } else if group.todos.isEmpty {
                    Text("Keine Aufgaben").font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                } else {
                    VStack(spacing: 5) {
                        ForEach(group.todos) { taskRow($0) }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 8)
                }
            }
        }
        .themeGlass(cornerRadius: 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCollapsed)
    }

    // MARK: Main tasks tab
    private var tasksTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("Aufgaben")
                    .font(.system(size: 16, weight: .bold))
                if !timeFilteredTasks.isEmpty {
                    Text("\(timeFilteredTasks.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(accent.opacity(0.12), in: Capsule())
                }
                Spacer()
                HStack(spacing: 6) {
                    // Multi-select toggle
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            isSelecting.toggle()
                            if !isSelecting { selectedTaskIDs.removeAll() }
                        }
                    } label: {
                        Image(systemName: isSelecting ? "checkmark.circle.fill" : "checkmark.circle.badge.plus")
                            .font(.system(size: 14))
                            .foregroundStyle(isSelecting ? accent : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain).help("Mehrfachauswahl")

                    // Show completed toggle
                    Button {
                        withAnimation(.spring(response: 0.25)) { showCompleted.toggle() }
                    } label: {
                        Image(systemName: showCompleted ? "eye.fill" : "eye")
                            .font(.system(size: 14))
                            .foregroundStyle(showCompleted ? accent : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain).help("Erledigte anzeigen")

                    // New folder button
                    Button {
                        newFolderName = ""
                        showAddFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain).help("Neuer Ordner")

                    // Add task button
                    Button {
                        withAnimation(.spring(response: 0.3)) { showingAddForm = true }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 26, height: 26)
                            .background(accent.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain).help("Neue Aufgabe (⌘N)")
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

            // Multi-select action bar
            if isSelecting && !selectedTaskIDs.isEmpty {
                HStack(spacing: 10) {
                    Text("\(selectedTaskIDs.count) ausgewählt")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation { showFolderPicker = true }
                        pendingFolderTaskID = selectedTaskIDs.first
                    } label: {
                        Label("Ordner", systemImage: "folder").font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    Button {
                        for id in selectedTaskIDs {
                            if let todo = todoStore.todos.first(where: { $0.id == id }) {
                                todoStore.delete(todo)
                            }
                        }
                        selectedTaskIDs.removeAll()
                        isSelecting = false
                    } label: {
                        Label("Löschen", systemImage: "trash").font(.system(size: 12)).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 14).padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Highlight card
            highlightCard

            // Search bar
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.tertiary)
                TextField("Suchen …", text: $searchText)
                    .textFieldStyle(.plain).font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color.secondary.opacity(0.4))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 6)

            // Time filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MacTodoTimeFilter.allCases, id: \.self) { filter in
                        let isSelected = timeFilter == filter
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { timeFilter = filter }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: filter.icon).font(.system(size: 11, weight: .semibold))
                                Text(filter.label).font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isSelected ? filter.color.opacity(0.20) : Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(
                                isSelected ? filter.color.opacity(0.7) : Color.secondary.opacity(0.22),
                                lineWidth: 1.5
                            ))
                            .foregroundStyle(isSelected ? filter.color : Color.primary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: isSelected)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)

            // Folder sections
            VStack(spacing: 8) {
                ForEach(macTodoGroups) { group in
                    macFolderSection(group)
                }
            }
            .padding(.horizontal, 14)

            // Completed section
            if showCompleted {
                let completedTasks = todoStore.todos.filter { $0.isCompleted }
                if !completedTasks.isEmpty {
                    HStack {
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                        Text("Erledigt").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).fixedSize()
                        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)

                    VStack(spacing: 6) {
                        ForEach(completedTasks.sorted { $0.updatedAt > $1.updatedAt }) { taskRow($0) }
                    }
                    .padding(.horizontal, 14)
                }
            }

            Spacer(minLength: 10)
        }
    }

    private func taskRow(_ todo: MacTodoItem) -> some View {
        let isExpanded  = expandedTaskID == todo.id
        let isSelected  = selectedTaskID == todo.id
        let isMultiSel  = selectedTaskIDs.contains(todo.id)
        let doneCount   = todo.subTasks.filter(\.isCompleted).count
        let totalCount  = todo.subTasks.count
        let isHighlight = highlightIDStr == todo.id.uuidString

        let priorityColor: Color = {
            switch todo.priority {
            case .high:   return .red
            case .medium: return .orange
            case .low:    return .green
            }
        }()

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Multi-select checkbox
                if isSelecting {
                    Button {
                        if isMultiSel { selectedTaskIDs.remove(todo.id) } else { selectedTaskIDs.insert(todo.id) }
                    } label: {
                        Image(systemName: isMultiSel ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(isMultiSel ? accent : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                // Highlight star badge
                if isHighlight {
                    Text("⭐️").font(.system(size: 11))
                }

                // Completion toggle
                Button { todoStore.toggle(todo) } label: {
                    ZStack {
                        Circle().fill(todo.isCompleted ? priorityColor : .clear).frame(width: 20, height: 20)
                        Circle().stroke(priorityColor.opacity(todo.isCompleted ? 1 : 0.45), lineWidth: 1.5).frame(width: 20, height: 20)
                        if todo.isCompleted {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                // Title + metadata
                Button {
                    guard totalCount > 0 else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                        expandedTaskID = isExpanded ? nil : todo.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(todo.title)
                                .font(.system(size: 13, weight: .medium))
                                .strikethrough(todo.isCompleted, color: .secondary)
                                .foregroundStyle(todo.isCompleted ? Color.secondary.opacity(0.5) : Color.primary)
                                .lineLimit(1)
                            if let due = todo.dueDate {
                                HStack(spacing: 3) {
                                    Image(systemName: "calendar").font(.system(size: 9))
                                    Text(dueDateLabel(due)).font(.system(size: 10))
                                }
                                .foregroundStyle(todo.isOverdue ? .red : .secondary)
                            }
                        }
                        if totalCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist").font(.system(size: 9))
                                Text("\(doneCount)/\(totalCount)").font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(doneCount == totalCount ? Color.green : accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background((doneCount == totalCount ? Color.green : accent).opacity(0.12), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                if totalCount > 0 {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Color.secondary.opacity(0.4))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .themeGlass(cornerRadius: 10)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(todo.isCompleted ? 0.25 : 0.85), themeC2.opacity(todo.isCompleted ? 0.15 : 0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3).padding(.vertical, 8)
            }
            .background(isMultiSel ? accent.opacity(0.10) : (isSelected ? accent.opacity(0.06) : Color.clear))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        if isSelecting {
                            if isMultiSel { selectedTaskIDs.remove(todo.id) } else { selectedTaskIDs.insert(todo.id) }
                        } else {
                            selectedTaskID = todo.id
                        }
                    }
            )
            .contextMenu {
                if !todo.isCompleted {
                    Button {
                        highlightIDStr = isHighlight ? "" : todo.id.uuidString
                    } label: {
                        Label(isHighlight ? "Highlight entfernen" : "Als Highlight setzen",
                              systemImage: isHighlight ? "star.slash" : "star.fill")
                    }
                    Button {
                        todoStore.toggleFavorite(todo)
                    } label: {
                        Label(todo.isFavorite ? "Favorit entfernen" : "Als Favorit markieren",
                              systemImage: todo.isFavorite ? "heart.slash" : "heart.fill")
                    }
                }
                if !todoStore.customFolders.isEmpty || todo.customFolder != nil {
                    Menu("In Ordner verschieben") {
                        Button("Allgemein") { todoStore.assignTodo(todo.id, toFolder: nil) }
                        ForEach(todoStore.customFolders, id: \.self) { folder in
                            Button(folder) { todoStore.assignTodo(todo.id, toFolder: folder) }
                        }
                    }
                }
                Divider()
                Button(role: .destructive) {
                    deleteWithSnackbar(todo)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
            .opacity(todo.isCompleted ? 0.6 : 1.0)

            if isExpanded && totalCount > 0 {
                VStack(spacing: 0) {
                    ForEach(todo.subTasks) { sub in
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.clear).frame(width: 22)
                            Button {
                                var updated = todo
                                if let idx = updated.subTasks.firstIndex(where: { $0.id == sub.id }) {
                                    updated.subTasks[idx].isCompleted.toggle()
                                    todoStore.update(updated)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(sub.isCompleted ? Color.green : Color.secondary.opacity(0.35), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                    if sub.isCompleted {
                                        Circle().fill(Color.green).frame(width: 14, height: 14)
                                        Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            Text(sub.title)
                                .font(.system(size: 12))
                                .strikethrough(sub.isCompleted, color: .secondary)
                                .foregroundStyle(sub.isCompleted ? Color.secondary.opacity(0.4) : Color.primary.opacity(0.75))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        if sub.id != todo.subTasks.last?.id {
                            Divider().opacity(0.07).padding(.leading, 48)
                        }
                    }
                }
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 3)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func dueDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Heute" }
        if cal.isDateInTomorrow(date)  { return "Morgen" }
        if cal.isDateInYesterday(date) { return "Gestern" }
        let f = DateFormatter(); f.dateFormat = "d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    // MARK: - Planner Tab

    private var plannerTab: some View {
        let today = todayTimedTodos
        let doneCount = today.filter(\.isCompleted).count

        return VStack(alignment: .leading, spacing: 12) {
            // Header card
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.day.timeline.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeC1)
                        Text("Tagesplan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(shortDateString)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(today.count) Aufgabe\(today.count == 1 ? "" : "n") · \(doneCount) erledigt")
                        .font(.caption)
                        .foregroundStyle(themeC1.opacity(0.85))
                }
                Spacer()
                if !today.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(themeC1.opacity(0.15), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: today.isEmpty ? 0 : CGFloat(doneCount) / CGFloat(today.count))
                            .stroke(
                                LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: doneCount)
                        Text("\(Int((CGFloat(doneCount) / CGFloat(max(today.count, 1))) * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 48, height: 48)
                }
            }
            .padding(14)
            .themeGlass(cornerRadius: 16)

            // Task list
            if today.isEmpty {
                emptyState(icon: "calendar.badge.checkmark", text: "Nichts für heute geplant")
            } else {
                VStack(spacing: 6) {
                    ForEach(today) { todo in
                        HStack(spacing: 10) {
                            Button { todoStore.toggle(todo) } label: {
                                ZStack {
                                    Circle()
                                        .fill(todo.isCompleted
                                              ? LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing)
                                              : LinearGradient(colors: [.clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .stroke(todo.isCompleted ? themeC1 : Color.secondary.opacity(0.35), lineWidth: 1.5)
                                        .frame(width: 20, height: 20)
                                    if todo.isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(todo.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .strikethrough(todo.isCompleted, color: .secondary)
                                    .foregroundStyle(todo.isCompleted ? Color.secondary.opacity(0.5) : Color.primary)
                                    .lineLimit(1)
                                if let due = todo.dueDate {
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock").font(.system(size: 9))
                                        Text(timeString(due)).font(.system(size: 10))
                                    }
                                    .foregroundStyle(themeC1.opacity(0.8))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .themeGlass(cornerRadius: 10)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [themeC1.opacity(todo.isCompleted ? 0.25 : 0.85),
                                                 themeC2.opacity(todo.isCompleted ? 0.15 : 0.55)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 3)
                                .padding(.vertical, 8)
                        }
                        .opacity(todo.isCompleted ? 0.6 : 1.0)
                    }
                }
            }

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    // MARK: - Stats Tab

    private func formatFocusDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 min" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m) min"
    }

    private var statsTab: some View {
        VStack(spacing: 10) {

            // Fokus: Heute / Woche
            HStack(spacing: 10) {
                statCard(
                    title: "Heute",
                    value: formatFocusDuration(timerMgr.todayFocusSeconds),
                    subtitle: timerMgr.isRunning && timerMgr.mode == .focus ? "aktiv" : "Fokuszeit",
                    icon: "sun.max.fill",
                    color: themeC1,
                    isLive: timerMgr.isRunning && timerMgr.mode == .focus
                )
                statCard(
                    title: "Diese Woche",
                    value: formatFocusDuration(timerMgr.weekFocusSeconds),
                    subtitle: "7 Tage",
                    icon: "calendar",
                    color: themeC2,
                    isLive: false
                )
            }

            // Streak + Tages-Ziel
            HStack(spacing: 10) {
                statsStreakCard
                statsGoalCard
            }

            // 7-Tage-Chart
            statsChartCard

            // Wochenvergleich
            statsWeekCompareCard

            // Aufgaben
            HStack(spacing: 10) {
                statCard(
                    title: "Sessions",
                    value: "\(timerMgr.sessionCount)",
                    subtitle: "gesamt",
                    icon: "timer",
                    color: themeC1,
                    isLive: timerMgr.isRunning
                )
                statCard(
                    title: "Erledigt",
                    value: "\(completedThisMonth)",
                    subtitle: currentMonthLabel,
                    icon: "checkmark.circle.fill",
                    color: themeC2,
                    isLive: false
                )
            }
            HStack(spacing: 10) {
                statCard(
                    title: "Offen",
                    value: "\(thisMonthActiveTodos.count)",
                    subtitle: currentMonthLabel,
                    icon: "circle.dotted",
                    color: accent,
                    isLive: false
                )
                statCard(
                    title: "Überfällig",
                    value: "\(thisMonthOverdueTodos.count)",
                    subtitle: "Aufgaben",
                    icon: "exclamationmark.circle.fill",
                    color: thisMonthOverdueTodos.isEmpty ? .secondary : .red,
                    isLive: false
                )
            }

            // All-Time
            statsAllTimeCard

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
    }

    // MARK: Streak card
    private var statsStreakCard: some View {
        let streak = timerMgr.currentStreak
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.orange)
                Text("Streak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(streak)").font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                Text(streak == 1 ? "Tag" : "Tage")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 2)
            }
            Text(streak == 0 ? "Fang heute an 🔥" : streak < 3 ? "Weiter so!" : streak < 7 ? "Guter Lauf!" : "Auf Feuer! 🔥")
                .font(.caption).foregroundStyle(Color.orange.opacity(0.9))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).themeGlass(cornerRadius: 16)
    }

    // MARK: Goal card
    private var statsGoalCard: some View {
        let goal = dailyGoalMinutes
        let progress: Double = goal > 0 ? min(1.0, Double(timerMgr.todayFocusSeconds) / Double(goal * 60)) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "target").font(.system(size: 13, weight: .semibold)).foregroundStyle(.mint)
                Text("Tagesziel").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if progress >= 1.0 {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(.mint)
                }
            }
            ZStack {
                Circle().stroke(Color.mint.opacity(0.15), lineWidth: 7)
                Circle().trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.mint, themeC1], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .frame(width: 52, height: 52).frame(maxWidth: .infinity)
            Text("\(goal) min Ziel").font(.caption).foregroundStyle(Color.mint.opacity(0.9))
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).themeGlass(cornerRadius: 16)
    }

    // MARK: 7-day chart
    private var statsChartCard: some View {
        let data = timerMgr.last7DaysData
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Letzte 7 Tage").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("in Minuten").font(.caption).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(data, id: \.date) { entry in
                    let minutes = entry.seconds / 60
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    BarMark(
                        x: .value("Tag", entry.date, unit: .day),
                        y: .value("Minuten", minutes)
                    )
                    .foregroundStyle(
                        isToday
                            ? LinearGradient(colors: [themeC1, themeC2], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [themeC1.opacity(0.35), themeC1.opacity(0.55)], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(5)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.secondary)
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                }
            }
            .frame(height: 120)
        }
        .padding(16).themeGlass(cornerRadius: 16)
    }

    // MARK: Weekly comparison
    private var statsWeekCompareCard: some View {
        let thisWeek = timerMgr.weekFocusSeconds
        let lastWeek = timerMgr.lastWeekFocusSeconds
        let trendPositiv = thisWeek >= lastWeek
        let trendColor: Color = trendPositiv ? .green : .red
        let trendIcon = trendPositiv ? "arrow.up.right" : "arrow.down.right"
        let trendText: String = {
            guard lastWeek > 0 else { return thisWeek > 0 ? "+100%" : "0%" }
            let pct = Int(Double(thisWeek - lastWeek) / Double(lastWeek) * 100)
            return (pct >= 0 ? "+" : "") + "\(pct)%"
        }()
        let blueAccent = Color(red: 0.4, green: 0.6, blue: 1.0)
        let maxSec = max(thisWeek, lastWeek, 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 13, weight: .semibold)).foregroundStyle(blueAccent)
                Text("Wochenvergleich").font(.system(size: 13, weight: .semibold))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: trendIcon).font(.system(size: 10, weight: .bold))
                    Text(trendText).font(.caption.weight(.bold))
                }
                .foregroundStyle(lastWeek == 0 ? blueAccent : trendColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((lastWeek == 0 ? blueAccent : trendColor).opacity(0.12), in: Capsule())
            }

            VStack(spacing: 6) {
                weekBar(label: "Letzte Woche", seconds: lastWeek, maxSeconds: maxSec, color: blueAccent.opacity(0.45))
                weekBar(label: "Diese Woche",  seconds: thisWeek, maxSeconds: maxSec, color: blueAccent)
            }

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Letzte Woche").font(.caption2).foregroundStyle(.secondary)
                    Text(formatFocusDuration(lastWeek)).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Diese Woche").font(.caption2).foregroundStyle(.secondary)
                    Text(formatFocusDuration(thisWeek)).font(.system(size: 13, weight: .bold, design: .rounded))
                }
            }
        }
        .padding(16).themeGlass(cornerRadius: 16)
    }

    private func weekBar(label: String, seconds: Int, maxSeconds: Int, color: Color) -> some View {
        let ratio = maxSeconds > 0 ? CGFloat(seconds) / CGFloat(maxSeconds) : 0
        return HStack(spacing: 8) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 72, alignment: .leading)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * ratio), height: 10)
                    .animation(.easeOut(duration: 0.5), value: seconds)
            }
            .frame(height: 10)
        }
    }

    // MARK: All-time card
    private var statsAllTimeCard: some View {
        VStack(spacing: 0) {
            statsAllTimeRow(label: "Gesamt Fokuszeit", value: formatFocusDuration(timerMgr.allTimeFocusSeconds), icon: "infinity", color: themeC1)
            Divider().opacity(0.15).padding(.horizontal, 14)
            statsAllTimeRow(label: "Aktive Tage", value: "\(timerMgr.activeFocusDays)", icon: "calendar.badge.checkmark", color: themeC2)
            Divider().opacity(0.15).padding(.horizontal, 14)
            statsAllTimeRow(label: "Bester Tag", value: formatFocusDuration(timerMgr.bestDaySeconds), icon: "trophy.fill", color: themeC1)
        }
        .themeGlass(cornerRadius: 16)
    }

    private func statsAllTimeRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 30, height: 30)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(label).font(.system(size: 13)).foregroundStyle(.primary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color, isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if isLive {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                }
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(color.opacity(0.8))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeGlass(cornerRadius: 16)
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                let isActive = activeTab == tab
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { activeTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive
                                ? LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.secondary.opacity(0.5), Color.secondary.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text(tab.label)
                            .font(.system(size: 9, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? themeC1 : Color.secondary.opacity(0.5))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background {
                        if isActive {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(
                                    colors: [themeC1.opacity(0.14), themeC2.opacity(0.08)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .matchedGeometryEffect(id: "tabBG", in: tabNS)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [themeC1.opacity(0.06), themeC2.opacity(0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Empty State

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(accent.opacity(0.45))
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28)
    }

    // MARK: - Month filter helpers

    private var thisMonthActiveTodos: [MacTodoItem] {
        let cal = Calendar.current
        let now = Date()
        return todoStore.activeTodos.filter { todo in
            guard let due = todo.dueDate else { return true }
            return cal.isDate(due, equalTo: now, toGranularity: .month)
        }
    }

    private var thisMonthOverdueTodos: [MacTodoItem] {
        let cal = Calendar.current
        let now = Date()
        return todoStore.overdueTodos.filter { todo in
            guard let due = todo.dueDate else { return false }
            return cal.isDate(due, equalTo: now, toGranularity: .month)
        }
    }

    private var completedThisMonth: Int {
        let cal = Calendar.current
        let now = Date()
        return todoStore.todos.filter {
            $0.isCompleted && cal.isDate($0.updatedAt, equalTo: now, toGranularity: .month)
        }.count
    }

    private var currentMonthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "MMMM"
        return f.string(from: Date())
    }

    // MARK: - Helpers

    private var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE, d. MMM"
        return f.string(from: Date())
    }

    private var todayTimedTodos: [MacTodoItem] {
        let cal = Calendar.current
        return todoStore.todos
            .filter { guard let due = $0.dueDate else { return false }
                      return cal.isDate(due, inSameDayAs: Date()) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
