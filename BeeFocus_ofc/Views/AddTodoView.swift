import SwiftUI
import PhotosUI
import AVFoundation
import EventKit

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

    var body: some View {
        NavigationView {
            Form {
                basicInfoSection
                categoryAndPrioritySection
                dueDateSection
                calendarToggleSection
                imagesSection
                subTasksSection
            }
            .navigationTitle(localizer.localizedString(forKey: "new_task_title"))
            .toolbar { toolbarContent }
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
            }
            .onAppear {
                if hasDueDate {
                    selectedWeekOption = presetLabel(for: dueDate)
                }
            }
            .onChange(of: selectedItems) { _, _ in
                Task { await processSelectedItems() }
            }
            .onChange(of: dueDate) { _, newValue in
                selectedWeekOption = hasDueDate ? presetLabel(for: newValue) : nil
            }
            .onChange(of: hasDueDate) { _, newValue in
                if !newValue { selectedWeekOption = nil }
            }
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
                    Text(priority.rawValue).tag(priority)
                }
            }
        }
    }

    private var dueDateSection: some View {
        Section {
            Toggle(localizer.localizedString(forKey: "enable_due_date"), isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(localizer.localizedString(forKey: "date_time"), selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
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
            }
        }
    }

    private var calendarToggleSection: some View {
        Section {
            Toggle(localizer.localizedString(forKey: "add_to_system_calendar"), isOn: $addToCalendar)

            Menu {
                Button("Heute") {
                    withAnimation {
                        hasDueDate = true
                    }
                    dueDate = Date().endOfDay
                    selectedWeekOption = "Heute"
                }
                Button("Mitte der Woche") {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let mid = cal.date(byAdding: .day, value: 3, to: start) ?? start
                    dueDate = mid.endOfDay
                    selectedWeekOption = "Mitte der Woche"
                }
                Button("Ende dieser Woche") {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let end = cal.date(byAdding: .day, value: 6, to: start)?.endOfDay ?? Date()
                    dueDate = end
                    selectedWeekOption = "Ende dieser Woche"
                }
                Button("Ende nächster Woche") {
                    withAnimation {
                        hasDueDate = true
                    }
                    let cal = Calendar.current
                    let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
                    let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
                    let nextEnd = cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
                    dueDate = nextEnd
                    selectedWeekOption = "Ende nächster Woche"
                }
                Divider()
                Button("Benutzerdefiniert…") { /* Nutzer wählt im DatePicker selbst */ }
            } label: {
                if let sel = selectedWeekOption, !sel.isEmpty {
                    Label("Als Wochenziel setzen: \(sel)", systemImage: "target")
                } else {
                    Label("Als Wochenziel setzen", systemImage: "target")
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
            .onChange(of: selectedItems) { _, _ in
                Task { await processSelectedItems() }
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
            Button(localizer.localizedString(forKey: "cancel")) { dismiss() }
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
        if cal.isDate(d, inSameDayAs: today) { return "Heute" }
        if cal.isDate(d, inSameDayAs: midOfWeek) { return "Mitte der Woche" }
        if cal.isDate(d, inSameDayAs: endOfThisWeek) { return "Ende dieser Woche" }
        if cal.isDate(d, inSameDayAs: endOfNextWeek) { return "Ende nächster Woche" }
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

        let todo = TodoItem(
            title: title,
            description: description,
            dueDate: hasDueDate ? dueDate : nil,
            reminderOffsetMinutes: finalOffset,
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
