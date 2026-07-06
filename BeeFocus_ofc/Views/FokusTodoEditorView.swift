import SwiftUI
import PhotosUI
import AVFoundation
import EventKit

// MARK: - FokusTodoEditorView

struct FokusTodoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @ObservedObject private var localizer = LocalizationManager.shared

    let existingTodo: TodoItem?
    let prefilledDate: Date?

    private var isEditMode: Bool { existingTodo != nil }
    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    // MARK: - State
    @State private var title: String
    @State private var bodyText: String
    @State private var priority: TodoPriority
    @State private var category: Category?

    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var hasEndTime: Bool
    @State private var endDate: Date

    @State private var reminderOffset: Int

    @State private var recurrenceEnabled: Bool
    @State private var recurrenceFreq: String
    @State private var recurrenceInterval: Int
    @State private var weeklyWeekdays: Set<Int>

    @State private var subTasks: [SubTask]
    @State private var newSubTaskTitle = ""
    @State private var subTaskPendingDelete: SubTask? = nil
    @State private var showSubTaskDeleteAlert = false

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [IdentifiableUIImage] = []
    @State private var selectedImagePreview: IdentifiableUIImage?

    @State private var addToCalendar: Bool
    @State private var selectedCalendar: EKCalendar? = nil
    @State private var calendarAccessDenied = false
    @State private var showCamera = false
    @State private var showCameraPermAlert = false
    @State private var showDiscardDialog = false
    @State private var showDeleteConfirm = false
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var appeared = false

    // MARK: - Init
    init(todo: TodoItem? = nil, prefilledDate: Date? = nil) {
        self.existingTodo = todo
        self.prefilledDate = prefilledDate

        let t = todo
        _title       = State(initialValue: t?.title ?? "")
        _bodyText    = State(initialValue: t?.description ?? "")
        _priority    = State(initialValue: t?.priority ?? .medium)
        _category    = State(initialValue: t?.category)
        _addToCalendar = State(initialValue: t?.calendarEnabled ?? false)

        let base = t?.dueDate ?? prefilledDate ?? Date()
        _hasDueDate  = State(initialValue: t?.dueDate != nil || prefilledDate != nil)
        _dueDate     = State(initialValue: base)
        _hasEndTime  = State(initialValue: t?.endDate != nil)
        _endDate     = State(initialValue: t?.endDate ?? base.addingTimeInterval(3600))

        _reminderOffset = State(initialValue: t?.reminderOffsetMinutes ?? -1)
        _recurrenceEnabled = State(initialValue: t?.recurrenceEnabled ?? false)
        _subTasks    = State(initialValue: t?.subTasks ?? [])
        _selectedImages = State(initialValue: (t?.imageDataArray ?? []).compactMap {
            UIImage(data: $0).map { IdentifiableUIImage(image: $0) }
        })

        switch t?.recurrenceRule ?? .none {
        case .daily(let i):
            _recurrenceFreq = State(initialValue: "daily")
            _recurrenceInterval = State(initialValue: i)
            _weeklyWeekdays = State(initialValue: [])
        case .weekly(let i, let days):
            _recurrenceFreq = State(initialValue: "weekly")
            _recurrenceInterval = State(initialValue: i)
            _weeklyWeekdays = State(initialValue: Set(days ?? []))
        case .monthly(let i):
            _recurrenceFreq = State(initialValue: "monthly")
            _recurrenceInterval = State(initialValue: i)
            _weeklyWeekdays = State(initialValue: [])
        case .none:
            _recurrenceFreq = State(initialValue: "daily")
            _recurrenceInterval = State(initialValue: 1)
            _weeklyWeekdays = State(initialValue: [])
        }
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
                        if hasDueDate { reminderSection }
                        if hasDueDate { calendarSection }
                        categorySection
                        subtasksSection
                        recurrenceSection
                        photosSection
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .transaction { $0.animation = appeared ? $0.animation : nil }
                .onAppear { appeared = true }
            }
            .navigationTitle(isEditMode ? localizer.localizedString(forKey: "edit_todo_title") : localizer.localizedString(forKey: "new_task_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(forKey: "cancel_button")) {
                        if hasUnsavedChanges() { showDiscardDialog = true } else { dismiss() }
                    }
                    .foregroundStyle(themeC1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.localizedString(forKey: "save_button")) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? .secondary : themeC1)
                        .disabled(title.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges())
        .confirmationDialog(localizer.localizedString(forKey: "discard_changes_title"), isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button(localizer.localizedString(forKey: "discard_changes"), role: .destructive) { dismiss() }
            if isEditMode {
                Button(localizer.localizedString(forKey: "delete_task"), role: .destructive) {
                    if let t = existingTodo { todoStore.deleteTodo(t) }
                    dismiss()
                }
            }
            Button(localizer.localizedString(forKey: "keep_editing"), role: .cancel) {}
        } message: {
            Text(localizer.localizedString(forKey: "unsaved_changes_message"))
        }
        .confirmationDialog(localizer.localizedString(forKey: "alert_delete_task"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(localizer.localizedString(forKey: "delete_button"), role: .destructive) {
                if let t = existingTodo { todoStore.deleteTodo(t) }
                dismiss()
            }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) {}
        } message: {
            Text(String(format: localizer.localizedString(forKey: "delete_task_confirm_message"), title))
        }
        .alert(localizer.localizedString(forKey: "new_category_title"), isPresented: $showAddCategoryAlert) {
            TextField(localizer.localizedString(forKey: "category_name_placeholder"), text: $newCategoryName)
            Button(localizer.localizedString(forKey: "add")) { addCategory() }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) { newCategoryName = "" }
        }
        .alert(localizer.localizedString(forKey: "camera_access_required"), isPresented: $showCameraPermAlert) {
            Button(localizer.localizedString(forKey: "settings_button")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) {}
        }
        .alert(localizer.localizedString(forKey: "calendar_no_access_title"), isPresented: $calendarAccessDenied) {
            Button(localizer.localizedString(forKey: "settings_button")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) {}
        } message: {
            Text(localizer.localizedString(forKey: "calendar_no_access_message"))
        }
        .alert(localizer.localizedString(forKey: "delete_subtask_title"), isPresented: $showSubTaskDeleteAlert, presenting: subTaskPendingDelete) { sub in
            Button(localizer.localizedString(forKey: "delete_button"), role: .destructive) {
                withAnimation { subTasks.removeAll { $0.id == sub.id } }
                subTaskPendingDelete = nil
            }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) { subTaskPendingDelete = nil }
        } message: { sub in
            Text(String(format: localizer.localizedString(forKey: "delete_subtask_message"), sub.title))
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { img in
                if let img { selectedImages.append(IdentifiableUIImage(image: img)) }
            }
        }
        .sheet(item: $selectedImagePreview) { w in
            ImagePreviewView(image: w.image)
        }
    }

    // MARK: - Titel & Beschreibung
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "title_placeholder"), icon: "pencil.line")
            VStack(spacing: 0) {
                TextField(localizer.localizedString(forKey: "title_placeholder"), text: $title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                    .submitLabel(.next)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, bodyText.isEmpty ? 14 : 8)

                if !bodyText.isEmpty || true {
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
                                Text(localizer.localizedString(forKey: "description_optional_placeholder"))
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary.opacity(0.6))
                                    .padding(.horizontal, 14)
                                    .padding(.top, 12)
                                    .allowsHitTesting(false)
                            }
                        }
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Priorität
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "priority"), icon: "flag.fill")
            HStack(spacing: 10) {
                ForEach(TodoPriority.allCases) { p in
                    priorityChip(p)
                }
            }
            .padding(12)
            .themeGlass(cornerRadius: 16)
        }
    }

    private func priorityChip(_ p: TodoPriority) -> some View {
        let color: Color = p == .high ? .red : p == .medium ? .orange : .green
        let selected = priority == p
        return Button { withAnimation(.spring(response: 0.3)) { priority = p } } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(p.displayName)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (isDark ? .white : color) : .secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(selected ? color.opacity(isDark ? 0.28 : 0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
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
            sectionLabel(localizer.localizedString(forKey: "date_time"), icon: "calendar.badge.clock")
            VStack(spacing: 0) {
                // Datum-Toggle
                Toggle(isOn: $hasDueDate.animation(.spring(response: 0.35))) {
                    Label(localizer.localizedString(forKey: "set_date_toggle"), systemImage: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if hasDueDate {
                    Divider().opacity(0.15).padding(.horizontal, 14)

                    // Kalender
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(themeC1)
                        .padding(.horizontal, 8).padding(.vertical, 4)

                    Divider().opacity(0.15).padding(.horizontal, 14)

                    // Von / Bis nebeneinander
                    HStack(spacing: 0) {
                        // Von
                        VStack(spacing: 6) {
                            Text(localizer.localizedString(forKey: "time_from_label"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                            DatePicker("", selection: $dueDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(themeC1)
                                .onChange(of: dueDate) {
                                    if hasEndTime && endDate <= dueDate {
                                        endDate = dueDate.addingTimeInterval(3600)
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)

                        // Pfeil / Toggle
                        Button {
                            withAnimation(.spring(response: 0.35)) { hasEndTime.toggle() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: hasEndTime ? "arrow.right" : "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(hasEndTime ? themeC1 : themeC1.opacity(0.35))
                                Text(hasEndTime ? localizer.localizedString(forKey: "time_until_label") : localizer.localizedString(forKey: "time_no_end_label"))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(hasEndTime ? themeC1 : .secondary)
                            }
                            .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)

                        // Until
                        VStack(spacing: 6) {
                            Text(localizer.localizedString(forKey: "time_to_label"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.secondary.opacity(hasEndTime ? 1.0 : 0.35))
                            if hasEndTime {
                                DatePicker("", selection: $endDate, in: dueDate..., displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .tint(themeC1)
                            } else {
                                Text("–")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(Color.secondary.opacity(0.3))
                                    .frame(height: 34)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)

                    // Dauer-Badge
                    if hasEndTime {
                        let mins = Int(endDate.timeIntervalSince(dueDate) / 60)
                        if mins > 0 {
                            HStack {
                                Spacer()
                                let label = mins >= 60
                                    ? (mins % 60 == 0 ? "\(mins/60)h" : "\(mins/60)h \(mins%60)min")
                                    : "\(mins)min"
                                Label(label, systemImage: "timer")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(themeC1)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(themeC1.opacity(0.12), in: Capsule())
                                Spacer()
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Erinnerung
    private var reminderFireTime: Date? {
        guard reminderOffset >= 0 else { return nil }
        return dueDate.addingTimeInterval(TimeInterval(-reminderOffset * 60))
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "reminder_label"), icon: "bell.fill")
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        reminderChip(-1,   label: localizer.localizedString(forKey: "reminder_none"))
                        reminderChip(0,    label: localizer.localizedString(forKey: "reminder_chip_on_time"))
                        reminderChip(5,    label: localizer.localizedString(forKey: "reminder_chip_5m"))
                        reminderChip(15,   label: localizer.localizedString(forKey: "reminder_chip_15m"))
                        reminderChip(30,   label: localizer.localizedString(forKey: "reminder_chip_30m"))
                        reminderChip(60,   label: localizer.localizedString(forKey: "reminder_chip_1h"))
                        reminderChip(120,  label: localizer.localizedString(forKey: "reminder_chip_2h"))
                        reminderChip(1440, label: localizer.localizedString(forKey: "reminder_chip_1d"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                if let fireTime = reminderFireTime {
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(themeC1)
                        Text(String(format: localizer.localizedString(forKey: "reminder_fire_time"), fireTime.formatted(.dateTime.hour().minute())))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    private func reminderChip(_ offset: Int, label: String) -> some View {
        let selected = reminderOffset == offset
        return Button {
            withAnimation(.spring(response: 0.3)) { reminderOffset = offset }
            if offset >= 0 {
                NotificationManager.shared.requestAuthorization()
            }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : (isDark ? .white.opacity(0.7) : .secondary))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    selected
                    ? LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .overlay(Capsule().stroke(selected ? Color.clear : themeC1.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Kalender
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "calendar_section_label"), icon: "calendar.badge.plus")
            VStack(spacing: 0) {
                Toggle(isOn: $addToCalendar.animation(.spring(response: 0.35))) {
                    Label(localizer.localizedString(forKey: "add_to_calendar_toggle"), systemImage: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if addToCalendar {
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizer.localizedString(forKey: "choose_calendar"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                        CalendarPickerView(selectedCalendar: $selectedCalendar)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                    }
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Kategorie
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "category"), icon: "folder.fill")
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(nil, name: localizer.localizedString(forKey: "category_none_label"))
                        ForEach(todoStore.categories) { cat in
                            categoryChip(cat, name: cat.name)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                Divider().opacity(0.15).padding(.horizontal, 14)
                Button {
                    newCategoryName = ""
                    showAddCategoryAlert = true
                } label: {
                    Label(localizer.localizedString(forKey: "add_category"), systemImage: "plus.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeC1)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    private func categoryChip(_ cat: Category?, name: String) -> some View {
        let color: Color = cat?.color ?? themeC1.opacity(0.6)
        let selected = category?.id == cat?.id && (cat != nil || category == nil)
        return Button {
            withAnimation(.spring(response: 0.3)) { category = cat }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (isDark ? .white : color) : .secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? color.opacity(isDark ? 0.25 : 0.15) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(selected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtasks
    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "subtasks"), icon: "checklist")
            VStack(spacing: 0) {
                if !subTasks.isEmpty {
                    ForEach(subTasks) { sub in
                        HStack(spacing: 10) {
                            Button {
                                if let idx = subTasks.firstIndex(where: { $0.id == sub.id }) {
                                    withAnimation { subTasks[idx].isCompleted.toggle() }
                                }
                            } label: {
                                Image(systemName: sub.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundStyle(sub.isCompleted ? .green : themeC1.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                            Text(sub.title)
                                .font(.system(size: 15))
                                .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                                .strikethrough(sub.isCompleted, color: .gray)
                            Spacer()
                            Button {
                                subTaskPendingDelete = sub
                                showSubTaskDeleteAlert = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        if sub.id != subTasks.last?.id {
                            Divider().opacity(0.12).padding(.leading, 42)
                        }
                    }
                    Divider().opacity(0.15).padding(.horizontal, 14)
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(themeC1)
                    TextField(localizer.localizedString(forKey: "new_subtask_placeholder"), text: $newSubTaskTitle)
                        .font(.system(size: 15))
                        .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
                        .submitLabel(.done)
                        .onSubmit { addSubTask() }
                    if !newSubTaskTitle.isEmpty {
                        Button { addSubTask() } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeC1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Wiederholung
    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "recurrence_section_header"), icon: "arrow.clockwise")
            VStack(spacing: 0) {
                Toggle(isOn: $recurrenceEnabled) {
                    Label(localizer.localizedString(forKey: "recurrence_enabled_toggle"), systemImage: "repeat")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                }
                .tint(themeC1)
                .padding(.horizontal, 14).padding(.vertical, 13)

                if recurrenceEnabled {
                    Divider().opacity(0.15).padding(.horizontal, 14)
                    VStack(spacing: 12) {
                        Picker("", selection: $recurrenceFreq) {
                            Text(localizer.localizedString(forKey: "recurrence_daily")).tag("daily")
                            Text(localizer.localizedString(forKey: "recurrence_weekly")).tag("weekly")
                            Text(localizer.localizedString(forKey: "recurrence_monthly")).tag("monthly")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 4)

                        HStack {
                            Text(localizer.localizedString(forKey: "recurrence_every_label"))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            Stepper("\(recurrenceInterval) \(freqLabel)", value: $recurrenceInterval, in: 1...30)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                        }

                        if recurrenceFreq == "weekly" {
                            weekdayPickerRow
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 14)
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    private var freqLabel: String {
        let loc = LocalizationManager.shared
        switch recurrenceFreq {
        case "weekly":  return recurrenceInterval == 1 ? loc.localizedString(forKey: "freq_week")  : loc.localizedString(forKey: "freq_weeks")
        case "monthly": return recurrenceInterval == 1 ? loc.localizedString(forKey: "freq_month") : loc.localizedString(forKey: "freq_months")
        default:        return recurrenceInterval == 1 ? loc.localizedString(forKey: "freq_day")   : loc.localizedString(forKey: "freq_days")
        }
    }

    private var weekdayPickerRow: some View {
        let df = DateFormatter()
        df.locale = LocalizationManager.shared.currentLocale
        let allSymbols = df.veryShortWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
        let indices = [2, 3, 4, 5, 6, 7, 1]
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let day = indices[i]
                let selected = weeklyWeekdays.contains(day)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if selected { weeklyWeekdays.remove(day) } else { weeklyWeekdays.insert(day) }
                    }
                } label: {
                    Text(allSymbols[(indices[i] - 1)])
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(selected ? .white : (isDark ? .white.opacity(0.6) : .secondary))
                        .background(selected ? LinearGradient(colors: [themeC1, themeC2], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing), in: Circle())
                        .overlay(Circle().stroke(selected ? Color.clear : themeC1.opacity(0.3), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Fotos
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(localizer.localizedString(forKey: "photos_section_label"), icon: "photo.fill")
            VStack(spacing: 0) {
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(selectedImages) { w in
                                Image(uiImage: w.image)
                                    .resizable().scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onTapGesture { selectedImagePreview = w }
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            withAnimation { selectedImages.removeAll { $0.id == w.id } }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 5, y: -5)
                                    }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                    }
                    Divider().opacity(0.15).padding(.horizontal, 14)
                }
                HStack(spacing: 0) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                        Label(localizer.localizedString(forKey: "gallery_label"), systemImage: "photo.on.rectangle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeC1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .onChange(of: selectedItems) { Task { await loadPhotos() } }

                    Divider().frame(width: 1).opacity(0.15)

                    Button {
                        checkCamera()
                    } label: {
                        Label(localizer.localizedString(forKey: "camera_label"), systemImage: "camera")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeC1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
            }
            .themeGlass(cornerRadius: 16)
        }
    }

    // MARK: - Aktions-Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button { save() } label: {
                Text(localizer.localizedString(forKey: "save_button"))
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
                    Label(localizer.localizedString(forKey: "delete_task"), systemImage: "trash")
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
        if title != (t?.title ?? "") { return true }
        if bodyText != (t?.description ?? "") { return true }
        if priority != (t?.priority ?? .medium) { return true }
        if hasDueDate != (t?.dueDate != nil || prefilledDate != nil) { return true }
        if hasEndTime != (t?.endDate != nil) { return true }
        if recurrenceEnabled != (t?.recurrenceEnabled ?? false) { return true }
        if !selectedImages.isEmpty && (t?.imageDataArray ?? []).isEmpty { return true }
        return false
    }

    private func addSubTask() {
        let s = newSubTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        withAnimation { subTasks.append(SubTask(title: s)) }
        newSubTaskTitle = ""
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let randomColor = String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
        let newCat = Category(name: name, colorHex: randomColor)
        todoStore.addCategory(newCat)
        category = todoStore.categories.first(where: { $0.name == name }) ?? newCat
        newCategoryName = ""
    }

    private func checkCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:       showCamera = true
        case .notDetermined:    AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { granted ? (showCamera = true) : (showCameraPermAlert = true) }
        }
        default:                showCameraPermAlert = true
        }
    }

    @MainActor
    private func loadPhotos() async {
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img  = UIImage(data: data) {
                let w = IdentifiableUIImage(image: img)
                if !selectedImages.contains(w) { selectedImages.append(w) }
            }
        }
        selectedItems = []
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let rule: TodoItem.RecurrenceRule = {
            guard recurrenceEnabled else { return .none }
            switch recurrenceFreq {
            case "weekly":  return .weekly(interval: recurrenceInterval, weekdays: weeklyWeekdays.isEmpty ? nil : Array(weeklyWeekdays).sorted())
            case "monthly": return .monthly(interval: recurrenceInterval)
            default:        return .daily(interval: recurrenceInterval)
            }
        }()

        let imageData = selectedImages.compactMap { $0.image.jpegData(compressionQuality: 0.8) }

        let saved = TodoItem(
            id:                    existingTodo?.id ?? UUID(),
            title:                 trimmed,
            description:           bodyText,
            isCompleted:           existingTodo?.isCompleted ?? false,
            dueDate:               hasDueDate ? dueDate : nil,
            reminderOffsetMinutes: hasDueDate && reminderOffset >= 0 ? reminderOffset : nil,
            recurrenceEnabled:     recurrenceEnabled,
            recurrenceRule:        rule,
            lastCompletionDate:    existingTodo?.lastCompletionDate,
            nextResetDate:         existingTodo?.nextResetDate,
            category:              category,
            priority:              priority,
            subTasks:              subTasks,
            createdAt:             existingTodo?.createdAt ?? Date(),
            updatedAt:             Date(),
            completedAt:           existingTodo?.completedAt,
            lastResetDate:         existingTodo?.lastResetDate,
            calendarEventIdentifier: existingTodo?.calendarEventIdentifier,
            focusTimeInMinutes:    existingTodo?.focusTimeInMinutes,
            imageDataArray:        imageData,
            calendarEnabled:       addToCalendar,
            isFavorite:            existingTodo?.isFavorite ?? false,
            customFolder:          existingTodo?.customFolder,
            endDate:               hasDueDate && hasEndTime ? endDate : nil
        )

        if isEditMode {
            todoStore.updateTodo(saved)
        } else {
            todoStore.addTodo(saved)
        }

        if addToCalendar && hasDueDate {
            addCalendarEvent(for: saved)
        }

        dismiss()
    }

    private func addCalendarEvent(for todo: TodoItem) {
        let store = EKEventStore()
        store.requestAccess(to: .event) { granted, _ in
            guard granted, let due = todo.dueDate else {
                DispatchQueue.main.async { calendarAccessDenied = !granted }
                return
            }
            let event = EKEvent(eventStore: store)
            event.title = todo.title
            event.notes = todo.description
            event.startDate = due
            event.endDate = todo.endDate ?? due.addingTimeInterval(3600)
            if let off = todo.reminderOffsetMinutes, off >= 0 {
                event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-off * 60)))
            }
            event.calendar = selectedCalendar ?? store.defaultCalendarForNewEvents
            try? store.save(event, span: .thisEvent)
        }
    }
}
