import WidgetKit
import SwiftUI

// MARK: - Shared Models (widget-side copy — must match TodoStore+Widget.swift)

struct WidgetSnapshot: Codable {
    let dueTodayCount: Int
    let overdueCount: Int
    let completedTodayCount: Int
    let totalOpenCount: Int
    let focusMinutesToday: Int
    let topTasks: [WidgetTask]
    let activeTheme: String
    let monthTasks: [WidgetTask]
    let activeMonthLabel: String

    init(dueTodayCount: Int, overdueCount: Int, completedTodayCount: Int,
         totalOpenCount: Int, focusMinutesToday: Int, topTasks: [WidgetTask],
         activeTheme: String, monthTasks: [WidgetTask] = [], activeMonthLabel: String = "") {
        self.dueTodayCount = dueTodayCount
        self.overdueCount = overdueCount
        self.completedTodayCount = completedTodayCount
        self.totalOpenCount = totalOpenCount
        self.focusMinutesToday = focusMinutesToday
        self.topTasks = topTasks
        self.activeTheme = activeTheme
        self.monthTasks = monthTasks
        self.activeMonthLabel = activeMonthLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dueTodayCount       = try c.decode(Int.self, forKey: .dueTodayCount)
        overdueCount        = try c.decode(Int.self, forKey: .overdueCount)
        completedTodayCount = try c.decode(Int.self, forKey: .completedTodayCount)
        totalOpenCount      = try c.decode(Int.self, forKey: .totalOpenCount)
        focusMinutesToday   = try c.decode(Int.self, forKey: .focusMinutesToday)
        topTasks            = try c.decode([WidgetTask].self, forKey: .topTasks)
        activeTheme         = try c.decode(String.self, forKey: .activeTheme)
        monthTasks          = (try? c.decode([WidgetTask].self, forKey: .monthTasks)) ?? []
        activeMonthLabel    = (try? c.decode(String.self, forKey: .activeMonthLabel)) ?? ""
    }

    // Ignore new Watch-only fields (todayBausteine) gracefully via custom decoder above

    static let placeholder = WidgetSnapshot(
        dueTodayCount: 3, overdueCount: 1, completedTodayCount: 2,
        totalOpenCount: 8, focusMinutesToday: 45,
        topTasks: [
            WidgetTask(id: UUID(), title: "Meeting vorbereiten", isHighPriority: true),
            WidgetTask(id: UUID(), title: "Arzt anrufen", isHighPriority: false),
            WidgetTask(id: UUID(), title: "Einkaufen", isHighPriority: false)
        ],
        activeTheme: ""
    )
}

struct WidgetTask: Codable, Identifiable {
    let id: UUID
    let title: String
    let isHighPriority: Bool
    // Extra fields — decoded optionally for forward compatibility
    var dueDate: Date?          = nil
    var endDate: Date?          = nil
    var priorityRaw: String     = "medium"
    var categoryName: String?   = nil
    var categoryColorHex: String? = nil
    var taskDescription: String = ""
    var subTasksTotal: Int      = 0
    var subTasksCompleted: Int  = 0
    var isFavorite: Bool        = false
    var isOverdue: Bool         = false

    init(id: UUID, title: String, isHighPriority: Bool) {
        self.id = id; self.title = title; self.isHighPriority = isHighPriority
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        title            = try c.decode(String.self, forKey: .title)
        isHighPriority   = try c.decode(Bool.self, forKey: .isHighPriority)
        dueDate          = try? c.decode(Date.self, forKey: .dueDate)
        endDate          = try? c.decode(Date.self, forKey: .endDate)
        priorityRaw      = (try? c.decode(String.self, forKey: .priorityRaw)) ?? "medium"
        categoryName     = try? c.decode(String.self, forKey: .categoryName)
        categoryColorHex = try? c.decode(String.self, forKey: .categoryColorHex)
        taskDescription  = (try? c.decode(String.self, forKey: .taskDescription)) ?? ""
        subTasksTotal    = (try? c.decode(Int.self, forKey: .subTasksTotal)) ?? 0
        subTasksCompleted = (try? c.decode(Int.self, forKey: .subTasksCompleted)) ?? 0
        isFavorite       = (try? c.decode(Bool.self, forKey: .isFavorite)) ?? false
        isOverdue        = (try? c.decode(Bool.self, forKey: .isOverdue)) ?? false
    }
}

