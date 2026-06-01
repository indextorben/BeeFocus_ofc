import SwiftUI

struct DayScore {
    let date: Date
    let tasks: Int     // 0–30
    let focus: Int     // 0–30
    let habits: Int    // 0–20
    let journal: Int   // 0–10
    var total: Int { tasks + focus + habits + journal }
}

struct ProduktivitaetsScoreView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var today: DayScore { score(for: Date()) }

    private func score(for date: Date) -> DayScore {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)

        // Tasks completed on this day
        let tasksDone = todoStore.todos.filter { t in
            t.isCompleted && t.completedAt.map { cal.isDate($0, inSameDayAs: date) } == true
        }.count
        let taskPts = min(Int(Double(tasksDone) / 5.0 * 30), 30)

        // Focus minutes
        let focusMins = todoStore.dailyFocusMinutes[day] ?? 0
        let focusPts = min(Int(Double(focusMins) / 60.0 * 30), 30)

        // Habits
        let habits = HabitStore.shared.habits
        let habitDone = habits.filter { $0.isCompleted(on: date) }.count
        let habitPts = habits.isEmpty ? 0 : min(Int(Double(habitDone) / Double(habits.count) * 20), 20)

        // Journal
        let journalPts = JournalStore.shared.entries.contains {
            cal.isDate($0.date, inSameDayAs: date)
        } ? 10 : 0

        return DayScore(date: date, tasks: taskPts, focus: focusPts, habits: habitPts, journal: journalPts)
    }

    private var last7: [DayScore] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> DayScore? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return score(for: d)
        }
    }

    private func scoreColor(_ s: Int) -> Color {
        switch s {
        case 80...: return Color(red: 0.2, green: 0.85, blue: 0.5)
        case 50...: return Color(red: 0.3, green: 0.65, blue: 1.0)
        case 25...: return Color(red: 1.0, green: 0.65, blue: 0.2)
        default:    return Color(red: 0.7, green: 0.3, blue: 0.3)
        }
    }

    private func scoreLabel(_ s: Int) -> String {
        switch s {
        case 80...: return "Ausgezeichnet 🌟"
        case 60...: return "Stark 💪"
        case 40...: return "Solide 👍"
        case 20...: return "Anlauf nehmen ⚡"
        default:    return "Frischer Start 🌱"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                         Color(red: 0.1,  green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Big score ring
                    scoreRing
                        .padding(.top, 32)

                    // Breakdown
                    breakdownCard
                        .padding(.horizontal, 20)

                    // Weekly chart
                    weeklyChart
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }

            // Close
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
                    .padding(.top, 16).padding(.trailing, 20)
                }
                Spacer()
            }
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        let s = today.total
        let pct = Double(s) / 100.0
        let col = scoreColor(s)

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 160, height: 160)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        LinearGradient(colors: [col, col.opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: s)

                VStack(spacing: 4) {
                    Text("\(s)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ 100")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            VStack(spacing: 4) {
                Text("Produktivitäts-Score")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text(scoreLabel(s))
                    .font(.system(size: 15))
                    .foregroundStyle(col)
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Breakdown

    private var breakdownCard: some View {
        VStack(spacing: 0) {
            breakRow(icon: "checkmark.circle.fill", label: "Aufgaben erledigt",
                     value: today.tasks, max: 30, color: Color(red: 0.3, green: 0.82, blue: 0.5))
            Divider().background(.white.opacity(0.06)).padding(.horizontal, 16)
            breakRow(icon: "timer", label: "Fokuszeit",
                     value: today.focus, max: 30, color: Color(red: 0.3, green: 0.6, blue: 1.0))
            Divider().background(.white.opacity(0.06)).padding(.horizontal, 16)
            breakRow(icon: "calendar.badge.checkmark", label: "Gewohnheiten",
                     value: today.habits, max: 20, color: Color(red: 0.65, green: 0.35, blue: 1.0))
            Divider().background(.white.opacity(0.06)).padding(.horizontal, 16)
            breakRow(icon: "book.closed.fill", label: "Fokus-Journal",
                     value: today.journal, max: 10, color: Color(red: 1.0, green: 0.6, blue: 0.2))
        }
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func breakRow(icon: String, label: String, value: Int, max: Int, color: Color) -> some View {
        let pct = Double(value) / Double(max)
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(color)
                        .frame(width: geo.size.width * pct, height: 5)
                        .animation(.spring(response: 0.5), value: pct)
                }
            }
            .frame(width: 80, height: 5)
            Text("\(value)/\(max)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(value == max ? color : .white.opacity(0.4))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let scores = last7
        let maxScore = max(scores.map(\.total).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(scores, id: \.date) { day in
                    let h = max(Double(day.total) / Double(maxScore), 0.05)
                    let col = scoreColor(day.total)
                    let isToday = Calendar.current.isDateInToday(day.date)

                    VStack(spacing: 6) {
                        Text("\(day.total)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(col.opacity(0.9))

                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(colors: [col, col.opacity(0.4)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: CGFloat(h) * 80)
                            .overlay(
                                isToday ? RoundedRectangle(cornerRadius: 5)
                                    .stroke(.white.opacity(0.3), lineWidth: 1.5) : nil
                            )

                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 9))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(scores.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day.date) }) ?? 0) * 0.05), value: day.total)
                }
            }
            .frame(height: 110)
        }
        .padding(18)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
