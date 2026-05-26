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
        case fokuszeit = "Fokuszeit"
        case streak    = "Streak"
        case aufgaben  = "Aufgaben"
        case spezial   = "Spezial"

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
        name: "Erste Schritte",
        beschreibung: "Starte deine allererste Fokus-Session",
        icon: "play.circle.fill",
        farbe: .green,
        kategorie: .fokuszeit,
        bonusPunkte: 25,
        isUnlocked: { $0.totalSekunden >= 60 },
        progress:   { min(1.0, Double($0.totalSekunden) / 60.0) },
        progressLabel: { _ in "Starte eine Fokus-Session" }
    ),

    FokusAchievement(
        id: "30min_total",
        name: "Halb dabei",
        beschreibung: "30 Minuten Fokus insgesamt gesammelt",
        icon: "hourglass",
        farbe: .teal,
        kategorie: .fokuszeit,
        bonusPunkte: 50,
        isUnlocked: { $0.totalSekunden >= 1800 },
        progress:   { min(1.0, Double($0.totalSekunden) / 1800.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 60) von 30 min" }
    ),

    FokusAchievement(
        id: "1h_total",
        name: "Stunden-Macher",
        beschreibung: "1 Stunde Fokuszeit insgesamt erreicht",
        icon: "clock.fill",
        farbe: .blue,
        kategorie: .fokuszeit,
        bonusPunkte: 75,
        isUnlocked: { $0.totalSekunden >= 3600 },
        progress:   { min(1.0, Double($0.totalSekunden) / 3600.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 60) von 60 min" }
    ),

    FokusAchievement(
        id: "2h_day",
        name: "Tages-Sprint",
        beschreibung: "2 Stunden an einem einzigen Tag fokussiert",
        icon: "bolt.fill",
        farbe: .yellow,
        kategorie: .fokuszeit,
        bonusPunkte: 150,
        isUnlocked: { $0.maxTagesSekunden >= 7200 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 7200.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) von 120 min (bester Tag)" }
    ),

    FokusAchievement(
        id: "4h_day",
        name: "Power-Tag",
        beschreibung: "4 Stunden an einem einzigen Tag fokussiert",
        icon: "star.fill",
        farbe: .orange,
        kategorie: .fokuszeit,
        bonusPunkte: 300,
        isUnlocked: { $0.maxTagesSekunden >= 14400 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 14400.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) von 240 min (bester Tag)" }
    ),

    FokusAchievement(
        id: "10h_total",
        name: "Doppelstellig",
        beschreibung: "10 Stunden Fokus insgesamt gesammelt",
        icon: "10.circle.fill",
        farbe: .indigo,
        kategorie: .fokuszeit,
        bonusPunkte: 200,
        isUnlocked: { $0.totalSekunden >= 36000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 36000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) von 10 Stunden" }
    ),

    FokusAchievement(
        id: "50h_total",
        name: "Halbzeit-Meister",
        beschreibung: "50 Stunden Fokus – du bist nicht zu stoppen",
        icon: "50.circle.fill",
        farbe: .purple,
        kategorie: .fokuszeit,
        bonusPunkte: 500,
        isUnlocked: { $0.totalSekunden >= 180000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 180000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) von 50 Stunden" }
    ),

    FokusAchievement(
        id: "100h_total",
        name: "100-Stunden-Legende",
        beschreibung: "100 Stunden konzentrierte Arbeit – absolute Elite",
        icon: "crown.fill",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .fokuszeit,
        bonusPunkte: 1200,
        isUnlocked: { $0.totalSekunden >= 360000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 360000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) von 100 Stunden" }
    ),

    // ────────────── STREAK ──────────────

    FokusAchievement(
        id: "streak_3",
        name: "Drei am Stück",
        beschreibung: "3 Tage hintereinander fokussiert",
        icon: "flame",
        farbe: .orange,
        kategorie: .streak,
        bonusPunkte: 75,
        isUnlocked: { $0.longestStreak >= 3 },
        progress:   { min(1.0, Double($0.longestStreak) / 3.0) },
        progressLabel: { ctx in "Längste Streak: \(ctx.longestStreak) von 3 Tagen" }
    ),

    FokusAchievement(
        id: "streak_7",
        name: "Wochenkrieger",
        beschreibung: "7 Tage am Stück – eine ganze Woche ohne Pause",
        icon: "flame.fill",
        farbe: .red,
        kategorie: .streak,
        bonusPunkte: 200,
        isUnlocked: { $0.longestStreak >= 7 },
        progress:   { min(1.0, Double($0.longestStreak) / 7.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) von 7 Tagen" }
    ),

    FokusAchievement(
        id: "streak_14",
        name: "Zwei Wochen nonstop",
        beschreibung: "14 Tage Fokus-Streak – beeindruckende Disziplin",
        icon: "medal.fill",
        farbe: Color(red: 0.8, green: 0.5, blue: 0.1),
        kategorie: .streak,
        bonusPunkte: 400,
        isUnlocked: { $0.longestStreak >= 14 },
        progress:   { min(1.0, Double($0.longestStreak) / 14.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) von 14 Tagen" }
    ),

    FokusAchievement(
        id: "streak_30",
        name: "Monats-Champion",
        beschreibung: "30 Tage Fokus-Streak – ein ganzer Monat!",
        icon: "trophy.fill",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 1000,
        isUnlocked: { $0.longestStreak >= 30 },
        progress:   { min(1.0, Double($0.longestStreak) / 30.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) von 30 Tagen" }
    ),

    // ────────────── AUFGABEN ──────────────

    FokusAchievement(
        id: "task_1",
        name: "Erste Aufgabe",
        beschreibung: "Deine allererste Aufgabe erledigt",
        icon: "checkmark.circle.fill",
        farbe: .green,
        kategorie: .aufgaben,
        bonusPunkte: 25,
        isUnlocked: { $0.completedTasks >= 1 },
        progress:   { min(1.0, Double($0.completedTasks)) },
        progressLabel: { _ in "Erledige eine Aufgabe" }
    ),

    FokusAchievement(
        id: "task_10",
        name: "Aufgaben-Einsteiger",
        beschreibung: "10 Aufgaben erfolgreich abgeschlossen",
        icon: "list.bullet.circle.fill",
        farbe: .mint,
        kategorie: .aufgaben,
        bonusPunkte: 75,
        isUnlocked: { $0.completedTasks >= 10 },
        progress:   { min(1.0, Double($0.completedTasks) / 10.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 10 Aufgaben" }
    ),

    FokusAchievement(
        id: "task_50",
        name: "Aufgaben-Profi",
        beschreibung: "50 Aufgaben abgehakt – du machst Dinge!",
        icon: "checkmark.seal.fill",
        farbe: .blue,
        kategorie: .aufgaben,
        bonusPunkte: 200,
        isUnlocked: { $0.completedTasks >= 50 },
        progress:   { min(1.0, Double($0.completedTasks) / 50.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 50 Aufgaben" }
    ),

    FokusAchievement(
        id: "task_100",
        name: "Aufgaben-Legende",
        beschreibung: "100 Aufgaben erledigt – das ist echte Produktivität",
        icon: "100.circle.fill",
        farbe: .purple,
        kategorie: .aufgaben,
        bonusPunkte: 500,
        isUnlocked: { $0.completedTasks >= 100 },
        progress:   { min(1.0, Double($0.completedTasks) / 100.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 100 Aufgaben" }
    ),

    // ────────────── SPEZIAL ──────────────

    FokusAchievement(
        id: "weekend",
        name: "Wochenend-Held",
        beschreibung: "Auch am Wochenende fokussiert – Respekt!",
        icon: "sun.max.fill",
        farbe: .yellow,
        kategorie: .spezial,
        bonusPunkte: 100,
        isUnlocked: { $0.weekendFokus },
        progress:   { $0.weekendFokus ? 1.0 : 0.0 },
        progressLabel: { _ in "Fokussiere dich an einem Samstag oder Sonntag" }
    ),

    FokusAchievement(
        id: "first_purchase",
        name: "Erster Kauf",
        beschreibung: "Erstes Item im Fokus-Store freigeschaltet",
        icon: "bag.fill",
        farbe: .pink,
        kategorie: .spezial,
        bonusPunkte: 50,
        isUnlocked: { $0.freigeschalteteCount >= 1 },
        progress:   { min(1.0, Double($0.freigeschalteteCount)) },
        progressLabel: { _ in "Kaufe ein Item im Fokus-Store" }
    ),

    FokusAchievement(
        id: "sammler",
        name: "Sammler",
        beschreibung: "5 Items im Fokus-Store freigeschaltet",
        icon: "bag.badge.plus",
        farbe: Color(red: 0.6, green: 0.3, blue: 0.9),
        kategorie: .spezial,
        bonusPunkte: 150,
        isUnlocked: { $0.freigeschalteteCount >= 5 },
        progress:   { min(1.0, Double($0.freigeschalteteCount) / 5.0) },
        progressLabel: { ctx in "\(ctx.freigeschalteteCount) von 5 Items" }
    ),

    FokusAchievement(
        id: "goal_reached",
        name: "Tagesziel erreicht!",
        beschreibung: "Das tägliche Fokus-Ziel zum ersten Mal erfüllt",
        icon: "target",
        farbe: .mint,
        kategorie: .spezial,
        bonusPunkte: 100,
        isUnlocked: { $0.goalReachedCount >= 1 },
        progress:   { min(1.0, Double($0.goalReachedCount)) },
        progressLabel: { _ in "Erreiche dein Tagesziel einmal" }
    ),

    FokusAchievement(
        id: "goal_10",
        name: "Zehn Ziele",
        beschreibung: "10 Mal das tägliche Fokus-Ziel erreicht",
        icon: "scope",
        farbe: .cyan,
        kategorie: .spezial,
        bonusPunkte: 300,
        isUnlocked: { $0.goalReachedCount >= 10 },
        progress:   { min(1.0, Double($0.goalReachedCount) / 10.0) },
        progressLabel: { ctx in "\(ctx.goalReachedCount) von 10 Zielen" }
    ),

    // ────────────── FOKUSZEIT (Erweiterung) ──────────────

    FokusAchievement(
        id: "5h_day",
        name: "Fokus-Marathon",
        beschreibung: "5 Stunden an einem einzigen Tag fokussiert",
        icon: "figure.run",
        farbe: Color(red: 1.0, green: 0.4, blue: 0.0),
        kategorie: .fokuszeit,
        bonusPunkte: 400,
        isUnlocked: { $0.maxTagesSekunden >= 18000 },
        progress:   { min(1.0, Double($0.maxTagesSekunden) / 18000.0) },
        progressLabel: { ctx in "\(ctx.maxTagesSekunden / 60) von 300 min (bester Tag)" }
    ),

    FokusAchievement(
        id: "25h_total",
        name: "Viertel-Hundert",
        beschreibung: "25 Stunden Fokus insgesamt gesammelt",
        icon: "25.circle.fill",
        farbe: Color(red: 0.2, green: 0.6, blue: 1.0),
        kategorie: .fokuszeit,
        bonusPunkte: 350,
        isUnlocked: { $0.totalSekunden >= 90000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 90000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) von 25 Stunden" }
    ),

    FokusAchievement(
        id: "200h_total",
        name: "Fokus-Titan",
        beschreibung: "200 Stunden Fokus – du hast ein neues Level erreicht",
        icon: "infinity.circle.fill",
        farbe: Color(red: 0.9, green: 0.2, blue: 0.5),
        kategorie: .fokuszeit,
        bonusPunkte: 2000,
        isUnlocked: { $0.totalSekunden >= 720000 },
        progress:   { min(1.0, Double($0.totalSekunden) / 720000.0) },
        progressLabel: { ctx in "\(ctx.totalSekunden / 3600) von 200 Stunden" }
    ),

    // ────────────── STREAK (Erweiterung) ──────────────

    FokusAchievement(
        id: "streak_50",
        name: "Unaufhaltsam",
        beschreibung: "50 Tage Fokus-Streak – absolute Disziplin",
        icon: "bolt.circle.fill",
        farbe: Color(red: 1.0, green: 0.55, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 1500,
        isUnlocked: { $0.longestStreak >= 50 },
        progress:   { min(1.0, Double($0.longestStreak) / 50.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) von 50 Tagen" }
    ),

    FokusAchievement(
        id: "streak_100",
        name: "100-Tage-Legende",
        beschreibung: "100 Tage Streak – du bist eine Legende",
        icon: "laurel.leading",
        farbe: Color(red: 1.0, green: 0.75, blue: 0.0),
        kategorie: .streak,
        bonusPunkte: 3000,
        isUnlocked: { $0.longestStreak >= 100 },
        progress:   { min(1.0, Double($0.longestStreak) / 100.0) },
        progressLabel: { ctx in "\(ctx.longestStreak) von 100 Tagen" }
    ),

    // ────────────── AUFGABEN (Erweiterung) ──────────────

    FokusAchievement(
        id: "task_25",
        name: "Aufgaben-Sammler",
        beschreibung: "25 Aufgaben erfolgreich abgeschlossen",
        icon: "tray.full.fill",
        farbe: Color(red: 0.1, green: 0.75, blue: 0.5),
        kategorie: .aufgaben,
        bonusPunkte: 100,
        isUnlocked: { $0.completedTasks >= 25 },
        progress:   { min(1.0, Double($0.completedTasks) / 25.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 25 Aufgaben" }
    ),

    FokusAchievement(
        id: "task_250",
        name: "Aufgaben-Titan",
        beschreibung: "250 Aufgaben abgehakt – unglaubliche Produktivität",
        icon: "checkmark.rectangle.stack.fill",
        farbe: Color(red: 0.3, green: 0.5, blue: 1.0),
        kategorie: .aufgaben,
        bonusPunkte: 1000,
        isUnlocked: { $0.completedTasks >= 250 },
        progress:   { min(1.0, Double($0.completedTasks) / 250.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 250 Aufgaben" }
    ),

    FokusAchievement(
        id: "task_500",
        name: "Aufgaben-Gott",
        beschreibung: "500 Aufgaben erledigt – du bist unaufhaltbar",
        icon: "star.circle.fill",
        farbe: Color(red: 0.6, green: 0.1, blue: 0.9),
        kategorie: .aufgaben,
        bonusPunkte: 2000,
        isUnlocked: { $0.completedTasks >= 500 },
        progress:   { min(1.0, Double($0.completedTasks) / 500.0) },
        progressLabel: { ctx in "\(ctx.completedTasks) von 500 Aufgaben" }
    ),

    // ────────────── SPEZIAL (Erweiterung) ──────────────

    FokusAchievement(
        id: "fokustage_7",
        name: "Erste Woche",
        beschreibung: "An 7 verschiedenen Tagen fokussiert",
        icon: "calendar.circle.fill",
        farbe: .teal,
        kategorie: .spezial,
        bonusPunkte: 75,
        isUnlocked: { $0.totalFokustage >= 7 },
        progress:   { min(1.0, Double($0.totalFokustage) / 7.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) von 7 Fokus-Tagen" }
    ),

    FokusAchievement(
        id: "fokustage_30",
        name: "Fokus-Monat",
        beschreibung: "An 30 verschiedenen Tagen fokussiert",
        icon: "calendar.badge.checkmark",
        farbe: Color(red: 0.2, green: 0.7, blue: 0.8),
        kategorie: .spezial,
        bonusPunkte: 200,
        isUnlocked: { $0.totalFokustage >= 30 },
        progress:   { min(1.0, Double($0.totalFokustage) / 30.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) von 30 Fokus-Tagen" }
    ),

    FokusAchievement(
        id: "fokustage_100",
        name: "Fokus-Veteran",
        beschreibung: "An 100 verschiedenen Tagen fokussiert – echte Hingabe",
        icon: "rosette",
        farbe: Color(red: 0.5, green: 0.3, blue: 1.0),
        kategorie: .spezial,
        bonusPunkte: 800,
        isUnlocked: { $0.totalFokustage >= 100 },
        progress:   { min(1.0, Double($0.totalFokustage) / 100.0) },
        progressLabel: { ctx in "\(ctx.totalFokustage) von 100 Fokus-Tagen" }
    ),

    FokusAchievement(
        id: "goal_30",
        name: "Ziel-Fanatiker",
        beschreibung: "30 Mal das tägliche Fokus-Ziel erreicht",
        icon: "checkmark.seal.fill",
        farbe: Color(red: 0.0, green: 0.8, blue: 0.6),
        kategorie: .spezial,
        bonusPunkte: 600,
        isUnlocked: { $0.goalReachedCount >= 30 },
        progress:   { min(1.0, Double($0.goalReachedCount) / 30.0) },
        progressLabel: { ctx in "\(ctx.goalReachedCount) von 30 Zielen" }
    ),

    FokusAchievement(
        id: "store_veteran",
        name: "Store-Veteran",
        beschreibung: "10 Items im Fokus-Store freigeschaltet",
        icon: "storefront.fill",
        farbe: Color(red: 1.0, green: 0.55, blue: 0.0),
        kategorie: .spezial,
        bonusPunkte: 300,
        isUnlocked: { $0.freigeschalteteCount >= 10 },
        progress:   { min(1.0, Double($0.freigeschalteteCount) / 10.0) },
        progressLabel: { ctx in "\(ctx.freigeschalteteCount) von 10 Items" }
    ),
]
