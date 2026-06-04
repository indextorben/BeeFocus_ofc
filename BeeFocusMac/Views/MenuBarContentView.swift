import SwiftUI

private enum MenuBarTab: CaseIterable {
    case timer, tasks, planner, stats

    var icon: String {
        switch self {
        case .timer:   return "timer"
        case .tasks:   return "checklist"
        case .planner: return "calendar.day.timeline.left"
        case .stats:   return "chart.bar.fill"
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager
    @Environment(\.activeTheme)  private var activeTheme
    @State private var activeTab: MenuBarTab = .timer
    @Namespace private var tabNS

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            ZStack {
                switch activeTab {
                case .timer:   timerTab
                case .tasks:   tasksTab
                case .planner: plannerTab
                case .stats:   statsTab
                }
            }
            .frame(minHeight: 230)
            Divider().opacity(0.2)
            bottomTabBar
        }
        .background(.ultraThinMaterial)
        .frame(width: 360)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.25), accent.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("BeeFocus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text(todayHeaderString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Quit BeeFocus")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var todayHeaderString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    // MARK: - Timer Tab

    private var timerTab: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 14)

            Text(timerMgr.mode.displayName.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(timerMgr.mode.color.opacity(0.85))
                .kerning(1.5)

            Spacer(minLength: 14)

            // Circular ring
            ZStack {
                Circle()
                    .stroke(timerMgr.mode.color.opacity(0.10), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: 1 - timerMgr.progress)
                    .stroke(
                        timerMgr.mode.color,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerMgr.progress)

                VStack(spacing: 5) {
                    Text(timerMgr.timeString)
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { i in
                            let filled = i < (timerMgr.sessionCount % 4 == 0 && timerMgr.sessionCount > 0 ? 4 : timerMgr.sessionCount % 4)
                            Circle()
                                .fill(filled ? timerMgr.mode.color : Color.primary.opacity(0.12))
                                .frame(width: 5, height: 5)
                                .animation(.easeInOut(duration: 0.3), value: timerMgr.sessionCount)
                        }
                    }
                }
            }
            .frame(width: 148, height: 148)

            Spacer(minLength: 18)

            HStack(spacing: 22) {
                Button { timerMgr.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Reset")

                Button { timerMgr.startPause() } label: {
                    Image(systemName: timerMgr.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            LinearGradient(
                                colors: [timerMgr.mode.color, timerMgr.mode.color.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: timerMgr.mode.color.opacity(0.5), radius: 12, y: 5)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help(timerMgr.isRunning ? "Pause" : "Start")

                Button { timerMgr.skipToNext() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Skip to next")
            }

            Spacer(minLength: 12)

            Text("\(timerMgr.sessionCount) session\(timerMgr.sessionCount == 1 ? "" : "s") completed")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 14)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tasks Tab

    private var tasksTab: some View {
        let today = todoStore.todayTodos
        let open  = today.filter { !$0.isCompleted }.count
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Today")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if open > 0 {
                    Text("\(open) open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(accent.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if today.isEmpty {
                emptyState(icon: "checkmark.circle.fill", text: "Nothing due today")
            } else {
                VStack(spacing: 0) {
                    ForEach(today.prefix(7)) { todo in
                        taskRow(todo)
                    }
                }
            }

            Spacer(minLength: 10)
        }
    }

    private func taskRow(_ todo: MacTodoItem) -> some View {
        HStack(spacing: 10) {
            Button { todoStore.toggle(todo) } label: {
                ZStack {
                    Circle()
                        .stroke(todo.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    if todo.isCompleted {
                        Circle().fill(Color.green).frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.system(size: 13))
                .strikethrough(todo.isCompleted, color: .secondary)
                .foregroundStyle(todo.isCompleted ? Color.secondary.opacity(0.5) : Color.primary)
                .lineLimit(1)

            Spacer()

            if todo.priority == .high && !todo.isCompleted {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.orange)
                    .frame(width: 3, height: 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color.primary.opacity(0.001)
                .contentShape(Rectangle())
        )
    }

    // MARK: - Planner Tab

    private var plannerTab: some View {
        let today = todayTimedTodos
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(shortDateString)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(today.count) task\(today.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            if today.isEmpty {
                emptyState(icon: "calendar.badge.checkmark", text: "Nothing scheduled")
            } else {
                VStack(spacing: 0) {
                    ForEach(today.prefix(6)) { todo in
                        HStack(spacing: 10) {
                            Button { todoStore.toggle(todo) } label: {
                                ZStack {
                                    Circle()
                                        .stroke(todo.isCompleted ? Color.green : Color.secondary.opacity(0.4), lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                    if todo.isCompleted {
                                        Circle().fill(Color.green).frame(width: 18, height: 18)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(todo.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .strikethrough(todo.isCompleted, color: .secondary)
                                    .foregroundStyle(todo.isCompleted ? Color.secondary.opacity(0.5) : Color.primary)
                                    .lineLimit(1)
                                if let due = todo.dueDate {
                                    Text(timeString(due))
                                        .font(.system(size: 10))
                                        .foregroundStyle(accent.opacity(0.8))
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                }
            }

            Spacer(minLength: 10)
        }
    }

    // MARK: - Stats Tab

    private var statsTab: some View {
        let cal = Calendar.current
        let completedToday = todoStore.todos.filter {
            $0.isCompleted && cal.isDateInToday($0.updatedAt)
        }.count

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statCard(label: "Done today",   value: "\(completedToday)",                 color: .green,              icon: "checkmark.circle.fill")
                statCard(label: "Overdue",      value: "\(todoStore.overdueTodos.count)",    color: .red,                icon: "exclamationmark.circle.fill")
            }
            HStack(spacing: 10) {
                statCard(label: "Open tasks",   value: "\(todoStore.activeTodos.count)",     color: accent,              icon: "circle.dotted")
                statCard(label: "Sessions",     value: "\(timerMgr.sessionCount)",           color: timerMgr.mode.color, icon: "timer")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func statCard(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 4) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        activeTab = tab
                    }
                } label: {
                    ZStack {
                        if activeTab == tab {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(accent.opacity(0.14))
                                .matchedGeometryEffect(id: "tabBG", in: tabNS)
                        }
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14, weight: activeTab == tab ? .semibold : .regular))
                                .foregroundStyle(activeTab == tab ? accent : Color.secondary.opacity(0.6))
                            if activeTab == tab {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 3, height: 3)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(height: 38)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Empty State

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(accent.opacity(0.45))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Helpers

    private var shortDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date())
    }

    private var todayTimedTodos: [MacTodoItem] {
        let cal = Calendar.current
        return todoStore.todos
            .filter { guard let due = $0.dueDate else { return false }
                      return cal.isDate(due, inSameDayAs: Date()) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
