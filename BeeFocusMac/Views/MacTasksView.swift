import SwiftUI

struct MacTasksView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.activeTheme) private var activeTheme
    @Environment(\.colorScheme) private var colorScheme

    @State private var filter: TaskFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var newTitle = ""
    @State private var newPriority: MacTodoPriority = .medium
    @State private var newDueDate: Date = Date()
    @State private var hasDate = false

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }
    private var isDark: Bool { colorScheme == .dark }

    enum TaskFilter: String, CaseIterable {
        case all       = "Alle"
        case today     = "Heute"
        case overdue   = "Überfällig"
        case completed = "Erledigt"

        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .today: return "sun.max"
            case .overdue: return "exclamationmark.circle"
            case .completed: return "checkmark.circle"
            }
        }
    }

    private var filtered: [MacTodoItem] {
        let base: [MacTodoItem]
        switch filter {
        case .all:       base = todoStore.todos.filter { !$0.isCompleted }
        case .today:     base = todoStore.todayTodos
        case .overdue:   base = todoStore.overdueTodos
        case .completed: base = todoStore.todos.filter { $0.isCompleted }
        }
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                filterChips
                    .padding(.top, 8)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { todo in
                                MacTodoCard(todo: todo) {
                                    todoStore.toggle(todo)
                                } onDelete: {
                                    todoStore.delete(todo)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) { addSheet }
    }

    // MARK: - Background

    private var background: some View {
        Group {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.12),
                             Color(red: 0.10, green: 0.08, blue: 0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.96, green: 0.95, blue: 1.0),
                             Color(red: 0.99, green: 0.98, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aufgaben")
                    .font(.system(size: 28, weight: .bold))
                Text("\(todoStore.activeTodos.count) offen · \(todoStore.overdueTodos.count) überfällig")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { f in
                    let isActive = filter == f
                    Button { withAnimation(.spring(response: 0.3)) { filter = f } } label: {
                        Label(f.rawValue, systemImage: f.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? .white : accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isActive ? accent : accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(accent.opacity(0.4))
            Text("Keine Aufgaben")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Add Sheet

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("Aufgabe") {
                    TextField("Titel", text: $newTitle)
                }
                Section("Priorität") {
                    Picker("Priorität", selection: $newPriority) {
                        ForEach(MacTodoPriority.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Fälligkeitsdatum", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Datum", selection: $newDueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Neue Aufgabe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { showAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        guard !newTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let item = MacTodoItem(
                            title: newTitle,
                            priority: newPriority,
                            dueDate: hasDate ? newDueDate : nil
                        )
                        todoStore.addTodo(item)
                        newTitle = ""; hasDate = false; newPriority = .medium
                        showAddSheet = false
                    }
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 400, height: 360)
    }
}
