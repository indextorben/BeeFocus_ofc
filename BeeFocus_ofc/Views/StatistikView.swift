import SwiftUI
import UIKit
import MessageUI

struct StatistikView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared
    @StateObject private var mailShare = MailShareService()
    @State private var headerAppeared = false
    @State private var sectionsAppeared = false
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0
    @AppStorage("fokuspunkteAusgegeben") private var fokuspunkteAusgegeben: Int = 0
    @AppStorage("fokuspunktePeak") private var fokuspunktePeak: Int = 0
    @AppStorage("freigeschalteteItems") private var freigeschalteteItemsString: String = ""
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly = false
    @State private var kaufBestaetigung: StoreItem? = nil
    @State private var verkaufBestaetigung: StoreItem? = nil
    @State private var kaufErfolg: String? = nil
    @State private var showFPInfo = false
    @State private var storeTab: StoreTab = .themes
    @AppStorage("aktiverTimerModus") private var aktiverTimerModus: String = ""
    @AppStorage("aktivePriorityStyle") private var aktivePriorityStyle: String = "standard"
    @AppStorage("konfettiEnabled") private var konfettiEnabled: Bool = false
    @AppStorage("fokusSperrmodus") private var fokusSperrmodus: Bool = false
    @AppStorage("dailyGoalEnabled") private var dailyGoalEnabled: Bool = false
    @AppStorage("fokusStreakEnabled") private var fokusStreakEnabled: Bool = false
    @AppStorage("fokusZitatEnabled") private var fokusZitatEnabled: Bool = false
    @AppStorage("wochenrueckblickEnabled") private var wochenrueckblickEnabled: Bool = false
    @State private var showWochenrueckblick = false
    @State private var showChallenges = false
    @State private var showKIGesamtbericht = false
    @State private var showKIAnalyse = false
    @State private var showProStatistik = false
    @State private var showKIReflexion = false
    @State private var showKIWochenbericht = false
    @State private var showKIZerteiler = false
    @State private var showKIStrategie = false
    @State private var selectedHeatmapDay: Date? = nil
    @State private var selectedHeatmapWeekday: Int? = nil // 0=Mo … 6=So
    @State private var heatmapWidth: CGFloat = 320
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60
    @ObservedObject private var timerManager = TimerManager.shared

    private var freigeschalteteItems: Set<String> {
        Set(freigeschalteteItemsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }

    private func kaufeItem(_ item: StoreItem) {
        guard fokuspunkteVerfuegbar >= item.kosten else { return }
        fokuspunkteAusgegeben += item.kosten
        var current = freigeschalteteItems
        current.insert(item.name)
        freigeschalteteItemsString = current.joined(separator: ",")
        switch item.tab {
        case .themes:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { aktivesThema = item.name }
        case .timer:
            aktiverTimerModus = item.name
            applyTimerModus(item.name)
        case .features:
            if item.name == "Prioritäts-Emojis" { aktivePriorityStyle = "emoji" }
            if item.name == "Konfetti-Effekt" { konfettiEnabled = true }
            if item.name == "Fokus-Sperrmodus" { fokusSperrmodus = true }
            if item.name == "Tägliches Fokus-Ziel" { dailyGoalEnabled = true }
            if item.name == "Streak-Tracker" { fokusStreakEnabled = true }
            if item.name == "Fokus-Zitat" { fokusZitatEnabled = true }
            if item.name == "Wochenrückblick" { wochenrueckblickEnabled = true }
        }
        kaufErfolg = item.name
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { kaufErfolg = nil }
        }
    }

    private func aktiviereThema(_ item: StoreItem) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            aktivesThema = aktivesThema == item.name ? "" : item.name
        }
    }

    private func verkaufeItem(_ item: StoreItem) {
        let erstattung = item.kosten / 2
        fokuspunkteAusgegeben = max(0, fokuspunkteAusgegeben - erstattung)
        var current = freigeschalteteItems
        current.remove(item.name)
        freigeschalteteItemsString = current.joined(separator: ",")
        switch item.tab {
        case .themes:
            if aktivesThema == item.name { aktivesThema = "" }
        case .timer:
            if aktiverTimerModus == item.name { deaktiviereTimerModus() }
        case .features:
            if item.name == "Prioritäts-Emojis" && aktivePriorityStyle == "emoji" {
                aktivePriorityStyle = "standard"
            }
            if item.name == "Konfetti-Effekt" { konfettiEnabled = false }
            if item.name == "Fokus-Sperrmodus" { fokusSperrmodus = false }
            if item.name == "Tägliches Fokus-Ziel" { dailyGoalEnabled = false }
            if item.name == "Streak-Tracker" { fokusStreakEnabled = false }
            if item.name == "Fokus-Zitat" { fokusZitatEnabled = false }
            if item.name == "Wochenrückblick" { wochenrueckblickEnabled = false }
        }
    }

    // MARK: - Timer-Modus

    private func applyTimerModus(_ name: String) {
        switch name {
        case "Tiefenfokus":
            UserDefaults.standard.set(90, forKey: "focusTime")
            UserDefaults.standard.set(20, forKey: "shortBreakTime")
            UserDefaults.standard.set(30, forKey: "longBreakTime")
        case "52/17 Methode":
            UserDefaults.standard.set(52, forKey: "focusTime")
            UserDefaults.standard.set(17, forKey: "shortBreakTime")
            UserDefaults.standard.set(17, forKey: "longBreakTime")
        case "Micro-Sprint":
            UserDefaults.standard.set(10, forKey: "focusTime")
            UserDefaults.standard.set(3,  forKey: "shortBreakTime")
            UserDefaults.standard.set(10, forKey: "longBreakTime")
        default: break
        }
        TimerManager.shared.applyUpdatedSettingsIfNeeded()
    }

    private func deaktiviereTimerModus() {
        aktiverTimerModus = ""
        UserDefaults.standard.set(25, forKey: "focusTime")
        UserDefaults.standard.set(5,  forKey: "shortBreakTime")
        UserDefaults.standard.set(15, forKey: "longBreakTime")
        TimerManager.shared.applyUpdatedSettingsIfNeeded()
    }

    private func timerModusLabel(_ name: String) -> String {
        switch name {
        case "Tiefenfokus":   return "90 / 20 min"
        case "52/17 Methode": return "52 / 17 min"
        case "Micro-Sprint":  return "10 / 3 min"
        default: return ""
        }
    }

    private func themaFarben(fuer name: String) -> (Color, Color, Color) {
        switch name {
        case "Ozean":          return (.cyan, .teal, Color(red: 0.0, green: 0.6, blue: 0.9))
        case "Wald":           return (.green, Color(red: 0.1, green: 0.5, blue: 0.2), .mint)
        case "Nacht":          return (.indigo, Color(red: 0.1, green: 0.0, blue: 0.3), .purple)
        case "Solar":          return (.orange, .yellow, Color(red: 1.0, green: 0.4, blue: 0.0))
        case "Kirschblüte":    return (.pink, Color(red: 1.0, green: 0.4, blue: 0.6), .red)
        case "Vulkan":         return (.red, Color(red: 0.8, green: 0.1, blue: 0.0), .orange)
        case "Eis":            return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan, .white)
        case "Herbst":         return (Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.3, blue: 0.05), .orange)
        case "Lavendel":       return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.85, green: 0.7, blue: 1.0))
        case "Sonnenuntergang":return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink, Color(red: 1.0, green: 0.65, blue: 0.0))
        case "Galaxie":        return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95), Color(red: 0.80, green: 0.58, blue: 1.0))
        case "Nordlicht":      return (.green, Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 1.0))
        case "Aurora":         return (Color(red: 0.0, green: 0.9, blue: 0.8), Color(red: 0.5, green: 0.0, blue: 1.0), Color(red: 0.9, green: 0.0, blue: 1.0))
        case "Obsidian":       return (Color(red: 0.85, green: 0.65, blue: 0.1), Color(red: 0.6, green: 0.42, blue: 0.04), Color(red: 1.0, green: 0.85, blue: 0.3))
        case "Nebula":         return (Color(red: 1.0, green: 0.15, blue: 0.6), Color(red: 0.45, green: 0.0, blue: 0.85), Color(red: 0.1, green: 0.55, blue: 1.0))
        default:               return (.purple, .blue, Color(red: 0.4, green: 0.2, blue: 0.9))
        }
    }

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Store Tab
    enum StoreTab: String, CaseIterable {
        case themes  = "Themes"
        case timer   = "Timer"
        case features = "Features"
        var icon: String {
            switch self { case .themes: "paintpalette.fill"; case .timer: "clock.fill"; case .features: "star.fill" }
        }
        var farbe: Color {
            switch self { case .themes: .purple; case .timer: .blue; case .features: .orange }
        }
    }

    // MARK: - Store Item Model
    struct StoreItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let kosten: Int
        let farbe: Color
        let tab: StoreTab
        let beschreibung: String

        init(name: String, icon: String, kosten: Int, farbe: Color,
             tab: StoreTab = .themes, beschreibung: String = "") {
            self.name = name; self.icon = icon; self.kosten = kosten
            self.farbe = farbe; self.tab = tab; self.beschreibung = beschreibung
        }
    }

    var storeItems: [StoreItem] {[
        // Themes
        StoreItem(name: "Ozean",           icon: "water.waves",              kosten: 500,  farbe: .cyan,                              beschreibung: "Calm waves, deep blue"),
        StoreItem(name: "Wald",            icon: "leaf.fill",                kosten: 750,  farbe: .green,                             beschreibung: "Fresh nature, vibrant green"),
        StoreItem(name: "Eis",             icon: "snowflake",                kosten: 800,  farbe: Color(red: 0.6, green: 0.9, blue: 1.0), beschreibung: "Cool silence, crystal-clear white"),
        StoreItem(name: "Herbst",          icon: "wind",                     kosten: 900,  farbe: Color(red: 0.8, green: 0.4, blue: 0.1), beschreibung: "Warm tones, golden leaves"),
        StoreItem(name: "Nacht",           icon: "moon.stars.fill",          kosten: 1000, farbe: .indigo,                            beschreibung: "Velvety darkness, sparkling stars"),
        StoreItem(name: "Lavendel",        icon: "sparkles",                 kosten: 1200, farbe: .purple,                            beschreibung: "Soft violet, fragrant fields"),
        StoreItem(name: "Solar",           icon: "sun.max.fill",             kosten: 1500, farbe: .orange,                            beschreibung: "Energy of the sun, radiantly warm"),
        StoreItem(name: "Sonnenuntergang", icon: "sunset.fill",              kosten: 1800, farbe: Color(red: 1.0, green: 0.4, blue: 0.2), beschreibung: "Glowing evening sky orange"),
        StoreItem(name: "Kirschblüte",     icon: "camera.macro",             kosten: 2000, farbe: .pink,                              beschreibung: "Delicate blossoms, Japanese spring"),
        StoreItem(name: "Nordlicht",       icon: "aqi.medium",               kosten: 2500, farbe: Color(red: 0.0, green: 0.8, blue: 0.6), beschreibung: "Magical aurora spectacle"),
        StoreItem(name: "Vulkan",          icon: "flame.fill",               kosten: 3000, farbe: .red,                               beschreibung: "Burning intensity, pure power"),
        StoreItem(name: "Galaxie",         icon: "moon.circle.fill",         kosten: 5000,  farbe: Color(red: 0.4, green: 0.2, blue: 1.0), beschreibung: "Endless universe, cosmic depth"),
        StoreItem(name: "Aurora",          icon: "aqi.high",                 kosten: 10000, farbe: Color(red: 0.0, green: 0.9, blue: 0.8), beschreibung: "Electric aurora shimmer · Exclusive"),
        StoreItem(name: "Obsidian",        icon: "crown.fill",               kosten: 15000, farbe: Color(red: 0.85, green: 0.65, blue: 0.1), beschreibung: "Noble obsidian, pure gold · Prestige"),
        StoreItem(name: "Nebula",          icon: "rays",                     kosten: 20000, farbe: Color(red: 1.0, green: 0.2, blue: 0.65), beschreibung: "Cosmic nebula, infinite depth · Legendary"),

        // Timer-Modi
        StoreItem(name: "Tiefenfokus",    icon: "brain.head.profile",        kosten: 800,  farbe: .indigo, tab: .timer,
                  beschreibung: "90 min focus · 20 min break\nIdeal for complex, creative tasks"),
        StoreItem(name: "52/17 Methode", icon: "clock.badge.checkmark.fill", kosten: 1000, farbe: .blue,   tab: .timer,
                  beschreibung: "52 min focus · 17 min break\nMaximum concentration without burnout"),
        StoreItem(name: "Micro-Sprint",   icon: "bolt.circle.fill",          kosten: 400,  farbe: .yellow, tab: .timer,
                  beschreibung: "10 min focus · 3 min break\nQuick energy bursts for tough starts"),

        // Features
        StoreItem(name: "Aktivitäts-Heatmap", icon: "calendar.badge.checkmark", kosten: 1500, farbe: .green,  tab: .features,
                  beschreibung: "Year view of your focus activity as a heatmap – looks like GitHub"),
        StoreItem(name: "Prioritäts-Emojis",  icon: "face.smiling.fill",        kosten: 600,  farbe: .pink,   tab: .features,
                  beschreibung: "Replace text priority badges with expressive emojis 🔴🟡🟢"),
        StoreItem(name: "Konfetti-Effekt",    icon: "party.popper.fill",        kosten: 800,  farbe: .yellow, tab: .features,
                  beschreibung: "Celebrate every task completion with colorful confetti 🎉"),
        StoreItem(name: "Fokus-Sperrmodus",   icon: "lock.shield.fill",         kosten: 1200, farbe: .indigo, tab: .features,
                  beschreibung: "Blocks editing & deleting during focus time – no distraction"),
        StoreItem(name: "Tägliches Fokus-Ziel", icon: "target",                 kosten: 1000, farbe: .mint,   tab: .features,
                  beschreibung: "Progress ring for your daily focus goal – see how close you are"),
        StoreItem(name: "Streak-Tracker",     icon: "flame.fill",               kosten: 1500, farbe: .orange, tab: .features,
                  beschreibung: "Track your focus streak – how many days in a row you stayed focused 🔥"),
        StoreItem(name: "Fokus-Zitat",        icon: "quote.bubble.fill",        kosten: 600,  farbe: .teal,   tab: .features,
                  beschreibung: "Shows a motivating quote during focus mode – refreshes daily"),
        StoreItem(name: "Wochenrückblick",    icon: "chart.bar.doc.horizontal", kosten: 1200, farbe: Color(red: 0.4, green: 0.6, blue: 1.0), tab: .features,
                  beschreibung: "Compare this week with last – see your progress at a glance"),
        StoreItem(name: "Abzeichen-System",   icon: "medal.fill",               kosten: 2000, farbe: Color(red: 0.6, green: 0.3, blue: 0.9), tab: .features,
                  beschreibung: "Unlock 21 badges & earn up to 5,675 bonus FP – for focus, streaks, tasks and more"),
    ]}

    // MARK: - Gefilterter Basis-Datensatz (respektiert "Nur diesen Monat")
    private var baseTodos: [TodoItem] {
        guard filterCurrentMonthOnly else { return todoStore.todos }
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        let endOfMonth = cal.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) ?? Date()
        return todoStore.todos.filter { todo in
            guard let due = todo.dueDate else { return true } // ohne Datum immer anzeigen
            return due >= startOfMonth && due <= endOfMonth
        }
    }

    // MARK: - Basisstatistiken
    var completedTasks: Int { baseTodos.filter { $0.isCompleted }.count }
    var openTasks: Int     { baseTodos.filter { !$0.isCompleted }.count }
    var totalTasks: Int    { openTasks + completedTasks }
    var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }

    var todayOpenTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return baseTodos.filter { item in
            guard let due = item.dueDate else { return false }
            return !item.isCompleted && Calendar.current.isDate(due, inSameDayAs: today)
        }.count
    }

    var todayCompletedTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return baseTodos.filter { item in
            guard let due = item.dueDate else { return false }
            return item.isCompleted && Calendar.current.isDate(due, inSameDayAs: today)
        }.count
    }

    var overdueTasks: Int {
        baseTodos.filter { item in
            guard let due = item.dueDate, !item.isCompleted else { return false }
            return due < Date()
        }.count
    }

    var todayCompletionRate: Double {
        let total = todayCompletedTasks + todayOpenTasks
        return total > 0 ? Double(todayCompletedTasks) / Double(total) : 0
    }

    var tasksByCategory: [(name: String, count: Int, color: Color)] {
        todoStore.categories.map { cat in
            let count = baseTodos.filter { $0.category?.id == cat.id && !$0.isCompleted }.count
            return (cat.name, count, cat.color)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Fokus
    private var focusTodayMinutes: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.dailyFocusMinutes[today] ?? 0
    }

    private var focusGoalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(focusTodayMinutes) / Double(dailyGoal))
    }

    private func weekdayLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.dateFormat = "EEE"
        return String(df.string(from: date).prefix(2)).capitalized
    }

    private var chartAccentColors: [Color] {
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return aktivesThema.isEmpty ? [.cyan, .teal] : [c1, c2]
    }

    private var totalFocusMinutesAll: Int {
        todoStore.dailyFocusMinutes.values.reduce(0, +)
    }

    private var focusTodayDateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: LocalizationManager.shared.currentLanguageCode)
        f.dateFormat = "EEEE, d. MMM yyyy"
        return f.string(from: Date())
    }

    // MARK: - Streak
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let count = todoStore.dailyStats.filter { cal.isDate($0.key, inSameDayAs: day) }.values.reduce(0, +)
            if count == 0 { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private func computeLongestStreak() -> Int {
        let cal = Calendar.current
        let sortedDays = todoStore.dailyStats.keys.sorted()
        var best = 0, cur = 0
        var prevDay: Date? = nil
        for day in sortedDays {
            if (todoStore.dailyStats[day] ?? 0) > 0 {
                if let prev = prevDay,
                   cal.dateComponents([.day], from: prev, to: day).day == 1 {
                    cur += 1
                } else {
                    cur = 1
                }
                best = max(best, cur)
                prevDay = day
            } else {
                cur = 0; prevDay = nil
            }
        }
        return best
    }

    // MARK: - Fokuspunkte System

    // Live-berechneter Wert — dient nur zum Ermitteln neuer Punkte
    private var fokuspunkteAktuellBerechnet: Int {
        var pts = completedTasks * 10
            + totalFocusMinutesAll * 2
            + currentStreak * 50
            + todoStore.todos.filter { $0.isFavorite }.count * 5
            + todoStore.todos.filter { $0.isRecurring }.count * 3
        if #available(iOS 16, *) {
            pts += FokusModeManager.shared.achievementBonusPunkte
        }
        return pts
    }

    // Gesamtpunkte steigen nie automatisch — nur Käufe reduzieren das Guthaben
    var fokuspunkteGesamt: Int { max(fokuspunktePeak, fokuspunkteAktuellBerechnet) }

    var fokuspunkteVerfuegbar: Int { max(0, fokuspunkteGesamt - fokuspunkteAusgegeben) }

    var fokuspunkteStufe: (name: String, icon: String, farbe: Color) {
        switch fokuspunkteVerfuegbar {
        case 0..<100:  return ("Beginner",   "seedling",           .green)
        case ..<300:   return ("Learner",    "book.fill",          .teal)
        case ..<600:   return ("Focused",    "brain.head.profile", .blue)
        case ..<1000:  return ("Productive", "bolt.fill",          .indigo)
        case ..<2000:  return ("Expert",     "star.fill",          .purple)
        case ..<5000:  return ("Master",     "crown.fill",         .orange)
        default:       return ("Legend",     "flame.fill",         Color(red: 1, green: 0.3, blue: 0.1))
        }
    }

    var motivationText: String {
        switch completionRate {
        case 0:      return "Let's go – you've got this!"
        case ..<0.25: return "Good start, keep it up!"
        case ..<0.5:  return "You're on the right track!"
        case ..<0.75: return "More than halfway there!"
        case ..<1.0:  return "Almost done – great work!"
        default:      return "Everything done – fantastic!"
        }
    }

    // MARK: - Export
    func shareTodosByMail(_ todos: [TodoItem], recipients: [String]? = nil) {
        mailShare.shareTodosByMail(todos, languageCode: LocalizationManager.shared.currentLanguageCode, recipients: recipients)
    }

    private func exportStatistics() {
        DispatchQueue.main.async {
            let exportView = StatistikExportView(
                completed: completedTasks, open: openTasks,
                total: totalTasks, overdue: overdueTasks
            )
            .frame(width: 1240, height: 1754)
            .background(Color.white)
            let renderer = ImageRenderer(content: exportView)
            renderer.scale = 3
            guard let image = renderer.uiImage else { return }
            mailShare.exportData = ShareData(image: image)
        }
    }

    // MARK: - Section Groups (aufgeteilt um SwiftUI-ViewBuilder-Stack-Overflow zu vermeiden)

    // Single flat @ViewBuilder — alle Sections auf einer Ebene, kein Ketten-Aufruf.
    // Verhindert den TupleView-Typ-Overflow der vorher 5 Ebenen tief war.
    @ViewBuilder private var allSections: some View {
        AnyView(sectionsTop)
        AnyView(sectionsMiddle)
        AnyView(sectionsProStatistik)
        AnyView(sectionsKI)
        AnyView(sectionsGesamtbericht)
    }

    @ViewBuilder private var sectionsTop: some View {
        animatedSection(delay: 0.05) { fokuspunkteCard }
        animatedSection(delay: 0.10) {
            sectionGroup(icon: "storefront.fill", label: "Focus Store", color: Color(red: 1, green: 0.55, blue: 0.0)) { storeCard }
        }
        animatedSection(delay: 0.15) {
            sectionGroup(icon: "chart.bar.fill", label: localizer.localizedString(forKey: "overview_title"), color: .purple) { overviewCard }
        }
        animatedSection(delay: 0.20) {
            sectionGroup(icon: "sun.max.fill", label: localizer.localizedString(forKey: "today_activity_title"), color: .orange) {
                glassCard { todayCard }
            }
        }
        animatedSection(delay: 0.25) {
            sectionGroup(icon: "tag.fill", label: localizer.localizedString(forKey: "category_distribution_title"), color: .blue) {
                glassCard { categoryCard }
            }
        }
        animatedSection(delay: 0.30) {
            sectionGroup(icon: "timer", label: "Focus Time", color: .cyan) { glassCard { focusCard } }
        }
        if freigeschalteteItems.contains("Abzeichen-System") {
            animatedSection(delay: 0.32) {
                sectionGroup(icon: "medal.fill", label: "Badges", color: Color(red: 0.6, green: 0.3, blue: 0.9)) {
                    glassCard {
                        if #available(iOS 16, *) {
                            NavigationLink(destination: FokusAchievementsView()) {
                                iconNavRow(icon: "medal.fill", color: Color(red: 0.6, green: 0.3, blue: 0.9), label: "View all badges")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var sectionsMiddle: some View {
        if freigeschalteteItems.contains("Aktivitäts-Heatmap") {
            animatedSection(delay: 0.33) {
                sectionGroup(icon: "calendar.badge.checkmark", label: "Activity Heatmap", color: .green) {
                    glassCard { heatmapView }
                }
            }
        }
        if wochenrueckblickEnabled {
            animatedSection(delay: 0.34) {
                sectionGroup(icon: "chart.bar.doc.horizontal", label: String(localized: "review_title"), color: Color(red: 0.4, green: 0.6, blue: 1.0)) {
                    glassCard {
                        Button { showWochenrueckblick = true } label: {
                            iconNavRow(icon: "chart.bar.doc.horizontal", color: Color(red: 0.4, green: 0.6, blue: 1.0), label: String(localized: "review_open_btn"))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        animatedSection(delay: 0.35) {
            sectionGroup(icon: "circle.dashed", label: localizer.localizedString(forKey: "progress_overview_title"), color: .indigo) {
                glassCard { ringsCard }
            }
        }
        animatedSection(delay: 0.38) {
            sectionGroup(icon: "trophy.fill", label: "Challenges", color: Color(red: 1.0, green: 0.7, blue: 0.2)) {
                glassCard {
                    Button { showChallenges = true } label: {
                        iconNavRow(icon: "trophy.fill", color: Color(red: 1.0, green: 0.7, blue: 0.2), label: "View Focus Challenges")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Pro Statistiken
    @ViewBuilder private var sectionsProStatistik: some View {
        animatedSection(delay: 0.57) {
            sectionGroup(icon: "chart.bar.xaxis", label: "Pro Statistics", color: Color(red: 0.2, green: 0.6, blue: 1.0)) {
                glassCard {
                    Button { showProStatistik = true } label: {
                        iconNavRow(icon: "chart.bar.xaxis", color: Color(red: 0.2, green: 0.6, blue: 1.0), label: "Weekday, time of day & category analysis")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 0.2, green: 0.6, blue: 1.0))
                }
            }
        }
    }

    // MARK: KI-Features
    @ViewBuilder private var sectionsKI: some View {
        animatedSection(delay: 0.60) {
            sectionGroup(icon: "brain.head.profile", label: "AI Task Analysis", color: Color(red: 0.55, green: 0.35, blue: 1.0)) {
                glassCard {
                    Button { showKIAnalyse = true } label: {
                        iconNavRow(icon: "brain.head.profile", color: Color(red: 0.55, green: 0.35, blue: 1.0), label: "AI analyzes your tasks & priorities")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 0.55, green: 0.35, blue: 1.0))
                }
            }
        }
        animatedSection(delay: 0.62) {
            sectionGroup(icon: "moon.stars.fill", label: "AI Daily Reflection", color: Color(red: 1.0, green: 0.5, blue: 0.8)) {
                glassCard {
                    Button { showKIReflexion = true } label: {
                        iconNavRow(icon: "moon.stars.fill", color: Color(red: 1.0, green: 0.5, blue: 0.8), label: "Personal AI reflection of your day")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 1.0, green: 0.5, blue: 0.8))
                }
            }
        }
        animatedSection(delay: 0.64) {
            sectionGroup(icon: "chart.bar.doc.horizontal.fill", label: "AI Weekly Report", color: Color(red: 0.2, green: 0.75, blue: 1.0)) {
                glassCard {
                    Button { showKIWochenbericht = true } label: {
                        iconNavRow(icon: "chart.bar.doc.horizontal.fill", color: Color(red: 0.2, green: 0.75, blue: 1.0), label: "AI analyzes your entire week")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 0.2, green: 0.75, blue: 1.0))
                }
            }
        }
        animatedSection(delay: 0.66) {
            sectionGroup(icon: "scissors", label: "AI Task Splitter", color: Color(red: 0.3, green: 0.85, blue: 0.5)) {
                glassCard {
                    Button { showKIZerteiler = true } label: {
                        iconNavRow(icon: "scissors", color: Color(red: 0.3, green: 0.85, blue: 0.5), label: "Break complex tasks into steps")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 0.3, green: 0.85, blue: 0.5))
                }
            }
        }
        animatedSection(delay: 0.68) {
            sectionGroup(icon: "flame.fill", label: "AI Focus Strategy", color: Color(red: 1.0, green: 0.55, blue: 0.1)) {
                glassCard {
                    Button { showKIStrategie = true } label: {
                        iconNavRow(icon: "flame.fill", color: Color(red: 1.0, green: 0.55, blue: 0.1), label: "Personalized AI Productivity Plan")
                    }
                    .buttonStyle(.plain)
                    kiProBadge(color: Color(red: 1.0, green: 0.55, blue: 0.1))
                }
            }
        }
    }

    // MARK: - KI-Gesamtbericht

    @ViewBuilder private var sectionsGesamtbericht: some View {
        animatedSection(delay: 0.75) {
            sectionGroup(icon: "doc.text.magnifyingglass", label: "AI Overall Report", color: Color(red: 0.55, green: 0.35, blue: 1.0)) {
                glassCard {
                    Button { showKIGesamtbericht = true } label: {
                        iconNavRow(icon: "doc.text.magnifyingglass", color: Color(red: 0.55, green: 0.35, blue: 1.0), label: "Alle App-Daten analysiert & exportierbar")
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 1.0))
                        Text("Als PDF, PNG oder JPEG exportieren")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 1.0))
                    }
                    .padding(.horizontal, 14).padding(.bottom, 10)
                }
            }
        }
    }

    private func kiProBadge(color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text("Pro KI-Feature")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14).padding(.bottom, 10)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerHero.padding(.bottom, 4)
                        motivationBanner
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 12)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: sectionsAppeared)
                        allSections
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 52)
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "Statistik"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportStatistics() } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    }
                }
            }
            .sheet(item: $mailShare.exportData) { data in
                ShareActivityView(activityItems: [data.image])
            }
            .sheet(item: $mailShare.mailComposerData) { data in
                MailComposerWrapperView(subject: data.subject, body: data.body, recipients: data.recipients)
            }
            .sheet(isPresented: $showFPInfo) {
                fokuspunkteInfoSheet
            }
            .sheet(isPresented: $showChallenges) {
                FokusChallengesView().environmentObject(todoStore)
            }
            .sheet(isPresented: $showKIAnalyse) {
                KIAufgabenAnalyseView(todos: todoStore.todos)
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showKIReflexion) {
                KITagesreflexionView(todos: todoStore.todos)
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showKIWochenbericht) {
                KIWochenberichtView(todos: todoStore.todos)
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showKIZerteiler) {
                KIAufgabenZerteilerView()
                    .environmentObject(todoStore)
            }
            .sheet(isPresented: $showKIStrategie) {
                KIFokusStrategieView(todos: todoStore.todos)
                    .environmentObject(todoStore)
            }

            .sheet(isPresented: $showKIGesamtbericht) {
                KIGesamtberichtView()
                    .environmentObject(todoStore)
            }

            .sheet(isPresented: $showProStatistik) {
                StatistikProView()
                    .environmentObject(todoStore)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showWochenrueckblick) {
                let (c1, c2, _) = appThemaFarben(aktivesThema)
                WochenrueckblickSheet(
                    todoStore: todoStore,
                    themeC1: aktivesThema.isEmpty ? Color(red: 0.4, green: 0.6, blue: 1.0) : c1,
                    themeC2: aktivesThema.isEmpty ? Color(red: 0.55, green: 0.4, blue: 1.0) : c2
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { headerAppeared = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { sectionsAppeared = true }
            if fokuspunkteAktuellBerechnet > fokuspunktePeak {
                fokuspunktePeak = fokuspunkteAktuellBerechnet
            }
            if #available(iOS 16, *) {
                let cal = Calendar.current
                let longestStrk = computeLongestStreak()
                let weekendFokus = todoStore.dailyFocusMinutes.contains { date, mins in
                    mins > 0 && (cal.component(.weekday, from: date) == 1 || cal.component(.weekday, from: date) == 7)
                }
                let goalMet = todoStore.dailyFocusMinutes.values.filter { $0 >= dailyGoal }.count
                let fokustage = todoStore.dailyFocusMinutes.values.filter { $0 > 0 }.count
                let ctx = AchievementContext(
                    totalSekunden: totalFocusMinutesAll * 60,
                    maxTagesSekunden: (todoStore.dailyFocusMinutes.values.max() ?? 0) * 60,
                    currentStreak: currentStreak,
                    longestStreak: longestStrk,
                    completedTasks: completedTasks,
                    freigeschalteteCount: freigeschalteteItems.count,
                    weekendFokus: weekendFokus,
                    goalReachedCount: goalMet,
                    totalFokustage: fokustage
                )
                FokusModeManager.shared.checkAchievements(context: ctx)
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                wavePhase1 = .pi * 2
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                wavePhase2 = .pi * 2
            }
        }
        .onChange(of: fokuspunkteAktuellBerechnet) { newValue in
            if newValue > fokuspunktePeak {
                fokuspunktePeak = newValue
            }
        }
    }

    // MARK: - FP Info Sheet

    private var fokuspunkteInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Erklärung Fokuspunkte
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Earn Focus Points", systemImage: "bolt.fill")
                            .font(.headline)
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        Text("Focus points are credited for your productivity and never decrease automatically – only purchases in the Focus Store reduce your balance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 0) {
                        fpInfoRow(icon: "checkmark.circle.fill", color: .green,
                                  title: "Complete task", points: "+10 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "timer", color: .cyan,
                                  title: "Focus minute", points: "+2 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "flame.fill", color: .orange,
                                  title: "Streak day", points: "+50 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "star.fill", color: .yellow,
                                  title: "Starred task", points: "+5 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "arrow.triangle.2.circlepath", color: .teal,
                                  title: "Recurring task", points: "+3 FP")
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Erklärung Fokus-Store
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Focus Store", systemImage: "storefront.fill")
                            .font(.headline)
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        Text("In the Focus Store you can unlock color themes for the statistics view. Each theme changes the background gradient of this page.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 0) {
                        fpInfoRow(icon: "lock.open.fill", color: .blue,
                                  title: "Unlock theme", points: "spend FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "checkmark.circle", color: .green,
                                  title: "Activate / switch theme", points: "free")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "arrow.uturn.left.circle", color: .orange,
                                  title: "Sell theme", points: "½ FP back")
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Erklärung Abzeichen-System
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Badge System", systemImage: "medal.fill")
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.6, green: 0.3, blue: 0.9))
                        Text("Unlock the badge system in the store for 2,000 FP. For each badge earned you receive one-time bonus focus points – up to 5,675 FP in total.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 0) {
                        fpInfoRow(icon: "timer",                  color: .cyan,
                                  title: "Focus time badges",   points: "25–1200 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "flame.fill",             color: .orange,
                                  title: "Streak badges",      points: "75–1000 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "checkmark.circle.fill",  color: .green,
                                  title: "Task badges",    points: "25–500 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "star.fill",              color: .purple,
                                  title: "Special badges",     points: "50–300 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "crown.fill",             color: Color(red: 1.0, green: 0.75, blue: 0.0),
                                  title: "All 32 badges",     points: "up to +19,100 FP")
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Currently \(storeItems.count) items available – new ones coming with app updates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .navigationTitle("Focus Points & Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showFPInfo = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func fpInfoRow(icon: String, color: Color, title: String, points: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: color.opacity(0.35), radius: 3, x: 0, y: 2)
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Text(points)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func iconNavRow(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .shadow(color: color.opacity(0.35), radius: 3, x: 0, y: 2)
            Text(label)
                .font(.system(size: 15))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Animated Section

    private func animatedSection<C: View>(delay: Double, @ViewBuilder content: () -> C) -> some View {
        content()
            .opacity(sectionsAppeared ? 1 : 0)
            .offset(y: sectionsAppeared ? 0 : 18)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: sectionsAppeared)
    }

    // MARK: - Background

    private var aktiveThemaFarben: (Color, Color, Color) {
        aktivesThema.isEmpty ? (.purple, .blue, Color(red: 1, green: 0.6, blue: 0.2)) : themaFarben(fuer: aktivesThema)
    }

    // Theme decoration layers split out to keep backgroundGradient ZStack under the 10-child ViewBuilder limit
    @ViewBuilder private var themeDecorationLayer: some View {
        if aktivesThema == "Wald" {
            WaldDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Eis" {
            EisDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Nordlicht" {
            NordlichtDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Galaxie" {
            GalaxieDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Vulkan" {
            VulkanDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Herbst" {
            HerbstDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Nacht" {
            NachtDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Solar" {
            SolarDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Kirschblüte" {
            KirschblueteDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Lavendel" {
            LavendelDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        } else if aktivesThema == "Sonnenuntergang" {
            SonnenuntergangDecorationLayer()
                .transition(.opacity).animation(.easeInOut(duration: 0.8), value: aktivesThema)
        }
    }

    private var backgroundGradient: some View {
        let (c1, c2, c3) = aktiveThemaFarben
        return ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(colors: [c1.opacity(isDark ? 0.32 : 0.15), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.45))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.10)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [c2.opacity(isDark ? 0.24 : 0.12), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.4))
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.88, y: geo.size.height * 0.60)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [c3.opacity(isDark ? 0.16 : 0.09), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
                    .blur(radius: 14)
            }
            GeometryReader { geo in
                WaveShape(phase: wavePhase2, amplitude: 20, frequency: 1.4)
                    .fill(c2.opacity(isDark ? 0.10 : 0.07))
                    .frame(width: geo.size.width, height: geo.size.height * 0.40)
                    .position(x: geo.size.width * 0.5,
                               y: geo.size.height - geo.size.height * 0.40 * 0.5)
                WaveShape(phase: wavePhase1, amplitude: 13, frequency: 2.0)
                    .fill(c1.opacity(isDark ? 0.16 : 0.11))
                    .frame(width: geo.size.width, height: geo.size.height * 0.28)
                    .position(x: geo.size.width * 0.5,
                               y: geo.size.height - geo.size.height * 0.28 * 0.5)
            }
            .opacity(["", "Wald", "Eis", "Nordlicht", "Galaxie", "Vulkan", "Herbst", "Nacht", "Solar", "Kirschblüte", "Lavendel", "Sonnenuntergang"].contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)
            themeDecorationLayer
        }
        .animation(.easeInOut(duration: 0.6), value: aktivesThema)
        .ignoresSafeArea()
    }

    // MARK: - Hero Header

    private var headerHero: some View {
        let (c1, c2, _) = aktiveThemaFarben
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [c1.opacity(0.35), c2.opacity(0.12)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(headerAppeared ? 1 : 0.5).opacity(headerAppeared ? 1 : 0)

                Circle()
                    .trim(from: 0, to: headerAppeared ? completionRate : 0)
                    .stroke(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.4), value: headerAppeared)

                Circle()
                    .fill(LinearGradient(colors: [c1, c2.opacity(0.85)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: c1.opacity(0.45), radius: 18, x: 0, y: 8)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: aktivesThema)
            }
            .scaleEffect(headerAppeared ? 1 : 0.6).opacity(headerAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: aktivesThema)

            VStack(spacing: 5) {
                Text(localizer.localizedString(forKey: "Statistik"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing))
                    .animation(.easeInOut(duration: 0.5), value: aktivesThema)
                Text("\(Int(completionRate * 100))% abgeschlossen")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .offset(y: headerAppeared ? 0 : 12).opacity(headerAppeared ? 1 : 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: headerAppeared)
        }
        .padding(.top, 24).padding(.bottom, 4)
    }

    // MARK: - Motivation Banner

    private var motivationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: currentStreak > 0 ? "flame.fill" : "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(currentStreak > 0 ? Color.orange : Color.purple)
            Text(motivationText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
            Spacer()
            if currentStreak > 0 {
                HStack(spacing: 3) {
                    Text("\(currentStreak)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    Text(currentStreak == 1 ? "Tag" : "Tage").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(LinearGradient(colors: [aktiveThemaFarben.0.opacity(isDark ? 0.35 : 0.22),
                                                   aktiveThemaFarben.1.opacity(isDark ? 0.12 : 0.07)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: aktiveThemaFarben.0.opacity(isDark ? 0.18 : 0.08), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.5), value: aktivesThema)
    }

    // MARK: - Fokuspunkte Card

    private var fokuspunkteCard: some View {
        let stufe = fokuspunkteStufe
        let (fc1, fc2, _) = aktiveThemaFarben
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: isDark
                        ? [fc1.opacity(0.65), fc2.opacity(0.45)]
                        : [fc1, fc2],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: fc1.opacity(0.45), radius: 20, x: 0, y: 8)
                .animation(.easeInOut(duration: 0.6), value: aktivesThema)

            Circle().fill(Color.white.opacity(0.07))
                .frame(width: 120, height: 120).offset(x: 90, y: -30).blur(radius: 2)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.2),
                                                       Color(red: 1, green: 0.6, blue: 0.1)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.orange.opacity(0.5), radius: 10, x: 0, y: 4)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Fokuspunkte").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                        Button { showFPInfo = true } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Text("\(fokuspunkteVerfuegbar)")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    HStack(spacing: 5) {
                        Image(systemName: stufe.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(stufe.farbe)
                        Text(stufe.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Gesamt").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                    Text("\(fokuspunkteGesamt) FP").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    Text("verdient").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Store Card

    private var storeCard: some View {
        VStack(spacing: 12) {

            // ── Guthaben-Header ──────────────────────────────────────────
            glassCard {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        iconBadge(icon: "bolt.fill", color: Color(red: 1, green: 0.55, blue: 0.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dein Guthaben").font(.system(size: 13)).foregroundStyle(.secondary)
                            Text("\(fokuspunkteVerfuegbar) Fokuspunkte")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        }
                        Spacer()
                        if let name = kaufErfolg {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("\(name) freigeschaltet!").font(.system(size: 11, weight: .semibold)).foregroundStyle(.green)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    // Aktive Zustände (Theme / Timer / Emoji)
                    if !aktivesThema.isEmpty || !aktiverTimerModus.isEmpty || aktivePriorityStyle == "emoji" || konfettiEnabled || fokusSperrmodus {
                        Divider().opacity(0.3)
                        VStack(spacing: 0) {
                            if !aktivesThema.isEmpty {
                                let (tc, _, _) = themaFarben(fuer: aktivesThema)
                                activeStatusRow(
                                    dot: tc, label: "Theme", value: aktivesThema, farbe: tc,
                                    onDeactivate: { withAnimation { aktivesThema = "" } }
                                )
                            }
                            if !aktiverTimerModus.isEmpty {
                                let item = storeItems.first { $0.name == aktiverTimerModus }
                                activeStatusRow(
                                    dot: item?.farbe ?? .blue, label: "Timer", value: "\(aktiverTimerModus) (\(timerModusLabel(aktiverTimerModus)))", farbe: item?.farbe ?? .blue,
                                    onDeactivate: { deaktiviereTimerModus() }
                                )
                            }
                            if aktivePriorityStyle == "emoji" {
                                activeStatusRow(
                                    dot: .pink, label: "Priority", value: "Emojis active 🔴🟡🟢", farbe: .pink,
                                    onDeactivate: { aktivePriorityStyle = "standard" }
                                )
                            }
                            if konfettiEnabled {
                                activeStatusRow(
                                    dot: .yellow, label: "Confetti", value: "On 🎉", farbe: .yellow,
                                    onDeactivate: { konfettiEnabled = false }
                                )
                            }
                            if fokusSperrmodus {
                                activeStatusRow(
                                    dot: .indigo, label: "Lock mode", value: "Active 🔒", farbe: .indigo,
                                    onDeactivate: { fokusSperrmodus = false }
                                )
                            }
                        }
                    }
                }
            }

            // ── Kategorie-Tabs ───────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(StoreTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { storeTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 15, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(storeTab == tab ? tab.farbe : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(storeTab == tab ? tab.farbe.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            // ── Tab-Inhalt ───────────────────────────────────────────────
            switch storeTab {
            case .themes:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(storeItems.filter { $0.tab == .themes }) { item in storeCell(item) }
                }

            case .timer:
                VStack(spacing: 10) {
                    ForEach(storeItems.filter { $0.tab == .timer }) { item in timerModusZelle(item) }
                }

            case .features:
                VStack(spacing: 10) {
                    ForEach(storeItems.filter { $0.tab == .features }) { item in featureZelle(item) }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: kaufErfolg)
        .animation(.easeInOut(duration: 0.3), value: aktivesThema)
        .animation(.easeInOut(duration: 0.2), value: storeTab)
        // Kauf-Dialog
        .alert(
            kaufBestaetigung.map { "\"\($0.name)\" freischalten?" } ?? "",
            isPresented: Binding(get: { kaufBestaetigung != nil }, set: { if !$0 { kaufBestaetigung = nil } })
        ) {
            if let item = kaufBestaetigung {
                Button("Freischalten (\(item.kosten) FP)") { kaufeItem(item); kaufBestaetigung = nil }
                Button("Abbrechen", role: .cancel) { kaufBestaetigung = nil }
            }
        } message: {
            if let item = kaufBestaetigung {
                Text("Kostet \(item.kosten) Fokuspunkte. Du hast \(fokuspunkteVerfuegbar) FP.")
            }
        }
        // Verkauf-Dialog
        .alert(
            verkaufBestaetigung.map { "Sell \"\($0.name)\"?" } ?? "",
            isPresented: Binding(get: { verkaufBestaetigung != nil }, set: { if !$0 { verkaufBestaetigung = nil } })
        ) {
            if let item = verkaufBestaetigung {
                Button("Sell (\(item.kosten / 2) FP back)", role: .destructive) {
                    verkaufeItem(item); verkaufBestaetigung = nil
                }
                Button("Cancel", role: .cancel) { verkaufBestaetigung = nil }
            }
        } message: {
            if let item = verkaufBestaetigung {
                Text("You will receive \(item.kosten / 2) FP back.")
            }
        }
    }

    @ViewBuilder
    private func activeStatusRow(dot: Color, label: String, value: String, farbe: Color, onDeactivate: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 7, height: 7)
            Text("\(label):").font(.system(size: 12)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundStyle(farbe).lineLimit(1)
            Spacer()
            Button(action: onDeactivate) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // ── Timer-Modus Zelle ─────────────────────────────────────────────────
    private func timerModusZelle(_ item: StoreItem) -> some View {
        let istFreigeschaltet = freigeschalteteItems.contains(item.name)
        let istAktiv = aktiverTimerModus == item.name
        let kannKaufen = !istFreigeschaltet && fokuspunkteVerfuegbar >= item.kosten

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(istFreigeschaltet ? item.farbe.opacity(0.18) : item.farbe.opacity(0.07))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : item.farbe.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(istFreigeschaltet ? .primary : .secondary)
                    if istAktiv {
                        Text("Aktiv")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(item.farbe.gradient, in: Capsule())
                    }
                }
                Text(item.beschreibung)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if istFreigeschaltet {
                Button {
                    if istAktiv { deaktiviereTimerModus() }
                    else { aktiverTimerModus = item.name; applyTimerModus(item.name) }
                } label: {
                    Text(istAktiv ? "Deaktivieren" : "Aktivieren")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(istAktiv ? .secondary : item.farbe)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(istAktiv ? Color.primary.opacity(0.07) : item.farbe.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if kannKaufen { kaufBestaetigung = item }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("\(item.kosten)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0).opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!kannKaufen)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(istAktiv ? item.farbe.opacity(0.5) : item.farbe.opacity(0.12), lineWidth: istAktiv ? 1.5 : 1))
        .opacity(istFreigeschaltet ? 1.0 : (kannKaufen ? 0.9 : 0.55))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: istAktiv)
        .contextMenu {
            if istFreigeschaltet {
                Button { if istAktiv { deaktiviereTimerModus() } else { aktiverTimerModus = item.name; applyTimerModus(item.name) } } label: {
                    Label(istAktiv ? "Deactivate" : "Activate", systemImage: istAktiv ? "xmark.circle" : "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) { verkaufBestaetigung = item } label: {
                    Label("Sell (\(item.kosten / 2) FP back)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button { kaufBestaetigung = item } label: {
                    Label("Unlock (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
            }
        }
    }

    // ── Feature-Zelle ─────────────────────────────────────────────────────
    private func featureZelle(_ item: StoreItem) -> some View {
        let istFreigeschaltet = freigeschalteteItems.contains(item.name)
        let istAktiv: Bool = {
            switch item.name {
            case "Aktivitäts-Heatmap": return istFreigeschaltet
            case "Prioritäts-Emojis": return aktivePriorityStyle == "emoji"
            case "Konfetti-Effekt": return konfettiEnabled
            case "Fokus-Sperrmodus": return fokusSperrmodus
            case "Tägliches Fokus-Ziel": return dailyGoalEnabled
            case "Streak-Tracker": return fokusStreakEnabled
            case "Fokus-Zitat": return fokusZitatEnabled
            case "Wochenrückblick": return wochenrueckblickEnabled
            default: return false
            }
        }()
        let kannKaufen = !istFreigeschaltet && fokuspunkteVerfuegbar >= item.kosten

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(istFreigeschaltet ? item.farbe.opacity(0.18) : item.farbe.opacity(0.07))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : item.farbe.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(istFreigeschaltet ? .primary : .secondary)
                    if istAktiv {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(item.farbe)
                    }
                }
                Text(item.beschreibung)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if istFreigeschaltet {
                let isToggleable = ["Prioritäts-Emojis", "Konfetti-Effekt", "Fokus-Sperrmodus", "Tägliches Fokus-Ziel", "Streak-Tracker", "Fokus-Zitat", "Wochenrückblick"].contains(item.name)
                if isToggleable {
                    Button {
                        switch item.name {
                        case "Prioritäts-Emojis": aktivePriorityStyle = aktivePriorityStyle == "emoji" ? "standard" : "emoji"
                        case "Konfetti-Effekt": konfettiEnabled.toggle()
                        case "Fokus-Sperrmodus": fokusSperrmodus.toggle()
                        case "Tägliches Fokus-Ziel": dailyGoalEnabled.toggle()
                        case "Streak-Tracker": fokusStreakEnabled.toggle()
                        case "Fokus-Zitat": fokusZitatEnabled.toggle()
                        case "Wochenrückblick": wochenrueckblickEnabled.toggle()
                        default: break
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(istAktiv ? item.farbe : Color.secondary.opacity(0.4))
                                .frame(width: 6, height: 6)
                            Text(istAktiv ? "An" : "Aus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(istAktiv ? item.farbe : .secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(istAktiv ? item.farbe.opacity(0.12) : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(item.farbe.opacity(0.7))
                        .padding(.trailing, 4)
                }
            } else {
                Button {
                    if kannKaufen { kaufBestaetigung = item }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("\(item.kosten)").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0).opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!kannKaufen)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(istAktiv ? item.farbe.opacity(0.5) : item.farbe.opacity(0.12), lineWidth: istAktiv ? 1.5 : 1))
        .opacity(istFreigeschaltet ? 1.0 : (kannKaufen ? 0.9 : 0.55))
        .contextMenu {
            let isToggleable = ["Prioritäts-Emojis", "Konfetti-Effekt", "Fokus-Sperrmodus", "Tägliches Fokus-Ziel", "Streak-Tracker", "Fokus-Zitat", "Wochenrückblick"].contains(item.name)
            if istFreigeschaltet && isToggleable {
                Button {
                    switch item.name {
                    case "Prioritäts-Emojis": aktivePriorityStyle = istAktiv ? "standard" : "emoji"
                    case "Konfetti-Effekt": konfettiEnabled.toggle()
                    case "Fokus-Sperrmodus": fokusSperrmodus.toggle()
                    case "Tägliches Fokus-Ziel": dailyGoalEnabled.toggle()
                    case "Streak-Tracker": fokusStreakEnabled.toggle()
                    case "Fokus-Zitat": fokusZitatEnabled.toggle()
                    case "Wochenrückblick": wochenrueckblickEnabled.toggle()
                    default: break
                    }
                } label: {
                    Label(istAktiv ? "Deactivate" : "Activate", systemImage: istAktiv ? "xmark.circle" : "checkmark.circle")
                }
                Divider()
            }
            if istFreigeschaltet {
                Button(role: .destructive) { verkaufBestaetigung = item } label: {
                    Label("Sell (\(item.kosten / 2) FP back)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button { kaufBestaetigung = item } label: {
                    Label("Unlock (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
            }
        }
    }

    private func storeCell(_ item: StoreItem) -> some View {
        let istFreigeschaltet = freigeschalteteItems.contains(item.name)
        let istAktiv = aktivesThema == item.name
        let kannKaufen = !istFreigeschaltet && fokuspunkteVerfuegbar >= item.kosten
        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(istAktiv
                    ? LinearGradient(colors: [item.farbe.opacity(isDark ? 0.45 : 0.25), item.farbe.opacity(isDark ? 0.2 : 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : (istFreigeschaltet
                        ? LinearGradient(colors: [item.farbe.opacity(isDark ? 0.22 : 0.12), item.farbe.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [item.farbe.opacity(istAktiv ? 0.9 : (istFreigeschaltet ? 0.5 : (kannKaufen ? 0.35 : 0.12))),
                                         item.farbe.opacity(0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: istAktiv ? 2 : 1)
                )

            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(item.farbe.opacity(istFreigeschaltet ? 0.22 : 0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(istFreigeschaltet ? item.farbe : item.farbe.opacity(0.4))
                        .frame(width: 44, height: 44)
                    if istAktiv {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .padding(2).background(item.farbe, in: Circle())
                    } else if !istFreigeschaltet && !kannKaufen {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                            .padding(4).background(Color.black.opacity(0.4), in: Circle())
                    }
                }

                Text(item.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : .primary)

                // Status-Badge / Preis
                if istAktiv {
                    Text("Aktiv")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(item.farbe.gradient, in: Capsule())
                } else if istFreigeschaltet {
                    Text("Aktivieren")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(item.farbe)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(item.farbe.opacity(0.15), in: Capsule())
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        Text("\(item.kosten)").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .frame(height: 110)
        .opacity(istFreigeschaltet ? 1.0 : (kannKaufen ? 0.92 : 0.55))
        .shadow(color: istAktiv ? item.farbe.opacity(0.45) : (istFreigeschaltet ? item.farbe.opacity(0.15) : .clear), radius: istAktiv ? 12 : 6, x: 0, y: istAktiv ? 5 : 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: istAktiv)
        .onTapGesture {
            if istFreigeschaltet {
                aktiviereThema(item)
            } else if kannKaufen {
                kaufBestaetigung = item
            }
        }
        .contextMenu {
            if istFreigeschaltet {
                Button {
                    aktiviereThema(item)
                } label: {
                    Label(istAktiv ? "Deactivate" : "Activate", systemImage: istAktiv ? "xmark.circle" : "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) {
                    verkaufBestaetigung = item
                } label: {
                    Label("Sell (\(item.kosten / 2) FP back)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button {
                    kaufBestaetigung = item
                } label: {
                    Label("Unlock (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
            }
        }
    }

    // MARK: - Aktivitäts-Heatmap

    private func heatmapMonthLabel(_ date: Date, cal: Calendar) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "MMM"
        return df.string(from: date)
    }

    private var heatmapView: some View {
        let weekdayLabels = ["Mo", "", "Mi", "", "Fr", "", "So"]
        let weekdayColW: CGFloat = 24
        let cSpacing: CGFloat = 3

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let rawStart = cal.date(byAdding: .day, value: -111, to: today)! // 16 Wochen
        let weekdayRaw = cal.component(.weekday, from: rawStart)
        let daysBack = (weekdayRaw + 5) % 7
        let alignedStart = cal.date(byAdding: .day, value: -daysBack, to: rawStart)!

        var allDays: [Date?] = []
        var cursor = alignedStart
        while cursor <= today {
            allDays.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        while allDays.count % 7 != 0 { allDays.append(nil) }

        let weeks: [[Date?]] = stride(from: 0, to: allDays.count, by: 7).map { i in
            Array(allDays[i..<min(i + 7, allDays.count)])
        }
        let maxMinutes = max(todoStore.dailyFocusMinutes.values.max() ?? 1, 1)
        let totalDays = todoStore.dailyFocusMinutes.filter { $0.value > 0 }.count
        let nWeeks = CGFloat(weeks.count)

        // Zellgröße füllt exakt die verfügbare Breite (kein Scrollen)
        let availW = max(80, heatmapWidth - weekdayColW - 6)
        let cSize = max(4, (availW - cSpacing * (nWeeks - 1)) / nWeeks)
        let radius = max(2, cSize / 4)

        return VStack(alignment: .leading, spacing: 10) {
            // Breitenmessung
            Color.clear
                .frame(height: 0)
                .background(GeometryReader { geo in
                    Color.clear.onAppear { heatmapWidth = geo.size.width }
                })

            HStack(alignment: .top, spacing: 6) {
                // Wochentag-Labels (fest links, tippbar)
                VStack(alignment: .trailing, spacing: cSpacing) {
                    Color.clear.frame(height: 16)
                    ForEach(0..<7, id: \.self) { i in
                        let isSelected = selectedHeatmapWeekday == i
                        let label = weekdayLabels[i]
                        Text(label.isEmpty ? "·" : label)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(
                                label.isEmpty
                                    ? (isSelected ? Color.green.opacity(0.7) : Color.secondary.opacity(0.25))
                                    : (isSelected ? Color.green : Color.secondary)
                            )
                            .frame(width: weekdayColW, height: cSize, alignment: .trailing)
                            .scaleEffect(isSelected ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedHeatmapDay = nil
                                    selectedHeatmapWeekday = selectedHeatmapWeekday == i ? nil : i
                                }
                            }
                    }
                }

                // Grid — kein Scrollen, Zellen füllen die volle Breite
                HStack(alignment: .top, spacing: cSpacing) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cSpacing) {
                            let monthLabel: String = {
                                for d in week.compactMap({ $0 }) {
                                    if cal.component(.day, from: d) <= 7 {
                                        return heatmapMonthLabel(d, cal: cal)
                                    }
                                }
                                return ""
                            }()
                            Text(monthLabel.isEmpty ? " " : monthLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(monthLabel.isEmpty ? Color.clear : Color.secondary)
                                .frame(width: cSize, height: 16, alignment: .leading)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            ForEach(0..<7, id: \.self) { di in
                                if let day = week[di] {
                                    let minutes = todoStore.dailyFocusMinutes[day] ?? 0
                                    let intensity = CGFloat(minutes) / CGFloat(maxMinutes)
                                    let isToday = cal.isDateInToday(day)
                                    let isSelected = selectedHeatmapDay == day
                                    RoundedRectangle(cornerRadius: radius)
                                        .fill(minutes == 0
                                              ? Color.primary.opacity(0.07)
                                              : Color.green.opacity(0.15 + intensity * 0.75))
                                        .frame(width: cSize, height: cSize)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: radius)
                                                .stroke(
                                                    isSelected ? Color.white : (isToday ? Color.green : Color.clear),
                                                    lineWidth: isSelected ? 1.5 : 1
                                                )
                                        )
                                        .scaleEffect(isSelected ? 1.35 : 1.0)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
                                        .contentShape(Rectangle().size(CGSize(width: max(cSize, 20), height: max(cSize, 20))))
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                selectedHeatmapWeekday = nil
                                                selectedHeatmapDay = selectedHeatmapDay == day ? nil : day
                                            }
                                        }
                                } else {
                                    Color.clear.frame(width: cSize, height: cSize)
                                }
                            }
                        }
                    }
                }
            }

            heatmapDayTooltipView
            heatmapWeekdayTooltipView

            // Legende
            HStack(spacing: 6) {
                Text("Wenig").font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach([0.1, 0.3, 0.5, 0.75, 1.0], id: \.self) { v in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green.opacity(0.15 + v * 0.75))
                        .frame(width: 13, height: 13)
                }
                Text("Viel").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Text("\(totalDays) aktive Tage")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedHeatmapDay)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedHeatmapWeekday)
    }

    @ViewBuilder
    private var heatmapDayTooltipView: some View {
        if let day = selectedHeatmapDay {
            let minutes = todoStore.dailyFocusMinutes[day] ?? 0
            let df = heatmapDayFormatter()
            let h = minutes / 60
            let m = minutes % 60
            let timeText = h > 0 ? "\(h) Std. \(m) Min. Fokus" : "\(m) Min. Fokus"
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(minutes == 0 ? Color.primary.opacity(0.08) : Color.green.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: minutes == 0 ? "moon.zzz.fill" : "timer")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(minutes == 0 ? Color.secondary : Color.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(df.string(from: day))
                        .font(.system(size: 12, weight: .semibold))
                    if minutes == 0 {
                        Text("Kein Fokus").font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        Text(timeText).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.green)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedHeatmapDay = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(minutes == 0 ? 0 : 0.35), lineWidth: 1))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var heatmapWeekdayTooltipView: some View {
        if let wd = selectedHeatmapWeekday {
            let stats = weekdayStats(for: wd)
            let bestDF = heatmapShortFormatter()
            let ah = stats.avg / 60; let am = stats.avg % 60
            let th = stats.total / 60; let tm = stats.total % 60
            let avgText = stats.avg == 0 ? "–" : (ah > 0 ? "\(ah)h \(am)m" : "\(am) min")
            let totalText = stats.total == 0 ? "–" : (th > 0 ? "\(th)h \(tm)m" : "\(tm) min")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(stats.avg == 0 ? 0.07 : 0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: stats.avg == 0 ? "moon.zzz.fill" : "chart.bar.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(stats.avg == 0 ? Color.secondary : Color.green)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.name).font(.system(size: 13, weight: .bold))
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ø Fokus").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(avgText).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(stats.avg == 0 ? Color.secondary : Color.green)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Gesamt").font(.system(size: 9)).foregroundStyle(.secondary)
                            Text(totalText).font(.system(size: 11, weight: .semibold))
                        }
                        if let best = stats.best, best.minutes > 0 {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Bester Tag").font(.system(size: 9)).foregroundStyle(.secondary)
                                Text(bestDF.string(from: best.date))
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.orange)
                            }
                        }
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedHeatmapWeekday = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.green.opacity(stats.avg == 0 ? 0 : 0.35), lineWidth: 1))
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }

    private struct WeekdayStats {
        let name: String
        let avg: Int
        let total: Int
        let best: (date: Date, minutes: Int)?
    }

    private func weekdayStats(for wd: Int) -> WeekdayStats {
        let fullNames = ["Montag","Dienstag","Mittwoch","Donnerstag","Freitag","Samstag","Sonntag"]
        let calWD = wd < 6 ? wd + 2 : 1
        var cal2 = Calendar(identifier: .gregorian)
        cal2.firstWeekday = 2
        let matching = todoStore.dailyFocusMinutes.filter { cal2.component(.weekday, from: $0.key) == calWD }
        let total = matching.values.reduce(0, +)
        let avg = matching.isEmpty ? 0 : total / matching.count
        let bestEntry = matching.max(by: { $0.value < $1.value })
        let best = bestEntry.map { (date: $0.key, minutes: $0.value) }
        return WeekdayStats(name: fullNames[wd], avg: avg, total: total, best: best)
    }

    private func heatmapDayFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f
    }

    private func heatmapShortFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM yyyy"
        return f
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                bigStatCell(value: "\(totalTasks)",     label: localizer.localizedString(forKey: "overview_total"),     icon: "list.bullet",             color: .blue)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(completedTasks)", label: localizer.localizedString(forKey: "overview_completed"), icon: "checkmark.circle.fill",   color: .green)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(openTasks)",      label: localizer.localizedString(forKey: "overview_open"),      icon: "square.and.pencil",        color: .orange)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(overdueTasks)",   label: localizer.localizedString(forKey: "overview_overdue"),   icon: "exclamationmark.triangle", color: .red)
            }
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(isDark ? 0.12 : 0.65), Color.white.opacity(isDark ? 0.04 : 0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)

            glassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        iconBadge(icon: "percent", color: .purple)
                        Text(String(format: localizer.localizedString(forKey: "overview_completion_rate"), Int(completionRate * 100)))
                            .font(.system(size: 15))
                        Spacer()
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.purple)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.07)).frame(height: 12)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * completionRate, height: 12)
                                .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.45), value: completionRate)
                        }
                    }
                    .frame(height: 12)
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
            }
        }
    }

    // MARK: - Today Card

    private var todayCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(todayCompletedTasks)")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.green)
                        .contentTransition(.numericText())
                    Text(localizer.localizedString(forKey: "today_completed"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)

                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 60)

                VStack(spacing: 4) {
                    Text("\(todayOpenTasks)")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                        .contentTransition(.numericText())
                    Text(localizer.localizedString(forKey: "today_due"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }

            cardDivider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    iconBadge(icon: "sun.max.fill", color: .orange)
                    Text(String(format: localizer.localizedString(forKey: "today_completion_rate"), Int(todayCompletionRate * 100)))
                        .font(.system(size: 15))
                    Spacer()
                    Text("\(Int(todayCompletionRate * 100))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.07)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * todayCompletionRate, height: 10)
                            .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: todayCompletionRate)
                    }
                }
                .frame(height: 10)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    // MARK: - Category Card

    private var categoryCard: some View {
        Group {
            if todoStore.categories.isEmpty {
                HStack {
                    Spacer()
                    Text(localizer.localizedString(forKey: "category_distribution_empty"))
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(tasksByCategory, id: \.name) { item in
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(item.color.opacity(0.15)).frame(width: 44, height: 44)
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(item.color)
                                        .contentTransition(.numericText())
                                }
                                Text(item.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Focus Card

    private var focusCard: some View {
        VStack(spacing: 0) {
            // Today row with streak badge
            HStack(spacing: 12) {
                iconBadge(icon: "flame.fill", color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(focusTodayDateText).font(.system(size: 13)).foregroundStyle(.secondary)
                    Text("Heute: \(focusTodayMinutes) Min.")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                if todoStore.focusStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.yellow)
                        Text("\(todoStore.focusStreak) Tage")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            // Goal progress bar
            if dailyGoal > 0 {
                HStack(alignment: .center, spacing: 12) {
                    iconBadge(icon: "target", color: chartAccentColors[0])
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(focusTodayMinutes)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("/ \(dailyGoal) min Tagesziel")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 5)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(colors: chartAccentColors, startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(focusGoalProgress), height: 5)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: focusTodayMinutes)
                            }
                        }
                        .frame(height: 5)
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text("\(timerManager.todayCompletedSessions)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(chartAccentColors[0])
                        Text("Sessions")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                Divider().padding(.leading, 58).opacity(0.45)
            }

            cardDivider()

            // Total focus time
            HStack(spacing: 12) {
                iconBadge(icon: "timer", color: .cyan)
                Text("Gesamt Fokuszeit")
                    .font(.system(size: 16))
                Spacer()
                let h = totalFocusMinutesAll / 60
                let m = totalFocusMinutesAll % 60
                Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            cardDivider()

            // Weekly chart
            focusWeeklyChart
                .padding(.horizontal, 16).padding(.vertical, 14)
        }
    }

    private var focusWeeklyChart: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Verlauf – 7 Tage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let avg = todoStore.weeklyFocusAverage
                if avg > 0 {
                    Text("Ø \(avg) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                let data = todoStore.weeklyFocusData
                let maxVal = max(data.map(\.minutes).max() ?? 1, dailyGoal > 0 ? dailyGoal : 1, 1)
                let gap: CGFloat = 5
                let barW = (geo.size.width - gap * CGFloat(data.count - 1)) / CGFloat(max(1, data.count))

                ZStack(alignment: .bottomLeading) {
                    if dailyGoal > 0 {
                        let goalFrac = CGFloat(dailyGoal) / CGFloat(maxVal)
                        let goalY = geo.size.height * (1 - goalFrac)
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: goalY))
                            p.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                        }
                        .stroke(chartAccentColors[0].opacity(0.5),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }

                    HStack(alignment: .bottom, spacing: gap) {
                        ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                            let frac = CGFloat(item.minutes) / CGFloat(maxVal)
                            let isToday = Calendar.current.isDateInToday(item.date)
                            let goalMet = dailyGoal > 0 && item.minutes >= dailyGoal
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    goalMet
                                    ? LinearGradient(colors: chartAccentColors, startPoint: .bottom, endPoint: .top)
                                    : LinearGradient(
                                        colors: [chartAccentColors[0].opacity(isToday ? 0.8 : 0.3),
                                                 chartAccentColors[0].opacity(isToday ? 0.5 : 0.18)],
                                        startPoint: .bottom, endPoint: .top)
                                )
                                .frame(width: barW, height: max(3, frac * geo.size.height))
                        }
                    }
                    .frame(height: geo.size.height, alignment: .bottom)
                }
            }
            .frame(height: 54)

            HStack(spacing: 0) {
                ForEach(Array(todoStore.weeklyFocusData.enumerated()), id: \.offset) { _, item in
                    Text(weekdayLabel(item.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Calendar.current.isDateInToday(item.date)
                                         ? chartAccentColors[0] : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Rings Card

    private var ringsCard: some View {
        HStack(spacing: 0) {
            CompletionRing(title: localizer.localizedString(forKey: "progress_today"),    value: todayCompletionRate, color: .orange)
            CompletionRing(title: localizer.localizedString(forKey: "progress_total"),    value: completionRate,      color: .purple)
            CompletionRing(title: localizer.localizedString(forKey: "progress_critical"), value: min(1.0, Double(overdueTasks) / Double(max(1, openTasks))), color: .red)
        }
        .padding(.horizontal, 16).padding(.vertical, 20)
    }

    // MARK: - Design Components

    private func bigStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let hasTema = !aktivesThema.isEmpty
        let (c1, c2, _) = aktiveThemaFarben
        return VStack(spacing: 0) { content() }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [c1.opacity(isDark ? 0.14 : 0.09),
                                 c2.opacity(isDark ? 0.07 : 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(hasTema ? 1.0 : 0.0)
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: hasTema
                        ? [c1.opacity(isDark ? 0.50 : 0.32), c2.opacity(isDark ? 0.22 : 0.16)]
                        : [Color.white.opacity(isDark ? 0.13 : 0.65), Color.white.opacity(isDark ? 0.04 : 0.20)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
            .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.5), value: aktivesThema)
    }

    private func sectionGroup<Content: View>(icon: String, label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                Text(label.uppercased()).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6).padding(.bottom, 7)
            content()
        }
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(LinearGradient(colors: [color, color.opacity(0.72)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: color.opacity(0.38), radius: 4, x: 0, y: 2)
    }

    private func cardDivider() -> some View {
        Divider().padding(.leading, 58).opacity(0.45)
    }
}

// MARK: - Supporting Views (unverändert)

struct MiniStatCard: View {
    var title: String; var value: String; var icon: String; var color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color)
                .padding(8).background(color.opacity(0.2)).clipShape(Circle())
            Text(value).font(.system(size: 16, weight: .bold)).contentTransition(.numericText())
            Text(title).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(6)
    }
}

struct ShareData: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ProgressBar: View {
    var value: Double; var color: Color
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.15)).frame(height: geometry.size.height)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(CGFloat(value), 1)) * geometry.size.width, height: geometry.size.height)
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 8)
    }
}

struct CompletionRing: View {
    var title: String; var value: Double; var color: Color
    private var clamped: Double { max(0, min(value, 1)) }
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 8)
                Circle().trim(from: 0, to: clamped)
                    .stroke(AngularGradient(gradient: Gradient(colors: [color.opacity(0.7), color]), center: .center),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: clamped)
                Text("\(Int(clamped * 100))%").font(.system(size: 14, weight: .bold)).foregroundColor(color)
            }
            .frame(width: 64, height: 64)
            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
