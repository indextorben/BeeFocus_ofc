import SwiftUI

struct MacTasksView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.activeTheme) private var activeTheme

    @State private var filter: TaskFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var editingTodo: MacTodoItem? = nil

    @State private var showDeleteSnackbar = false
    @State private var snackbarTask: Task<Void, Never>? = nil

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }

    enum TaskFilter: String, CaseIterable {
        case all       = "Alle"
        case today     = "Heute"
        case tomorrow  = "Morgen"
        case thisWeek  = "Woche"
        case overdue   = "Überfällig"
        case completed = "Erledigt"

        var icon: String {
            switch self {
            case .all:       return "tray.full"
            case .today:     return "sun.max"
            case .tomorrow:  return "moon.stars"
            case .thisWeek:  return "calendar"
            case .overdue:   return "exclamationmark.circle"
            case .completed: return "checkmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .all:       return .blue
            case .today:     return .orange
            case .tomorrow:  return .indigo
            case .thisWeek:  return .teal
            case .overdue:   return .red
            case .completed: return .green
            }
        }
    }

    private var baseFiltered: [MacTodoItem] {
        switch filter {
        case .all:       return todoStore.todos.filter { !$0.isCompleted }
        case .today:     return todoStore.todayTodos
        case .tomorrow:  return todoStore.tomorrowTodos
        case .thisWeek:  return todoStore.thisWeekTodos
        case .overdue:   return todoStore.overdueTodos
        case .completed: return todoStore.todos.filter { $0.isCompleted }
        }
    }

    private var filtered: [MacTodoItem] {
        let base = searchText.isEmpty ? baseFiltered : baseFiltered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
            || $0.description.localizedCaseInsensitiveContains(searchText)
        }
        if filter == .completed { return base }
        return sorted(base)
    }

    private func sorted(_ items: [MacTodoItem]) -> [MacTodoItem] {
        let favs   = items.filter { $0.isFavorite }
        let normal = items.filter { !$0.isFavorite }
        return sortByDueAndPriority(favs) + sortByDueAndPriority(normal)
    }

    private func sortByDueAndPriority(_ items: [MacTodoItem]) -> [MacTodoItem] {
        items.sorted { a, b in
            let aHas = a.dueDate != nil
            let bHas = b.dueDate != nil
            if aHas != bHas { return aHas }
            if aHas { return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture) }
            let pa = priorityRank(a.priority), pb = priorityRank(b.priority)
            if pa != pb { return pa < pb }
            return a.createdAt > b.createdAt
        }
    }

    private func priorityRank(_ p: MacTodoPriority) -> Int {
        switch p { case .high: return 0; case .medium: return 1; case .low: return 2 }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                searchBar
                    .padding(.horizontal, 16)

                filterChips
                    .padding(.top, 10)

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .opacity(0.5)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { todo in
                                MacTodoCard(
                                    todo: todo,
                                    onToggle: { todoStore.toggle(todo) },
                                    onDelete: { deleteTodo(todo) },
                                    onEdit:   { editingTodo = todo },
                                    onToggleFavorite: { todoStore.toggleFavorite(todo) }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }

                if filter == .completed && !filtered.isEmpty {
                    Button(role: .destructive) {
                        todoStore.deleteCompleted()
                    } label: {
                        Label("Alle erledigten löschen", systemImage: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            }

            // Snackbar
            VStack {
                Spacer()
                if showDeleteSnackbar {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundStyle(.white)
                        Text("Aufgabe gelöscht")
                            .foregroundStyle(.white)
                            .font(.system(size: 13))
                        Spacer()
                        Button("Rückgängig") {
                            snackbarTask?.cancel()
                            withAnimation { showDeleteSnackbar = false }
                            todoStore.undo()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.82), in: Capsule())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showDeleteSnackbar)
        }
        .sheet(isPresented: $showAddSheet) {
            MacAddTodoSheet().environmentObject(todoStore)
        }
        .sheet(item: $editingTodo) { todo in
            MacEditTodoSheet(todo: todo).environmentObject(todoStore)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aufgaben")
                    .font(.system(size: 22, weight: .bold))
                Text("\(todoStore.activeTodos.count) offen · \(todoStore.overdueTodos.count) überfällig")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
            TextField("Suchen …", text: $searchText)
                .font(.system(size: 13))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TaskFilter.allCases, id: \.self) { f in
                    let isActive = filter == f
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { filter = f }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: f.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(f.rawValue)
                                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        }
                        .foregroundStyle(isActive ? f.color : .secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background {
                            if isActive {
                                Capsule().fill(f.color.opacity(0.12))
                            } else {
                                Capsule().fill(Color.clear)
                            }
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(isActive ? f.color.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: filter == .completed ? "checkmark.circle" : "tray")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.tertiary)
            Text(filter == .completed ? "Nichts erledigt" : "Keine Aufgaben")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func deleteTodo(_ todo: MacTodoItem) {
        todoStore.delete(todo)
        snackbarTask?.cancel()
        withAnimation { showDeleteSnackbar = true }
        snackbarTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showDeleteSnackbar = false } }
        }
    }
}
