import SwiftUI
import AppKit

// MARK: - Tab enum

private enum MenuBarTab: CaseIterable {
    case tasks, planner, timer, stats

    var icon: String {
        switch self {
        case .tasks:   return "checklist"
        case .planner: return "calendar.day.timeline.left"
        case .timer:   return "timer"
        case .stats:   return "chart.bar.fill"
        }
    }

    var label: String {
        switch self {
        case .tasks:   return "Aufgaben"
        case .planner: return "Tag"
        case .timer:   return "Timer"
        case .stats:   return "Statistik"
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
    @State private var showingSettings = false

    // Subtask expansion
    @State private var expandedTaskID: UUID? = nil

    // Inline form subtasks
    @State private var newSubTasks: [MacSubTask] = []
    @State private var newSubTaskInput: String = ""

    // Tasks filters
    @State private var searchText      = ""
    @State private var priorityFilter: MacTodoPriority? = nil
    @State private var showCompleted   = false

    // Timer task picker
    @State private var showTimerTaskPicker = false

    // Command palette
    @State private var showingCommandPalette = false

    // Task list keyboard navigation
    @State private var selectedTaskID: UUID? = nil

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }
    private var themeC1: Color { appThemaFarben(activeTheme).0 }
    private var themeC2: Color { appThemaFarben(activeTheme).1 }

    var body: some View {
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
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider().opacity(0.2)
                bottomTabBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(commandPaletteOverlay)
        .background(keyboardShortcutLayer)
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
        let tasks = filteredTasks
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
        guard let id = selectedTaskID, let task = filteredTasks.first(where: { $0.id == id }) else { return }
        todoStore.toggle(task)
    }

    private func deleteSelectedTask() {
        guard activeTab == .tasks, !showingAddForm else { return }
        guard let id = selectedTaskID, let task = filteredTasks.first(where: { $0.id == id }) else { return }
        let tasks = filteredTasks
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            let nextID = tasks.count > 1 ? tasks[idx > 0 ? idx - 1 : 1].id : nil
            selectedTaskID = nextID
        }
        todoStore.delete(task)
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))

            // Behaviour toggles
            settingsSectionLabel("Verhalten", icon: "slider.horizontal.3")
            VStack(spacing: 0) {
                settingsToggleRow("Auto-Start (Pause/Fokus)", icon: "play.circle", binding: $timerMgr.autoStart)
                Divider().opacity(0.12).padding(.leading, 14)
                settingsToggleRow("Sound & Benachrichtigungen", icon: "bell.fill", binding: $timerMgr.soundEnabled)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))

            // AI settings
            settingsSectionLabel("KI Quick Input", icon: "sparkles")
            aiSettingsPanel

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
                    .background(accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
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
                .tint(accent)
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
                            .foregroundStyle(aiKeySaved ? .green : accent)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    private func settingsSectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent.opacity(0.85))
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
                .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Neue Aufgabe").font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Speichern") { saveInlineTask() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(newTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary : accent)
                .buttonStyle(.plain)
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
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
                    .tint(accent)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    if newHasDueDate {
                        Divider().opacity(0.15).padding(.horizontal, 12)
                        DatePicker("", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(accent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
            // Subtasks
            VStack(alignment: .leading, spacing: 6) {
                formLabel("Teilaufgaben", icon: "checklist")
                VStack(spacing: 0) {
                    ForEach($newSubTasks) { $sub in
                        HStack(spacing: 8) {
                            Button { withAnimation { sub.isCompleted.toggle() } } label: {
                                ZStack {
                                    Circle().stroke(sub.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 16, height: 16)
                                    if sub.isCompleted {
                                        Circle().fill(Color.green).frame(width: 16, height: 16)
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
                        if sub.id != newSubTasks.last?.id { Divider().opacity(0.1).padding(.leading, 10) }
                    }
                    if !newSubTasks.isEmpty { Divider().opacity(0.1) }
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle").font(.system(size: 14)).foregroundStyle(accent)
                        TextField("Neue Teilaufgabe…", text: $newSubTaskInput, onCommit: addInlineSubTask)
                            .textFieldStyle(.plain).font(.system(size: 13))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }

            // Button zum vollständigen Formular
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
                .foregroundStyle(accent.opacity(0.8))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
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
                                .foregroundStyle(smartInputText.isEmpty ? Color.secondary : accent)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(smartInputText.isEmpty ? 0.06 : 0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(smartInputText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                .help("Mit KI ausfüllen (Return)")
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(aiDidFill ? accent.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: aiDidFill ? 1.5 : 1)
            )

            if let err = parseError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
            }
            if aiDidFill {
                Label("Felder automatisch ausgefüllt", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(accent)
            }

            // Kein Key konfiguriert
            if MacKeychain.load(for: aiProvider.keychainKey) == nil {
                Button {
                    withAnimation { showingAddForm = false; showingSettings = true }
                } label: {
                    Label("API-Key in Einstellungen hinterlegen →", systemImage: "key.fill")
                        .font(.system(size: 11)).foregroundStyle(accent.opacity(0.8))
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
            .foregroundStyle(accent.opacity(0.85))
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

    private var filteredTasks: [MacTodoItem] {
        var tasks = thisMonthActiveTodos
        if let pf = priorityFilter { tasks = tasks.filter { $0.priority == pf } }
        if !searchText.isEmpty { tasks = tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
        return tasks
    }

    private var filteredCompletedTasks: [MacTodoItem] {
        let cal = Calendar.current
        let now = Date()
        var tasks = todoStore.todos.filter {
            $0.isCompleted &&
            (($0.dueDate == nil) || $0.dueDate.map { cal.isDate($0, equalTo: now, toGranularity: .month) } == true)
        }
        if let pf = priorityFilter { tasks = tasks.filter { $0.priority == pf } }
        if !searchText.isEmpty { tasks = tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
        return tasks.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var tasksTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Aufgaben")
                        .font(.system(size: 16, weight: .bold))
                    Text(currentMonthLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    if filteredTasks.count > 0 {
                        Text("\(filteredTasks.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(accent.opacity(0.12), in: Capsule())
                    }
                    Button {
                        withAnimation(.spring(response: 0.25)) { showCompleted.toggle() }
                    } label: {
                        Image(systemName: showCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(showCompleted ? accent : Color.secondary.opacity(0.5))
                    }
                    .buttonStyle(.plain).help("Erledigte anzeigen")

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
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 10)

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
            .padding(.horizontal, 14).padding(.bottom, 8)

            // Priority filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    priorityChip(nil, label: "Alle")
                    ForEach(MacTodoPriority.allCases, id: \.self) { p in
                        let rgb = p.color
                        let c = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
                        priorityChip(p, label: p.label, color: c)
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 10)

            // Task list
            if filteredTasks.isEmpty && !showCompleted {
                emptyState(icon: "checkmark.circle",
                           text: searchText.isEmpty ? "Keine offenen Aufgaben" : "Keine Treffer")
            } else {
                VStack(spacing: 6) {
                    ForEach(filteredTasks) { taskRow($0) }
                }
                .padding(.horizontal, 14)

                if showCompleted {
                    if !filteredTasks.isEmpty {
                        HStack {
                            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                            Text("Erledigt")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary).fixedSize()
                            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                    }
                    if filteredCompletedTasks.isEmpty {
                        emptyState(icon: "tray", text: "Keine erledigten Aufgaben")
                    } else {
                        VStack(spacing: 6) {
                            ForEach(filteredCompletedTasks) { taskRow($0) }
                        }
                        .padding(.horizontal, 14)
                    }
                }
            }

            Spacer(minLength: 10)
        }
    }

    private func priorityChip(_ priority: MacTodoPriority?, label: String, color: Color = .secondary) -> some View {
        let selected = priorityFilter == priority
        return Button {
            withAnimation(.spring(response: 0.22)) { priorityFilter = priority }
        } label: {
            HStack(spacing: 4) {
                if let p = priority {
                    let rgb = p.color
                    Circle().fill(Color(red: rgb.0, green: rgb.1, blue: rgb.2)).frame(width: 6, height: 6)
                }
                Text(label).font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (priority == nil ? accent : color) : Color.secondary)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(
                selected ? (priority == nil ? accent : color).opacity(0.14) : Color.primary.opacity(0.05),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func taskRow(_ todo: MacTodoItem) -> some View {
        let isExpanded = expandedTaskID == todo.id
        let isSelected = selectedTaskID == todo.id
        let doneCount  = todo.subTasks.filter(\.isCompleted).count
        let totalCount = todo.subTasks.count

        let priorityColor: Color = {
            switch todo.priority {
            case .high:   return .red
            case .medium: return .orange
            case .low:    return .green
            }
        }()

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { todoStore.toggle(todo) } label: {
                    ZStack {
                        Circle()
                            .fill(todo.isCompleted ? priorityColor : .clear)
                            .frame(width: 20, height: 20)
                        Circle()
                            .stroke(priorityColor.opacity(todo.isCompleted ? 1 : 0.45), lineWidth: 1.5)
                            .frame(width: 20, height: 20)
                        if todo.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

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
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
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
            .background(isSelected ? accent.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { selectedTaskID = todo.id }
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

    private var statsTab: some View {
        VStack(spacing: 10) {
            // Top row – themeC1 / themeC2 wie FokusStatistikView
            HStack(spacing: 10) {
                statCard(
                    title: "Sessions",
                    value: "\(timerMgr.sessionCount)",
                    subtitle: "heute",
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

            // Bottom row
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
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(color.opacity(0.8))
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
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
