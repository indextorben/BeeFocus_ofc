import SwiftUI

// MARK: - Quick-Add: Simple Task Entry

struct QuickAddSheet: View {

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    let themeC1: Color
    let themeC2: Color

    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    @State private var title: String = ""
    @State private var priority: TodoPriority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var category: Category? = nil
    @State private var addedSuccessfully = false

    @FocusState private var titleFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                (darkModeEnabled
                    ? Color(red: 0.07, green: 0.07, blue: 0.10)
                    : Color(red: 0.94, green: 0.94, blue: 0.97))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if addedSuccessfully {
                        successView
                    } else {
                        inputView
                    }
                }
            }
            .navigationTitle(String(localized: "quickadd_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeC1.opacity(0.2), themeC2.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 8) {
                Text(String(localized: "quickadd_headline"))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
            }

            // Form
            VStack(spacing: 16) {
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    TextField(String(localized: "quickadd_placeholder"), text: $title)
                        .font(.system(size: 16))
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(themeC1.opacity(0.25), lineWidth: 1)
                        )
                }

                // Priority
                HStack(spacing: 8) {
                    ForEach(TodoPriority.allCases) { p in
                        priorityChip(p)
                    }
                }

                // Due date toggle
                Toggle(isOn: $hasDueDate.animation()) {
                    Label("Set date", systemImage: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(darkModeEnabled ? .white.opacity(0.85) : .primary)
                }
                .tint(themeC1)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                if hasDueDate {
                    DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(themeC1)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // Category
                if !todoStore.categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, name: "None")
                            ForEach(todoStore.categories) { cat in
                                categoryChip(cat, name: cat.name)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Add button
                Button {
                    addTask()
                } label: {
                    Label(String(localized: "quickadd_add"), systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                ? LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear { titleFocused = true }
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeC1.opacity(0.2), themeC2.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text(String(localized: "quickadd_success"))
                .font(.system(size: 22, weight: .bold))
            Text(String(localized: "quickadd_success_sub"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func priorityChip(_ p: TodoPriority) -> some View {
        let color: Color = p == .high ? .red : p == .medium ? .orange : .green
        let selected = priority == p
        return Button { withAnimation(.spring(response: 0.3)) { priority = p } } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(p.displayName)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? (darkModeEnabled ? .white : color) : .secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? color.opacity(0.2) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(selected ? color.opacity(0.5) : themeC1.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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
                    .foregroundStyle(selected ? (darkModeEnabled ? .white : color) : .secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? color.opacity(darkModeEnabled ? 0.25 : 0.15) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(selected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let item = TodoItem(
            title: trimmed,
            dueDate: hasDueDate ? dueDate : nil,
            category: category,
            categoryID: category?.id,
            priority: priority,
            subTasks: []
        )
        todoStore.addTodo(item)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            addedSuccessfully = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}
