import SwiftUI
import WatchKit
import UserNotifications
import Combine

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
    case tagesplan = "Plan"
    case monat     = "Monat"
    case mehr      = "Mehr"

    var icon: String {
        switch self {
        case .heute:     return "sun.max.fill"
        case .tagesplan: return "rectangle.stack.fill"
        case .monat:     return "calendar"
        case .mehr:      return "ellipsis.circle.fill"
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
                tabBar
                Group {
                    switch activeTab {
                    case .heute:
                        TodayView(session: session, accent: accent)
                    case .tagesplan:
                        TagesplanView(session: session, accent: accent)
                    case .monat:
                        MonatView(session: session, accent: accent)
                    case .mehr:
                        MehrView(session: session, accent: accent)
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
                            .font(.system(size: 13, weight: activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(activeTab == tab ? accent : .secondary)
                        Text(tab.rawValue)
                            .font(.system(size: 8, weight: activeTab == tab ? .semibold : .regular))
                            .foregroundStyle(activeTab == tab ? accent : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
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

// MARK: - Mehr (Menu)

struct MehrView: View {
    @ObservedObject var session: WatchSessionManager
    let accent: Color

    var body: some View {
        List {
            NavigationLink {
                WasserView(session: session)
            } label: {
                Label("Wasser", systemImage: "drop.fill")
                    .foregroundStyle(.cyan)
            }
            .listRowBackground(rowBg(.cyan))

            NavigationLink {
                WatchTimerView(accent: accent)
            } label: {
                Label("Timer", systemImage: "timer")
                    .foregroundStyle(accent)
            }
            .listRowBackground(rowBg(accent))

            NavigationLink {
                GewohnheitenView(session: session)
            } label: {
                Label("Gewohnheiten", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .listRowBackground(rowBg(.yellow))

            NavigationLink {
                CountdownWatchView(session: session)
            } label: {
                Label("Countdown", systemImage: "calendar.badge.clock")
                    .foregroundStyle(.orange)
            }
            .listRowBackground(rowBg(.orange))

            NavigationLink {
                MotivationWatchView(accent: accent)
            } label: {
                Label("Motivation", systemImage: "quote.bubble.fill")
                    .foregroundStyle(.pink)
            }
            .listRowBackground(rowBg(.pink))
        }
        .listStyle(.plain)
        .navigationTitle("Mehr")
    }

    private func rowBg(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(0.08))
            .padding(.vertical, 2)
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
            statCell(n: snap.dueTodayCount,       label: "Heute",      color: accent)
            Divider().frame(height: 22).padding(.horizontal, 4)
            statCell(n: snap.completedTodayCount, label: "Erledigt",   color: .green)
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

// MARK: - Wasser

struct WasserView: View {
    @ObservedObject var session: WatchSessionManager
    @State private var localAddedML: Int = 0

    private var totalML: Int { session.snapshot.waterTodayML + localAddedML }
    private var goalML: Int { max(session.snapshot.waterGoalML, 1) }
    private var progress: Double { min(Double(totalML) / Double(goalML), 1.0) }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.cyan,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: progress)

                    VStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 14))
                        Text("\(totalML)")
                            .font(.system(size: 20, weight: .bold))
                        Text("/ \(goalML) ml")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                HStack(spacing: 6) {
                    ForEach([150, 250, 330], id: \.self) { ml in
                        Button {
                            localAddedML += ml
                            session.addWater(ml: ml)
                            WKInterfaceDevice.current().play(.click)
                        } label: {
                            Text("+\(ml)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.cyan)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .navigationTitle("Wasser")
    }
}

// MARK: - Watch Timer

struct WatchTimerView: View {
    let accent: Color

    @AppStorage("focusTime")      private var focusTime: Int = 25
    @AppStorage("shortBreakTime") private var shortBreakTime: Int = 5
    @AppStorage("watchTimerEndTS")  private var endTimestamp: Double = 0
    @AppStorage("watchTimerRunning") private var running: Bool = false
    @AppStorage("watchTimerIsBreak") private var isBreak: Bool = false

    @State private var remaining: TimeInterval = 0

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var totalDuration: TimeInterval {
        isBreak ? TimeInterval(shortBreakTime * 60) : TimeInterval(focusTime * 60)
    }
    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - remaining / totalDuration
    }
    private var timeString: String {
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .foregroundStyle(isBreak ? .green : accent)
                Text(isBreak ? "Pause" : "Fokus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isBreak ? .green : accent)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(isBreak ? Color.green : accent,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                Text(timeString)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
            }
            .frame(width: 100, height: 100)

            HStack(spacing: 14) {
                Button(action: resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: toggleTimer) {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(isBreak ? Color.green : accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .onAppear(perform: restoreTimer)
        .onReceive(clock) { _ in tick() }
        .navigationTitle("Timer")
    }

    private func restoreTimer() {
        if running && endTimestamp > 0 {
            remaining = max(0, endTimestamp - Date().timeIntervalSince1970)
            if remaining == 0 { timerFinished() }
        } else if remaining == 0 {
            remaining = totalDuration
        }
    }

    private func toggleTimer() {
        if running {
            running = false
            endTimestamp = 0
        } else {
            if remaining <= 0 { remaining = totalDuration }
            endTimestamp = Date().timeIntervalSince1970 + remaining
            running = true
            scheduleNotification()
        }
    }

    private func resetTimer() {
        running = false
        endTimestamp = 0
        remaining = totalDuration
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func tick() {
        guard running else { return }
        remaining = max(0, endTimestamp - Date().timeIntervalSince1970)
        if remaining <= 0 { timerFinished() }
    }

    private func timerFinished() {
        running = false
        endTimestamp = 0
        isBreak.toggle()
        remaining = isBreak ? TimeInterval(shortBreakTime * 60) : TimeInterval(focusTime * 60)
        WKInterfaceDevice.current().play(.notification)
    }

    private func scheduleNotification() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = isBreak ? "Pause beendet" : "Fokuszeit vorbei"
        content.body  = isBreak ? "Weiter mit Fokus!" : "Zeit für eine Pause."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let req = UNNotificationRequest(identifier: "watchTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - Gewohnheiten

struct GewohnheitenView: View {
    @ObservedObject var session: WatchSessionManager
    @State private var completedLocally: Set<UUID> = []

    var body: some View {
        List {
            if session.snapshot.habits.isEmpty {
                Section {
                    Label("Gewohnheiten in der App anlegen", systemImage: "star.slash")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            } else {
                let (done, total) = progressTuple
                Section {
                    HStack {
                        Text("\(done)/\(total) heute")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if done == total && total > 0 {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    ForEach(session.snapshot.habits) { habit in
                        let isDone = habit.isCompletedToday || completedLocally.contains(habit.id)
                        Button {
                            guard !isDone else { return }
                            completedLocally.insert(habit.id)
                            session.toggleHabit(id: habit.id)
                            WKInterfaceDevice.current().play(.success)
                        } label: {
                            HabitWatchRow(habit: habit, isDone: isDone)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Gewohnheiten")
    }

    private var progressTuple: (Int, Int) {
        let habits = session.snapshot.habits
        let done = habits.filter { $0.isCompletedToday || completedLocally.contains($0.id) }.count
        return (done, habits.count)
    }
}

struct HabitWatchRow: View {
    let habit: WatchHabit
    let isDone: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isDone ? habit.color : habit.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: habit.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isDone ? .white : habit.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.system(size: 13, weight: .semibold))
                    .strikethrough(isDone)
                    .foregroundStyle(isDone ? .secondary : .primary)
                if habit.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.system(size: 9)).foregroundStyle(.orange)
                        Text("\(habit.streak) Tage").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(habit.color.opacity(isDone ? 0.05 : 0.08))
                .padding(.vertical, 2)
        )
    }
}

// MARK: - Countdown

struct CountdownWatchView: View {
    @ObservedObject var session: WatchSessionManager

    var body: some View {
        List {
            if session.snapshot.countdownEvents.isEmpty {
                Section {
                    Label("Events in der App anlegen", systemImage: "calendar.badge.plus")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(session.snapshot.countdownEvents) { event in
                        CountdownEventWatchRow(event: event)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Countdown")
    }
}

struct CountdownEventWatchRow: View {
    let event: WatchCountdown

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(event.farbe.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: event.symbol).font(.system(size: 14)).foregroundStyle(event.farbe)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Group {
                    if event.tageVerbleibend == 0 {
                        Text("Heute!").foregroundStyle(.green).fontWeight(.bold)
                    } else if event.tageVerbleibend < 0 {
                        Text("Vorbei").foregroundStyle(.secondary)
                    } else {
                        Text("\(event.tageVerbleibend) Tage").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 11))
            }

            Spacer()

            if event.tageVerbleibend > 0 {
                Text("\(event.tageVerbleibend)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(event.farbe)
            } else if event.tageVerbleibend == 0 {
                Image(systemName: "party.popper.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12)
                .fill(event.farbe.opacity(0.08))
                .padding(.vertical, 2)
        )
    }
}

// MARK: - Motivation

private let motivationQuotes: [(text: String, author: String)] = [
    ("Der einzige Weg, großartige Arbeit zu leisten, ist zu lieben, was du tust.", "Steve Jobs"),
    ("Du musst die Veränderung sein, die du in der Welt sehen willst.", "Mahatma Gandhi"),
    ("Erfolg ist die Summe kleiner Anstrengungen, die sich Tag für Tag wiederholen.", "Robert Collier"),
    ("Der beste Zeitpunkt, einen Baum zu pflanzen, war vor 20 Jahren. Der zweitbeste ist jetzt.", "Chinesisches Sprichwort"),
    ("Deine Einstellung bestimmt deine Richtung.", "Unbekannt"),
    ("Jeder Experte war einmal ein Anfänger.", "Helen Hayes"),
    ("Das Geheimnis des Fortschritts ist, mit dem Anfangen anzufangen.", "Mark Twain"),
    ("Träume groß, fange klein an, handle jetzt.", "Robin Sharma"),
    ("Disziplin ist die Brücke zwischen Zielen und Leistung.", "Jim Rohn"),
    ("Nicht weil es schwer ist, wagen wir es nicht. Es ist schwer, weil wir es nicht wagen.", "Seneca"),
    ("Energie und Beharrlichkeit besiegen alles.", "Benjamin Franklin"),
    ("Wer aufhört, besser zu werden, hat aufgehört, gut zu sein.", "Philip Rosenthal"),
    ("Fang dort an, wo du bist. Nutze, was du hast. Tu, was du kannst.", "Arthur Ashe"),
    ("Die Motivation bringt dich zum Start. Die Gewohnheit hält dich im Laufen.", "Jim Ryun"),
    ("Wer ein klares Warum hat, erträgt fast jedes Wie.", "Friedrich Nietzsche"),
    ("Jeder Morgen ist ein neuer Anfang.", "Unbekannt"),
    ("Mach es mit Leidenschaft oder gar nicht.", "Unbekannt"),
    ("Kleine tägliche Verbesserungen führen zu großen Ergebnissen.", "Robin Sharma"),
    ("Tue jeden Tag etwas, das dich deinem Traum näher bringt.", "Unbekannt"),
    ("Wer kämpft, kann verlieren. Wer nicht kämpft, hat schon verloren.", "Bertolt Brecht"),
    ("Glaube an den Prozess. Vertraue auf die Arbeit.", "Unbekannt"),
    ("Aufgeben ist keine Option.", "Michael Schumacher"),
    ("Ruhm gehört denen, die niemals aufgeben.", "Winston Churchill"),
    ("Heute ist der Tag, an dem du anfängst.", "Unbekannt"),
    ("Sei die beste Version deiner selbst.", "Unbekannt"),
]

struct MotivationWatchView: View {
    let accent: Color
    @State private var quoteIndex: Int = 0

    private var quote: (text: String, author: String) {
        motivationQuotes[quoteIndex % motivationQuotes.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(accent)
                        .font(.system(size: 14))
                    Text("Motivation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Text(quote.text)
                    .font(.system(size: 13))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(quote.author)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation { quoteIndex += 1 }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                        Text("Nächstes")
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(accent)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(10)
        }
        .navigationTitle("Motivation")
        .onAppear {
            let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
            quoteIndex = day
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
