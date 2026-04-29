import SwiftUI

struct WeeklyGoalsView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) var colorScheme
    @State private var startOfWeek: Date = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
    @State private var weekSegment: Int = 0
    @State private var editingTodo: TodoItem? = nil
    @State private var headerAppeared = false
    @ObservedObject private var localizer = LocalizationManager.shared

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Helpers

    private func isInCurrentWeek(_ date: Date) -> Bool {
        date >= startOfWeek.startOfDay && date <= endOfWeek
    }

    private func compareTodos(_ a: TodoItem, _ b: TodoItem) -> Bool {
        let ad = a.dueDate ?? .distantFuture
        let bd = b.dueDate ?? .distantFuture
        if ad != bd { return ad < bd }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }

    private var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)?.endOfDay ?? Date()
    }

    private var todosThisWeek: [TodoItem] {
        todoStore.todos
            .filter { !$0.isCompleted && ($0.dueDate.map { isInCurrentWeek($0) } ?? false) }
            .sorted(by: compareTodos)
    }

    private var completedThisWeekCount: Int {
        todoStore.todos.filter { $0.isCompleted && ($0.dueDate.map { isInCurrentWeek($0) } ?? false) }.count
    }

    private var plannedNextWeekCount: Int {
        let cal = Calendar.current
        let nextStart = cal.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) ?? startOfWeek
        let nextEnd = cal.date(byAdding: .day, value: 6, to: nextStart)?.endOfDay ?? nextStart
        return todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return due >= nextStart.startOfDay && due <= nextEnd
        }.count
    }

    private var dueDatedOutsideCurrentWeekCount: Int {
        todoStore.todos.filter { todo in
            guard !todo.isCompleted, let due = todo.dueDate else { return false }
            return !isInCurrentWeek(due)
        }.count
    }

    private var nextDueDate: Date? {
        todoStore.todos.compactMap { !$0.isCompleted ? $0.dueDate : nil }.sorted().first
    }

    private var weekLabel: String {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        if cal.isDate(startOfWeek, inSameDayAs: currentStart) {
            return localizer.localizedString(forKey: "weekly_menu_this_week")
        } else if let last = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart),
                  cal.isDate(startOfWeek, inSameDayAs: last) {
            return localizer.localizedString(forKey: "weekly_menu_last_week")
        } else if let next = cal.date(byAdding: .weekOfYear, value: 1, to: currentStart),
                  cal.isDate(startOfWeek, inSameDayAs: next) {
            return localizer.localizedString(forKey: "weekly_menu_next_week")
        }
        return weekRangeString()
    }

    private var completionRateThisWeek: Double {
        let total = todosThisWeek.count + completedThisWeekCount
        guard total > 0 else { return 0 }
        return Double(completedThisWeekCount) / Double(total)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                weekBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if todosThisWeek.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(todosThisWeek) { todo in
                                let binding = Binding<TodoItem>(
                                    get: { todoStore.todos.first(where: { $0.id == todo.id }) ?? todo },
                                    set: { updated in
                                        if let idx = todoStore.todos.firstIndex(where: { $0.id == updated.id }) {
                                            todoStore.todos[idx] = updated
                                        }
                                    }
                                )
                                weeklyTodoCard(todo: todo, binding: binding)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey(localizer.localizedString(forKey: "weekly_goals_title")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { todoStore.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(todoStore.canUndo
                            ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                }
                .disabled(!todoStore.canUndo)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { todoStore.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(todoStore.canRedo
                            ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                }
                .disabled(!todoStore.canRedo)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(localizer.localizedString(forKey: "weekly_menu_this_week")) { setWeekAbsolute(0) }
                    Button(localizer.localizedString(forKey: "weekly_menu_next_week")) { setWeekAbsolute(1) }
                    Button(localizer.localizedString(forKey: "weekly_menu_last_week")) { setWeekAbsolute(-1) }
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                }
            }
        }
        .onAppear {
            syncWeekSegmentWithStart()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                headerAppeared = true
            }
        }
        .onChange(of: startOfWeek) { _, _ in syncWeekSegmentWithStart() }
        .sheet(item: $editingTodo) { item in EditTodoView(todo: item) }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(colors: [Color.purple.opacity(isDark ? 0.25 : 0.12), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.45))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.08)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [Color.blue.opacity(isDark ? 0.18 : 0.09), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.4))
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.88, y: geo.size.height * 0.65)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.2).opacity(isDark ? 0.12 : 0.07), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.85)
                    .blur(radius: 14)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Week Banner

    private var weekBanner: some View {
        VStack(spacing: 12) {
            // Week label + range
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.purple, .blue.opacity(0.85)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                    Image(systemName: "target")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(weekLabel)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(weekRangeString())
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12))
                        Text("\(completedThisWeekCount)").font(.system(size: 13, weight: .semibold))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "circle").foregroundStyle(.orange).font(.system(size: 12))
                        Text("\(todosThisWeek.count)").font(.system(size: 13, weight: .semibold))
                    }
                }
            }

            // Progress bar
            if completedThisWeekCount > 0 || !todosThisWeek.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.08)).frame(height: 8)
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [.purple, .blue],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * completionRateThisWeek, height: 8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: completionRateThisWeek)
                        }
                    }
                    .frame(height: 8)
                    Text("\(Int(completionRateThisWeek * 100))% dieser Woche erledigt")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            // Next week CTA
            if plannedNextWeekCount > 0 {
                Button { setWeekAbsolute(1) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(String(format: localizer.localizedString(forKey: "weekly_next_week_cta"), plannedNextWeekCount))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                                in: Capsule())
                    .shadow(color: .purple.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

#if DEBUG
            HStack(spacing: 6) {
                Image(systemName: "info.circle").foregroundStyle(.secondary).font(.system(size: 11))
                Text(diagnosticLineText).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
#endif
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(LinearGradient(
                colors: [Color.white.opacity(isDark ? 0.12 : 0.65),
                         Color.white.opacity(isDark ? 0.04 : 0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
        .shadow(color: Color.purple.opacity(isDark ? 0.10 : 0.04), radius: 18, x: 0, y: 2)
        .scaleEffect(headerAppeared ? 1 : 0.96)
        .opacity(headerAppeared ? 1 : 0)
    }

    // MARK: - Todo Card

    private func weeklyTodoCard(todo: TodoItem, binding: Binding<TodoItem>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            TodoCard(todo: binding, showCategory: true) {
                todoStore.toggleTodo(todo)
            } onEdit: {
                editingTodo = todo
            } onDelete: {
                todoStore.deleteTodo(todo)
            } onShare: {
                TodoShare.share(todo: todo)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LinearGradient(
                colors: [Color.white.opacity(isDark ? 0.10 : 0.55),
                         Color.white.opacity(isDark ? 0.03 : 0.15)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: Color.black.opacity(isDark ? 0.20 : 0.06), radius: 10, x: 0, y: 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { todoStore.toggleTodo(todo) } label: {
                Label(localizer.localizedString(forKey: "weekly_done_swipe"), systemImage: "checkmark")
            }.tint(.green)
            Button(role: .destructive) { todoStore.deleteTodo(todo) } label: {
                Label(localizer.localizedString(forKey: "delete"), systemImage: "trash")
            }
            Button { TodoShare.share(todo: todo) } label: {
                Label(localizer.localizedString(forKey: "Teilen"), systemImage: "square.and.arrow.up")
            }.tint(.blue)
        }
        .strikethrough(binding.wrappedValue.isCompleted, color: .gray)
        .opacity(binding.wrappedValue.isCompleted ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: binding.wrappedValue.isCompleted)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                    Image(systemName: "target")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(LinearGradient(colors: [.purple, .blue],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                VStack(spacing: 8) {
                    Text(localizer.localizedString(forKey: "weekly_empty_title"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(localizer.localizedString(forKey: "weekly_empty_message"))
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                }

                if dueDatedOutsideCurrentWeekCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundStyle(.secondary).font(.system(size: 13))
                        Text(String(format: localizer.localizedString(forKey: "weekly_empty_info"), dueDatedOutsideCurrentWeekCount))
                            .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(isDark ? 0.12 : 0.65),
                             Color.white.opacity(isDark ? 0.04 : 0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 18, x: 0, y: 6)
            .padding(.horizontal, 24)

            // Action buttons
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    emptyButton(label: localizer.localizedString(forKey: "weekly_button_this_week"),
                                icon: "calendar", action: { setWeekAbsolute(0) })
                    emptyButton(label: localizer.localizedString(forKey: "weekly_button_next_week"),
                                icon: "calendar.badge.plus", action: { setWeekAbsolute(1) })
                }

                if let nd = nextDueDate, !isInCurrentWeek(nd) {
                    Button { jumpToWeek(of: nd) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrowshape.turn.up.right.circle.fill")
                            Text(localizer.localizedString(forKey: "weekly_jump_to_next_due"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.purple, .blue],
                                                   startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .purple.opacity(0.35), radius: 8, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                }
            }

            Spacer()
        }
    }

    private func emptyButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Week Navigation

    private func setWeekAbsolute(_ mode: Int) {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let target: Date
        switch mode {
        case -1: target = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart) ?? currentStart
        case  1: target = cal.date(byAdding: .weekOfYear, value:  1, to: currentStart) ?? currentStart
        default: target = currentStart
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { startOfWeek = target }
    }

    private func jumpToWeek(of date: Date) {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { startOfWeek = weekStart }
    }

    private func weekRangeString() -> String {
        let df = DateFormatter()
        df.dateFormat = "d. MMM"
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        return "\(df.string(from: startOfWeek.startOfDay)) – \(df.string(from: endOfWeek))"
    }

    private func syncWeekSegmentWithStart() {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        if cal.isDate(startOfWeek, inSameDayAs: currentStart) { weekSegment = 0 }
        else if let last = cal.date(byAdding: .weekOfYear, value: -1, to: currentStart),
                cal.isDate(startOfWeek, inSameDayAs: last) { weekSegment = -1 }
        else if let next = cal.date(byAdding: .weekOfYear, value: 1, to: currentStart),
                cal.isDate(startOfWeek, inSameDayAs: next) { weekSegment = 1 }
        else { weekSegment = 0 }
    }

    private var diagnosticLineText: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        let nextStr = nextDueDate.map { df.string(from: $0) } ?? "–"
        return String(format: localizer.localizedString(forKey: "weekly_debug_line"), weekRangeString(), todosThisWeek.count, nextStr)
    }
}

// MARK: - Weekly Todo Row

private struct WeeklyTodoRow: View {
    @Binding var todo: TodoItem

    private var dueStatus: (text: String, color: Color)? {
        guard let due = todo.dueDate else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: due)
        if dueDay < today { return ("Überfällig", .red) }
        if cal.isDate(dueDay, inSameDayAs: today) { return ("Heute", .orange) }
        let df = DateFormatter()
        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier)
        df.dateStyle = .short; df.timeStyle = .none
        return (df.string(from: due), .blue)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                withAnimation(.easeInOut) { todo.isCompleted.toggle() }
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(todo.title).font(.system(size: 15, weight: .semibold))
                    if todo.isFavorite {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).imageScale(.small)
                    }
                }
                if let due = todo.dueDate {
                    let df = DateFormatter()
                    let _ = { df.dateStyle = .medium; df.timeStyle = .none
                        df.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? Locale.current.identifier) }()
                    Text(df.string(from: due))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let status = dueStatus {
                Text(status.text)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(status.color.opacity(0.12), in: Capsule())
                    .foregroundStyle(status.color)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { todo.isFavorite.toggle() }
            } label: {
                Image(systemName: todo.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(todo.isFavorite ? .yellow : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain).padding(.leading, 4)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button { withAnimation(.easeInOut) { todo.isCompleted = true } } label: {
                Label("Erledigt", systemImage: "checkmark")
            }.tint(.green)
        }
    }
}

// MARK: - Date Extension

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date {
        let start = Calendar.current.startOfDay(for: self)
        return Calendar.current.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? self
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let mockStore = TodoStore()
    if mockStore.todos.isEmpty {
        let cal = Calendar.current
        let today = Date()
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        let wed = cal.date(byAdding: .day, value: 2, to: startOfWeek) ?? startOfWeek
        let fri = cal.date(byAdding: .day, value: 4, to: startOfWeek) ?? startOfWeek
        let work = Category(name: "Arbeit", colorHex: "#FF9500")
        let personal = Category(name: "Persönlich", colorHex: "#007AFF")
        mockStore.todos = [
            TodoItem(title: "Präsentation vorbereiten", isCompleted: false, dueDate: wed, category: work),
            TodoItem(title: "Wocheneinkauf planen", isCompleted: false, dueDate: fri, category: personal)
        ]
    }
    return NavigationStack { WeeklyGoalsView().environmentObject(mockStore) }
}
#endif
