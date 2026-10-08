import SwiftUI
import AppKit

// MARK: - Custom dismiss environment key

private struct MacEditorDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var macEditorDismiss: (() -> Void)? {
        get { self[MacEditorDismissKey.self] }
        set { self[MacEditorDismissKey.self] = newValue }
    }
}

// MARK: - Standalone window opener

enum MacAddTodoWindow {
    private static weak var window: NSWindow?

    static func open(todoStore: MacTodoStore, prefilled: MacTodoItem? = nil) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = prefilled == nil ? "Neue Aufgabe" : "Aufgabe bearbeiten"
        win.center()
        win.isReleasedWhenClosed = false
        win.minSize = NSSize(width: 440, height: 600)

        let content = MacTodoEditorView(todo: prefilled)
            .environmentObject(todoStore)
            .environment(\.macEditorDismiss, { win.close() })

        win.contentViewController = NSHostingController(rootView: content)
        win.makeKeyAndOrderFront(nil)
        window = win
    }
}

// MARK: - MacAddTodoSheet (sheet wrapper for in-app use)

struct MacAddTodoSheet: View {
    @EnvironmentObject var todoStore: MacTodoStore
    var prefilledDate: Date? = nil

    var body: some View {
        MacTodoEditorView(todo: nil, prefilledDate: prefilledDate)
            .environmentObject(todoStore)
    }
}

// MARK: - MacEditTodoSheet

struct MacEditTodoSheet: View {
    @EnvironmentObject var todoStore: MacTodoStore
    let todo: MacTodoItem

    var body: some View {
        MacTodoEditorView(todo: todo)
            .environmentObject(todoStore)
    }
}

// MARK: - MacTodoEditorView

