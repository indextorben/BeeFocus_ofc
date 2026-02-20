import SwiftUI
import PhotosUI
import AVFoundation
import EventKit

struct EditTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    let todo: TodoItem
    
    // MARK: - Form fields
    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var reminderSelection: Int = -1 // -1 = no reminder, 0 = at time, >0 = minutes before
    @State private var reminderTitle: String = ""
    @State private var reminderBody: String = ""
    @State private var category: Category
    @State private var priority: TodoPriority
    @State private var subTasks: [SubTask]
    @State private var newSubTaskTitle = ""
    
    // MARK: - Recurrence
    @State private var recurrenceEnabled: Bool = false
    @State private var recurrenceFrequency: String = "daily"  // "daily", "weekly", "monthly", "yearly"
    @State private var recurrenceInterval: Int = 1
    @State private var weeklyWeekdays: Set<Int> = []
    
    // MARK: - Image handling
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [IdentifiableUIImage] = []
    @State private var selectedImageForPreview: IdentifiableUIImage?
    @State private var imageToDelete: IdentifiableUIImage?
    
    // MARK: - State controls
    @State private var showDeleteConfirmation = false
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var showDiscardDialog = false
    
    // MARK: - Kategorie
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showCategoryAlert = false
    
    // MARK: - Kalender
    @State private var addToCalendar = false
    @State private var calendarAccessDenied = false
    @State private var selectedWeekOption: String? = nil
    
    // MARK: - Localization
    @ObservedObject private var localizer = LocalizationManager.shared

    private var dynamicDefaultReminderTitle: String {
        let loc = LocalizationManager.shared
        let isGerman = (loc.currentLanguageCode == "de")
        let keyTitle = (reminderSelection >= 0) ? (isGerman ? "reminder_default_title_de" : "reminder_default_title_en") : (isGerman ? "due_default_title_de" : "due_default_title_en")
        let template = loc.localizedString(forKey: keyTitle)
        let baseTitle = title.isEmpty ? loc.localizedString(forKey: "task_title") : title
        return template.replacingOccurrences(of: "%@", with: baseTitle)
    }
    private var dynamicDefaultReminderBody: String {
        let loc = LocalizationManager.shared
        let isGerman = (loc.currentLanguageCode == "de")
        let hasDescription = !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let bodyKey = (reminderSelection >= 0) ? (isGerman ? "reminder_default_body_de" : "reminder_default_body_en") : (isGerman ? "due_default_body_de" : "due_default_body_en")
        var template = loc.localizedString(forKey: bodyKey)
        let fallbackKey = (reminderSelection >= 0) ? (isGerman ? "reminder_default_body_fallback_de" : "reminder_default_body_fallback_en") : (isGerman ? "due_default_body_fallback_de" : "due_default_body_fallback_en")
        let desc = hasDescription ? description : loc.localizedString(forKey: fallbackKey)
        return template.replacingOccurrences(of: "%@", with: desc)
    }

    // MARK: - Init
    init(todo: TodoItem) {
        self.todo = todo
        _title = State(initialValue: todo.title)
        _description = State(initialValue: todo.description)
        _dueDate = State(initialValue: todo.dueDate ?? Date())
        _hasDueDate = State(initialValue: todo.dueDate != nil)
        if let off = todo.reminderOffsetMinutes {
            if [0,5,15,30,60,120,1440].contains(off) {
                _reminderSelection = State(initialValue: off)
            } else {
                _reminderSelection = State(initialValue: 0)
            }
        } else {
            _reminderSelection = State(initialValue: -1)
        }
        _reminderTitle = State(initialValue: todo.reminderTitle ?? "")
        _reminderBody = State(initialValue: todo.reminderBody ?? "")
        _category = State(initialValue: todo.category ?? Category(id: UUID(), name: "Keine Kategorie", colorHex: "#FFFFFF"))
        _priority = State(initialValue: todo.priority)
        _subTasks = State(initialValue: todo.subTasks)
        _selectedImages = State(initialValue: todo.imageDataArray.compactMap {
            UIImage(data: $0).map { IdentifiableUIImage(image: $0) }
        })
        
        // Recurrence initialization
        _recurrenceEnabled = State(initialValue: todo.recurrenceEnabled)
        if todo.recurrenceEnabled {
            switch todo.recurrenceRule {
            case .none:
                _recurrenceFrequency = State(initialValue: "daily")
                _recurrenceInterval = State(initialValue: 1)
                _weeklyWeekdays = State(initialValue: [])
            case .daily(let interval):
                _recurrenceFrequency = State(initialValue: "daily")
                _recurrenceInterval = State(initialValue: interval)
                _weeklyWeekdays = State(initialValue: [])
            case .weekly(let interval, let weekdays):
                _recurrenceFrequency = State(initialValue: "weekly")
                _recurrenceInterval = State(initialValue: interval)
                _weeklyWeekdays = State(initialValue: Set(weekdays ?? []))
            case .monthly(let interval):
                _recurrenceFrequency = State(initialValue: "monthly")
                _recurrenceInterval = State(initialValue: interval)
                _weeklyWeekdays = State(initialValue: [])
            }
        } else {
            _recurrenceFrequency = State(initialValue: "daily")
            _recurrenceInterval = State(initialValue: 1)
            _weeklyWeekdays = State(initialValue: [])
        }
    }
    
    // MARK: - Change detection
    private func basicFieldsChanged() -> Bool {
        if title != todo.title { return true }
        if description != todo.description { return true }
        if (todo.dueDate != nil) != hasDueDate { return true }
        if hasDueDate, dueDate != (todo.dueDate ?? Date.distantPast) { return true }
        return false
    }

    private func reminderChanged() -> Bool {
        let currentOffset: Int? = (reminderSelection == -1) ? nil : reminderSelection
        if currentOffset != todo.reminderOffsetMinutes { return true }
        let trimmedTitle = reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = reminderBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if (todo.reminderTitle ?? "") != trimmedTitle { return true }
        if (todo.reminderBody ?? "") != trimmedBody { return true }
        return false
    }

    private func categoryOrPriorityChanged() -> Bool {
        if category != (todo.category ?? Category(id: UUID(), name: "Keine Kategorie", colorHex: "#FFFFFF")) { return true }
        if priority != todo.priority { return true }
        return false
    }

    private func subTasksChanged() -> Bool {
        return subTasks != todo.subTasks
    }

    private func imagesChanged() -> Bool {
        let originalImages: [Data] = todo.imageDataArray
        let currentImages: [Data] = selectedImages.compactMap { $0.image.jpegData(compressionQuality: 0.8) }
        return originalImages != currentImages
    }

    private func recurrenceChanged() -> Bool {
        if recurrenceEnabled != todo.recurrenceEnabled { return true }
        if recurrenceEnabled {
            switch (todo.recurrenceRule, recurrenceFrequency) {
            case (.daily(let oldInterval), "daily"):
                if oldInterval != recurrenceInterval { return true }
            case (.weekly(let oldInterval, let oldDays), "weekly"):
                let newDays = Array(weeklyWeekdays).sorted()
                if oldInterval != recurrenceInterval { return true }
                if (oldDays ?? []) != newDays { return true }
            case (.monthly(let oldInterval), "monthly"):
                if oldInterval != recurrenceInterval { return true }
            default:
                return true
            }
        }
        return false
    }

    private func hasUnsavedChanges() -> Bool {
        if basicFieldsChanged() { return true }
        if reminderChanged() { return true }
        if categoryOrPriorityChanged() { return true }
        if subTasksChanged() { return true }
        if imagesChanged() { return true }
        if recurrenceChanged() { return true }
        return false
    }
    
    // MARK: - Body
    private var formContent: some View {
        Form {
            basicInfoSection
            categoryAndPrioritySection
            dueDateSection
            recurrenceSection
            calendarToggleSection
            imagesSection
            subTasksSection
        }
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle(localizer.localizedString(forKey: "edit_todo_title"))
                .toolbar { toolbarContent }
        }
        .sheet(item: $selectedImageForPreview) { wrappedImage in
            ImagePreviewView(image: wrappedImage.image)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let image = image {
                    selectedImages.append(IdentifiableUIImage(image: image))
                }
            }
        }
        .alert(localizer.localizedString(forKey: "camera_access_required"), isPresented: $showCameraPermissionAlert) {
            settingsAlertButtons
        } message: {
            Text(localizer.localizedString(forKey: "camera_access_explanation"))
        }
        .alert(localizer.localizedString(forKey: "delete_image_title"), isPresented: $showDeleteConfirmation, presenting: imageToDelete) { image in
            deleteImageAlertButtons(for: image)
        } message: { _ in
            Text(localizer.localizedString(forKey: "delete_image_message"))
        }
        .alert(localizer.localizedString(forKey: "new_category_title"), isPresented: $showAddCategoryAlert) {
            VStack { TextField(localizer.localizedString(forKey: "new_category_placeholder"), text: $newCategoryName) }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) { newCategoryName = "" }
            Button(localizer.localizedString(forKey: "add_button")) { addNewCategory() }
        } message: {
            Text(localizer.localizedString(forKey: "new_category_message"))
        }
        .alert(localizer.localizedString(forKey: "category_missing_title"), isPresented: $showCategoryAlert) {
            Button(localizer.localizedString(forKey: "ok_button"), role: .cancel) { }
        } message: {
            Text(localizer.localizedString(forKey: "category_missing_message"))
        }
        .alert(localizer.localizedString(forKey: "calendar_access_denied_title"), isPresented: $calendarAccessDenied) {
            Button(localizer.localizedString(forKey: "ok_button"), role: .cancel) { }
        } message: {
            Text(localizer.localizedString(forKey: "calendar_access_denied_message"))
        }
        .onAppear {
            if hasDueDate { selectedWeekOption = presetLabel(for: dueDate) }
        }
        .onChange(of: dueDate) { newValue in
            selectedWeekOption = hasDueDate ? presetLabel(for: newValue) : nil
        }
        .onChange(of: hasDueDate) { newValue in
            if !newValue { selectedWeekOption = nil }
        }
        .interactiveDismissHandling(hasUnsavedChanges(), onAttempt: { showDiscardDialog = true })
        .confirmationDialog(localizer.localizedString(forKey: "discard_changes_title"), isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button(localizer.localizedString(forKey: "discard_changes"), role: .destructive) { dismiss() }
            Button(localizer.localizedString(forKey: "delete_task"), role: .destructive) {
                todoStore.deleteTodo(todo)
                dismiss()
            }
            Button(localizer.localizedString(forKey: "keep_editing"), role: .cancel) { }
        } message: {
            Text(localizer.localizedString(forKey: "discard_changes_message"))
        }
    }
    
    // MARK: - Sections
    private var basicInfoSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "todo_title_section"))) {
            TextField(localizer.localizedString(forKey: "todo_title_placeholder"), text: $title)
            TextEditor(text: $description)
                .frame(height: 100)
        }
    }
    
    private var categoryAndPrioritySection: some View {
        Section(header: Text(localizer.localizedString(forKey: "category_priority_section"))) {
            Picker(localizer.localizedString(forKey: "category_picker_label"), selection: $category) {
                ForEach(todoStore.categories, id: \.self) { category in
                    Text(category.name).tag(category)
                }
            }
            
            Button {
                showAddCategoryAlert = true
            } label: {
                Label(localizer.localizedString(forKey: "add_category_button"), systemImage: "plus.circle")
                    .foregroundColor(.blue)
            }
            
            Picker(localizer.localizedString(forKey: "priority_picker_label"), selection: $priority) {
                ForEach(TodoPriority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
        }
    }
    
    private var dueDateSection: some View {
        Section {
            Toggle(isOn: $hasDueDate) {
                Label(localizer.localizedString(forKey: "due_date_toggle"), systemImage: "calendar")
            }
            if hasDueDate {
                DatePicker(localizer.localizedString(forKey: "due_date_picker"), selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                Picker(localizer.localizedString(forKey: "reminder_label"), selection: $reminderSelection) {
                    Text(localizer.localizedString(forKey: "reminder_none")).tag(-1)
                    Text(localizer.localizedString(forKey: "reminder_at_time")).tag(0)
                    Text(localizer.localizedString(forKey: "reminder_5m")).tag(5)
                    Text(localizer.localizedString(forKey: "reminder_15m")).tag(15)
                    Text(localizer.localizedString(forKey: "reminder_30m")).tag(30)
                    Text(localizer.localizedString(forKey: "reminder_1h")).tag(60)
                    Text(localizer.localizedString(forKey: "reminder_2h")).tag(120)
                    Text(localizer.localizedString(forKey: "reminder_1d")).tag(1440)
                }
                TextField("", text: $reminderTitle, prompt: Text(dynamicDefaultReminderTitle))
                TextField("", text: $reminderBody, prompt: Text(dynamicDefaultReminderBody), axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }
    
    private var recurrenceSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "recurrence_section_header"))) {
            Toggle(localizer.localizedString(forKey: "recurrence_enabled_toggle"), isOn: $recurrenceEnabled)
            
            if recurrenceEnabled {
                Picker(localizer.localizedString(forKey: "recurrence_frequency_picker"), selection: $recurrenceFrequency) {
                    Text(localizer.localizedString(forKey: "recurrence_daily")).tag("daily")
                    Text(localizer.localizedString(forKey: "recurrence_weekly")).tag("weekly")
                    Text(localizer.localizedString(forKey: "recurrence_monthly")).tag("monthly")
                }
                .pickerStyle(.segmented)
                
                Stepper(value: $recurrenceInterval, in: 1...30) {
                    Text("\(localizer.localizedString(forKey: "recurrence_interval")): \(recurrenceInterval)")
                }
                if recurrenceFrequency == "weekly" {
                    VStack(alignment: .leading) {
                        Text(localizer.localizedString(forKey: "recurrence_weekdays_label"))
                        WeekdayPicker(selectedWeekdays: $weeklyWeekdays, localizer: localizer)
                    }
                }
            }
        }
    }
    
    private var calendarToggleSection: some View {
        Section {
            Toggle(localizer.localizedString(forKey: "add_to_calendar_toggle"), isOn: $addToCalendar)
            
            Menu {
                Button(localizer.localizedString(forKey: "weekly_goal_today")) {
                    withAnimation {
                        hasDueDate = true
                        dueDate = Date().endOfDay
                        selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_today")
                    }
                }
                Button(localizer.localizedString(forKey: "weekly_goal_midweek")) {
                    withAnimation {
                        hasDueDate = true
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        let mid = cal.date(byAdding: .day, value: 3, to: start) ?? start
                        dueDate = mid.endOfDay
                        selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_midweek")
                    }
                }
                Button(localizer.localizedString(forKey: "weekly_goal_end_this_week")) {
                    withAnimation {
                        hasDueDate = true
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        let end = cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? Date()
                        dueDate = end
                        selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_end_this_week")
                    }
                }
                Button(localizer.localizedString(forKey: "weekly_goal_end_next_week")) {
                    withAnimation {
                        hasDueDate = true
                        let cal = Calendar.current
                        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                        let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
                        let nextEnd = cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
                        dueDate = nextEnd
                        selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_end_next_week")
                    }
                }
                Divider()
                Button(localizer.localizedString(forKey: "weekly_goal_custom")) { /* Nutzer wählt im DatePicker selbst */ }
            } label: {
                if let sel = selectedWeekOption, !sel.isEmpty {
                    Label(String(format: localizer.localizedString(forKey: "weekly_goal_set_selected"), sel), systemImage: "target")
                } else {
                    Label(localizer.localizedString(forKey: "weekly_goal_set"), systemImage: "target")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var imagesSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "images_section"))) {
            if !selectedImages.isEmpty { imagesScrollView }
            photoPickerButton
            cameraButton
        }
    }
    
    private var imagesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(selectedImages) { wrappedImage in
                    Image(uiImage: wrappedImage.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onTapGesture { selectedImageForPreview = wrappedImage }
                        .contextMenu { deleteButton(for: wrappedImage) }
                }
            }.padding(.vertical, 5)
        }.frame(minHeight: 110)
    }
    
    private var photoPickerButton: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 5,
            matching: .images
        ) { actionLabel(localizer.localizedString(forKey: "select_from_gallery"), systemImage: "photo.on.rectangle") }
        .onChange(of: selectedItems) { Task { await processSelectedItems() } }
    }
    
    private var cameraButton: some View {
        Button(action: checkCameraPermission) {
            actionLabel(localizer.localizedString(forKey: "capture_with_camera"), systemImage: "camera")
        }
        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
    }
    
    private var subTasksSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "subtasks_section"))) {
            ForEach(subTasks) { subTask in
                HStack {
                    Text(subTask.title)
                    Spacer()
                    Button(action: { deleteSubTask(subTask) }) {
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
            }
            
            HStack {
                TextField(localizer.localizedString(forKey: "new_subtask_placeholder"), text: $newSubTaskTitle)
                Button(action: addSubTask) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                }.disabled(newSubTaskTitle.isEmpty)
            }
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button(localizer.localizedString(forKey: "cancel_button")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button(localizer.localizedString(forKey: "save_button")) { saveTodo() }.disabled(title.isEmpty) }
    }
    
    // MARK: - Helper Views
    private func actionLabel(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
    }
    
    private func deleteButton(for image: IdentifiableUIImage) -> some View {
        Button(role: .destructive) {
            imageToDelete = image
            showDeleteConfirmation = true
        } label: { Label(localizer.localizedString(forKey: "delete_button"), systemImage: "trash") }
    }
    
    private var settingsAlertButtons: some View {
        Group {
            Button(localizer.localizedString(forKey: "settings_button")) { openAppSettings() }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) { }
        }
    }
    
    private func deleteImageAlertButtons(for image: IdentifiableUIImage) -> some View {
        Group {
            Button(localizer.localizedString(forKey: "delete_button"), role: .destructive) { selectedImages.removeAll { $0.id == image.id } }
            Button(localizer.localizedString(forKey: "cancel_button"), role: .cancel) { }
        }
    }

    private func presetLabel(for date: Date) -> String? {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let endOfThisWeek = cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? today
        let midOfWeek = cal.date(byAdding: .day, value: 3, to: start)?.endOfDay ?? today
        let endOfNextWeek: Date = {
            let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
        }()
        let d = date
        if cal.isDate(d, inSameDayAs: today) { return localizer.localizedString(forKey: "weekly_goal_today") }
        if cal.isDate(d, inSameDayAs: midOfWeek) { return localizer.localizedString(forKey: "weekly_goal_midweek") }
        if cal.isDate(d, inSameDayAs: endOfThisWeek) { return localizer.localizedString(forKey: "weekly_goal_end_this_week") }
        if cal.isDate(d, inSameDayAs: endOfNextWeek) { return localizer.localizedString(forKey: "weekly_goal_end_next_week") }
        return nil
    }
    
    // MARK: - Logic
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showCamera = true
        case .notDetermined: requestCameraAccess()
        case .denied, .restricted: showCameraPermissionAlert = true
        @unknown default: break
        }
    }
    
    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { granted ? (showCamera = true) : (showCameraPermissionAlert = true) }
        }
    }
    
    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    @MainActor
    private func processSelectedItems() async {
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let image = IdentifiableUIImage(image: uiImage)
                if !selectedImages.contains(image) { selectedImages.append(image) }
            }
        }
        selectedItems = []
    }
    
    private func addSubTask() {
        guard !newSubTaskTitle.isEmpty else { return }
        subTasks.append(SubTask(title: newSubTaskTitle))
        newSubTaskTitle = ""
    }
    
    private func deleteSubTask(_ subTask: SubTask) {
        subTasks.removeAll { $0.id == subTask.id }
    }
    
    private func addNewCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let randomColor = String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
        let newCategory = Category(name: trimmedName, colorHex: randomColor)
        // Persist via store so it syncs to CloudKit and updates the dashboard
        todoStore.addCategory(newCategory)
        category = newCategory
        newCategoryName = ""
    }
    
    private func saveTodo() {
        if todoStore.categories.isEmpty { showCategoryAlert = true; return }
        
        let finalOffset: Int?
        switch reminderSelection {
        case -1:
            finalOffset = nil
        default:
            finalOffset = reminderSelection
        }
        
        let imageDataArray = selectedImages.compactMap { $0.image.jpegData(compressionQuality: 0.8) }
        
        let recurrenceRule: TodoItem.RecurrenceRule = {
            if !recurrenceEnabled { return .none }
            switch recurrenceFrequency {
            case "daily":
                return .daily(interval: recurrenceInterval)
            case "weekly":
                let days = Array(weeklyWeekdays).sorted()
                return .weekly(interval: recurrenceInterval, weekdays: days.isEmpty ? nil : days)
            case "monthly":
                return .monthly(interval: recurrenceInterval)
            default:
                return .none
            }
        }()
        
        let updatedTodo = TodoItem(
            id: todo.id,
            title: title,
            description: description,
            isCompleted: todo.isCompleted,
            dueDate: hasDueDate ? dueDate : nil,
            reminderOffsetMinutes: finalOffset,
            reminderTitle: reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderBody: reminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminderBody.trimmingCharacters(in: .whitespacesAndNewlines),
            recurrenceEnabled: recurrenceEnabled,
            recurrenceRule: recurrenceRule,
            category: category,
            priority: priority,
            subTasks: subTasks,
            imageDataArray: imageDataArray
        )
        
        todoStore.updateTodo(updatedTodo)
        
        if addToCalendar && hasDueDate { requestCalendarAccessAndAddEvent() }
        dismiss()
    }
    
    private func requestCalendarAccessAndAddEvent() {
        let eventStore = EKEventStore()
        eventStore.requestAccess(to: .event) { granted, _ in
            if granted {
                let event = EKEvent(eventStore: eventStore)
                event.title = title
                event.notes = description
                event.startDate = dueDate
                event.endDate = dueDate.addingTimeInterval(3600)
                event.calendar = eventStore.defaultCalendarForNewEvents
                
                let offsetForAlarm: Int?
                switch reminderSelection {
                case -1: offsetForAlarm = nil
                default: offsetForAlarm = reminderSelection
                }
                if let off = offsetForAlarm, off >= 0 {
                    let alarm = EKAlarm(relativeOffset: TimeInterval(-off * 60))
                    event.addAlarm(alarm)
                }
                
                do { try eventStore.save(event, span: .thisEvent) }
                catch { print("Error saving calendar event: \(error)") }
            } else {
                DispatchQueue.main.async { calendarAccessDenied = true }
            }
        }
    }
}

