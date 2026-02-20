import SwiftUI
import PhotosUI
import AVFoundation
import EventKit

extension View {
    @ViewBuilder
    fileprivate func contentViewInteractiveDismiss(hasUnsavedChanges: Bool) -> some View {
        self.interactiveDismissDisabled(hasUnsavedChanges)
    }
}

// MARK: - IdentifiableUIImage
struct IdentifiableUIImage: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: IdentifiableUIImage, rhs: IdentifiableUIImage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CameraPicker
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) private var presentationMode
    var completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.completion(image.fixOrientation())
            } else {
                parent.completion(nil)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension UIImage {
    func fixOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}

// MARK: - AddTodoView
struct AddTodoView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var reminderSelection: Int = -1 // -1 = no reminder, 0 = at time, >0 = minutes before, -2 = custom
    @State private var category: Category?
    @State private var priority = TodoPriority.medium
    @State private var subTasks: [SubTask] = []
    @State private var newSubTaskTitle = ""

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [IdentifiableUIImage] = []
    @State private var selectedImageForPreview: IdentifiableUIImage?
    @State private var imageToDelete: IdentifiableUIImage?

    @State private var showDeleteConfirmation = false
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    @State private var addToCalendar = false
    @State private var calendarAccessDenied = false
    @State private var showCategoryAlert = false
    @State private var selectedWeekOption: String? = nil

    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showDiscardDialog = false

    // New recurrence states
    @State private var recurrenceEnabled: Bool = false
    @State private var recurrenceFrequency: String = "daily"
    @State private var recurrenceInterval: Int = 1
    @State private var weeklyWeekdays: Set<Int> = []

    // Added per instructions
    @State private var reminderTitle: String = ""
    @State private var reminderBody: String = ""
    private let allowedDynamicTypeRange: ClosedRange<DynamicTypeSize> = .xSmall ... .large

    private var dynamicDefaultReminderTitle: String {
        let loc = LocalizationManager.shared
        let isGerman = (loc.currentLanguageCode == "de")
        let keyTitle = (reminderSelection >= 0) ? (isGerman ? "reminder_default_title_de" : "reminder_default_title_en") : (isGerman ? "due_default_title_de" : "due_default_title_en")
        let template = loc.localizedString(forKey: keyTitle)
        return template.replacingOccurrences(of: "%@", with: title.isEmpty ? loc.localizedString(forKey: "task_title") : title)
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
    private var hasUnsavedChanges: Bool {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if hasDueDate { return true }
        if reminderSelection != -1 { return true }
        if !reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !reminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !subTasks.isEmpty { return true }
        if !selectedImages.isEmpty { return true }
        return false
    }

    var body: some View {
        rootNavigationView
    }

    @ViewBuilder
    private var rootNavigationView: some View {
        NavigationView {
            let mainContent = contentView
                .navigationTitle(localizer.localizedString(forKey: "new_task_title"))

            mainContent
                .toolbar { toolbarContent }
        }
    }

    private var contentView: some View {
        let formContent = Form {
            basicInfoSection
            categoryAndPrioritySection
            dueDateSection
            // Insert Recurrence Section here
            recurrenceSection
            calendarToggleSection
            imagesSection
            subTasksSection
        }

        return formContent
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
                Text(localizer.localizedString(forKey: "camera_access_message"))
            }
            .alert(localizer.localizedString(forKey: "delete_image"), isPresented: $showDeleteConfirmation, presenting: imageToDelete) { image in
                deleteImageAlertButtons(for: image)
            } message: { _ in
                Text(localizer.localizedString(forKey: "delete_image_message"))
            }
            .alert(localizer.localizedString(forKey: "calendar_access_denied"), isPresented: $calendarAccessDenied) {
                Button(localizer.localizedString(forKey: "ok"), role: .cancel) { }
            } message: {
                Text(localizer.localizedString(forKey: "calendar_access_message"))
            }
            .alert(localizer.localizedString(forKey: "category_missing"), isPresented: $showCategoryAlert) {
                Button(localizer.localizedString(forKey: "ok"), role: .cancel) { }
            } message: {
                Text(localizer.localizedString(forKey: "category_missing_message"))
            }
            .onAppear {
                // Kategorie automatisch setzen oder Default anlegen
                if category == nil {
                    if let first = todoStore.categories.first {
                        category = first
                    } else {
                        let defaultCategory = Category(name: "Allgemein", colorHex: "#007AFF")
                        todoStore.addCategory(defaultCategory)
                        category = defaultCategory
                    }
                }
                reminderSelection = -1

                if hasDueDate {
                    selectedWeekOption = presetLabel(for: dueDate)
                }
            }
            .onChange(of: selectedItems) { _ in
                Task { await processSelectedItems() }
            }
            .onChange(of: dueDate) { newValue in
                selectedWeekOption = hasDueDate ? presetLabel(for: newValue) : nil
            }
            .onChange(of: hasDueDate) { newValue in
                if !newValue { selectedWeekOption = nil }
            }
            .modifier(InteractiveDismissWrapper(hasUnsavedChanges: hasUnsavedChanges, showDiscardDialog: $showDiscardDialog))
            .confirmationDialog(localizer.localizedString(forKey: "discard_changes_title"), isPresented: $showDiscardDialog, titleVisibility: .visible) {
                Button(localizer.localizedString(forKey: "discard_changes"), role: .destructive) { dismiss() }
                Button(localizer.localizedString(forKey: "keep_editing"), role: .cancel) { }
            } message: {
                Text(localizer.localizedString(forKey: "discard_changes_message"))
            }
    }

    private struct InteractiveDismissWrapper: ViewModifier {
        let hasUnsavedChanges: Bool
        @Binding var showDiscardDialog: Bool

        func body(content: Content) -> some View {
            content.contentViewInteractiveDismiss(hasUnsavedChanges: hasUnsavedChanges)
        }
    }

    // MARK: - Sections
    private var basicInfoSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "task_title"))) {
            TextField(localizer.localizedString(forKey: "title_placeholder"), text: $title)
            TextEditor(text: $description)
                .frame(height: 100)
        }
    }

    private var categoryAndPrioritySection: some View {
        Section(header: Text(localizer.localizedString(forKey: "categorization"))) {
            Picker(localizer.localizedString(forKey: "category"), selection: $category) {
                ForEach(todoStore.categories, id: \.self) { category in
                    Text(category.name).tag(Optional(category))
                }
            }

            Button {
                showAddCategoryAlert = true
            } label: {
                Label(localizer.localizedString(forKey: "add_category"), systemImage: "plus.circle")
                    .foregroundColor(.blue)
            }
            .alert(localizer.localizedString(forKey: "new_category"), isPresented: $showAddCategoryAlert) {
                VStack {
                    TextField(localizer.localizedString(forKey: "category_name_placeholder"), text: $newCategoryName)
                }
                Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { newCategoryName = "" }
                Button(localizer.localizedString(forKey: "add")) { addNewCategory() }
            } message: {
                Text(localizer.localizedString(forKey: "enter_new_category_name"))
            }

            Picker(localizer.localizedString(forKey: "priority"), selection: $priority) {
                ForEach(TodoPriority.allCases) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
        }
    }

    private var dueDateSection: some View {
        let dateTimeLabel: String = localizer.localizedString(forKey: "date_time")
        let components: DatePickerComponents = [.date, .hourAndMinute]
        let reminderLabel = localizer.localizedString(forKey: "reminder_label")
        let reminderNone = localizer.localizedString(forKey: "reminder_none")
        let reminderAtTime = localizer.localizedString(forKey: "reminder_at_time")
        let reminder5m = localizer.localizedString(forKey: "reminder_5m")
        let reminder15m = localizer.localizedString(forKey: "reminder_15m")
        let reminder30m = localizer.localizedString(forKey: "reminder_30m")
        let reminder1h = localizer.localizedString(forKey: "reminder_1h")
        let reminder2h = localizer.localizedString(forKey: "reminder_2h")
        let reminder1d = localizer.localizedString(forKey: "reminder_1d")
        return Section {
            Toggle(localizer.localizedString(forKey: "enable_due_date"), isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(dateTimeLabel, selection: $dueDate, displayedComponents: components)
                    .datePickerStyle(.compact)
                    .font(.callout)
                Picker(reminderLabel, selection: $reminderSelection) {
                    Text(reminderNone).tag(-1)
                    Text(reminderAtTime).tag(0)
                    Text(reminder5m).tag(5)
                    Text(reminder15m).tag(15)
                    Text(reminder30m).tag(30)
                    Text(reminder1h).tag(60)
                    Text(reminder2h).tag(120)
                    Text(reminder1d).tag(1440)
                }
                TextField("", text: $reminderTitle, prompt: Text(dynamicDefaultReminderTitle))
                TextField("", text: $reminderBody, prompt: Text(dynamicDefaultReminderBody), axis: .vertical)
                    .lineLimit(4)
                Text(localizer.localizedString(forKey: "reminder_edit_hint"))
                    .font(.footnote)
                    .foregroundColor(.secondary)
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

                Stepper(value: $recurrenceInterval, in: 1...100) {
                    Text("\(localizer.localizedString(forKey: "recurrence_interval")): \(recurrenceInterval)")
                }

                if recurrenceFrequency == "weekly" {
                    VStack(alignment: .leading) {
                        Text(localizer.localizedString(forKey: "recurrence_weekdays_label"))
                        HStack {
                            ForEach(orderedWeekdays, id: \.self) { day in
                                let dayShort = shortWeekdaySymbol(day)
                                Button(action: {
                                    if weeklyWeekdays.contains(day) {
                                        weeklyWeekdays.remove(day)
                                    } else {
                                        weeklyWeekdays.insert(day)
                                    }
                                }) {
                                    Text(dayShort)
                                        .font(.caption)
                                        .padding(6)
                                        .background(weeklyWeekdays.contains(day) ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                                        .foregroundColor(weeklyWeekdays.contains(day) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    private func shortWeekdaySymbol(_ weekday: Int) -> String {
        // weekday: 1=Sunday ... 7=Saturday
        let df = DateFormatter()
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        // Some SDKs expose optional weekday symbol arrays. Safely unwrap and fall back to veryShort symbols if empty.
        let primary: [String] = df.shortWeekdaySymbols ?? []
        let fallback: [String] = df.veryShortWeekdaySymbols ?? []
        let symbols: [String] = primary.isEmpty ? fallback : primary
        let index = (weekday - 1 + 7) % 7
        if symbols.indices.contains(index) {
            return symbols[index]
        }
        return "?"
    }
    private var orderedWeekdays: [Int] { [2, 3, 4, 5, 6, 7, 1] }

    private var calendarToggleSection: some View {
        Section {
            Toggle(localizer.localizedString(forKey: "add_to_system_calendar"), isOn: $addToCalendar)

            Menu {
                Button(localizer.localizedString(forKey: "weekly_goal_today")) {
                    withAnimation {
                        hasDueDate = true
                    }
                    dueDate = Date().endOfDay
                    selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_today")
                }
                Button(localizer.localizedString(forKey: "weekly_goal_midweek")) {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let mid = cal.date(byAdding: .day, value: 3, to: start) ?? start
                    dueDate = mid.endOfDay
                    selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_midweek")
                }
                Button(localizer.localizedString(forKey: "weekly_goal_end_this_week")) {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let end = cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? Date()
                    dueDate = end
                    selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_end_this_week")
                }
                Button(localizer.localizedString(forKey: "weekly_goal_end_next_week")) {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
                    let nextEnd = cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
                    dueDate = nextEnd
                    selectedWeekOption = localizer.localizedString(forKey: "weekly_goal_end_next_week")
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
        Section(header: Text(localizer.localizedString(forKey: "images"))) {
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(selectedImages) { image in
                            Image(uiImage: image.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { selectedImageForPreview = image }
                                .contextMenu { deleteButton(for: image) }
                        }
                    }.padding(.vertical, 5)
                }
                .frame(minHeight: 110)
            }

            PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                actionLabel(localizer.localizedString(forKey: "select_from_gallery"), systemImage: "photo.on.rectangle")
            }

            Button(action: checkCameraPermission) {
                actionLabel(localizer.localizedString(forKey: "take_with_camera"), systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        }
    }

    private var subTasksSection: some View {
        Section(header: Text(localizer.localizedString(forKey: "subtasks"))) {
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
        ToolbarItem(placement: .cancellationAction) {
            Button(localizer.localizedString(forKey: "cancel")) {
                if hasUnsavedChanges {
                    showDiscardDialog = true
                } else {
                    dismiss()
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(localizer.localizedString(forKey: "add")) { saveTodo() }
        }
    }

    // MARK: - Buttons & Alerts
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
        } label: {
            Label(localizer.localizedString(forKey: "delete"), systemImage: "trash")
        }
    }

    private var settingsAlertButtons: some View {
        Group {
            Button(localizer.localizedString(forKey: "settings")) { openAppSettings() }
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
        }
    }

    private func deleteImageAlertButtons(for image: IdentifiableUIImage) -> some View {
        Group {
            Button(localizer.localizedString(forKey: "delete"), role: .destructive) {
                selectedImages.removeAll { $0.id == image.id }
            }
            Button(localizer.localizedString(forKey: "cancel"), role: .cancel) { }
        }
    }

    // MARK: - Helper - Preset Label for Due Date
    private func presetLabel(for date: Date) -> String? {
        let cal = Calendar.current
        let today = Date()
        // Start of current week
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let endOfThisWeek = cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? today
        let midOfWeek = cal.date(byAdding: .day, value: 3, to: start)?.endOfDay ?? today
        let endOfNextWeek: Date = {
            let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            return cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
        }()

        let d = date
        // Match by day granularity
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
            DispatchQueue.main.async {
                granted ? (showCamera = true) : (showCameraPermissionAlert = true)
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func processSelectedItems() async {
        for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let image = IdentifiableUIImage(image: uiImage)
                if !selectedImages.contains(image) {
                    selectedImages.append(image)
                }
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

        todoStore.addCategory(newCategory)
        category = newCategory
        newCategoryName = ""
    }

    private func saveTodo() {
        // Stelle sicher, dass eine Kategorie vorhanden ist
        if category == nil {
            if let first = todoStore.categories.first {
                category = first
            } else {
                let defaultCategory = Category(name: "Allgemein", colorHex: "#007AFF")
                todoStore.addCategory(defaultCategory)
                category = defaultCategory
            }
        }

        guard !title.isEmpty, let selectedCategory = category else { return }

        let finalOffset: Int?
        switch reminderSelection {
        case -1:
            finalOffset = nil
        default:
            finalOffset = reminderSelection
        }

        // Compose recurrenceRule
        let recurrenceRule: TodoItem.RecurrenceRule = {
            guard recurrenceEnabled else { return .none }
            switch recurrenceFrequency {
            case "daily":
                return .daily(interval: recurrenceInterval)
            case "weekly":
                return .weekly(interval: recurrenceInterval, weekdays: Array(weeklyWeekdays).sorted())
            case "monthly":
                return .monthly(interval: recurrenceInterval)
            default:
                return .none
            }
        }()

        let todo = TodoItem(
            title: title,
            description: description,
            dueDate: hasDueDate ? dueDate : nil,
            reminderOffsetMinutes: finalOffset,
            reminderTitle: reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminderTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderBody: reminderBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reminderBody.trimmingCharacters(in: .whitespacesAndNewlines),
            recurrenceEnabled: recurrenceEnabled,
            recurrenceRule: recurrenceRule,
            category: selectedCategory,
            priority: priority,
            subTasks: subTasks,
            imageDataArray: selectedImages.compactMap { $0.image.jpegData(compressionQuality: 0.8) }
        )

        todoStore.addTodo(todo)

        if addToCalendar && hasDueDate {
            requestCalendarAccessAndAddEvent()
        }

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
                // Add alarm based on reminder selection
                let offsetForAlarm: Int?
                switch reminderSelection {
                case -1: offsetForAlarm = nil
                default: offsetForAlarm = reminderSelection
                }
                if let off = offsetForAlarm, off >= 0 {
                    let alarm = EKAlarm(relativeOffset: TimeInterval(-off * 60))
                    event.addAlarm(alarm)
                }
                event.calendar = eventStore.defaultCalendarForNewEvents
                do {
                    try eventStore.save(event, span: .thisEvent)
                } catch {
                    print("Fehler beim Speichern des Kalender-Eintrags: \(error)")
                }
            } else {
                DispatchQueue.main.async {
                    calendarAccessDenied = true
                }
            }
        }
    }
}

// MARK: - Preview View
struct ImagePreviewView: View {
    let image: UIImage

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
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

