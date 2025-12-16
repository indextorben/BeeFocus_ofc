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

    // MARK: - Init
    init(todo: TodoItem) {
        self.todo = todo
        _title = State(initialValue: todo.title)
        _description = State(initialValue: todo.description)
        _dueDate = State(initialValue: todo.dueDate ?? Date())
        _hasDueDate = State(initialValue: todo.dueDate != nil)
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
            .navigationTitle("Aufgabe bearbeiten")
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
            .alert("Kamera-Zugriff benötigt", isPresented: $showCameraPermissionAlert) {
                settingsAlertButtons
            } message: {
                Text("Bitte erlauben Sie den Kamerazugriff in den Einstellungen")
            }
            .alert("Bild löschen", isPresented: $showDeleteConfirmation, presenting: imageToDelete) { image in
                deleteImageAlertButtons(for: image)
            } message: { _ in
                Text("Möchtest du dieses Bild wirklich löschen?")
            }
            .alert("Neue Kategorie", isPresented: $showAddCategoryAlert) {
                VStack {
                    TextField("Kategoriename", text: $newCategoryName)
                }
                Button("Abbrechen", role: .cancel) { newCategoryName = "" }
                Button("Hinzufügen") { addNewCategory() }
            } message: {
                Text("Gib den Namen der neuen Kategorie ein.")
            }
            .alert("Kategorie fehlt", isPresented: $showCategoryAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte wähle eine Kategorie aus, bevor du die Aufgabe speicherst.")
            }
            .alert("Kalender-Zugriff verweigert", isPresented: $calendarAccessDenied) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte erlauben Sie den Kalenderzugriff in den Einstellungen.")
            }
        }
    }
    
    // MARK: - Sections
    private var basicInfoSection: some View {
        Section(header: Text("Aufgabentitel")) {
            TextField("Titel", text: $title)
            TextEditor(text: $description)
                .frame(height: 100)
        }
    }
    
    private var categoryAndPrioritySection: some View {
        Section(header: Text("Kategorisierung")) {
            Picker("Kategorie", selection: $category) {
                ForEach(todoStore.categories, id: \.self) { category in
                    Text(category.name).tag(category)
                }
            }
            
            Button {
                showAddCategoryAlert = true
            } label: {
                Label("Kategorie hinzufügen", systemImage: "plus.circle")
                    .foregroundColor(.blue)
            }
            
            Picker("Priorität", selection: $priority) {
                ForEach(TodoPriority.allCases) { priority in
                    Text(priority.rawValue).tag(priority)
                }
            }
        }
    }
    
    private var dueDateSection: some View {
        Section {
            Toggle(isOn: $hasDueDate) { Label("Fälligkeitsdatum aktivieren", systemImage: "calendar") }
            if hasDueDate {
                DatePicker("Datum & Uhrzeit", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }
        }
    }
    
    private var calendarToggleSection: some View {
        Section {
            Toggle("In Systemkalender eintragen", isOn: $addToCalendar)
        }
    }
    
    private var imagesSection: some View {
        Section(header: Text("Bilder")) {
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
        ) { actionLabel("Aus Galerie auswählen", systemImage: "photo.on.rectangle") }
        .onChange(of: selectedItems) { Task { await processSelectedItems() } }
    }
    
    private var cameraButton: some View {
        Button(action: checkCameraPermission) { actionLabel("Mit Kamera aufnehmen", systemImage: "camera") }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
    }
    
    private var subTasksSection: some View {
        Section(header: Text("Unteraufgaben")) {
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
                TextField("Neue Unteraufgabe", text: $newSubTaskTitle)
                Button(action: addSubTask) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                }.disabled(newSubTaskTitle.isEmpty)
            }
        }
    }
    
    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Speichern") { saveTodo() }.disabled(title.isEmpty) }
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
        } label: { Label("Löschen", systemImage: "trash") }
    }
    
    private var settingsAlertButtons: some View {
        Group {
            Button("Einstellungen") { openAppSettings() }
            Button("Abbrechen", role: .cancel) { }
        }
    }
    
    private func deleteImageAlertButtons(for image: IdentifiableUIImage) -> some View {
        Group {
            Button("Löschen", role: .destructive) { selectedImages.removeAll { $0.id == image.id } }
            Button("Abbrechen", role: .cancel) { }
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
        todoStore.categories.append(newCategory)
        category = newCategory
        newCategoryName = ""
    }
    
    private func saveTodo() {
        if todoStore.categories.isEmpty { showCategoryAlert = true; return }
        
        let imageDataArray = selectedImages.compactMap { $0.image.jpegData(compressionQuality: 0.8) }
        let updatedTodo = TodoItem(
            id: todo.id,
            title: title,
            description: description,
            isCompleted: todo.isCompleted,
            dueDate: hasDueDate ? dueDate : nil,
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
                do { try eventStore.save(event, span: .thisEvent) }
                catch { print("Fehler beim Speichern des Kalender-Eintrags: \(error)") }
            } else {
                DispatchQueue.main.async { calendarAccessDenied = true }
            }
        }
    }
}