private extension Date {
    var endOfDay: Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: self)
        return cal.date(bySettingHour: 23, minute: 59, second: 59, of: start) ?? self
    }
}
// Supporting weekday picker view for recurrence weekly weekdays selection
private struct WeekdayPicker: View {
    @Binding var selectedWeekdays: Set<Int>
    var localizer: LocalizationManager
    
    private var weekdaySymbols: [String] {
        let df = DateFormatter()
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        return df.shortWeekdaySymbols // Sunday-first
    }
    private let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1] // Monday-first order (1=Sun..7=Sat)
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<weekdayOrder.count, id: \.self) { idx in
                let dayIndex = weekdayOrder[idx]
                let symbolIndex = (dayIndex - 1 + 7) % 7
                let dayName = weekdaySymbols[symbolIndex]
                Button(action: {
                    if selectedWeekdays.contains(dayIndex) {
                        selectedWeekdays.remove(dayIndex)
                    } else {
                        selectedWeekdays.insert(dayIndex)
                    }
                }) {
                    Text(dayName)
                        .font(.caption)
                        .frame(width: 30, height: 30)
                        .foregroundColor(selectedWeekdays.contains(dayIndex) ? .white : .primary)
                        .background(selectedWeekdays.contains(dayIndex) ? Color.blue : Color.clear)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(dayName)
                .accessibilityAddTraits(selectedWeekdays.contains(dayIndex) ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

private extension View {
    func interactiveDismissHandling(_ isDisabled: Bool, onAttempt: @escaping () -> Void) -> some View {
        self.interactiveDismissDisabled(isDisabled)
    }
}
