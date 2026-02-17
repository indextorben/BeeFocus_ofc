import SwiftUI

struct WeeklyGoalsView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @State private var startOfWeek: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    @State private var weekSegment: Int = 0 // -1: last, 0: this, 1: next
    @State private var editingTodo: TodoItem? = nil

    // MARK: - Helpers
    private func isInCurrentWeek(_ date: Date) -> Bool {
        return date >= startOfWeek.startOfDay && date <= endOfWeek
    }

    private func compareTodos(_ a: TodoItem, _ b: TodoItem) -> Bool {
        let ad: Date = a.dueDate ?? .distantFuture
        let bd: Date = b.dueDate ?? .distantFuture
        if ad != bd { return ad < bd }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }

    private var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)?.endOfDay ?? Date()
    }

    private var todosThisWeek: [TodoItem] {
        let filtered: [TodoItem] = todoStore.todos.filter { (todo: TodoItem) -> Bool in
            guard !todo.isCompleted else { return false }
            guard let due: Date = todo.dueDate else { return false }
            return isInCurrentWeek(due)
        }
        let sorted: [TodoItem] = filtered.sorted(by: compareTodos(_:_:))
        return sorted
    }

    private var completedThisWeekCount: Int {
        let completed: [TodoItem] = todoStore.todos.filter { (todo: TodoItem) -> Bool in
            guard todo.isCompleted else { return false }
            guard let due: Date = todo.dueDate else { return false }
            return isInCurrentWeek(due)
        }
        return completed.count
    }
    
    private var plannedNextWeekCount: Int {
        let cal = Calendar.current
        let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? startOfWeek
        let nextEnd = cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
        let planned = todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= nextStart.startOfDay && due <= nextEnd
        }
        return planned.count
    }
    
    private var dueDatedOutsideCurrentWeekCount: Int {
        let items = todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return !isInCurrentWeek(due)
        }
        return items.count
    }
    
    private var nextDueDate: Date? {
        let candidates = todoStore.todos.compactMap { todo -> Date? in
            guard !todo.isCompleted, let due = todo.dueDate else { return nil }
            return due
        }.sorted()
        return candidates.first
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    private var diagnosticLineText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let nextStr: String = {
            if let nd = nextDueDate { return df.string(from: nd) } else { return "–" }
        }()
        return "Woche: \(weekRangeString()) • In Woche: \(todosThisWeek.count) • Nächstes Fällig: \(nextStr)"
    }

    private struct TodoGroup: Identifiable {
        let id: String
        let title: String
        let items: [TodoItem]
    }

    private var groupedThisWeek: [TodoGroup] {
        var dict: [String: [TodoItem]] = [:]
        for item in todosThisWeek {
            let key: String = item.category?.name ?? "Ohne Kategorie"
            var bucket: [TodoItem] = dict[key] ?? []
            bucket.append(item)
            dict[key] = bucket
        }
        let sortedKeys: [String] = Array(dict.keys).sorted()
        var result: [TodoGroup] = []
        result.reserveCapacity(sortedKeys.count)
        for key in sortedKeys {
            let items: [TodoItem] = dict[key] ?? []
            let group: TodoGroup = TodoGroup(id: key, title: key, items: items)
            result.append(group)
        }
        return result
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                Group {
                    if todosThisWeek.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(todosThisWeek) { todo in
                                    let binding = Binding<TodoItem>(
                                        get: {
                                            todoStore.todos.first(where: { $0.id == todo.id }) ?? todo
                                        },
                                        set: { updated in
                                            if let idx = todoStore.todos.firstIndex(where: { $0.id == updated.id }) {
                                                todoStore.todos[idx] = updated
                                            }
                                        }
                                    )

                                    HStack(alignment: .top, spacing: 8) {
                                        TodoCard(todo: binding, showCategory: true) {
                                            // onToggle
                                            todoStore.toggleTodo(todo)
                                        } onEdit: {
                                            editingTodo = todo
                                        } onDelete: {
                                            todoStore.deleteTodo(todo)
                                        } onShare: {
                                            TodoShare.share(todo: todo)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            todoStore.toggleTodo(todo)
                                        } label: {
                                            Label("Erledigt", systemImage: "checkmark")
                                        }
                                        .tint(.green)

                                        Button(role: .destructive) {
                                            todoStore.deleteTodo(todo)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }

                                        Button {
                                            TodoShare.share(todo: todo)
                                        } label: {
                                            Label("Teilen", systemImage: "square.and.arrow.up")
                                        }
                                        .tint(.blue)
                                    }
                                    .strikethrough(binding.wrappedValue.isCompleted, color: .gray)
                                    .opacity(binding.wrappedValue.isCompleted ? 0.6 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: binding.wrappedValue.isCompleted)
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Wöchentliche Ziele")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    todoStore.undo()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(todoStore.canUndo ? .blue : .gray)
                }
                .disabled(!todoStore.canUndo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    todoStore.redo()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(todoStore.canRedo ? .blue : .gray)
                }
                .disabled(!todoStore.canRedo)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Diese Woche") { setWeekAbsolute(0) }
                    Button("Nächste Woche") { setWeekAbsolute(1) }
                    Button("Letzte Woche") { setWeekAbsolute(-1) }
                } label: {
                    Label("Woche", systemImage: "calendar")
                }
            }
        }
        .onAppear {
            syncWeekSegmentWithStart()
        }
        .onChange(of: startOfWeek) { _, _ in
            syncWeekSegmentWithStart()
        }
        .sheet(item: $editingTodo) { item in
            EditTodoView(todo: item)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                Label("Geplant: \(todosThisWeek.count)", systemImage: "target")
                Label("Erledigt: \(completedThisWeekCount)", systemImage: "checkmark.circle")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
#if DEBUG
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text(diagnosticLineText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
#endif
            if plannedNextWeekCount > 0 {
                Button {
                    setWeekAbsolute(1)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle")
                        Text("\(plannedNextWeekCount) in nächster Woche ansehen")
                    }
                }
                .font(.subheadline)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private func categoryCard(for group: TodoGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title)
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, todo in
                    if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                        WeeklyTodoRow(todo: $todoStore.todos[idx])
                    } else {
                        WeeklyTodoRow(todo: .constant(todo))
                    }
                    if index < group.items.count - 1 {
                        Divider().opacity(0.12)
                    }
                }
            }
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private func todoCard(for todo: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let name = todo.category?.name, !name.isEmpty {
                Text(name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                WeeklyTodoRow(todo: $todoStore.todos[idx])
            } else {
                WeeklyTodoRow(todo: .constant(todo))
            }
        }
        .padding()
        .background(BlurView(style: .systemUltraThinMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Noch keine Wochenziele")
                .font(.headline)
            Text("Lege in einer Aufgabe ein Fälligkeitsdatum innerhalb der ausgewählten Woche fest, damit sie hier erscheint. Nutze das Menü oben (Kalender), um die richtige Woche zu wählen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            if dueDatedOutsideCurrentWeekCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Es gibt \(dueDatedOutsideCurrentWeekCount) Aufgaben mit Fälligkeitsdatum, aber nicht in dieser Woche. Wechsle die Woche über das Kalender-Menü oben.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            HStack(spacing: 12) {
                Button {
                    setWeekAbsolute(0)
                } label: {
                    Label("Diese Woche", systemImage: "calendar")
                }
                .buttonStyle(.bordered)
                Button {
                    setWeekAbsolute(1)
                } label: {
                    Label("Nächste Woche", systemImage: "calendar")
                }
                .buttonStyle(.bordered)
            }
            if let nd = nextDueDate, !isInCurrentWeek(nd) {
                Button {
                    jumpToWeek(of: nd)
                } label: {
                    Label("Zur nächstfälligen Aufgabe springen", systemImage: "arrowshape.turn.up.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func setWeek(offset: Int) {
        if let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: startOfWeek) {
            startOfWeek = newStart
        }
    }

    private func jumpToWeek(of date: Date) {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        withAnimation { startOfWeek = weekStart }
    }

    private func setWeekAbsolute(_ mode: Int) {
        // mode: -1 = last week, 0 = this week, 1 = next week
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let target: Date
        switch mode {
        case -1:
            target = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart) ?? currentStart
        case 1:
            target = cal.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
        default:
            target = currentStart
        }
        withAnimation { startOfWeek = target }
    }

    private func weekRangeString() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let startStr = df.string(from: startOfWeek.startOfDay)
        let endStr = df.string(from: endOfWeek)
        return "\(startStr) – \(endStr)"
    }
    
    private func syncWeekSegmentWithStart() {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let lastStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart) ?? currentStart
        let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: currentStart) ?? currentStart
        if Calendar.current.isDate(startOfWeek, inSameDayAs: currentStart) {
            weekSegment = 0
        } else if Calendar.current.isDate(startOfWeek, inSameDayAs: lastStart) {
            weekSegment = -1
        } else if Calendar.current.isDate(startOfWeek, inSameDayAs: nextStart) {
            weekSegment = 1
        } else {
            weekSegment = 0
        }
    }
}

