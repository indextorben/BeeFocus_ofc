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

    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = true
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

    // Neu für Kategorie hinzufügen
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
            .navigationTitle("Neue Aufgabe")
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
                Text("Bitte erlauben Sie den Kamerazugriff in den Einstellungen.")
            }
            .alert("Bild löschen", isPresented: $showDeleteConfirmation, presenting: imageToDelete) { image in
                deleteImageAlertButtons(for: image)
            } message: { _ in
                Text("Möchten Sie dieses Bild wirklich löschen?")
            }
            .alert("Kalender-Zugriff verweigert", isPresented: $calendarAccessDenied) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte erlauben Sie den Kalenderzugriff in den Einstellungen.")
            }
            .alert("Kategorie fehlt", isPresented: $showCategoryAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte wählen Sie eine Kategorie aus, bevor Sie die Aufgabe speichern.")
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
                    Text(category.name).tag(Optional(category))
                }
            }

            Button {
                showAddCategoryAlert = true
            } label: {
                Label("Kategorie hinzufügen", systemImage: "plus.circle")
                    .foregroundColor(.blue)
            }
            .alert("Neue Kategorie", isPresented: $showAddCategoryAlert) {
                VStack {
                    TextField("Kategoriename", text: $newCategoryName)
                }
                Button("Abbrechen", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Hinzufügen") {
                    addNewCategory()
                }
            } message: {
                Text("Gib den Namen der neuen Kategorie ein.")
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
            Toggle("Fälligkeitsdatum aktivieren", isOn: $hasDueDate)
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

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                actionLabel("Aus Galerie auswählen", systemImage: "photo.on.rectangle")
            }
            .onChange(of: selectedItems) { _, _ in
                Task { await processSelectedItems() }
            }

            Button(action: checkCameraPermission) {
                actionLabel("Mit Kamera aufnehmen", systemImage: "camera")
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        }
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
        ToolbarItem(placement: .cancellationAction) {
            Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Hinzufügen") { saveTodo() }
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
            Label("Löschen", systemImage: "trash")
        }
    }

    private var settingsAlertButtons: some View {
        Group {
            Button("Einstellungen") { openAppSettings() }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    private func deleteImageAlertButtons(for image: IdentifiableUIImage) -> some View {
        Group {
            Button("Löschen", role: .destructive) {
                selectedImages.removeAll { $0.id == image.id }
            }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    // MARK: - Logic
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            requestCameraAccess()
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            break
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

        // Zufällige Farbe im Hex-Format erzeugen
        let randomColor = String(format: "#%06X", Int.random(in: 0...0xFFFFFF))

        // Neue Kategorie mit Name und Farbe erstellen
        let newCategory = Category(name: trimmedName, colorHex: randomColor)

        // Kategorie zum Store hinzufügen und auswählen
        todoStore.categories.append(newCategory)
        category = newCategory
        newCategoryName = ""
    }

    private func saveTodo() {
        if category == nil {
            showCategoryAlert = true
            return
        }

        guard !title.isEmpty, let selectedCategory = category else { return }

        let todo = TodoItem(
            title: title,
            description: description,
            dueDate: hasDueDate ? dueDate : nil,
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
