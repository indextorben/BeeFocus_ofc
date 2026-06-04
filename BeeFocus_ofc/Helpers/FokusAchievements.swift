import SwiftUI

// MARK: - Context

struct AchievementContext {
    let totalSekunden: Int        // gesamte Fokuszeit in Sekunden
    let maxTagesSekunden: Int     // höchste Fokuszeit an einem einzigen Tag
    let currentStreak: Int        // aktueller Tages-Streak
    let longestStreak: Int        // längster Streak aller Zeiten
    let completedTasks: Int       // abgeschlossene Aufgaben gesamt
    let freigeschalteteCount: Int // im Store freigeschaltete Items
    let weekendFokus: Bool        // je an einem Sa/So fokussiert
    let goalReachedCount: Int     // Tage, an denen das Tagesziel erreicht wurde
    let totalFokustage: Int       // Tage mit mindestens einer Fokus-Session
}

// MARK: - Model

struct FokusAchievement: Identifiable {
    let id: String
    let name: String
    let beschreibung: String
    let icon: String
    let farbe: Color
    let kategorie: Kategorie
    let bonusPunkte: Int
    let isUnlocked: (AchievementContext) -> Bool
    let progress: (AchievementContext) -> Double       // 0..1
    let progressLabel: (AchievementContext) -> String

    enum Kategorie: String, CaseIterable {
        case fokuszeit = "Focus Time"
        case streak    = "Streak"
        case aufgaben  = "Tasks"
        case spezial   = "Special"

        var systemIcon: String {
            switch self {
            case .fokuszeit: return "timer"
            case .streak:    return "flame.fill"
            case .aufgaben:  return "checkmark.circle.fill"
            case .spezial:   return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .fokuszeit: return .cyan
            case .streak:    return .orange
            case .aufgaben:  return .green
            case .spezial:   return .purple
            }
        }
    }

    static let all: [FokusAchievement] = _allAchievements
}

// MARK: - Achievement Definitions

