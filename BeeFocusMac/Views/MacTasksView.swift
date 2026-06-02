import SwiftUI

struct MacTasksView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @Environment(\.activeTheme) private var activeTheme

    @State private var filter: TaskFilter = .all
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var editingTodo: MacTodoItem? = nil

    // Löschen + Rückgängig
    @State private var showDeleteSnackbar = false
    @State private var snackbarTask: Task<Void, Never>? = nil

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }

    enum TaskFilter: String, CaseIterable {
        case all       = "Alle"
        case today     = "Heute"
        case tomorrow  = "Morgen"
        case thisWeek  = "Diese Woche"
        case overdue   = "Überfällig"
        case completed = "Erledigt"

        var icon: String {
            switch self {
            case .all:       return "list.bullet"
            case .today:     return "sun.max.fill"
            case .tomorrow:  return "moon.stars.fill"
            case .thisWeek:  return "calendar.badge.clock"
            case .overdue:   return "exclamationmark.circle.fill"
            case .completed: return "checkmark.circle.fill"
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
        let base: [MacTodoItem]
        if searchText.isEmpty {
            base = baseFiltered
        } else {
            base = baseFiltered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        // Favoriten zuerst, dann nach Fälligkeit → Priorität → Erstellungsdatum
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
            if aHas {
                return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
            }
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
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                filterChips
                    .padding(.top, 8)

                if filtered.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
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

                // "Alle Erledigten löschen"-Button
                if filter == .completed && !filtered.isEmpty {
                    Button(role: .destructive) {
                        todoStore.deleteCompleted()
                    } label: {
                        Label("Alle erledigten löschen", systemImage: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.red)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
            }

            // Löschen-Snackbar
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
            MacAddTodoSheet()
                .environmentObject(todoStore)
        }
        .sheet(item: $editingTodo) { todo in
            MacEditTodoSheet(todo: todo)
                .environmentObject(todoStore)
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

    // MARK: - Suche

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            TextField("Aufgaben suchen …", text: $searchText)
                .font(.system(size: 14))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
                            .foregroundStyle(isActive ? .white : f.color)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isActive ? f.color : f.color.opacity(0.12))
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

    // MARK: - Helpers

    private func deleteTodo(_ todo: MacTodoItem) {
        todoStore.delete(todo)
        snackbarTask?.cancel()
        withAnimation { showDeleteSnackbar = true }
        snackbarTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { showDeleteSnackbar = false }
            }
        }
    }

}
