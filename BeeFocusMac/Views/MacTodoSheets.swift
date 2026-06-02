import SwiftUI

// MARK: - MacAddTodoSheet

struct MacAddTodoSheet: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.dismiss) private var dismiss

    var prefilledDate: Date? = nil

    init(prefilledDate: Date? = nil) {
        self.prefilledDate = prefilledDate
    }

    var body: some View {
        MacTodoEditorView(todo: nil, prefilledDate: prefilledDate)
            .environmentObject(todoStore)
    }
}

// MARK: - MacEditTodoSheet

struct MacEditTodoSheet: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.dismiss) private var dismiss

    let todo: MacTodoItem

    var body: some View {
        MacTodoEditorView(todo: todo)
            .environmentObject(todoStore)
    }
}

// MARK: - MacTodoEditorView (identisch mit iOS FokusTodoEditorView)

struct MacTodoEditorView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.dismiss) private var dismiss
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
    @State private var selectedWeekOption: String? = nil
    @State private var showDiscardDialog = false
    @State private var showDeleteConfirm = false
    @State private var appeared = false

    // MARK: - Init
    init(todo: MacTodoItem? = nil, prefilledDate: Date? = nil) {
        self.existingTodo  = todo
        self.prefilledDate = prefilledDate

        let base = todo?.dueDate ?? prefilledDate ?? Date()
        _title       = State(initialValue: todo?.title ?? "")
        _bodyText    = State(initialValue: todo?.description ?? "")
        _priority    = State(initialValue: todo?.priority ?? .medium)
        _hasDueDate  = State(initialValue: todo?.dueDate != nil || prefilledDate != nil)
        _dueDate     = State(initialValue: base)
        _isFavorite  = State(initialValue: todo?.isFavorite ?? false)
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
                        dateTimeSection
                        quickDateSection
                        favoriteSection
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .transaction { $0.animation = appeared ? $0.animation : nil }
                .onAppear {
                    appeared = true
                    if hasDueDate { selectedWeekOption = presetLabel(for: dueDate) }
                }
                .onChange(of: dueDate)    { selectedWeekOption = hasDueDate ? presetLabel(for: $0) : nil }
                .onChange(of: hasDueDate) { if !$0 { selectedWeekOption = nil } }
            }
            .navigationTitle(isEditMode ? "Aufgabe bearbeiten" : "Neue Aufgabe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if hasUnsavedChanges() { showDiscardDialog = true } else { dismiss() }
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
        .frame(width: 480, height: 640)
        .confirmationDialog("Änderungen verwerfen?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button("Verwerfen", role: .destructive) { dismiss() }
            if isEditMode {
                Button("Aufgabe löschen", role: .destructive) {
                    if let t = existingTodo { todoStore.delete(t) }
                    dismiss()
                }
            }
            Button("Weiter bearbeiten", role: .cancel) {}
        } message: {
            Text("Nicht gespeicherte Änderungen gehen verloren.")
        }
        .confirmationDialog("Aufgabe löschen?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let t = existingTodo { todoStore.delete(t) }
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("\"\(title)\" wird unwiderruflich gelöscht.")
        }
    }

    // MARK: - Titel & Beschreibung

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Titel", icon: "pencil.line")
            VStack(spacing: 0) {
                TextField("Aufgabenname", text: $title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, bodyText.isEmpty ? 14 : 8)

                Divider().opacity(0.15).padding(.horizontal, 14)
                TextEditor(text: $bodyText)
                    .font(.system(size: 15))
                    .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                    .frame(minHeight: 72, maxHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("Beschreibung (optional)")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.top, 12)
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
                ForEach(MacTodoPriority.allCases, id: \.self) { p in
                    priorityChip(p)
                }
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
            .background(
                selected ? color.opacity(isDark ? 0.28 : 0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? color.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Datum & Zeit

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Datum & Zeit", icon: "calendar.badge.clock")
            VStack(spacing: 0) {
                Toggle(isOn: $hasDueDate.animation(.spring(response: 0.35))) {
                    Label("Datum festlegen", systemImage: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if hasDueDate {
                    Divider().opacity(0.15).padding(.horizontal, 14)

                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(themeC1)
                        .padding(.horizontal, 8).padding(.vertical, 4)

                    Divider().opacity(0.15).padding(.horizontal, 14)

                    DatePicker("Uhrzeit", selection: $dueDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(themeC1)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Schnellauswahl (wie iOS calendarSection quick date menu)

    private var quickDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Schnellauswahl", icon: "target")
            VStack(spacing: 0) {
                Menu {
                    Button("Heute") {
                        withAnimation { hasDueDate = true }
                        dueDate = Date().endOfDay
                        selectedWeekOption = "Heute"
                    }
                    Button("Mitte dieser Woche") {
                        withAnimation { hasDueDate = true }
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        dueDate = (cal.date(byAdding: .day, value: 3, to: start) ?? start).endOfDay
                        selectedWeekOption = "Mitte dieser Woche"
                    }
                    Button("Ende dieser Woche") {
                        withAnimation { hasDueDate = true }
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        dueDate = (cal.date(byAdding: .day, value: 6, to: start) ?? start).endOfDay
                        selectedWeekOption = "Ende dieser Woche"
                    }
                    Button("Ende nächster Woche") {
                        withAnimation { hasDueDate = true }
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
                        dueDate = (cal.date(byAdding: .day, value: 6, to: nextStart) ?? nextStart).endOfDay
                        selectedWeekOption = "Ende nächster Woche"
                    }
                    Divider()
                    Button("Eigenes Datum") {}
                } label: {
                    HStack {
                        Label(
                            selectedWeekOption.map { "Schnellauswahl: \($0)" } ?? "Datum schnell setzen …",
                            systemImage: "target"
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Favorit

    private var favoriteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Optionen", icon: "star.fill")
            VStack(spacing: 0) {
                Toggle(isOn: $isFavorite.animation(.spring(response: 0.35))) {
                    Label("Als Favorit markieren", systemImage: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Aktions-Buttons (identisch mit iOS)

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { save() } label: {
                Text("Speichern")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        title.isEmpty
                            ? LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: title.isEmpty ? .clear : themeC1.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(title.isEmpty)

            if isEditMode {
                Button { showDeleteConfirm = true } label: {
                    Label("Aufgabe löschen", systemImage: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(isDark ? 0.15 : 0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Section Label (identisch mit iOS)

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
        if title    != (t?.title ?? "")       { return true }
        if bodyText != (t?.description ?? "") { return true }
        if priority != (t?.priority ?? .medium) { return true }
        if hasDueDate != (t?.dueDate != nil || prefilledDate != nil) { return true }
        if isFavorite != (t?.isFavorite ?? false) { return true }
        return false
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if isEditMode, var updated = existingTodo {
            updated.title       = trimmed
            updated.description = bodyText
            updated.priority    = priority
            updated.dueDate     = hasDueDate ? dueDate : nil
            updated.isFavorite  = isFavorite
            updated.updatedAt   = Date()
            todoStore.update(updated)
        } else {
            let item = MacTodoItem(
                title:       trimmed,
                description: bodyText,
                dueDate:     hasDueDate ? dueDate : nil,
                priority:    priority,
                isFavorite:  isFavorite
            )
            todoStore.addTodo(item)
        }
        dismiss()
    }

    private func presetLabel(for date: Date) -> String? {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let midWeek     = (cal.date(byAdding: .day, value: 3, to: start) ?? start).endOfDay
        let endWeek     = (cal.date(byAdding: .day, value: 6, to: start) ?? start).endOfDay
        let nextStart   = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        let endNextWeek = (cal.date(byAdding: .day, value: 6, to: nextStart) ?? nextStart).endOfDay
        if cal.isDateInToday(date)                    { return "Heute" }
        if cal.isDate(date, inSameDayAs: midWeek)     { return "Mitte dieser Woche" }
        if cal.isDate(date, inSameDayAs: endWeek)     { return "Ende dieser Woche" }
        if cal.isDate(date, inSameDayAs: endNextWeek) { return "Ende nächster Woche" }
        return nil
    }
}

// MARK: - Date Extension

private extension Date {
    var endOfDay: Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: cal.startOfDay(for: self)) ?? self
    }
}