struct MacTodoEditorView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.macEditorDismiss) private var macEditorDismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    let existingTodo: MacTodoItem?
    let prefilledDate: Date?

    private var isEditMode: Bool { existingTodo != nil }
    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    // MARK: - State

    @State private var title: String
    @State private var bodyText: String
    @State private var priority: MacTodoPriority
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var isFavorite: Bool
    @State private var categoryID: UUID?

    // Extended
    @State private var subTasks: [MacSubTask]
    @State private var newSubTaskTitle: String = ""
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var reminderOffset: Int?
    @State private var recurrenceEnabled: Bool
    @State private var recurrenceRule: MacRecurrenceRule

    @State private var showDiscardDialog = false
    @State private var showDeleteConfirm  = false
    @State private var showCategoryManager = false
    @State private var appeared = false

    init(todo: MacTodoItem? = nil, prefilledDate: Date? = nil) {
        self.existingTodo  = todo
        self.prefilledDate = prefilledDate

        let base = todo?.dueDate ?? prefilledDate ?? Date()
        _title             = State(initialValue: todo?.title ?? "")
        _bodyText          = State(initialValue: todo?.description ?? "")
        _priority          = State(initialValue: todo?.priority ?? .medium)
        _hasDueDate        = State(initialValue: todo?.dueDate != nil || prefilledDate != nil)
        _dueDate           = State(initialValue: base)
        _isFavorite        = State(initialValue: todo?.isFavorite ?? false)
        _categoryID        = State(initialValue: todo?.categoryID)
        _subTasks          = State(initialValue: todo?.subTasks ?? [])
        _hasEndTime        = State(initialValue: todo?.endTime != nil)
        _endTime           = State(initialValue: todo?.endTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: base) ?? base)
        _reminderOffset    = State(initialValue: todo?.reminderOffsetMinutes)
        _recurrenceEnabled = State(initialValue: todo?.recurrenceEnabled ?? false)
        _recurrenceRule    = State(initialValue: todo?.recurrenceRule ?? .none)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        titleSection
                        prioritySection
                        categorySection
                        dateTimeSection
                        reminderSection
                        recurrenceSection
                        subtasksSection
                        favoriteSection
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .transaction { $0.animation = appeared ? $0.animation : nil }
                .onAppear { appeared = true }
            }
            .navigationTitle(isEditMode ? "Aufgabe bearbeiten" : "Neue Aufgabe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if hasUnsavedChanges() { showDiscardDialog = true } else { performDismiss() }
                    }
                    .foregroundStyle(themeC1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? .secondary : themeC1)
                        .disabled(title.isEmpty)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 600)
        .confirmationDialog("Änderungen verwerfen?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { performDismiss() }
            if isEditMode {
                Button("Aufgabe löschen", role: .destructive) {
                    if let t = existingTodo { todoStore.delete(t) }
                    performDismiss()
                }
            }
            Button("Weiter bearbeiten", role: .cancel) {}
        } message: { Text("Nicht gespeicherte Änderungen gehen verloren.") }
        .confirmationDialog("Aufgabe löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let t = existingTodo { todoStore.delete(t) }
                performDismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { Text("\"\(title)\" wird unwiderruflich gelöscht.") }
    }

    private func performDismiss() { macEditorDismiss?() ?? dismiss() }

    // MARK: - Titel & Beschreibung

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Titel & Beschreibung", icon: "pencil.line")
            VStack(spacing: 0) {
                TextField("Aufgabenname", text: $title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                    .padding(.horizontal, 14).padding(.top, 14)
                    .padding(.bottom, bodyText.isEmpty ? 14 : 8)

                Divider().opacity(0.15).padding(.horizontal, 14)
                TextEditor(text: $bodyText)
                    .font(.system(size: 15))
                    .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                    .frame(minHeight: 56, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("Beschreibung (optional)")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.horizontal, 14).padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Priorität

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Priorität", icon: "flag.fill")
            HStack(spacing: 10) {
                ForEach(MacTodoPriority.allCases, id: \.self) { priorityChip($0) }
            }
            .padding(12)
            .themeGlass(cornerRadius: 16)
        }
    }

    private func priorityChip(_ p: MacTodoPriority) -> some View {
        let rgb = p.color
        let color = Color(red: rgb.0, green: rgb.1, blue: rgb.2)
        let selected = priority == p
        return Button {
            withAnimation(.spring(response: 0.3)) { priority = p }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(p.label)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (isDark ? .white : color) : .secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? color.opacity(isDark ? 0.28 : 0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(selected ? color.opacity(0.55) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Kategorie

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("Kategorie", icon: "folder.fill")
                Spacer()
                Button {
                    showCategoryManager = true
                } label: {
                    Label("Verwalten", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeC1)
                }
                .buttonStyle(.plain)
                .help("Kategorien erstellen, umbenennen oder löschen")
            }
            Menu {
                Button("Keine") { categoryID = nil }
                if !todoStore.categories.isEmpty { Divider() }
                ForEach(todoStore.categories) { cat in
                    Button(cat.name) { categoryID = cat.id }
                }
            } label: {
                HStack(spacing: 10) {
                    if let cat = todoStore.category(for: categoryID) {
                        Circle().fill(cat.color).frame(width: 12, height: 12)
                        Text(cat.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isDark ? .white : .primary)
                    } else {
                        Image(systemName: "folder")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                        Text("Keine Kategorie")
                            .font(.system(size: 15)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .themeGlass(cornerRadius: 16)

            if todoStore.categories.isEmpty {
                Button {
                    showCategoryManager = true
                } label: {
                    Label("Erste Kategorie anlegen", systemImage: "plus.circle")
                        .font(.system(size: 11)).foregroundStyle(themeC1)
                        .padding(.leading, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showCategoryManager) {
            MacCategoryManagerView()
                .environmentObject(todoStore)
        }
    }

    // MARK: - Datum & Zeit

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Datum & Zeit", icon: "calendar.badge.clock")
            VStack(spacing: 0) {
                Toggle(isOn: $hasDueDate.animation(.spring(response: 0.35))) {
                    Label("Datum festlegen", systemImage: "calendar")
                        .font(.system(size: 15, weight: .medium))
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if hasDueDate {
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).tint(themeC1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    HStack {
                        Text("Beginn")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        DatePicker("Beginn", selection: $dueDate, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact).labelsHidden().tint(themeC1)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)

                    Divider().opacity(0.15).padding(.horizontal, 14)
                    Toggle(isOn: $hasEndTime.animation(.spring(response: 0.35))) {
                        Label("Endzeit festlegen", systemImage: "timer")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .tint(themeC1)
                    .padding(.horizontal, 14).padding(.vertical, 13)

                    if hasEndTime {
                        Divider().opacity(0.15).padding(.horizontal, 14)
                        HStack {
                            Text("Ende")
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact).labelsHidden().tint(themeC1)
                                .onChange(of: dueDate) { newStart in
                                    if endTime <= newStart {
                                        endTime = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                                    }
                                }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Erinnerung

    private let reminderOptions: [(label: String, minutes: Int?)] = [
        ("Keine", nil),
        ("Zum Zeitpunkt", 0),
        ("5 Min. vorher", 5),
        ("15 Min. vorher", 15),
        ("30 Min. vorher", 30),
        ("1 Stunde vorher", 60),
        ("1 Tag vorher", 1440)
    ]

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Erinnerung", icon: "bell.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(reminderOptions, id: \.label) { opt in
                        let selected = reminderOffset == opt.minutes
                        Button {
                            withAnimation(.spring(response: 0.25)) { reminderOffset = opt.minutes }
                        } label: {
                            Text(opt.label)
                                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? (isDark ? .white : themeC1) : .secondary)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(selected ? themeC1.opacity(0.18) : Color.primary.opacity(0.06),
                                            in: Capsule())
                                .overlay(Capsule().stroke(selected ? themeC1.opacity(0.5) : Color.clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .themeGlass(cornerRadius: 16)

            if reminderOffset != nil && !hasDueDate {
                Label("Datum für Erinnerung setzen", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Wiederholung

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Wiederholung", icon: "repeat")
            VStack(spacing: 0) {
                Toggle(isOn: $recurrenceEnabled.animation(.spring(response: 0.35))) {
                    Label("Wiederkehrend", systemImage: "repeat")
                        .font(.system(size: 15, weight: .medium))
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if recurrenceEnabled {
                    Divider().opacity(0.15).padding(.horizontal, 14)

                    // Frequency picker
                    HStack(spacing: 0) {
                        ForEach(["Tägl.", "Wöch.", "Monatl."], id: \.self) { label in
                            let idx = ["Tägl.", "Wöch.", "Monatl."].firstIndex(of: label)!
                            let isSelected = recurrenceTypeIndex == idx
                            Button {
                                withAnimation(.spring(response: 0.25)) { applyRecurrenceType(idx) }
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? (isDark ? .white : themeC1) : .secondary)
                                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                                    .background(isSelected ? themeC1.opacity(0.18) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)

                    Divider().opacity(0.15).padding(.horizontal, 14)

                    // Interval stepper
                    HStack {
                        Text("Intervall").font(.system(size: 14, weight: .medium))
                        Spacer()
                        HStack(spacing: 10) {
                            Button {
                                if recurrenceInterval > 1 { recurrenceInterval -= 1; applyRecurrenceType(recurrenceTypeIndex) }
                            } label: {
                                Image(systemName: "minus").font(.system(size: 11, weight: .semibold))
                                    .frame(width: 24, height: 24)
                                    .background(Color.primary.opacity(0.08), in: Circle())
                            }.buttonStyle(.plain)
                            Text("× \(recurrenceInterval)").font(.system(size: 14, weight: .semibold, design: .monospaced))
                            Button {
                                recurrenceInterval += 1; applyRecurrenceType(recurrenceTypeIndex)
                            } label: {
                                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                                    .frame(width: 24, height: 24)
                                    .background(Color.primary.opacity(0.08), in: Circle())
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)

                    // Weekday selector (only for weekly)
                    if case .weekly = recurrenceRule {
                        Divider().opacity(0.15).padding(.horizontal, 14)
                        HStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { i in
                                let label = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][i]
                                let wd = i + 2 == 8 ? 1 : i + 2  // Calendar weekday (1=Sun,2=Mon...7=Sat → Mo=2..So=1)
                                let selected = selectedWeekdays.contains(wd)
                                Button {
                                    withAnimation(.spring(response: 0.2)) { toggleWeekday(wd) }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                        .foregroundStyle(selected ? (isDark ? .white : themeC1) : .secondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(selected ? themeC1.opacity(0.2) : Color.primary.opacity(0.05),
                                                    in: RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                    }

                    // Summary
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    Text(recurrenceRule.label)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    @State private var recurrenceInterval: Int = 1

    private var recurrenceTypeIndex: Int {
        switch recurrenceRule {
        case .daily:   return 0
        case .weekly:  return 1
        case .monthly: return 2
        default:       return 0
        }
    }

    private var selectedWeekdays: [Int] {
        if case .weekly(_, let wd) = recurrenceRule { return wd ?? [] }
        return []
    }

    private func applyRecurrenceType(_ idx: Int) {
        switch idx {
        case 0: recurrenceRule = .daily(interval: recurrenceInterval)
        case 1: recurrenceRule = .weekly(interval: recurrenceInterval, weekdays: selectedWeekdays.isEmpty ? nil : selectedWeekdays)
        case 2: recurrenceRule = .monthly(interval: recurrenceInterval)
        default: break
        }
    }

    private func toggleWeekday(_ wd: Int) {
        var wds = selectedWeekdays
        if wds.contains(wd) { wds.removeAll { $0 == wd } } else { wds.append(wd) }
        wds.sort()
        recurrenceRule = .weekly(interval: recurrenceInterval, weekdays: wds.isEmpty ? nil : wds)
    }

    // MARK: - Subtasks

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Teilaufgaben", icon: "list.bullet")
            VStack(spacing: 0) {
                ForEach($subTasks) { $sub in
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.2)) { sub.isCompleted.toggle() }
                        } label: {
                            ZStack {
                                Circle().stroke(sub.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                if sub.isCompleted {
                                    Circle().fill(Color.green).frame(width: 18, height: 18)
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        TextField("Teilaufgabe", text: $sub.title)
                            .font(.system(size: 14))
                            .strikethrough(sub.isCompleted, color: .secondary)
                            .foregroundStyle(sub.isCompleted ? .secondary : .primary)
                            .textFieldStyle(.plain)

                        Spacer()

                        Button {
                            withAnimation { subTasks.removeAll { $0.id == sub.id } }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.red.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)

                    if sub.id != subTasks.last?.id {
                        Divider().opacity(0.12).padding(.leading, 14)
                    }
                }

                if !subTasks.isEmpty { Divider().opacity(0.12).padding(.horizontal, 0) }

                // Add new subtask
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle").font(.system(size: 16)).foregroundStyle(themeC1)
                    TextField("Neue Teilaufgabe…", text: $newSubTaskTitle, onCommit: addSubTask)
                        .textFieldStyle(.plain).font(.system(size: 14))
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    private func addSubTask() {
        let t = newSubTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation { subTasks.append(MacSubTask(title: t)) }
        newSubTaskTitle = ""
    }

    // MARK: - Favorit

    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Optionen", icon: "star.fill")
            VStack(spacing: 0) {
                Toggle(isOn: $isFavorite.animation(.spring(response: 0.35))) {
                    Label("Als Favorit markieren", systemImage: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .medium))
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Aktions-Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { save() } label: {
                Text("Speichern")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(title.isEmpty
                        ? LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                                in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: title.isEmpty ? .clear : themeC1.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain).disabled(title.isEmpty)

            if isEditMode {
                Button { showDeleteConfirm = true } label: {
                    Label("Aufgabe löschen", systemImage: "trash")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.red.opacity(isDark ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(themeC1.opacity(0.85))
            .textCase(.uppercase)
            .tracking(0.5)
    }

    // MARK: - Logic

    private func hasUnsavedChanges() -> Bool {
        let t = existingTodo
        if title    != (t?.title ?? "")         { return true }
        if bodyText != (t?.description ?? "")   { return true }
        if priority != (t?.priority ?? .medium)  { return true }
        if hasDueDate != (t?.dueDate != nil || prefilledDate != nil) { return true }
        if isFavorite != (t?.isFavorite ?? false) { return true }
        if subTasks   != (t?.subTasks ?? [])     { return true }
        if hasEndTime != (t?.endTime != nil)     { return true }
        if categoryID != t?.categoryID           { return true }
        if reminderOffset != t?.reminderOffsetMinutes { return true }
        if recurrenceEnabled != (t?.recurrenceEnabled ?? false) { return true }
        return false
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if addSubTask_pending() { return }

        if isEditMode, var updated = existingTodo {
            updated.title                 = trimmed
            updated.description           = bodyText
            updated.priority              = priority
            updated.dueDate               = hasDueDate ? dueDate : nil
            updated.endTime               = (hasDueDate && hasEndTime) ? endTime : nil
            updated.isFavorite            = isFavorite
            updated.categoryID            = categoryID
            updated.updatedAt             = Date()
            updated.subTasks              = subTasks
            updated.reminderOffsetMinutes = reminderOffset
            updated.recurrenceEnabled     = recurrenceEnabled
            updated.recurrenceRule        = recurrenceEnabled ? recurrenceRule : .none
            todoStore.update(updated)
        } else {
            let item = MacTodoItem(
                title:                 trimmed,
                description:           bodyText,
                dueDate:               hasDueDate ? dueDate : nil,
                priority:              priority,
                isFavorite:            isFavorite,
                subTasks:              subTasks,
                endTime:               (hasDueDate && hasEndTime) ? endTime : nil,
                reminderOffsetMinutes: reminderOffset,
                recurrenceEnabled:     recurrenceEnabled,
                recurrenceRule:        recurrenceEnabled ? recurrenceRule : .none,
                categoryID:            categoryID
            )
            todoStore.addTodo(item)
        }
        performDismiss()
    }

    private func addSubTask_pending() -> Bool {
        let t = newSubTaskTitle.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { addSubTask(); return true }
        return false
    }
}

// MARK: - Date Extension

private extension Date {
    var endOfDay: Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.startOfDay(for: self)) ?? self
    }
}

// MARK: - MacCategoryManagerView
//
// Verwaltung der (mit iOS geteilten) Kategorien direkt auf dem Mac: erstellen,
// umbenennen, Farbe ändern, löschen. Nutzt dieselbe CloudKit-Datenquelle wie das
// iPhone (Record-Typ "Category"). Löschen entfernt nur die Zuweisung an Aufgaben,
// die Aufgaben selbst bleiben erhalten (kein Cascade-Delete).

struct MacCategoryManagerView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var newName: String = ""
    @State private var newColor: String = "#FF6B6B"
    @State private var editingID: UUID? = nil
    @State private var editingName: String = ""
    @State private var pendingDelete: MacCategory? = nil

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.15)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    addSection
                    listSection
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 460)
        .background(ThemeBackgroundView())
        .onAppear { newColor = todoStore.nextSuggestedCategoryColor() }
        .confirmationDialog(
            pendingDelete.map { "„\($0.name)" + "\" löschen?" } ?? "Kategorie löschen?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let cat = pendingDelete { todoStore.deleteCategory(cat) }
                pendingDelete = nil
            }
            Button("Abbrechen", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Die Kategorie wird entfernt. Zugewiesene Aufgaben bleiben erhalten und verlieren nur diese Kategorie.")
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Kategorien").font(.system(size: 14, weight: .semibold))
            }
            Spacer()
            Button("Fertig") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(themeC1)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Add

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEUE KATEGORIE")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(themeC1.opacity(0.85)).tracking(0.5)
            HStack(spacing: 8) {
                Circle().fill(Color(macHex: newColor)).frame(width: 16, height: 16)
                TextField("Name", text: $newName, onCommit: addCategory)
                    .textFieldStyle(.plain).font(.system(size: 14))
                Button(action: addCategory) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.5) : themeC1)
                }
                .buttonStyle(.plain)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .themeGlass(cornerRadius: 10)

            colorPalette(selected: $newColor)
        }
    }

    private func colorPalette(selected: Binding<String>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MacTodoStore.suggestedCategoryColors, id: \.self) { hex in
                    let isSel = selected.wrappedValue.uppercased() == hex.uppercased()
                    Button { selected.wrappedValue = hex } label: {
                        Circle()
                            .fill(Color(macHex: hex))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.primary.opacity(isSel ? 0.9 : 0), lineWidth: 2))
                            .overlay {
                                if isSel {
                                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: List

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VORHANDEN (\(todoStore.categories.count))")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            if todoStore.categories.isEmpty {
                Text("Noch keine Kategorien. Lege oben deine erste an.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(todoStore.categories) { cat in
                        categoryRow(cat)
                        if cat.id != todoStore.categories.last?.id {
                            Divider().opacity(0.1).padding(.leading, 38)
                        }
                    }
                }
                .themeGlass(cornerRadius: 12)
            }
        }
    }

    private func categoryRow(_ cat: MacCategory) -> some View {
        let count = todoStore.todos.filter { $0.categoryID == cat.id }.count
        return HStack(spacing: 10) {
            Menu {
                ForEach(MacTodoStore.suggestedCategoryColors, id: \.self) { hex in
                    Button {
                        todoStore.renameCategory(cat, to: cat.name, colorHex: hex)
                    } label: { Text(hex) }
                }
            } label: {
                Circle().fill(cat.color).frame(width: 18, height: 18)
                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 20)
            .help("Farbe ändern")

            if editingID == cat.id {
                TextField("Name", text: $editingName, onCommit: { commitRename(cat) })
                    .textFieldStyle(.plain).font(.system(size: 14))
                Button { commitRename(cat) } label: {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(.green)
                }.buttonStyle(.plain)
            } else {
                Text(cat.name).font(.system(size: 14, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer()
                Button { startRename(cat) } label: {
                    Image(systemName: "pencil").font(.system(size: 12)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).help("Umbenennen")
                Button { pendingDelete = cat } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Color.red.opacity(0.8))
                }.buttonStyle(.plain).help("Löschen")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    // MARK: Actions

    private func addCategory() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        todoStore.addCategory(name: trimmed, colorHex: newColor)
        newName = ""
        newColor = todoStore.nextSuggestedCategoryColor()
    }

    private func startRename(_ cat: MacCategory) {
        editingID = cat.id
        editingName = cat.name
    }

    private func commitRename(_ cat: MacCategory) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { todoStore.renameCategory(cat, to: trimmed) }
        editingID = nil
        editingName = ""
    }
}