private struct WeeklyTodoRow: View {
    @Binding var todo: TodoItem

    private var dueStatus: (text: String, color: Color)? {
        guard let due = todo.dueDate else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: due)
        if dueDay < today {
            return ("Überfällig", .red)
        } else if cal.isDate(dueDay, inSameDayAs: today) {
            return ("Heute", .orange)
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .none
            return (df.string(from: due), .blue)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                withAnimation(.easeInOut) {
                    todo.isCompleted.toggle()
                }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(todo.title)
                        .font(.headline)
                    if todo.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .imageScale(.small)
                    }
                }
                if let due: Date = todo.dueDate {
                    Text(due, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let status = dueStatus {
                Text(status.text)
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(status.color.opacity(0.15))
                    .foregroundStyle(status.color)
                    .clipShape(Capsule())
            }
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    todo.isFavorite.toggle()
                }
            } label: {
                Image(systemName: todo.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(todo.isFavorite ? .yellow : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                withAnimation(.easeInOut) { todo.isCompleted = true }
            } label: {
                Label("Erledigt", systemImage: "checkmark")
            }.tint(.green)
        }
    }
}

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        let start = Calendar.current.startOfDay(for: self)
        if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: start) {
            return nextDay.addingTimeInterval(-1)
        }
        return self
    }
}

