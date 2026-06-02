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
    var label: String {
        switch self {
        case .timer:   return "Timer"
        case .tasks:   return "Aufgaben"
        case .planner: return "Tag"
        case .stats:   return "Statistik"
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager
    @Environment(\.openWindow)   private var openWindow
    @Environment(\.activeTheme)  private var activeTheme
    @State private var activeTab: MenuBarTab = .timer

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
            Divider()
            footerBar
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuBarTab.allCases, id: \.self) { tab in
                Button { activeTab = tab } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(activeTab == tab ? accent : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(activeTab == tab ? accent.opacity(0.1) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .timer:   timerStrip
        case .tasks:   quickTaskList
        case .planner: compactPlanner
        case .stats:   compactStats
        }
    }

    // MARK: - Timer Strip

    private var timerStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerMgr.mode.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(timerMgr.timeString)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundStyle(timerMgr.mode.color)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { timerMgr.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)

                Button { timerMgr.startPause() } label: {
                    Image(systemName: timerMgr.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(timerMgr.mode.color, in: Circle())
                        .shadow(color: timerMgr.mode.color.opacity(0.4), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Quick Task List

    private var quickTaskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Heute")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let open = todoStore.todayTodos.filter { !$0.isCompleted }.count
                if open > 0 {
                    Text("\(open) offen")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if todoStore.todayTodos.isEmpty {
                Text("Keine Aufgaben für heute")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ForEach(todoStore.todayTodos.prefix(6)) { todo in
                    HStack(spacing: 8) {
                        Button {
                            todoStore.toggle(todo)
                        } label: {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.isCompleted ? Color.green : Color.secondary)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)

                        Text(todo.title)
                            .font(.system(size: 13))
                            .strikethrough(todo.isCompleted, color: .secondary)
                            .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                }
            }
        }
    }

    // MARK: - Compact Planner

    private var todayTimedTodos: [MacTodoItem] {
        let cal = Calendar.current
        return todoStore.todos
            .filter { guard let due = $0.dueDate else { return false }; return cal.isDate(due, inSameDayAs: Date()) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var compactPlanner: some View {
        let today = todayTimedTodos
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(todayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(today.count) Aufgabe\(today.count == 1 ? "" : "n")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if today.isEmpty {
                Text("Nichts geplant für heute")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            } else {
                ForEach(today.prefix(6)) { todo in
                    HStack(spacing: 8) {
                        Button { todoStore.toggle(todo) } label: {
                            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(todo.isCompleted ? Color.green : Color.secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(todo.title)
                                .font(.system(size: 12))
                                .strikethrough(todo.isCompleted, color: .secondary)
                                .foregroundStyle(todo.isCompleted ? Color.secondary : Color.primary)
                                .lineLimit(1)
                            if let due = todo.dueDate {
                                Text(timeString(due))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Compact Stats

    private var compactStats: some View {
        let cal = Calendar.current
        let completedToday = todoStore.todos.filter {
            $0.isCompleted && cal.isDateInToday($0.updatedAt)
        }.count

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                miniStat("Heute erledigt", value: "\(completedToday)", color: .green)
                Divider().frame(height: 40)
                miniStat("Überfällig", value: "\(todoStore.overdueTodos.count)", color: .red)
            }
            Divider()
            HStack(spacing: 0) {
                miniStat("Gesamt offen", value: "\(todoStore.activeTodos.count)", color: .blue)
                Divider().frame(height: 40)
                miniStat("Fokus-Sessions", value: "\(timerMgr.sessionCount)", color: accent)
            }
        }
        .padding(.vertical, 6)
    }

    private func miniStat(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var todayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d. MMM"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: Date())
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("App öffnen", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Beenden") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
