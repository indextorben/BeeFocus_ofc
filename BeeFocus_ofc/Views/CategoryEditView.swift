import SwiftUI

struct CategoryEditView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    @State private var newCategoryName: String = ""
    @State private var editingCategory: Category? = nil
    @FocusState private var focusedCategoryID: UUID?

    @State private var isEditing = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(todoStore.categories, id: \.id) { category in
                        HStack {
                            if editingCategory?.id == category.id {
                                TextField("Kategorie bearbeiten", text: Binding(
                                    get: { editingCategory?.name ?? "" },
                                    set: { newValue in
                                        if var editingCat = editingCategory {
                                            editingCat.name = newValue
                                            todoStore.renameCategory(from: editingCategory!, to: newValue)
                                            editingCategory = editingCat
                                        }
                                    }
                                ))
                                .focused($focusedCategoryID, equals: category.id)
                                .onSubmit {
                                    editingCategory = nil
                                    focusedCategoryID = nil
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)
                                Text(category.name)
                                    .padding(.leading, 4)
                                Spacer()
                                Button {
                                    editingCategory = category
                                    focusedCategoryID = category.id
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.forEach { index in
                            let categoryToDelete = todoStore.categories[index]
                            todoStore.deleteCategory(categoryToDelete)
                        }
                    }
                }
                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))

                HStack {
                    TextField("Neue Kategorie", text: $newCategoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addCategory()
                        }

                    Button(action: addCategory) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Kategorien bearbeiten")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "Fertig" : "Bearbeiten") {
                        isEditing.toggle()
                        editingCategory = nil
                        focusedCategoryID = nil
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newCategory = Category(name: trimmed, colorHex: "#007AFF") // Standardfarbe: Blau
        todoStore.addCategory(newCategory)
        newCategoryName = ""
    }
}
