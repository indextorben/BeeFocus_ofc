import SwiftUI

struct FokusChallenge: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let period: ChallengePeriod
    let target: Int
    let unit: String

    var localizedTitle: String { NSLocalizedString("ch_\(id)_title", comment: "") }
    var localizedDescription: String { NSLocalizedString("ch_\(id)_desc", comment: "") }
    var localizedUnit: String { NSLocalizedString("ch_unit_\(unit)", comment: "") }

    enum ChallengePeriod { case daily, weekly }
}

struct FokusChallengesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var todoStore: TodoStore
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("claimedChallenges") private var claimedRaw: String = ""

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var claimed: Set<String> {
        Set(claimedRaw.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func claimKey(_ c: FokusChallenge) -> String {
        let cal = Calendar.current
        switch c.period {
        case .daily:
            let d = cal.startOfDay(for: Date())
            return "\(c.id)_\(Int(d.timeIntervalSince1970))"
        case .weekly:
            let week = cal.component(.weekOfYear, from: Date())
            let year = cal.component(.year, from: Date())
            return "\(c.id)_\(year)w\(week)"
        }
    }

    private func isClaimed(_ c: FokusChallenge) -> Bool {
        claimed.contains(claimKey(c))
    }

    private func claim(_ c: FokusChallenge) {
        var set = claimed
        set.insert(claimKey(c))
        claimedRaw = set.joined(separator: ",")
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }

    // MARK: - Progress calculation

    private var todayCompleted: Int {
        let cal = Calendar.current
        return todoStore.todos.filter { t in
            t.isCompleted && t.completedAt.map { cal.isDateInToday($0) } == true
        }.count
    }

    private var todayFocusMinutes: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.dailyFocusMinutes[today] ?? 0
    }

    private var weeklyCompletedTasks: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return todoStore.todos.filter { t in
            t.isCompleted && (t.completedAt ?? .distantPast) >= weekAgo
        }.count
    }

    private var weeklyFocusMinutes: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return todoStore.dailyFocusMinutes
            .filter { $0.key >= weekAgo }
            .values.reduce(0, +)
    }

    private var habitStreakDays: Int {
        HabitStore.shared.habits.map { $0.currentStreak }.max() ?? 0
    }

    private var journalEntriesToday: Int {
        JournalStore.shared.hasTodayEntry() ? 1 : 0
    }

    private func progress(for c: FokusChallenge) -> Int {
        switch c.id {
        case "daily_tasks":    return todayCompleted
        case "daily_focus":    return todayFocusMinutes
        case "daily_journal":  return journalEntriesToday
        case "weekly_tasks":   return weeklyCompletedTasks
        case "weekly_focus":   return weeklyFocusMinutes / 60
        case "weekly_habit":   return habitStreakDays
        default:               return 0
        }
    }

    private var challenges: [FokusChallenge] {
        [
            FokusChallenge(
                id: "daily_tasks", title: "Productive Day",
                description: "Complete 5 tasks today",
                icon: "checkmark.circle.fill", color: Color(red: 0.3, green: 0.82, blue: 0.5),
                period: .daily, target: 5, unit: "tasks"
            ),
            FokusChallenge(
                id: "daily_focus", title: "Focus Block",
                description: "Accumulate 30 minutes of focus time today",
                icon: "timer", color: Color(red: 0.3, green: 0.6, blue: 1.0),
                period: .daily, target: 30, unit: "minutes"
            ),
            FokusChallenge(
                id: "daily_journal", title: "Daily Review",
                description: "Write your journal entry for today",
                icon: "book.closed.fill", color: Color(red: 0.65, green: 0.35, blue: 1.0),
                period: .daily, target: 1, unit: "entry"
            ),
            FokusChallenge(
                id: "weekly_tasks", title: "Task Week",
                description: "Complete 25 tasks this week",
                icon: "list.bullet.clipboard.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2),
                period: .weekly, target: 25, unit: "tasks"
            ),
            FokusChallenge(
                id: "weekly_focus", title: "Deep Worker",
                description: "Accumulate 5 hours of focus time this week",
                icon: "brain.head.profile", color: Color(red: 0.55, green: 0.35, blue: 1.0),
                period: .weekly, target: 5, unit: "hours"
            ),
            FokusChallenge(
                id: "weekly_habit", title: "Habit Streak",
                description: "Keep a habit going for 7 consecutive days",
                icon: "flame.fill", color: Color(red: 1.0, green: 0.4, blue: 0.2),
                period: .weekly, target: 7, unit: "days"
            ),
        ]
    }
    // Note: title/description fields are kept as English identifiers for legacy compatibility.
    // Localized display uses localizedTitle / localizedDescription computed properties.

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    sectionHeader(String(localized: "ch_section_daily"))
                        .padding(.horizontal, 20)

                    ForEach(challenges.filter { $0.period == .daily }) { c in
                        ChallengeCard(
                            challenge: c,
                            current: progress(for: c),
                            claimed: isClaimed(c)
                        ) { claim(c) }
                        .padding(.horizontal, 20)
                    }

                    sectionHeader(String(localized: "ch_section_weekly"))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    ForEach(challenges.filter { $0.period == .weekly }) { c in
                        ChallengeCard(
                            challenge: c,
                            current: progress(for: c),
                            claimed: isClaimed(c)
                        ) { claim(c) }
                        .padding(.horizontal, 20)
                    }

                    Spacer().frame(height: 32)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        let done = challenges.filter { progress(for: $0) >= $0.target || isClaimed($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "ch_header_title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(format: String(localized: "ch_header_completed_fmt"), done, challenges.count))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text("🏆")
                    .font(.system(size: 36))
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
        }
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: FokusChallenge
    let current: Int
    let claimed: Bool
    let onClaim: () -> Void

    @State private var showConfetti = false

    private var progress: Double {
        min(Double(current) / Double(challenge.target), 1.0)
    }

    private var isCompleted: Bool { current >= challenge.target }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(challenge.color.opacity(claimed ? 0.4 : 0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: claimed ? "checkmark.seal.fill" : challenge.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(claimed ? .white : challenge.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(challenge.localizedTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(claimed ? .white.opacity(0.6) : .white)
                        periodBadge
                    }
                    Text(challenge.localizedDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Text("\(current)/\(challenge.target)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isCompleted ? challenge.color : .white.opacity(0.4))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [challenge.color, challenge.color.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 6)

            // Claim button
            if isCompleted && !claimed {
                Button(action: {
                    showConfetti = true
                    onClaim()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                        Text(String(localized: "ch_claim_btn"))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        LinearGradient(colors: [challenge.color, challenge.color.opacity(0.7)],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if claimed {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(challenge.color)
                    Text(String(localized: "ch_completed"))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("✨")
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(claimed
                      ? challenge.color.opacity(0.06)
                      : (isCompleted ? challenge.color.opacity(0.12) : Color.white.opacity(0.05)))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(claimed ? challenge.color.opacity(0.2)
                                        : (isCompleted ? challenge.color.opacity(0.4) : Color.white.opacity(0.08)),
                                lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isCompleted)
        .animation(.easeInOut(duration: 0.3), value: claimed)
    }

    private var periodBadge: some View {
        Text(String(localized: challenge.period == .daily ? "ch_period_daily" : "ch_period_weekly"))
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(.white.opacity(0.1), in: Capsule())
    }
}
