import SwiftUI

// MARK: - Filter

enum TaskFilter: String, CaseIterable {
    case all      = "Alle"
    case today    = "Heute"
    case overdue  = "Überfällig"

    var icon: String {
        switch self {
        case .all:     return "list.bullet"
        case .today:   return "sun.max.fill"
        case .overdue: return "exclamationmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .all:     return .blue
        case .today:   return .orange
        case .overdue: return .red
        }
    }
}

// MARK: - TasksTabView

struct TasksTabView: View {
    @EnvironmentObject var store: MacTodoStore

    @State private var filter:      TaskFilter = .today
    @State private var newTitle:    String = ""
    @State private var newPriority: MacTodoPriority = .medium
    @State private var newDate:     Date = Date()
    @State private var hasDate:     Bool = false
    @State private var showAddForm: Bool = false

    private var displayedTodos: [MacTodoItem] {
        switch filter {
        case .all:     return store.activeTodos
        case .today:   return store.todayTodos
        case .overdue: return store.overdueTodos
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            todoList
            Divider()
            addBar
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TaskFilter.allCases, id: \.self) { f in
                    filterChip(f)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(_ f: TaskFilter) -> some View {
        let selected = filter == f
        return Button {
            withAnimation(.spring(response: 0.25)) { filter = f }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: f.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(f.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                let count = countFor(f)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(f.color, in: Capsule())
                }
            }
            .foregroundStyle(selected ? f.color : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(selected ? f.color.opacity(0.15) : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(selected ? f.color.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func countFor(_ f: TaskFilter) -> Int {
        switch f {
        case .all:     return store.activeTodos.count
        case .today:   return store.todayTodos.count
        case .overdue: return store.overdueTodos.count
        }
    }

    // MARK: - Todo List

    private var todoList: some View {
        Group {
            if displayedTodos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(displayedTodos) { todo in
                            TodoRowView(todo: todo)
                                .environmentObject(store)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .overdue ? "checkmark.circle" : "sun.and.horizon.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.4))
            Text(filter == .overdue ? "Keine überfälligen Aufgaben" : "Keine Aufgaben")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Add Bar

    private var addBar: some View {
        VStack(spacing: 0) {
            if showAddForm {
                addForm
                Divider()
            }
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3)) { showAddForm.toggle() }
                    if showAddForm { newTitle = ""; hasDate = false; newPriority = .medium }
                } label: {
                    Image(systemName: showAddForm ? "xmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(showAddForm ? Color.gray : Color.orange)
                }
                .buttonStyle(.plain)

                if showAddForm {
                    TextField("Aufgabenname …", text: $newTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .onSubmit { submitTodo() }

                    Button("Hinzufügen") { submitTodo() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .font(.system(size: 12, weight: .semibold))
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Text("Neue Aufgabe")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Priority
            HStack(spacing: 6) {
                Text("Priorität:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                ForEach(MacTodoPriority.allCases, id: \.self) { p in
                    let c = p.color
                    let color = Color(red: c.0, green: c.1, blue: c.2)
                    let sel   = newPriority == p
                    Button { newPriority = p } label: {
                        Text(p.label)
                            .font(.system(size: 11, weight: sel ? .semibold : .regular))
                            .foregroundStyle(sel ? color : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(sel ? color.opacity(0.15) : Color.clear, in: Capsule())
                            .overlay(Capsule().stroke(sel ? color.opacity(0.4) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            // Date
            HStack(spacing: 6) {
                Toggle("Datum:", isOn: $hasDate)
                    .font(.system(size: 12))
                    .toggleStyle(.checkbox)
                if hasDate {
                    DatePicker("", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func submitTodo() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let item = MacTodoItem(
            title:    t,
            dueDate:  hasDate ? newDate : nil,
            priority: newPriority
        )
        store.addTodo(item)
        withAnimation(.spring(response: 0.3)) {
            showAddForm = false
            newTitle    = ""
            filter      = .all
        }
    }
}

// MARK: - TodoRowView

struct TodoRowView: View {
    let todo: MacTodoItem
    @EnvironmentObject var store: MacTodoStore
    @State private var isHovered = false

    private var priorityColor: Color {
        let c = todo.priority.color
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button { store.toggle(todo) } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(todo.isCompleted ? .green : priorityColor.opacity(0.7))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                    .strikethrough(todo.isCompleted, color: .secondary)
                    .lineLimit(1)

                if let due = todo.dueDate {
                    Text(due, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(todo.isOverdue ? .red : .secondary)
                }
            }

            Spacer()

            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 3, height: 22)
                .opacity(todo.isCompleted ? 0.3 : 0.8)

            if isHovered {
                Button { store.delete(todo) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}
