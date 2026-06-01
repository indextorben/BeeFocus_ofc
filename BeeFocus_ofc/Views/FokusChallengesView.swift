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
                id: "daily_tasks", title: "Produktiver Tag",
                description: "Erledige heute 5 Aufgaben",
                icon: "checkmark.circle.fill", color: Color(red: 0.3, green: 0.82, blue: 0.5),
                period: .daily, target: 5, unit: "Aufgaben"
            ),
            FokusChallenge(
                id: "daily_focus", title: "Fokus-Block",
                description: "Sammle 30 Minuten Fokuszeit heute",
                icon: "timer", color: Color(red: 0.3, green: 0.6, blue: 1.0),
                period: .daily, target: 30, unit: "Minuten"
            ),
            FokusChallenge(
                id: "daily_journal", title: "Tagesrückblick",
                description: "Schreibe deinen heutigen Journal-Eintrag",
                icon: "book.closed.fill", color: Color(red: 0.65, green: 0.35, blue: 1.0),
                period: .daily, target: 1, unit: "Eintrag"
            ),
            FokusChallenge(
                id: "weekly_tasks", title: "Aufgaben-Woche",
                description: "Erledige diese Woche 25 Aufgaben",
                icon: "list.bullet.clipboard.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2),
                period: .weekly, target: 25, unit: "Aufgaben"
            ),
            FokusChallenge(
                id: "weekly_focus", title: "Deep Worker",
                description: "Akkumuliere diese Woche 5 Stunden Fokuszeit",
                icon: "brain.head.profile", color: Color(red: 0.55, green: 0.35, blue: 1.0),
                period: .weekly, target: 5, unit: "Stunden"
            ),
            FokusChallenge(
                id: "weekly_habit", title: "Gewohnheits-Streak",
                description: "Halte eine Gewohnheit 7 Tage am Stück",
                icon: "flame.fill", color: Color(red: 1.0, green: 0.4, blue: 0.2),
                period: .weekly, target: 7, unit: "Tage"
            ),
        ]
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerSection
                        .padding(.top, 24)
                        .padding(.horizontal, 20)

                    sectionHeader("Tägliche Challenges")
                        .padding(.horizontal, 20)

                    ForEach(challenges.filter { $0.period == .daily }) { c in
                        ChallengeCard(
                            challenge: c,
                            current: progress(for: c),
                            claimed: isClaimed(c)
                        ) { claim(c) }
                        .padding(.horizontal, 20)
                    }

                    sectionHeader("Wöchentliche Challenges")
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
                    Text("Fokus-Challenges")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(done) von \(challenges.count) abgeschlossen")
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
                        Text(challenge.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(claimed ? .white.opacity(0.6) : .white)
                        periodBadge
                    }
                    Text(challenge.description)
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
                        Text("Challenge abschließen!")
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
                    Text("Abgeschlossen")
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
        Text(challenge.period == .daily ? "Täglich" : "Woche")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(.white.opacity(0.1), in: Capsule())
    }
}
