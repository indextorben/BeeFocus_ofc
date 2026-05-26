import SwiftUI

// MARK: - Theme helper (mirrors appThemaFarben from main app)
private func watchThemeColors(_ name: String) -> (Color, Color, Color) {
    switch name {
    case "Ozean":            return (.cyan, .teal, Color(red: 0.0, green: 0.6, blue: 0.9))
    case "Wald":             return (.green, Color(red: 0.1, green: 0.5, blue: 0.2), .mint)
    case "Nacht":            return (.indigo, Color(red: 0.1, green: 0.0, blue: 0.3), .purple)
    case "Solar":            return (.orange, .yellow, Color(red: 1.0, green: 0.4, blue: 0.0))
    case "Kirschblüte":      return (.pink, Color(red: 1.0, green: 0.4, blue: 0.6), .red)
    case "Vulkan":           return (.red, Color(red: 0.8, green: 0.1, blue: 0.0), .orange)
    case "Eis":              return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan, .white)
    case "Herbst":           return (Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.3, blue: 0.05), .orange)
    case "Lavendel":         return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.85, green: 0.7, blue: 1.0))
    case "Sonnenuntergang":  return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink, Color(red: 1.0, green: 0.65, blue: 0.0))
    case "Galaxie":          return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95), Color(red: 0.80, green: 0.58, blue: 1.0))
    case "Nordlicht":        return (.green, Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 1.0))
    default:                 return (.purple, .blue, Color(red: 0.4, green: 0.2, blue: 0.9))
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared
    @State private var completedIDs: Set<UUID> = []

    private var c1: Color { watchThemeColors(session.snapshot.activeTheme).0 }
    private var c2: Color { watchThemeColors(session.snapshot.activeTheme).1 }

    var body: some View {
        ZStack {
            themeBackground
            ScrollView {
                VStack(spacing: 8) {
                    summaryCard
                    tasksCard
                    if session.snapshot.focusMinutesToday > 0 {
                        focusCard
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("BeeFocus")
        .onAppear { session.loadSnapshot() }
    }

    // MARK: - Background

    private var themeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                    Color(red: 0.10, green: 0.08, blue: 0.20),
                    Color(red: 0.08, green: 0.06, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [c1.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 80
            )
            RadialGradient(
                colors: [c2.opacity(0.18), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 70
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.snapshot.dueTodayCount)")
                    .font(.title2.bold())
                    .foregroundStyle(c1)
                Text("heute fällig")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Divider()
                .frame(height: 28)
                .opacity(0.3)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if session.snapshot.overdueCount > 0 {
                    Text("\(session.snapshot.overdueCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text("überfällig")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(session.snapshot.completedTodayCount)")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("erledigt")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(c1.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Tasks card

    private var tasksCard: some View {
        let tasks = session.snapshot.monthTasks
        let label = session.snapshot.activeMonthLabel
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(c1)
                Text(label.isEmpty ? "AUFGABEN" : label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(c1)
                    .tracking(0.5)
                    .lineLimit(1)
                Spacer()
                Text("\(tasks.count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(c1.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(c1.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 7)

            Divider()
                .background(c1.opacity(0.2))
                .padding(.horizontal, 8)

            if tasks.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                    Text("Keine Aufgaben")
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(tasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(c1.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func taskRow(_ task: WatchTask) -> some View {
        let done = completedIDs.contains(task.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                _ = completedIDs.insert(task.id)
            }
            session.completeTask(id: task.id)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(done ? Color.green.opacity(0.2) : (task.isHighPriority ? Color.orange.opacity(0.15) : c1.opacity(0.1)))
                        .frame(width: 22, height: 22)
                    Image(systemName: done ? "checkmark.circle.fill" : (task.isHighPriority ? "exclamationmark.circle.fill" : "circle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(done ? .green : (task.isHighPriority ? .orange : c1))
                }
                Text(task.title)
                    .font(.system(size: 13))
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(done)
    }

    // MARK: - Focus card

    private var focusCard: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(c1.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(c1)
            }
            Text(focusLabel)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(c1.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var focusLabel: String {
        let m = session.snapshot.focusMinutesToday
        if m >= 60 {
            let h = m / 60; let rem = m % 60
            return rem > 0 ? "\(h)h \(rem)min Fokus heute" : "\(h)h Fokus heute"
        }
        return "\(m)min Fokus heute"
    }
}

#Preview {
    ContentView()
}