// MARK: - Provider

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        completion(TodoWidgetEntry(date: Date(), snapshot: loadSnapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = TodoWidgetEntry(date: Date(), snapshot: loadSnapshot())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadSnapshot() -> WidgetSnapshot {
        let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")
        guard let data = defaults?.data(forKey: "widgetSnapshot"),
              let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snap
    }
}

// MARK: - Theme Colors

func themeColors(_ theme: String) -> [Color] {
    switch theme {
    case "Ozean":           return [Color(red: 0.0,  green: 0.55, blue: 0.80), Color(red: 0.0,  green: 0.40, blue: 0.65)]
    case "Wald":            return [Color(red: 0.15, green: 0.62, blue: 0.25), Color(red: 0.05, green: 0.42, blue: 0.15)]
    case "Nacht":           return [Color(red: 0.18, green: 0.10, blue: 0.45), Color(red: 0.08, green: 0.04, blue: 0.28)]
    case "Solar":           return [Color(red: 0.95, green: 0.55, blue: 0.0),  Color(red: 0.85, green: 0.35, blue: 0.0) ]
    case "Kirschblüte":     return [Color(red: 0.95, green: 0.38, blue: 0.60), Color(red: 0.80, green: 0.20, blue: 0.45)]
    case "Vulkan":          return [Color(red: 0.85, green: 0.18, blue: 0.05), Color(red: 0.65, green: 0.08, blue: 0.0) ]
    case "Eis":             return [Color(red: 0.35, green: 0.72, blue: 0.92), Color(red: 0.18, green: 0.55, blue: 0.80)]
    case "Herbst":          return [Color(red: 0.80, green: 0.40, blue: 0.08), Color(red: 0.60, green: 0.25, blue: 0.02)]
    case "Lavendel":        return [Color(red: 0.58, green: 0.28, blue: 0.88), Color(red: 0.42, green: 0.15, blue: 0.72)]
    case "Sonnenuntergang": return [Color(red: 0.95, green: 0.38, blue: 0.15), Color(red: 0.80, green: 0.22, blue: 0.45)]
    case "Galaxie":         return [Color(red: 0.55, green: 0.25, blue: 0.92), Color(red: 0.30, green: 0.08, blue: 0.70)]
    case "Nordlicht":       return [Color(red: 0.05, green: 0.62, blue: 0.42), Color(red: 0.02, green: 0.42, blue: 0.58)]
    default:                return [Color(red: 0.42, green: 0.18, blue: 0.82), Color(red: 0.25, green: 0.08, blue: 0.65)]
    }
}

// MARK: - Entry View Dispatcher

struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodoWidgetEntry

    @ViewBuilder
    var body: some View {
        if family == .systemSmall {
            SmallWidgetView(snap: entry.snapshot)
        } else if family == .systemMedium {
            MediumWidgetView(snap: entry.snapshot)
        } else if family == .systemLarge {
            LargeWidgetView(snap: entry.snapshot)
        } else if family == .accessoryCircular {
            AccessoryCircularView(snap: entry.snapshot)
        } else if family == .accessoryRectangular {
            AccessoryRectangularView(snap: entry.snapshot)
        } else if family == .accessoryInline {
            AccessoryInlineView(snap: entry.snapshot)
        } else {
            SmallWidgetView(snap: entry.snapshot)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let snap: WidgetSnapshot
    private var totalToday: Int { snap.dueTodayCount + snap.completedTodayCount }
    private var progress: CGFloat {
        totalToday > 0 ? CGFloat(snap.completedTodayCount) / CGFloat(totalToday) : 0
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("BeeFocus")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snap.dueTodayCount)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("offen")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Text("heute fällig")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            HStack(spacing: 12) {
                Label("\(snap.completedTodayCount)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                if snap.overdueCount > 0 {
                    Label("\(snap.overdueCount)", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.3))
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "beefocus://today"))
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let snap: WidgetSnapshot

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("BeeFocus")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.85))

                Spacer()

                statBlock(value: snap.dueTodayCount, label: "Heute", icon: "sun.max.fill")
                if widgetShowOverdue {
                    statBlock(value: snap.overdueCount, label: "Überf.", icon: "exclamationmark.circle.fill",
                              accent: snap.overdueCount > 0 ? Color(red: 1.0, green: 0.55, blue: 0.3) : .white)
                }
                statBlock(value: snap.completedTodayCount, label: "Erledigt", icon: "checkmark.circle.fill")
            }
            .frame(width: 110)
            .padding(.leading, 14)
            .padding(.vertical, 14)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 6) {
                if snap.topTasks.isEmpty {
                    Spacer()
                    Text("Keine Aufgaben\nfür heute 🎉")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ForEach(snap.topTasks.prefix(3)) { task in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(task.isHighPriority
                                      ? Color(red: 1.0, green: 0.55, blue: 0.3)
                                      : Color.white.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(task.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    if snap.dueTodayCount > 3 {
                        Text("+ \(snap.dueTodayCount - 3) weitere")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(URL(string: "beefocus://today"))
    }

    private func statBlock(value: Int, label: String, icon: String, accent: Color = .white) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(accent.opacity(0.85))
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Large Widget

private let widgetGroupDefaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")

private var widgetShowFocusMinutes: Bool {
    widgetGroupDefaults?.object(forKey: "widgetShowFocusMinutes") as? Bool ?? true
}
private var widgetShowOverdue: Bool {
    widgetGroupDefaults?.object(forKey: "widgetShowOverdue") as? Bool ?? true
}

struct LargeWidgetView: View {
    let snap: WidgetSnapshot
    private var totalToday: Int { snap.dueTodayCount + snap.completedTodayCount }
    private var progress: CGFloat {
        totalToday > 0 ? CGFloat(snap.completedTodayCount) / CGFloat(totalToday) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("BeeFocus")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                Spacer()
                Text(todayString())
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Heutiger Fortschritt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text("\(snap.completedTodayCount)/\(totalToday)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 16)

            if snap.topTasks.isEmpty {
                Spacer()
                Text("Keine Aufgaben für heute 🎉")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(snap.topTasks.prefix(4)) { task in
                        HStack(spacing: 10) {
                            Circle()
                                .stroke(task.isHighPriority
                                        ? Color(red: 1.0, green: 0.55, blue: 0.3)
                                        : Color.white.opacity(0.6), lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            Text(task.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            if task.isHighPriority {
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.3))
                            }
                        }
                    }
                    if snap.dueTodayCount > 4 {
                        Text("+ \(snap.dueTodayCount - 4) weitere Aufgaben")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Spacer()

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
                .padding(.horizontal, 16)

            HStack(spacing: 16) {
                if widgetShowOverdue {
                    Label("\(snap.overdueCount) überf.", systemImage: "exclamationmark.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(snap.overdueCount > 0
                                         ? Color(red: 1.0, green: 0.65, blue: 0.35)
                                         : Color.white.opacity(0.55))
                }
                Spacer()
                if widgetShowFocusMinutes {
                    Label("\(snap.focusMinutesToday) Min Fokus", systemImage: "timer")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .widgetURL(URL(string: "beefocus://today"))
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEE, d. MMM"
        return f.string(from: Date())
    }
}

// MARK: - Lock Screen: Circular

struct AccessoryCircularView: View {
    let snap: WidgetSnapshot
    private var totalToday: Int { snap.dueTodayCount + snap.completedTodayCount }
    private var progress: CGFloat {
        totalToday > 0 ? CGFloat(snap.completedTodayCount) / CGFloat(totalToday) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(snap.dueTodayCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("heute")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "beefocus://today"))
    }
}

// MARK: - Lock Screen: Rectangular

struct AccessoryRectangularView: View {
    let snap: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("\(snap.dueTodayCount) Aufgaben heute", systemImage: "checklist")
                .font(.system(size: 13, weight: .semibold))
            if snap.overdueCount > 0 {
                Label("\(snap.overdueCount) überfällig", systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Label("\(snap.completedTodayCount) erledigt", systemImage: "checkmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "beefocus://today"))
    }
}

// MARK: - Lock Screen: Inline

struct AccessoryInlineView: View {
    let snap: WidgetSnapshot

    var body: some View {
        Label(
            snap.overdueCount > 0
                ? "\(snap.dueTodayCount) heute · \(snap.overdueCount) überf."
                : "\(snap.dueTodayCount) Aufgaben heute",
            systemImage: "checklist"
        )
        .widgetURL(URL(string: "beefocus://today"))
    }
}

// MARK: - Widget Configurations

struct TodoWidget: Widget {
    let kind = "BeeFocusTodoWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: themeColors(entry.snapshot.activeTheme),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Aufgaben")
        .description("Deine heutigen Aufgaben auf einem Blick.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct BeeFocusLockScreenWidget: Widget {
    let kind = "BeeFocusLockScreenWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("BeeFocus Sperrbildschirm")
        .description("Kompakter Überblick auf dem Sperrbildschirm.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