#if DEBUG
#Preview {
    // Lightweight mock store for previews to avoid dependency on TodoStore.preview
    let mockStore: TodoStore = TodoStore()

    // Seed a few sample todos if the store is empty
    if mockStore.todos.isEmpty {
        let calendar = Calendar.current
        let today: Date = Date()
        let startOfWeek: Date = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let wednesday: Date = calendar.date(byAdding: .day, value: 2, to: startOfWeek) ?? startOfWeek
        let friday: Date = calendar.date(byAdding: .day, value: 4, to: startOfWeek) ?? startOfWeek

        // Create a couple of sample categories if your model supports it; otherwise omit category assignment
        let workCategory: Category = Category(name: "Arbeit", colorHex: "#FF9500")
        let personalCategory: Category = Category(name: "Persönlich", colorHex: "#007AFF")

        let sampleTodos: [TodoItem] = [
            TodoItem(title: "Präsentation vorbereiten", isCompleted: false, dueDate: wednesday, category: workCategory),
            TodoItem(title: "Wocheneinkauf planen", isCompleted: false, dueDate: friday, category: personalCategory)
        ]
        mockStore.todos = sampleTodos
    }

    return NavigationStack {
        WeeklyGoalsView()
            .environmentObject(mockStore)
    }
}
#endif

