import SwiftUI

// MARK: - Theme helper

private func watchThemeColors(_ name: String) -> (Color, Color) {
    switch name {
    case "Ozean":           return (.cyan, .teal)
    case "Wald":            return (.green, Color(red: 0.1, green: 0.5, blue: 0.2))
    case "Nacht":           return (.indigo, .purple)
    case "Solar":           return (.orange, .yellow)
    case "Kirschblüte":     return (.pink, Color(red: 1.0, green: 0.4, blue: 0.6))
    case "Vulkan":          return (.red, .orange)
    case "Eis":             return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan)
    case "Herbst":          return (Color(red: 0.8, green: 0.4, blue: 0.1), .orange)
    case "Lavendel":        return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9))
    case "Sonnenuntergang": return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink)
    case "Galaxie":         return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95))
    case "Nordlicht":       return (.green, Color(red: 0.0, green: 0.8, blue: 0.6))
    default:                return (Color(red: 0.5, green: 0.35, blue: 1.0), Color(red: 0.3, green: 0.15, blue: 0.85))
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared
    @State private var selectedTab = 0

    private var c1: Color { watchThemeColors(session.snapshot.activeTheme).0 }
    private var c2: Color { watchThemeColors(session.snapshot.activeTheme).1 }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayTab(session: session, c1: c1, c2: c2)
                .tag(0)
            TagesplanTab(session: session, c1: c1, c2: c2)
                .tag(1)
            MonatTab(session: session, c1: c1, c2: c2)
                .tag(2)
            FokusTab(session: session, c1: c1, c2: c2)
                .tag(3)
        }
        .tabViewStyle(.page)
        .background(watchBackground(c1: c1, c2: c2).ignoresSafeArea())
        .onAppear { session.loadSnapshot() }
    }
}

// MARK: - Background

func watchBackground(c1: Color, c2: Color) -> some View {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.14),
                Color(red: 0.10, green: 0.08, blue: 0.20),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        RadialGradient(colors: [c1.opacity(0.30), .clear], center: .topLeading,    startRadius: 0, endRadius: 90)
        RadialGradient(colors: [c2.opacity(0.20), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 70)
    }
}

// MARK: - Today Tab

