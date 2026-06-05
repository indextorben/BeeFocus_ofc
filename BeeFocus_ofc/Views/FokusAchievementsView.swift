import SwiftUI

@available(iOS 16, *)
struct FokusAchievementsView: View {
    @StateObject private var manager = FokusModeManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema = ""
    @AppStorage("darkModeEnabled")       private var darkModeEnabled = false
    @Environment(\.colorScheme) var colorScheme

    var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    @State private var selectedKategorie: FokusAchievement.Kategorie? = nil
    @State private var newlyUnlockedID: String? = nil

    private var visibleAchievements: [FokusAchievement] {
        if let k = selectedKategorie {
            return FokusAchievement.all.filter { $0.kategorie == k }
        }
        return FokusAchievement.all
    }

    private var unlockedCount: Int { manager.unlockedAchievementIDs.count }
    private var totalCount:    Int { FokusAchievement.all.count }
    private var bonusEarned:   Int { manager.achievementBonusPunkte }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    summaryCard
                    filterRow
                    achievementGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 52)
            }
        }
        .navigationTitle(String(localized: "ach_nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
        .overlay(alignment: .top) {
            if let id = newlyUnlockedID,
               let a = FokusAchievement.all.first(where: { $0.id == id }) {
                newUnlockBanner(a)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(themeC1.opacity(0.15), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: totalCount > 0 ? CGFloat(unlockedCount) / CGFloat(totalCount) : 0)
                        .stroke(
                            LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: unlockedCount)
                    VStack(spacing: 1) {
                        Text("\(unlockedCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(isDark ? .white : .primary)
                        Text("/ \(totalCount)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
                    }
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "ach_unlocked_summary"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(themeC1)
                        Text(String(format: String(localized: "ach_bonus_earned_fmt"), bonusEarned))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(themeC1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeC1.opacity(0.12), in: Capsule())

                    let remaining = totalCount - unlockedCount
                    Text(remaining == 0 ? String(localized: "ach_all_unlocked") : String(format: String(localized: "ach_remaining_fmt"), remaining))
                        .font(.caption)
                        .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
                }
                Spacer()
            }
        }
        .padding(18)
        .themeGlass(cornerRadius: 20)
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: String(localized: "ach_filter_all"), icon: "square.grid.2x2.fill", kategorie: nil)
                ForEach(FokusAchievement.Kategorie.allCases, id: \.rawValue) { k in
                    filterChip(label: k.rawValue, icon: k.systemIcon, kategorie: k)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func filterChip(label: String, icon: String, kategorie: FokusAchievement.Kategorie?) -> some View {
        let isSelected = selectedKategorie == kategorie
        let color: Color = kategorie?.color ?? themeC1
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedKategorie = kategorie
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : (isDark ? .white.opacity(0.7) : Color.secondary))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    : AnyShapeStyle((isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))),
                in: Capsule()
            )
            .overlay(Capsule().stroke(isSelected ? Color.clear : color.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Achievement Grid

    private var achievementGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(visibleAchievements) { achievement in
                achievementCard(achievement)
            }
        }
    }

    private func achievementCard(_ a: FokusAchievement) -> some View {
        let unlocked = manager.unlockedAchievementIDs.contains(a.id)
        // Build a placeholder context for progress display
        // placeholder — LiveProgressBar reads live values from manager
        _ = AchievementContext(
            totalSekunden: 0, maxTagesSekunden: 0,
            currentStreak: 0, longestStreak: 0,
            completedTasks: 0, freigeschalteteCount: 0,
            weekendFokus: false, goalReachedCount: 0,
            totalFokustage: 0
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(unlocked ? a.farbe.opacity(0.22) : (isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)))
                        .frame(width: 48, height: 48)
                    Image(systemName: a.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(unlocked ? a.farbe : (isDark ? .white.opacity(0.22) : Color.secondary.opacity(0.35)))
                }
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(a.farbe)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isDark ? .white.opacity(0.2) : Color.secondary.opacity(0.3))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(a.localizedName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(unlocked ? (isDark ? .white : .primary) : (isDark ? .white.opacity(0.55) : Color.secondary))
                    .lineLimit(1)
                Text(a.localizedBeschreibung)
                    .font(.system(size: 11))
                    .foregroundStyle(isDark ? .white.opacity(0.4) : Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !unlocked {
                LiveProgressBar(achievement: a, manager: manager, color: a.farbe)
            }

            HStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(unlocked ? a.farbe : (isDark ? .white.opacity(0.3) : Color.secondary.opacity(0.4)))
                Text("+\(a.bonusPunkte) FP")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(unlocked ? a.farbe : (isDark ? .white.opacity(0.3) : Color.secondary.opacity(0.4)))
                if unlocked {
                    Spacer()
                    Text(String(localized: "ach_earned"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(a.farbe.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            if unlocked {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(a.farbe.opacity(isDark ? 0.10 : 0.06))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    unlocked ? a.farbe.opacity(0.4) : (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)),
                    lineWidth: unlocked ? 1.5 : 1
                )
        )
        .shadow(color: unlocked ? a.farbe.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
    }

    // MARK: - New Unlock Banner

    private func newUnlockBanner(_ a: FokusAchievement) -> some View {
        HStack(spacing: 12) {
            Image(systemName: a.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(a.farbe)
                .frame(width: 36, height: 36)
                .background(a.farbe.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "ach_banner_title"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(a.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Text("+\(a.bonusPunkte) FP")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.18), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(colors: [a.farbe, a.farbe.opacity(0.7)],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: a.farbe.opacity(0.5), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}

// MARK: - Live Progress Bar (reads real manager state)

@available(iOS 16, *)
private struct LiveProgressBar: View {
    let achievement: FokusAchievement
    @ObservedObject var manager: FokusModeManager
    let color: Color

    private var context: AchievementContext {
        AchievementContext(
            totalSekunden: manager.dailyFocusSeconds.values.reduce(0, +),
            maxTagesSekunden: manager.maxTagesSekunden,
            currentStreak: manager.currentStreak,
            longestStreak: manager.longestStreak,
            completedTasks: 0,
            freigeschalteteCount: 0,
            weekendFokus: manager.weekendFokus,
            goalReachedCount: 0,
            totalFokustage: manager.totalFokustage
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.12))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(colors: [color, color.opacity(0.6)],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(achievement.progress(context))), height: 5)
                        .animation(.easeOut(duration: 0.5), value: achievement.progress(context))
                }
            }
            .frame(height: 5)
            Text(achievement.progressLabel(context))
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.75))
        }
    }
}

#Preview {
    if #available(iOS 16, *) {
        NavigationStack {
            FokusAchievementsView()
        }
    }
}