private let _allAchievements: [FokusAchievement] = [

    // ────────────── FOKUSZEIT ──────────────

    FokusAchievement(
        id: "erste_session",
        name: "First Steps",
        beschreibung: "Start your very first focus session",
        icon: "play.circle.fill",
        farbe: .green,
        kategorie: .fokuszeit,
        bonusPunkte: 25,
        isUnlocked: { $0.totalSekunden >= 60 },
        progress:   { min(1.0, Double($0.totalSekunden) / 60.0) },
        progressLabel: { _ in "Start a focus session" }
    ),

    FokusAchievement(
        id: "30min_total",
        name: "Halfway There",
        beschreibung: "Collected 30 minutes of focus in total",
        icon: "hourglass",
        farbe: .teal,
        kategorie: .fokuszeit,
        bonusPunkte: 50,
        isUnlocked: { $0.totalSekunden >= 1800 },
        progress:   { min(1.0, Double($0.totalSekunden) / 1800.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 60) of 30 min" }
    ),

    FokusAchievement(
        id: "1h_total",
        name: "Hour Maker",
        beschreibung: "Reached 1 hour of focus time in total",
        icon: "clock.fill",
        farbe: .blue,
        kategorie: .fokuszeit,
        bonusPunkte: 75,
        isUnlocked: { $0.totalSekunden >= 3600 },
        progress:   { min(1.0, Double($0.totalSekunden) / 3600.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 60) of 60 min" }
    ),

    FokusAchievement(
        id: "2h_day",
        name: "Daily Sprint",
        beschreibung: "Focused for 2 hours in a single day",
        icon: "bolt.fill",
        farbe: .yellow,
        kategorie: .fokuszeit,
        bonusPunkte: 150,
        isUnlocked: { $0.maxTagesSekunden >= 7200 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 7200.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) of 120 min (best day)" }
    ),

    FokusAchievement(
        id: "4h_day",
        name: "Power Day",
        beschreibung: "Focused for 4 hours in a single day",
        icon: "star.fill",
        farbe: .orange,
        kategorie: .fokuszeit,
        bonusPunkte: 300,
        isUnlocked: { $0.maxTagesSekunden >= 14400 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 14400.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) of 240 min (best day)" }
    ),

    FokusAchievement(
        id: "10h_total",
        name: "Double Digits",
        beschreibung: "Collected 10 hours of focus in total",
        icon: "10.circle.fill",
        farbe: .indigo,
        kategorie: .fokuszeit,
        bonusPunkte: 200,
        isUnlocked: { $0.totalSekunden >= 36000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 36000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) of 10 hours" }
    ),

    FokusAchievement(
        id: "50h_total",
        name: "Halfway Master",
        beschreibung: "50 hours of focus – you can't be stopped",
        icon: "50.circle.fill",
        farbe: .purple,
        kategorie: .fokuszeit,
        bonusPunkte: 500,
        isUnlocked: { $0.totalSekunden >= 180000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 180000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) of 50 hours" }
    ),

    FokusAchievement(
        id: "100h_total",
        name: "100-Hour Legend",
        beschreibung: "100 hours of concentrated work – absolute elite",
        icon: "crown.fill",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .fokuszeit,
        bonusPunkte: 1200,
        isUnlocked: { $0.totalSekunden >= 360000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 360000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) of 100 hours" }
    ),

    // ────────────── STREAK ──────────────

    FokusAchievement(
        id: "streak_3",
        name: "Three in a Row",
        beschreibung: "Focused for 3 consecutive days",
        icon: "flame",
        farbe: .orange,
        kategorie: .streak,
        bonusPunkte: 75,
        isUnlocked: { $0.longestStreak >= 3 },
        progress:   { min(1.0, Double($0.longestStreak) / 3.0) },
        progressLabel: { ctx in "Longest streak: \(ctx.longestStreak) of 3 days" }
    ),

    FokusAchievement(
        id: "streak_7",
        name: "Week Warrior",
        beschreibung: "7 days in a row – a whole week without a break",
        icon: "flame.fill",
        farbe: .red,
        kategorie: .streak,
        bonusPunkte: 200,
        isUnlocked: { $0.longestStreak >= 7 },
        progress:   { min(1.0, Double($0.longestStreak) / 7.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) of 7 days" }
    ),

    FokusAchievement(
        id: "streak_14",
        name: "Two Weeks Nonstop",
        beschreibung: "14-day focus streak – impressive discipline",
        icon: "medal.fill",
        farbe: Color(red: 0.8, green: 0.5, blue: 0.1),
        kategorie: .streak,
        bonusPunkte: 400,
        isUnlocked: { $0.longestStreak >= 14 },
        progress:   { min(1.0, Double($0.longestStreak) / 14.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) of 14 days" }
    ),

    FokusAchievement(
        id: "streak_30",
        name: "Monthly Champion",
        beschreibung: "30-day focus streak – a whole month!",
        icon: "trophy.fill",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 1000,
        isUnlocked: { $0.longestStreak >= 30 },
        progress:   { min(1.0, Double($0.longestStreak) / 30.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) of 30 days" }
    ),

    // ────────────── AUFGABEN ──────────────

    FokusAchievement(
        id: "task_1",
        name: "First Task",
        beschreibung: "Completed your very first task",
        icon: "checkmark.circle.fill",
        farbe: .green,
        kategorie: .aufgaben,
        bonusPunkte: 25,
        isUnlocked: { $0.completedTasks >= 1 },
        progress:   { min(1.0, Double($0.completedTasks)) },
        progressLabel: { _ in "Complete a task" }
    ),

    FokusAchievement(
        id: "task_10",
        name: "Task Beginner",
        beschreibung: "Successfully completed 10 tasks",
        icon: "list.bullet.circle.fill",
        farbe: .mint,
        kategorie: .aufgaben,
        bonusPunkte: 75,
        isUnlocked: { $0.completedTasks >= 10 },
        progress:   { min(1.0, Double($0.completedTasks) / 10.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 10 tasks" }
    ),

    FokusAchievement(
        id: "task_50",
        name: "Task Pro",
        beschreibung: "50 tasks checked off – you get things done!",
        icon: "checkmark.seal.fill",
        farbe: .blue,
        kategorie: .aufgaben,
        bonusPunkte: 200,
        isUnlocked: { $0.completedTasks >= 50 },
        progress:   { min(1.0, Double($0.completedTasks) / 50.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 50 tasks" }
    ),

    FokusAchievement(
        id: "task_100",
        name: "Task Legend",
        beschreibung: "100 tasks completed – that's real productivity",
        icon: "100.circle.fill",
        farbe: .purple,
        kategorie: .aufgaben,
        bonusPunkte: 500,
        isUnlocked: { $0.completedTasks >= 100 },
        progress:   { min(1.0, Double($0.completedTasks) / 100.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 100 tasks" }
    ),

    // ────────────── SPEZIAL ──────────────

    FokusAchievement(
        id: "weekend",
        name: "Weekend Hero",
        beschreibung: "Focused on the weekend too – respect!",
        icon: "sun.max.fill",
        farbe: .yellow,
        kategorie: .spezial,
        bonusPunkte: 100,
        isUnlocked: { $0.weekendFokus },
        progress:   { $0.weekendFokus ? 1.0 : 0.0 },
        progressLabel: { _ in "Focus on a Saturday or Sunday" }
    ),

    FokusAchievement(
        id: "first_purchase",
        name: "First Purchase",
        beschreibung: "Unlocked the first item in the Focus Store",
        icon: "bag.fill",
        farbe: .pink,
        kategorie: .spezial,
        bonusPunkte: 50,
        isUnlocked: { $0.freigeschalteteCount >= 1 },
        progress:   { min(1.0, Double($0.freigeschalteteCount)) },
        progressLabel: { _ in "Buy an item in the Focus Store" }
    ),

    FokusAchievement(
        id: "sammler",
        name: "Collector",
        beschreibung: "Unlocked 5 items in the Focus Store",
        icon: "bag.badge.plus",
        farbe: Color(red: 0.6, green: 0.3, blue: 0.9),
        kategorie: .spezial,
        bonusPunkte: 150,
        isUnlocked: { $0.freigeschalteteCount >= 5 },
        progress:   { min(1.0, Double($0.freigeschalteteCount) / 5.0) },
        progressLabel: { ctx in "\(ctx.freigeschalteteCount) of 5 items" }
    ),

    FokusAchievement(
        id: "goal_reached",
        name: "Daily Goal Reached!",
        beschreibung: "Fulfilled the daily focus goal for the first time",
        icon: "target",
        farbe: .mint,
        kategorie: .spezial,
        bonusPunkte: 100,
        isUnlocked: { $0.goalReachedCount >= 1 },
        progress:   { min(1.0, Double($0.goalReachedCount)) },
        progressLabel: { _ in "Reach your daily goal once" }
    ),

    FokusAchievement(
        id: "goal_10",
        name: "Ten Goals",
        beschreibung: "Reached the daily focus goal 10 times",
        icon: "scope",
        farbe: .cyan,
        kategorie: .spezial,
        bonusPunkte: 300,
        isUnlocked: { $0.goalReachedCount >= 10 },
        progress:   { min(1.0, Double($0.goalReachedCount) / 10.0) },
        progressLabel: { ctx in "\(ctx.goalReachedCount) of 10 goals" }
    ),

    // ────────────── FOKUSZEIT (Erweiterung) ──────────────

    FokusAchievement(
        id: "5h_day",
        name: "Focus Marathon",
        beschreibung: "Focused for 5 hours in a single day",
        icon: "figure.run",
        farbe: Color(red: 1.0, green: 0.4, blue: 0.0),
        kategorie: .fokuszeit,
        bonusPunkte: 400,
        isUnlocked: { $0.maxTagesSekunden >= 18000 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 18000.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) of 300 min (best day)" }
    ),

    FokusAchievement(
        id: "25h_total",
        name: "Quarter Hundred",
        beschreibung: "Collected 25 hours of focus in total",
        icon: "25.circle.fill",
        farbe: Color(red: 0.2, green: 0.6, blue: 1.0),
        kategorie: .fokuszeit,
        bonusPunkte: 350,
        isUnlocked: { $0.totalSekunden >= 90000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 90000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) of 25 hours" }
    ),

    FokusAchievement(
        id: "200h_total",
        name: "Focus Titan",
        beschreibung: "200 hours of focus – you've reached a new level",
        icon: "infinity.circle.fill",
        farbe: Color(red: 0.9, green: 0.2, blue: 0.5),
        kategorie: .fokuszeit,
        bonusPunkte: 2000,
        isUnlocked: { $0.totalSekunden >= 720000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 720000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) of 200 hours" }
    ),

    // ────────────── STREAK (Erweiterung) ──────────────

    FokusAchievement(
        id: "streak_50",
        name: "Unstoppable",
        beschreibung: "50-day focus streak – absolute discipline",
        icon: "bolt.circle.fill",
        farbe: Color(red: 1.0, green: 0.55, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 1500,
        isUnlocked: { $0.longestStreak >= 50 },
        progress:   { min(1.0, Double($0.longestStreak) / 50.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) of 50 days" }
    ),

    FokusAchievement(
        id: "streak_100",
        name: "100-Day Legend",
        beschreibung: "100-day streak – you are a legend",
        icon: "laurel.leading",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 3000,
        isUnlocked: { $0.longestStreak >= 100 },
        progress:   { min(1.0, Double($0.longestStreak) / 100.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) of 100 days" }
    ),

    // ────────────── AUFGABEN (Erweiterung) ──────────────

    FokusAchievement(
        id: "task_25",
        name: "Task Collector",
        beschreibung: "Successfully completed 25 tasks",
        icon: "tray.full.fill",
        farbe: Color(red: 0.1, green: 0.75, blue: 0.5),
        kategorie: .aufgaben,
        bonusPunkte: 100,
        isUnlocked: { $0.completedTasks >= 25 },
        progress:   { min(1.0, Double($0.completedTasks) / 25.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 25 tasks" }
    ),

    FokusAchievement(
        id: "task_250",
        name: "Task Titan",
        beschreibung: "250 tasks checked off – incredible productivity",
        icon: "checkmark.rectangle.stack.fill",
        farbe: Color(red: 0.3, green: 0.5, blue: 1.0),
        kategorie: .aufgaben,
        bonusPunkte: 1000,
        isUnlocked: { $0.completedTasks >= 250 },
        progress:   { min(1.0, Double($0.completedTasks) / 250.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 250 tasks" }
    ),

    FokusAchievement(
        id: "task_500",
        name: "Task God",
        beschreibung: "500 tasks completed – you are unstoppable",
        icon: "star.circle.fill",
        farbe: Color(red: 0.6, green: 0.1, blue: 0.9),
        kategorie: .aufgaben,
        bonusPunkte: 2000,
        isUnlocked: { $0.completedTasks >= 500 },
        progress:   { min(1.0, Double($0.completedTasks) / 500.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) of 500 tasks" }
    ),

    // ────────────── SPEZIAL (Erweiterung) ──────────────

    FokusAchievement(
        id: "fokustage_7",
        name: "First Week",
        beschreibung: "Focused on 7 different days",
        icon: "calendar.circle.fill",
        farbe: .teal,
        kategorie: .spezial,
        bonusPunkte: 75,
        isUnlocked: { $0.totalFokustage >= 7 },
        progress:   { min(1.0, Double($0.totalFokustage) / 7.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) of 7 focus days" }
    ),

    FokusAchievement(
        id: "fokustage_30",
        name: "Focus Month",
        beschreibung: "Focused on 30 different days",
        icon: "calendar.badge.checkmark",
        farbe: Color(red: 0.2, green: 0.7, blue: 0.8),
        kategorie: .spezial,
        bonusPunkte: 200,
        isUnlocked: { $0.totalFokustage >= 30 },
        progress:   { min(1.0, Double($0.totalFokustage) / 30.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) of 30 focus days" }
    ),

    FokusAchievement(
        id: "fokustage_100",
        name: "Focus Veteran",
        beschreibung: "Focused on 100 different days – true dedication",
        icon: "rosette",
        farbe: Color(red: 0.5, green: 0.3, blue: 1.0),
        kategorie: .spezial,
        bonusPunkte: 800,
        isUnlocked: { $0.totalFokustage >= 100 },
        progress:   { min(1.0, Double($0.totalFokustage) / 100.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) of 100 focus days" }
    ),

    FokusAchievement(
        id: "goal_30",
        name: "Goal Fanatic",
        beschreibung: "Reached the daily focus goal 30 times",
        icon: "checkmark.seal.fill",
        farbe: Color(red: 0.0, green: 0.8, blue: 0.6),
        kategorie: .spezial,
        bonusPunkte: 600,
        isUnlocked: { $0.goalReachedCount >= 30 },
        progress:   { min(1.0, Double($0.goalReachedCount) / 30.0) },
        progressLabel: { ctx in "\(ctx.goalReachedCount) of 30 goals" }
    ),

    FokusAchievement(
        id: "store_veteran",
        name: "Store Veteran",
        beschreibung: "Unlocked 10 items in the Focus Store",
        icon: "storefront.fill",
        farbe: Color(red: 1.0, green: 0.55, blue: 0.0),
        kategorie: .spezial,
        bonusPunkte: 300,
        isUnlocked: { $0.freigeschalteteCount >= 10 },
        progress:   { min(1.0, Double($0.freigeschalteteCount) / 10.0) },
        progressLabel: { ctx in "\(ctx.freigeschalteteCount) of 10 items" }
    ),
]
