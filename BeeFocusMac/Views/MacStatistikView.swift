import SwiftUI

struct MacStatistikView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager

    private let cal = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsCards
                Divider()
                weekChart
                Divider()
                priorityBreakdown
                Divider()
                focusSessions
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea())
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard("Heute erledigt",  value: "\(completedToday)",     icon: "checkmark.circle.fill", color: .green)
            statCard("Überfällig",      value: "\(todoStore.overdueTodos.count)", icon: "exclamationmark.circle.fill", color: .red)
            statCard("Gesamt offen",    value: "\(todoStore.activeTodos.count)",  icon: "circle",                   color: .blue)
            statCard("Fokus-Sitzungen", value: "\(timerMgr.sessionCount)",        icon: "timer",                    color: .orange)
        }
    }

    private func statCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Weekly Chart

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Wochenübersicht", icon: "chart.bar.fill")
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7Days, id: \.self) { day in
                    let count = completedOn(day)
                    let maxCount = max(last7Days.map { completedOn($0) }.max() ?? 1, 1)
                    let height = max(CGFloat(count) / CGFloat(maxCount) * 100, 4)
                    let isToday = cal.isDateInToday(day)
                    VStack(spacing: 4) {
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isToday ? Color.orange : Color.blue.opacity(0.5))
                            .frame(height: height)
                        Text(dayLabel(day))
                            .font(.system(size: 10))
                            .foregroundStyle(isToday ? .orange : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Priority Breakdown

    private var priorityBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Aufgaben nach Priorität", icon: "flag.fill")
            HStack(spacing: 12) {
                priorityRow("Hoch",    count: count(for: .high),   color: Color(red: 1, green: 0.25, blue: 0.25))
                priorityRow("Mittel",  count: count(for: .medium), color: Color(red: 1, green: 0.6, blue: 0.1))
                priorityRow("Niedrig", count: count(for: .low),    color: Color(red: 0.2, green: 0.8, blue: 0.3))
            }
        }
    }

    private func priorityRow(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 6).frame(width: 56, height: 56)
                Text("\(count)").font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            }
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Focus Sessions

    private var focusSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Fokus-Timer", icon: "timer")
            HStack(spacing: 12) {
                infoTile("Aktuelle Phase", value: timerMgr.mode.rawValue, color: timerMgr.mode.color)
                infoTile("Verbleibend",    value: timerMgr.timeString,    color: timerMgr.mode.color)
                infoTile("Sitzungen",      value: "\(timerMgr.sessionCount)", color: .orange)
                infoTile("Fokuszeit",      value: "\(timerMgr.focusDuration) min", color: .secondary)
            }
        }
    }

    private func infoTile(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        }
    }

    private var completedToday: Int {
        todoStore.todos.filter { $0.isCompleted && cal.isDateInToday($0.updatedAt) }.count
    }

    private var last7Days: [Date] {
        (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
                          .map { cal.startOfDay(for: $0) }
    }

    private func completedOn(_ day: Date) -> Int {
        todoStore.todos.filter {
            $0.isCompleted && cal.isDate($0.updatedAt, inSameDayAs: day)
        }.count
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }

    private func count(for priority: MacTodoPriority) -> Int {
        todoStore.activeTodos.filter { $0.priority == priority }.count
    }
}
