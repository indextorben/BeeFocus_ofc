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
    @State private var category: Category
    @State private var priority: TodoPriority
    @State private var subTasks: [SubTask]
    @State private var newSubTaskTitle = ""
    
    // MARK: - Image handling
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [IdentifiableUIImage] = []
    @State private var selectedImageForPreview: IdentifiableUIImage?
    @State private var imageToDelete: IdentifiableUIImage?
    
    // MARK: - State controls
    @State private var showDeleteConfirmation = false
    @State private var showCamera = false
    @State private var showCameraPermissionAlert = false
    
    // MARK: - Kategorie
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showCategoryAlert = false
    
    // MARK: - Kalender
    @State private var addToCalendar = false
    @State private var calendarAccessDenied = false
    
    // MARK: - Localization
    @ObservedObject private var localizer = LocalizationManager.shared

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
        _category = State(initialValue: todo.category ?? Category(id: UUID(), name: "Keine Kategorie", colorHex: "#FFFFFF"))
        _priority = State(initialValue: todo.priority)
        _subTasks = State(initialValue: todo.subTasks)
        _selectedImages = State(initialValue: todo.imageDataArray.compactMap {
            UIImage(data: $0).map { IdentifiableUIImage(image: $0) }
        })
    }
    
    // MARK: - Body
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
            .navigationTitle(localizer.localizedString(forKey: "edit_todo_title"))
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
                    Text(priority.rawValue).tag(priority)
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
            }
        }
    }
    
    private var calendarToggleSection: some View {
        Section {
            Toggle(localizer.localizedString(forKey: "add_to_calendar_toggle"), isOn: $addToCalendar)
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
        let updatedTodo = TodoItem(
            id: todo.id,
            title: title,
            description: description,
            isCompleted: todo.isCompleted,
            dueDate: hasDueDate ? dueDate : nil,
            reminderOffsetMinutes: finalOffset,
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

