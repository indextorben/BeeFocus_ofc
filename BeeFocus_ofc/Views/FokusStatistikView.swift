import SwiftUI
import Charts

@available(iOS 16, *)
struct FokusStatistikView: View {
    @StateObject private var manager = FokusModeManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("dailyGoalEnabled") private var dailyGoalEnabled: Bool = false
    @AppStorage("fokusStreakEnabled") private var fokusStreakEnabled: Bool = false
    @AppStorage("wochenrueckblickEnabled") private var wochenrueckblickEnabled: Bool = false
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60
    @State private var liveSeconds: Int = 0
    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) var colorScheme

    var isDark: Bool { colorScheme == .dark }

    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private var todayTotal: Int { manager.todaySeconds + liveSeconds }
    private var weekTotal: Int { manager.weekSeconds + liveSeconds }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        // If today has no focus yet, start checking from yesterday
        let todayKey = manager.dateKey(for: checkDate)
        if (manager.dailyFocusSeconds[todayKey] ?? 0) == 0 && !manager.isFocusModeActive {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        for _ in 0..<365 {
            let key = manager.dateKey(for: checkDate)
            let secs = manager.dailyFocusSeconds[key] ?? 0
            let isToday = cal.isDateInToday(checkDate) && manager.isFocusModeActive
            if secs > 0 || isToday {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private var goalProgress: Double {
        let goal = manager.dailyGoalMinutes > 0 ? manager.dailyGoalMinutes : dailyGoal
        guard goal > 0 else { return 0 }
        return min(1.0, Double(todayTotal) / Double(goal * 60))
    }

    private var lastWeekSeconds: Int {
        let cal = Calendar.current
        return (7..<14).compactMap { offset -> Int? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return manager.dailyFocusSeconds[manager.dateKey(for: day)]
        }.reduce(0, +)
    }

    private var weekTrend: Double {
        guard lastWeekSeconds > 0 else { return weekTotal > 0 ? 1.0 : 0.0 }
        return Double(weekTotal - lastWeekSeconds) / Double(lastWeekSeconds)
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topCards
                    bonusCards
                    achievementsCard
                    if wochenrueckblickEnabled {
                        wochenrueckblickCard
                    }
                    chartCard
                    allTimeStat
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Focus Statistics")
        .navigationBarTitleDisplayMode(.large)
        .onReceive(ticker) { _ in
            guard manager.isFocusModeActive, let start = manager.currentSessionStart else {
                liveSeconds = 0
                return
            }
            liveSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    // MARK: - Top Cards

    private var topCards: some View {
        HStack(spacing: 14) {
            statCard(
                title: "Today",
                value: formatDuration(todayTotal),
                subtitle: manager.isFocusModeActive ? "Active" : "Total",
                icon: "sun.max.fill",
                color: themeC1,
                isLive: manager.isFocusModeActive
            )
            statCard(
                title: "This Week",
                value: formatDuration(weekTotal),
                subtitle: "7 Days",
                icon: "calendar",
                color: themeC2,
                isLive: false
            )
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color, isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                Spacer()
                if isLive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? .white : .primary)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(color.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeGlass(cornerRadius: 18)
    }

    // MARK: - Bonus Cards (Streak + Goal)

    private var bonusCards: some View {
        HStack(spacing: 14) {
            streakCard
            goalCard
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Streak")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(currentStreak)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(currentStreak > 0 ? Color.orange : (isDark ? .white.opacity(0.3) : Color.secondary))
                Text(currentStreak == 1 ? "Day" : "Days")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                    .padding(.bottom, 2)
            }
            Text(currentStreak == 0 ? "Start today!" : currentStreak < 3 ? "Keep it up!" : currentStreak < 7 ? "Great run!" : "Unstoppable!")
                .font(.caption)
                .foregroundStyle(Color.orange.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeGlass(cornerRadius: 18)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.mint)
                Text("Daily Goal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                Spacer()
                if goalProgress >= 1.0 {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.mint)
                }
            }
            ZStack {
                Circle()
                    .stroke(Color.mint.opacity(0.15), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: goalProgress)
                    .stroke(
                        LinearGradient(colors: [.mint, themeC1], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: goalProgress)
                Text("\(Int(goalProgress * 100))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : .primary)
            }
            .frame(width: 60, height: 60)
            .frame(maxWidth: .infinity)
            Text("\(manager.dailyGoalMinutes > 0 ? manager.dailyGoalMinutes : dailyGoal) min goal")
                .font(.caption)
                .foregroundStyle(Color.mint.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeGlass(cornerRadius: 18)
    }

    // MARK: - Achievements Card

    private var achievementsCard: some View {
        let total    = FokusAchievement.all.count
        let unlocked = manager.unlockedAchievementIDs.count
        let bonus    = manager.achievementBonusPunkte
        let progress = total > 0 ? CGFloat(unlocked) / CGFloat(total) : 0
        let recentUnlocked = FokusAchievement.all
            .filter { manager.unlockedAchievementIDs.contains($0.id) }
            .prefix(5)

        return NavigationLink(destination: FokusAchievementsView()) {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeC1)
                    Text("Badges")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.25) : Color.secondary.opacity(0.4))
                }

                HStack(spacing: 16) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(themeC1.opacity(0.15), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(colors: [themeC1, themeC2],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                        VStack(spacing: 1) {
                            Text("\(unlocked)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(isDark ? .white : .primary)
                            Text("/\(total)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                        }
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(unlocked == 0
                             ? "No badges yet"
                             : unlocked == total
                                ? "All badges unlocked! 🎉"
                                : "\(unlocked) of \(total) unlocked")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)

                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(themeC1)
                            Text(bonus > 0 ? "+\(bonus) FP Bonus" : "Earn badges = earn FP")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(bonus > 0 ? themeC1 : (isDark ? .white.opacity(0.4) : .secondary))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(themeC1.opacity(0.1), in: Capsule())

                        // Recent achievement icons
                        if !recentUnlocked.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(recentUnlocked)) { a in
                                    ZStack {
                                        Circle()
                                            .fill(a.farbe.opacity(0.18))
                                            .frame(width: 26, height: 26)
                                        Image(systemName: a.icon)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(a.farbe)
                                    }
                                }
                                if unlocked > 5 {
                                    Text("+\(unlocked - 5)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeGlass(cornerRadius: 18)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wochenrückblick

    private var wochenrueckblickCard: some View {
        let trendPositiv = weekTrend >= 0
        let trendColor: Color = trendPositiv ? .green : .red
        let trendIcon = trendPositiv ? "arrow.up.right" : "arrow.down.right"
        let trendText = lastWeekSeconds == 0
            ? "First Week"
            : String(format: "%+.0f%%", weekTrend * 100)
        let blueAccent = Color(red: 0.4, green: 0.6, blue: 1.0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(blueAccent)
                Text("Weekly Review")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(trendText)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(lastWeekSeconds == 0 ? blueAccent : trendColor)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((lastWeekSeconds == 0 ? blueAccent : trendColor).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 0) {
                weekBar(label: "Last Week", seconds: lastWeekSeconds, color: blueAccent.opacity(0.5))
                Spacer().frame(width: 12)
                weekBar(label: "This Week", seconds: weekTotal, color: blueAccent)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Week")
                        .font(.caption2)
                        .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                    Text(formatDuration(lastWeekSeconds))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDark ? .white.opacity(0.6) : Color.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("This Week")
                        .font(.caption2)
                        .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                    Text(formatDuration(weekTotal))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isDark ? .white : .primary)
                }
            }
        }
        .padding(18)
        .themeGlass(cornerRadius: 18)
    }

    private func weekBar(label: String, seconds: Int, color: Color) -> some View {
        let maxSec = max(weekTotal, lastWeekSeconds, 1)
        let ratio = CGFloat(seconds) / CGFloat(maxSec)
        return GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * ratio), height: 12)
                    .animation(.easeOut(duration: 0.6), value: seconds)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 12)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Last 7 Days")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Spacer()
                Text("in minutes")
                    .font(.caption)
                    .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
            }

            Chart {
                ForEach(manager.last7Days, id: \.date) { entry in
                    let minutes = entry.seconds / 60
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    BarMark(
                        x: .value("Tag", entry.date, unit: .day),
                        y: .value("Minuten", isToday ? (todayTotal / 60) : minutes)
                    )
                    .foregroundStyle(
                        isToday
                            ? LinearGradient(colors: [themeC1, themeC2], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [themeC1.opacity(0.35), themeC1.opacity(0.55)], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color.secondary)
                    AxisGridLine()
                        .foregroundStyle(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.06))
                }
            }
            .frame(height: 180)
        }
        .padding(18)
        .themeGlass(cornerRadius: 18)
    }

    // MARK: - All Time

    private var allTimeStat: some View {
        let total = manager.dailyFocusSeconds.values.reduce(0, +) + liveSeconds
        let sessions = manager.dailyFocusSeconds.values.filter { $0 > 0 }.count
        let maxDay = manager.last7Days.max(by: { $0.seconds < $1.seconds })

        return VStack(spacing: 0) {
            statRow(label: "Total (all time)", value: formatDuration(total), icon: "infinity", color: themeC1)
            Divider().opacity(0.2).padding(.horizontal, 16)
            statRow(label: "Active Days", value: "\(sessions)", icon: "calendar.badge.checkmark", color: themeC2)
            Divider().opacity(0.2).padding(.horizontal, 16)
            statRow(
                label: "Best Day (7D)",
                value: maxDay.map { formatDuration($0.seconds) } ?? "—",
                icon: "trophy.fill",
                color: themeC1
            )
        }
        .themeGlass(cornerRadius: 18)
    }

    private func statRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDark ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 min" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m) min"
    }
}

#Preview {
    if #available(iOS 16, *) {
        NavigationStack {
            FokusStatistikView()
        }
    }
}