struct TodayTab: View {
    @ObservedObject var session: WatchSessionManager
    @State private var completedIDs: Set<UUID> = []
    let c1: Color
    let c2: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                statsRow
                if session.snapshot.topTasks.isEmpty {
                    emptyState
                } else {
                    ForEach(session.snapshot.topTasks) { task in
                        taskCard(task)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Heute")
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(session.snapshot.dueTodayCount)",
                label: "offen",
                color: c1
            )
            Divider().frame(height: 28).opacity(0.3)
            statCell(
                value: "\(session.snapshot.completedTodayCount)",
                label: "erledigt",
                color: .green
            )
            if session.snapshot.overdueCount > 0 {
                Divider().frame(height: 28).opacity(0.3)
                statCell(
                    value: "\(session.snapshot.overdueCount)",
                    label: "überfällig",
                    color: .orange
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(c1.opacity(0.3), lineWidth: 1))
        )
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 14)).foregroundStyle(.green)
            Text("Alles erledigt! 🎉").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func taskCard(_ task: WatchTask) -> some View {
        let done = completedIDs.contains(task.id) || task.isOverdue && false
        let accent = task.accentColor

        return Button {
            guard !done else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                completedIDs.insert(task.id)
            }
            session.completeTask(id: task.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    // Left accent bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(task.isOverdue ? Color.orange : accent)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        // Time row
                        if let due = task.dueDate {
                            timeRow(due: due, end: task.endDate, isOverdue: task.isOverdue)
                        }

                        // Title row
                        HStack(spacing: 6) {
                            if done {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.green)
                            } else if task.isOverdue {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.orange)
                            } else if task.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.yellow)
                            }
                            Text(task.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(done ? .secondary : .primary)
                                .strikethrough(done, color: .secondary)
                                .lineLimit(2)
                        }

                        // Meta row
                        if task.categoryName != nil || task.subTasksTotal > 0 {
                            metaRow(task: task)
                        }
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 6)
                    .padding(.vertical, 8)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(task.isOverdue ? Color.orange.opacity(0.4) : accent.opacity(0.25), lineWidth: 1)
                    )
            )
            .opacity(done ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func timeRow(due: Date, end: Date?, isOverdue: Bool) -> some View {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let timeStr = end != nil
            ? "\(timeFmt.string(from: due)) – \(timeFmt.string(from: end!))"
            : timeFmt.string(from: due)

        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 9))
                .foregroundStyle(isOverdue ? .orange : .secondary)
            Text(timeStr)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isOverdue ? .orange : .secondary)
        }
    }

    private func metaRow(task: WatchTask) -> some View {
        HStack(spacing: 6) {
            if let catName = task.categoryName {
                HStack(spacing: 3) {
                    Circle()
                        .fill(task.categoryColor)
                        .frame(width: 5, height: 5)
                    Text(catName)
                        .font(.system(size: 10))
                        .foregroundStyle(task.categoryColor)
                        .lineLimit(1)
                }
            }
            if task.subTasksTotal > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("\(task.subTasksCompleted)/\(task.subTasksTotal)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Tagesplan Tab

struct TagesplanTab: View {
    @ObservedObject var session: WatchSessionManager
    let c1: Color
    let c2: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                headerLabel
                if session.snapshot.todayBausteine.isEmpty {
                    emptyBausteine
                } else {
                    ForEach(session.snapshot.todayBausteine) { baustein in
                        bausteinCard(baustein)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Tagesplan")
    }

    private var headerLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(c1)
            Text("BAUSTEINE HEUTE")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(c1)
                .tracking(0.5)
            Spacer()
            Text("\(session.snapshot.todayBausteine.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(c1.opacity(0.7))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(c1.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var emptyBausteine: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 24))
                .foregroundStyle(c1.opacity(0.5))
            Text("Keine Bausteine\nfür heute")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }

    private func bausteinCard(_ b: WatchBaustein) -> some View {
        HStack(spacing: 0) {
            // Colored left bar
            RoundedRectangle(cornerRadius: 2)
                .fill(b.farbe)
                .frame(width: 3)
                .padding(.vertical, 2)

            HStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(b.farbe.opacity(0.2))
                        .frame(width: 30, height: 30)
                    Image(systemName: b.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(b.farbe)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Time
                    Text(b.zeitLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)

                    // Title
                    HStack(spacing: 4) {
                        if b.isHighPriority {
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        Text(b.titel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    // Description
                    if !b.beschreibung.isEmpty {
                        Text(b.beschreibung)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(b.farbe.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Monat Tab

struct MonatTab: View {
    @ObservedObject var session: WatchSessionManager
    @State private var completedIDs: Set<UUID> = []
    let c1: Color
    let c2: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                monatHeader
                if session.snapshot.monthTasks.isEmpty {
                    monatEmpty
                } else {
                    ForEach(session.snapshot.monthTasks) { task in
                        monatTaskRow(task)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Monat")
    }

    private var monatHeader: some View {
        HStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(c2)
            Text(session.snapshot.activeMonthLabel.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(c2)
                .tracking(0.5)
                .lineLimit(1)
            Spacer()
            Text("\(session.snapshot.monthTasks.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(c2.opacity(0.7))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(c2.opacity(0.15), in: Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var monatEmpty: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 14)).foregroundStyle(.green)
            Text("Alles erledigt!").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private func monatTaskRow(_ task: WatchTask) -> some View {
        let done = completedIDs.contains(task.id)
        let accent = task.accentColor

        return Button {
            guard !done else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                completedIDs.insert(task.id)
            }
            session.completeTask(id: task.id)
        } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(task.isOverdue ? Color.orange : accent)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: done ? "checkmark.circle.fill" : (task.isOverdue ? "exclamationmark.circle.fill" : "circle"))
                            .font(.system(size: 13))
                            .foregroundStyle(done ? .green : (task.isOverdue ? .orange : accent))
                        Text(task.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(done ? .secondary : .primary)
                            .strikethrough(done, color: .secondary)
                            .lineLimit(2)
                    }

                    if let due = task.dueDate {
                        let fmt = DateFormatter()
                        let _ = { fmt.locale = Locale(identifier: "de"); fmt.dateFormat = "d. MMM" }()
                        HStack(spacing: 4) {
                            Image(systemName: "calendar").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(fmt.string(from: due)).font(.system(size: 10)).foregroundStyle(.secondary)
                            if task.subTasksTotal > 0 {
                                Text("·").foregroundStyle(.secondary)
                                Image(systemName: "checklist").font(.system(size: 9)).foregroundStyle(.secondary)
                                Text("\(task.subTasksCompleted)/\(task.subTasksTotal)").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 6)
                .padding(.vertical, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accent.opacity(0.2), lineWidth: 1)
                    )
            )
            .opacity(done ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Fokus Tab

struct FokusTab: View {
    @ObservedObject var session: WatchSessionManager
    let c1: Color
    let c2: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                focusRing
                statsGrid
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .navigationTitle("Fokus")
    }

    private var focusRing: some View {
        let mins = session.snapshot.focusMinutesToday
        let goal = 60.0
        let progress = min(Double(mins) / goal, 1.0)

        return ZStack {
            Circle()
                .stroke(c1.opacity(0.15), lineWidth: 8)
                .frame(width: 80, height: 80)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(c1, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
            VStack(spacing: 1) {
                Text(focusLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(c1)
                Text("Fokus")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private var focusLabel: String {
        let m = session.snapshot.focusMinutesToday
        if m >= 60 {
            let h = m / 60; let rem = m % 60
            return rem > 0 ? "\(h)h\(rem)m" : "\(h)h"
        }
        return "\(m)m"
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            statCell(icon: "checklist.checked", value: "\(session.snapshot.completedTodayCount)", label: "Heute erledigt", color: .green)
            statCell(icon: "tray.full.fill", value: "\(session.snapshot.totalOpenCount)", label: "Offen gesamt", color: c2)
            statCell(icon: "calendar.badge.clock", value: "\(session.snapshot.dueTodayCount)", label: "Heute fällig", color: c1)
            if session.snapshot.overdueCount > 0 {
                statCell(icon: "exclamationmark.circle.fill", value: "\(session.snapshot.overdueCount)", label: "Überfällig", color: .orange)
            }
        }
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
