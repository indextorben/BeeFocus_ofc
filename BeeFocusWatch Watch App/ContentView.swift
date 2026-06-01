import SwiftUI

// MARK: - Theme accent

private func themeAccent(for theme: String) -> Color {
    switch theme {
    case "Ozean", "Eis":        return .cyan
    case "Wald", "Nordlicht":   return .green
    case "Nacht":               return .indigo
    case "Solar":               return .orange
    case "Kirschblüte":         return .pink
    case "Vulkan":              return .red
    case "Herbst":              return Color(red: 0.9, green: 0.5, blue: 0.1)
    case "Lavendel", "Galaxie": return .purple
    case "Sonnenuntergang":     return Color(red: 1.0, green: 0.4, blue: 0.2)
    default:                    return Color(red: 0.5, green: 0.35, blue: 1.0)
    }
}

// MARK: - Formatters

private let timeFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
}()
private let dateFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "de"); f.dateFormat = "d. MMM"; return f
}()

// MARK: - Tab

enum WatchTab: String, CaseIterable {
    case heute     = "Heute"
    case tagesplan = "Tagesplan"
    case monat     = "Monat"

    var icon: String {
        switch self {
        case .heute:     return "sun.max.fill"
        case .tagesplan: return "rectangle.stack.fill"
        case .monat:     return "calendar"
        }
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared
    @State private var activeTab: WatchTab = .heute

    var accent: Color { themeAccent(for: session.snapshot.activeTheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar
                tabBar

                // Content
                Group {
                    switch activeTab {
                    case .heute:
                        TodayView(session: session, accent: accent)
                    case .tagesplan:
                        TagesplanView(session: session, accent: accent)
                    case .monat:
                        MonatView(session: session, accent: accent)
                    }
                }
            }
        }
        .onAppear { session.loadSnapshot() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(WatchTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { activeTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(activeTab == tab ? accent : .secondary)
                        Text(tab.rawValue)
                            .font(.system(size: 9, weight: activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(activeTab == tab ? accent : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(activeTab == tab ? accent.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Today

struct TodayView: View {
    @ObservedObject var session: WatchSessionManager
    @State private var doneIDs: Set<UUID> = []
    let accent: Color

    var snap: WatchSnapshot { session.snapshot }

    var body: some View {
        List {
            Section {
                statsRow
            }
            .listRowBackground(Color.clear)
            .listRowInsets(.init())

            if snap.topTasks.isEmpty {
                Section {
                    Label("Alles erledigt!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(snap.topTasks) { task in
                        TaskRow(task: task, accent: accent, doneIDs: $doneIDs) {
                            session.completeTask(id: task.id)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(n: snap.dueTodayCount,       label: "Heute",     color: accent)
            Divider().frame(height: 22).padding(.horizontal, 4)
            statCell(n: snap.completedTodayCount, label: "Erledigt",  color: .green)
            if snap.overdueCount > 0 {
                Divider().frame(height: 22).padding(.horizontal, 4)
                statCell(n: snap.overdueCount,    label: "Überfällig", color: .orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func statCell(n: Int, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(n)").font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: WatchTask
    let accent: Color
    @Binding var doneIDs: Set<UUID>
    let onComplete: () -> Void

    var isDone: Bool { doneIDs.contains(task.id) }
    var rowAccent: Color {
        if task.isOverdue { return .orange }
        if let hex = task.categoryColorHex { return Color(hexString: hex) }
        return task.priorityRaw == "high" ? .red : accent
    }

    var body: some View {
        Button {
            guard !isDone else { return }
            withAnimation(.spring(response: 0.3)) { doneIDs.insert(task.id) }
            onComplete()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .strokeBorder(isDone ? Color.green : rowAccent, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .strikethrough(isDone)
                        .lineLimit(2)

                    if let due = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 9))
                                .foregroundStyle(task.isOverdue ? .orange : .secondary)
                            Text(timeStr(due: due, end: task.endDate))
                                .font(.system(size: 11))
                                .foregroundStyle(task.isOverdue ? .orange : .secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        if let cat = task.categoryName {
                            HStack(spacing: 4) {
                                Circle().fill(task.categoryColor).frame(width: 6, height: 6)
                                Text(cat).font(.system(size: 11)).foregroundStyle(task.categoryColor).lineLimit(1)
                            }
                        }
                        if task.subTasksTotal > 0 {
                            Text("\(task.subTasksCompleted)/\(task.subTasksTotal)")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        if task.isFavorite {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .opacity(isDone ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(rowAccent.opacity(0.08))
                .padding(.vertical, 2)
        )
    }

    private func timeStr(due: Date, end: Date?) -> String {
        guard let end else { return timeFmt.string(from: due) }
        return "\(timeFmt.string(from: due)) – \(timeFmt.string(from: end))"
    }
}

// MARK: - Tagesplan

struct TagesplanView: View {
    @ObservedObject var session: WatchSessionManager
    let accent: Color

    var body: some View {
        List {
            if session.snapshot.todayBausteine.isEmpty {
                Section {
                    Label("Keine Bausteine für heute", systemImage: "rectangle.stack")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(session.snapshot.todayBausteine) { b in
                        BausteinRow(baustein: b)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct BausteinRow: View {
    let baustein: WatchBaustein

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(baustein.farbe.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: baustein.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(baustein.farbe)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if baustein.isHighPriority {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    Text(baustein.titel)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                }
                Text(baustein.zeitLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if !baustein.beschreibung.isEmpty {
                    Text(baustein.beschreibung)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(baustein.farbe.opacity(0.08))
                .padding(.vertical, 2)
        )
    }
}

// MARK: - Monat

struct MonatView: View {
    @ObservedObject var session: WatchSessionManager
    @State private var doneIDs: Set<UUID> = []
    let accent: Color

    var body: some View {
        List {
            Section(header:
                Text(session.snapshot.activeMonthLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
            ) {
                if session.snapshot.monthTasks.isEmpty {
                    Label("Alles erledigt!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green).font(.footnote)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(session.snapshot.monthTasks) { task in
                        MonatTaskRow(task: task, accent: accent, doneIDs: $doneIDs) {
                            session.completeTask(id: task.id)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct MonatTaskRow: View {
    let task: WatchTask
    let accent: Color
    @Binding var doneIDs: Set<UUID>
    let onComplete: () -> Void

    var isDone: Bool { doneIDs.contains(task.id) }
    var rowAccent: Color {
        if let hex = task.categoryColorHex { return Color(hexString: hex) }
        return task.priorityRaw == "high" ? .red : accent
    }

    var body: some View {
        Button {
            guard !isDone else { return }
            withAnimation(.spring(response: 0.3)) { doneIDs.insert(task.id) }
            onComplete()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isDone ? .green : rowAccent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .strikethrough(isDone)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let due = task.dueDate {
                            Text(dateFmt.string(from: due))
                                .font(.system(size: 11))
                                .foregroundStyle(task.isOverdue ? .orange : .secondary)
                        }
                        if task.subTasksTotal > 0 {
                            Text("\(task.subTasksCompleted)/\(task.subTasksTotal)")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 3)
            .opacity(isDone ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(rowAccent.opacity(0.08))
                .padding(.vertical, 2)
        )
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
