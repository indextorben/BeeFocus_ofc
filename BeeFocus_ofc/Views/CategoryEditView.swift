import SwiftUI

struct CategoryEditView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var newCategoryName: String = ""
    @State private var editingCategory: Category? = nil
    @FocusState private var focusedCategoryID: UUID?
    @State private var isEditing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Neue Kategorie Eingabe als stylische Card
                    HStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(.secondary)
                            TextField(
                                localizer.localizedString(forKey: "category_new"),
                                text: $newCategoryName
                            )
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .onSubmit(addCategory)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06))
                        )

                        Button(action: addCategory) {
                            Image(systemName: "plus")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(
                                    LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                )
                                .shadow(color: Color.purple.opacity(0.25), radius: 8, x: 0, y: 6)
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
                        .accessibilityLabel(Text(localizer.localizedString(forKey: "category_add")))
                    }
                    .padding(.horizontal)

                    // Kategorie-Liste als Cards
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(todoStore.categories, id: \.id) { category in
                                CategoryRow(
                                    category: category,
                                    editingCategory: $editingCategory,
                                    focusedCategoryID: _focusedCategoryID,
                                    todoStore: todoStore
                                )
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.06))
                                )
                                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                                .padding(.horizontal)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        todoStore.deleteCategory(category)
                                    } label: {
                                        Label(localizer.localizedString(forKey: "delete"), systemImage: "trash")
                                    }

                                    Button {
                                        withAnimation { editingCategory = category }
                                    } label: {
                                        Label(localizer.localizedString(forKey: "edit"), systemImage: "pencil")
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
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "category_manage"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizer.localizedString(forKey: "done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Logik
    private func addCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newCategory = Category(name: trimmed, colorHex: "#007AFF")
        todoStore.addCategory(newCategory)
        newCategoryName = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedCategoryID = newCategory.id
            editingCategory = newCategory
        }
    }
}

// MARK: - Einzelne Kategorie-Zeile
struct CategoryRow: View {
    let category: Category
    @Binding var editingCategory: Category?
    @FocusState var focusedCategoryID: UUID?
    let todoStore: TodoStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 14, height: 14)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.08))
                    .frame(width: 16, height: 16)
            }

            if editingCategory?.id == category.id {
                TextField(
                    "Kategorie bearbeiten",
                    text: Binding(
                        get: { editingCategory?.name ?? "" },
                        set: { newValue in
                            if let editingCat = editingCategory {
                                todoStore.renameCategory(from: editingCat, to: newValue)
                                editingCategory?.name = newValue
                            }
                        }
                    )
                )
                .focused($focusedCategoryID, equals: category.id)
                .textFieldStyle(.plain)
                .padding(.vertical, 7)
                .padding(.horizontal, 9)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { focusedCategoryID = category.id }
                }
                .onSubmit {
                    withAnimation(.easeInOut) {
                        editingCategory = nil
                        focusedCategoryID = nil
                    }
                }
            } else {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { editingCategory = category }
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .hoverEffect(.highlight)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder((editingCategory?.id == category.id) ? Color.blue.opacity(0.25) : Color.clear, lineWidth: 1.2)
        )
    }
}
