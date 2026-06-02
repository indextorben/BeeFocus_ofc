import SwiftUI

struct MacStatistikView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("fokuspunkteAusgegeben")  private var fokuspunkteAusgegeben: Int    = 0
    @AppStorage("fokuspunktePeak")        private var fokuspunktePeak: Int           = 0
    @AppStorage("freigeschalteteItems")   private var freigeschalteteItemsString: String = ""
    @AppStorage("aktivesStatistikThema")  private var aktivesThema: String           = ""
    @AppStorage("aktiverTimerModus")      private var aktiverTimerModus: String       = ""
    @AppStorage("aktivePriorityStyle")    private var aktivePriorityStyle: String     = "standard"
    @AppStorage("konfettiEnabled")        private var konfettiEnabled: Bool           = false
    @AppStorage("fokusSperrmodus")        private var fokusSperrmodus: Bool           = false

    @State private var headerAppeared   = false
    @State private var sectionsAppeared = false
    @State private var storeTab: StoreTab = .themes
    @State private var kaufBestaetigung: StoreItem?  = nil
    @State private var verkaufBestaetigung: StoreItem? = nil
    @State private var kaufErfolg: String? = nil
    @State private var showFPInfo = false

    private let cal = Calendar.current
    private var isDark: Bool { colorScheme == .dark }

    // MARK: - Enums & Models

    enum StoreTab: String, CaseIterable {
        case themes   = "Themes"
        case timer    = "Timer"
        case features = "Features"
        var icon: String {
            switch self { case .themes: "paintpalette.fill"; case .timer: "clock.fill"; case .features: "star.fill" }
        }
        var farbe: Color {
            switch self { case .themes: .purple; case .timer: .blue; case .features: .orange }
        }
    }

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
        StoreItem(name: "Ozean",           icon: "water.waves",              kosten: 500,   farbe: .cyan,                                    beschreibung: "Ruhige Wellen, tiefes Blau"),
        StoreItem(name: "Wald",            icon: "leaf.fill",                kosten: 750,   farbe: .green,                                   beschreibung: "Frische Natur, lebendiges Grün"),
        StoreItem(name: "Eis",             icon: "snowflake",                kosten: 800,   farbe: Color(red: 0.6, green: 0.9, blue: 1.0),   beschreibung: "Kühle Stille, kristallklares Weiß"),
        StoreItem(name: "Herbst",          icon: "wind",                     kosten: 900,   farbe: Color(red: 0.8, green: 0.4, blue: 0.1),   beschreibung: "Warme Töne, goldenes Laub"),
        StoreItem(name: "Nacht",           icon: "moon.stars.fill",          kosten: 1000,  farbe: .indigo,                                  beschreibung: "Samtene Dunkelheit, funkelnde Sterne"),
        StoreItem(name: "Lavendel",        icon: "sparkles",                 kosten: 1200,  farbe: .purple,                                  beschreibung: "Sanftes Violett, duftende Felder"),
        StoreItem(name: "Solar",           icon: "sun.max.fill",             kosten: 1500,  farbe: .orange,                                  beschreibung: "Energie der Sonne, strahlend warm"),
        StoreItem(name: "Sonnenuntergang", icon: "sunset.fill",              kosten: 1800,  farbe: Color(red: 1.0, green: 0.4, blue: 0.2),   beschreibung: "Glühendes Abendhimmel-Orange"),
        StoreItem(name: "Kirschblüte",     icon: "camera.macro",             kosten: 2000,  farbe: .pink,                                    beschreibung: "Zarte Blüten, japanisches Frühjahr"),
        StoreItem(name: "Nordlicht",       icon: "aqi.medium",               kosten: 2500,  farbe: Color(red: 0.0, green: 0.8, blue: 0.6),   beschreibung: "Magisches Aurora-Spektakel"),
        StoreItem(name: "Vulkan",          icon: "flame.fill",               kosten: 3000,  farbe: .red,                                     beschreibung: "Brennende Intensität, pure Kraft"),
        StoreItem(name: "Galaxie",         icon: "moon.circle.fill",         kosten: 5000,  farbe: Color(red: 0.4, green: 0.2, blue: 1.0),   beschreibung: "Endloses Universum, kosmische Tiefe"),
        StoreItem(name: "Aurora",          icon: "aqi.high",                 kosten: 10000, farbe: Color(red: 0.0, green: 0.9, blue: 0.8),   beschreibung: "Elektrischer Auroraschimmer · Exklusiv"),
        StoreItem(name: "Obsidian",        icon: "crown.fill",               kosten: 15000, farbe: Color(red: 0.85, green: 0.65, blue: 0.1), beschreibung: "Edler Obsidian, reines Gold · Prestige"),
        StoreItem(name: "Nebula",          icon: "rays",                     kosten: 20000, farbe: Color(red: 1.0, green: 0.2, blue: 0.65),  beschreibung: "Kosmischer Nebel · Legendär"),

        StoreItem(name: "Tiefenfokus",    icon: "brain.head.profile",        kosten: 800,   farbe: .indigo, tab: .timer,
                  beschreibung: "90 min Fokus · 20 min Pause\nIdeal für komplexe, kreative Aufgaben"),
        StoreItem(name: "52/17 Methode", icon: "clock.badge.checkmark.fill", kosten: 1000,  farbe: .blue,   tab: .timer,
                  beschreibung: "52 min Fokus · 17 min Pause\nMaximale Konzentration ohne Burnout"),
        StoreItem(name: "Micro-Sprint",   icon: "bolt.circle.fill",          kosten: 400,   farbe: .yellow, tab: .timer,
                  beschreibung: "10 min Fokus · 3 min Pause\nSchnelle Energie-Schübe für schwere Starts"),

        StoreItem(name: "Prioritäts-Emojis",  icon: "face.smiling.fill",  kosten: 600,  farbe: .pink,   tab: .features,
                  beschreibung: "Ersetze Text-Prioritäts-Badges durch ausdrucksstarke Emojis 🔴🟡🟢"),
        StoreItem(name: "Konfetti-Effekt",    icon: "party.popper.fill",  kosten: 800,  farbe: .yellow, tab: .features,
                  beschreibung: "Feiere jeden Aufgaben-Abschluss mit einem bunten Konfetti-Regen 🎉"),
        StoreItem(name: "Fokus-Sperrmodus",   icon: "lock.shield.fill",   kosten: 1200, farbe: .indigo, tab: .features,
                  beschreibung: "Sperrt Bearbeiten & Löschen während der Fokuszeit – keine Ablenkung"),
    ]}

    // MARK: - Computed Stats

    private var freigeschalteteItems: Set<String> {
        Set(freigeschalteteItemsString.components(separatedBy: ",").filter { !$0.isEmpty })
    }
    var completedTasks: Int  { todoStore.todos.filter { $0.isCompleted }.count }
    var openTasks: Int       { todoStore.activeTodos.count }
    var totalTasks: Int      { openTasks + completedTasks }
    var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }
    var overdueTasks: Int    { todoStore.overdueTodos.count }

    var todayCompletedTasks: Int {
        todoStore.todos.filter { $0.isCompleted && cal.isDateInToday($0.updatedAt) }.count
    }
    var todayOpenTasks: Int {
        todoStore.todos.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return cal.isDateInToday(due)
        }.count
    }
    var todayCompletionRate: Double {
        let total = todayCompletedTasks + todayOpenTasks
        return total > 0 ? Double(todayCompletedTasks) / Double(total) : 0
    }

    private var aktiveThemaFarben: (Color, Color, Color) {
        aktivesThema.isEmpty ? (.purple, .blue, Color(red: 1, green: 0.6, blue: 0.2)) : appThemaFarben(aktivesThema)
    }

    var motivationText: String {
        switch completionRate {
        case 0:       return "Los geht's – du schaffst das!"
        case ..<0.25: return "Guter Start, weiter so!"
        case ..<0.5:  return "Du bist auf dem richtigen Weg!"
        case ..<0.75: return "Mehr als die Hälfte geschafft!"
        case ..<1.0:  return "Fast am Ziel – stark!"
        default:      return "Alles erledigt – fantastisch!"
        }
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while true {
            let count = todoStore.todos.filter { $0.isCompleted && cal.isDate($0.updatedAt, inSameDayAs: day) }.count
            if count == 0 { break }
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    // MARK: - Fokuspunkte

    private var fokuspunkteAktuellBerechnet: Int {
        completedTasks * 10
        + timerMgr.sessionCount * 25
        + todoStore.todos.filter { $0.isFavorite }.count * 5
    }
    var fokuspunkteGesamt: Int      { max(fokuspunktePeak, fokuspunkteAktuellBerechnet) }
    var fokuspunkteVerfuegbar: Int  { max(0, fokuspunkteGesamt - fokuspunkteAusgegeben) }

    var fokuspunkteStufe: (name: String, icon: String, farbe: Color) {
        switch fokuspunkteVerfuegbar {
        case 0..<100:  return ("Anfänger",  "seedling",           .green)
        case ..<300:   return ("Lernender", "book.fill",          .teal)
        case ..<600:   return ("Fokussiert","brain.head.profile", .blue)
        case ..<1000:  return ("Produktiv", "bolt.fill",          .indigo)
        case ..<2000:  return ("Experte",   "star.fill",          .purple)
        case ..<5000:  return ("Meister",   "crown.fill",         .orange)
        default:       return ("Legende",   "flame.fill",         Color(red: 1, green: 0.3, blue: 0.1))
        }
    }

    // MARK: - Timer Modus

    private func timerModusLabel(_ name: String) -> String {
        switch name {
        case "Tiefenfokus":   return "90 / 20 min"
        case "52/17 Methode": return "52 / 17 min"
        case "Micro-Sprint":  return "10 / 3 min"
        default: return ""
        }
    }

    private func applyTimerModus(_ name: String) {
        switch name {
        case "Tiefenfokus":
            timerMgr.focusDuration = 90; timerMgr.shortBreak = 20; timerMgr.longBreak = 30
        case "52/17 Methode":
            timerMgr.focusDuration = 52; timerMgr.shortBreak = 17; timerMgr.longBreak = 17
        case "Micro-Sprint":
            timerMgr.focusDuration = 10; timerMgr.shortBreak = 3;  timerMgr.longBreak = 10
        default: break
        }
        UserDefaults.standard.set(timerMgr.focusDuration, forKey: "mac_focusDuration")
        UserDefaults.standard.set(timerMgr.shortBreak,    forKey: "mac_shortBreak")
        UserDefaults.standard.set(timerMgr.longBreak,     forKey: "mac_longBreak")
        if timerMgr.mode == .focus { timerMgr.resetToCurrentMode() }
    }

    private func deaktiviereTimerModus() {
        aktiverTimerModus = ""
        timerMgr.focusDuration = 25; timerMgr.shortBreak = 5; timerMgr.longBreak = 15
        UserDefaults.standard.set(25, forKey: "mac_focusDuration")
        UserDefaults.standard.set(5,  forKey: "mac_shortBreak")
        UserDefaults.standard.set(15, forKey: "mac_longBreak")
        timerMgr.resetToCurrentMode()
    }

    // MARK: - Store Logic

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
            if item.name == "Prioritäts-Emojis"  { aktivePriorityStyle = "emoji" }
            if item.name == "Konfetti-Effekt"     { konfettiEnabled = true }
            if item.name == "Fokus-Sperrmodus"    { fokusSperrmodus = true }
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
            if item.name == "Prioritäts-Emojis" && aktivePriorityStyle == "emoji" { aktivePriorityStyle = "standard" }
            if item.name == "Konfetti-Effekt"  { konfettiEnabled = false }
            if item.name == "Fokus-Sperrmodus" { fokusSperrmodus = false }
        }
    }

    // MARK: - Weekly Data

    private var last7Days: [Date] {
        (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: Date()) }
                          .map { cal.startOfDay(for: $0) }
    }
    private func completedOn(_ day: Date) -> Int {
        todoStore.todos.filter { $0.isCompleted && cal.isDate($0.updatedAt, inSameDayAs: day) }.count
    }
    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; f.locale = Locale(identifier: "de_DE")
        return String(f.string(from: date).prefix(2)).capitalized
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    headerHero.padding(.bottom, 4)

                    motivationBanner
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 12)
                        .animation(.easeOut(duration: 0.4).delay(0.1), value: sectionsAppeared)

                    animatedSection(delay: 0.05) { fokuspunkteCard }
                    animatedSection(delay: 0.10) {
                        sectionGroup(icon: "storefront.fill", label: "Fokus-Store", color: Color(red: 1, green: 0.55, blue: 0.0)) { storeCard }
                    }
                    animatedSection(delay: 0.15) {
                        sectionGroup(icon: "chart.bar.fill", label: "ÜBERSICHT", color: .purple) { overviewCard }
                    }
                    animatedSection(delay: 0.20) {
                        sectionGroup(icon: "sun.max.fill", label: "HEUTE", color: .orange) {
                            glassCard { todayCard }
                        }
                    }
                    animatedSection(delay: 0.25) {
                        sectionGroup(icon: "timer", label: "FOKUS-TIMER", color: .cyan) {
                            glassCard { focusCard }
                        }
                    }
                    animatedSection(delay: 0.30) {
                        sectionGroup(icon: "circle.dashed", label: "FORTSCHRITT", color: .indigo) {
                            glassCard { ringsCard }
                        }
                    }
                    animatedSection(delay: 0.35) {
                        sectionGroup(icon: "chart.bar.xaxis", label: "WOCHENÜBERSICHT", color: .teal) {
                            glassCard { weeklyChart }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { headerAppeared = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { sectionsAppeared = true }
            if fokuspunkteAktuellBerechnet > fokuspunktePeak { fokuspunktePeak = fokuspunkteAktuellBerechnet }
        }
        .onChange(of: fokuspunkteAktuellBerechnet) { v in
            if v > fokuspunktePeak { fokuspunktePeak = v }
        }
        .alert(kaufBestaetigung.map { "\"\($0.name)\" freischalten?" } ?? "",
               isPresented: Binding(get: { kaufBestaetigung != nil }, set: { if !$0 { kaufBestaetigung = nil } })) {
            if let item = kaufBestaetigung {
                Button("Freischalten (\(item.kosten) FP)") { kaufeItem(item); kaufBestaetigung = nil }
                Button("Abbrechen", role: .cancel) { kaufBestaetigung = nil }
            }
        } message: {
            if let item = kaufBestaetigung {
                Text("Kostet \(item.kosten) Fokuspunkte. Du hast \(fokuspunkteVerfuegbar) FP.")
            }
        }
        .alert(verkaufBestaetigung.map { "\"\($0.name)\" verkaufen?" } ?? "",
               isPresented: Binding(get: { verkaufBestaetigung != nil }, set: { if !$0 { verkaufBestaetigung = nil } })) {
            if let item = verkaufBestaetigung {
                Button("Verkaufen (\(item.kosten / 2) FP zurück)", role: .destructive) {
                    verkaufeItem(item); verkaufBestaetigung = nil
                }
                Button("Abbrechen", role: .cancel) { verkaufBestaetigung = nil }
            }
        } message: {
            if let item = verkaufBestaetigung {
                Text("Du erhältst \(item.kosten / 2) FP zurück.")
            }
        }
        .sheet(isPresented: $showFPInfo) { fokuspunkteInfoSheet }
    }

    // MARK: - Header Hero

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
                    .fill(LinearGradient(colors: [c1, c2.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: c1.opacity(0.45), radius: 18, x: 0, y: 8)
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .modifier(BounceSymbolEffect(value: aktivesThema))
            }
            .scaleEffect(headerAppeared ? 1 : 0.6).opacity(headerAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: headerAppeared)

            VStack(spacing: 5) {
                Text("Statistik")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing))
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
        let (c1, c2, _) = aktiveThemaFarben
        return HStack(spacing: 10) {
            Image(systemName: currentStreak > 0 ? "flame.fill" : "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(currentStreak > 0 ? Color.orange : c1)
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
            .strokeBorder(LinearGradient(
                colors: [c1.opacity(isDark ? 0.35 : 0.22), c2.opacity(isDark ? 0.12 : 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.5), value: aktivesThema)
    }

    // MARK: - Fokuspunkte Card

    private var fokuspunkteCard: some View {
        let stufe = fokuspunkteStufe
        let (fc1, fc2, _) = aktiveThemaFarben
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: isDark ? [fc1.opacity(0.65), fc2.opacity(0.45)] : [fc1, fc2],
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
                        .modifier(PulseSymbolEffect())
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Fokuspunkte").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                        Button { showFPInfo = true } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
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

                    if !aktivesThema.isEmpty || !aktiverTimerModus.isEmpty || aktivePriorityStyle == "emoji" || konfettiEnabled || fokusSperrmodus {
                        Divider().opacity(0.3)
                        VStack(spacing: 0) {
                            if !aktivesThema.isEmpty {
                                let (tc, _, _) = appThemaFarben(aktivesThema)
                                activeStatusRow(dot: tc, label: "Theme", value: aktivesThema, farbe: tc) {
                                    withAnimation { aktivesThema = "" }
                                }
                            }
                            if !aktiverTimerModus.isEmpty {
                                let item = storeItems.first { $0.name == aktiverTimerModus }
                                activeStatusRow(dot: item?.farbe ?? .blue, label: "Timer",
                                               value: "\(aktiverTimerModus) (\(timerModusLabel(aktiverTimerModus)))",
                                               farbe: item?.farbe ?? .blue) { deaktiviereTimerModus() }
                            }
                            if aktivePriorityStyle == "emoji" {
                                activeStatusRow(dot: .pink, label: "Priorität", value: "Emojis aktiv 🔴🟡🟢", farbe: .pink) {
                                    aktivePriorityStyle = "standard"
                                }
                            }
                            if konfettiEnabled {
                                activeStatusRow(dot: .yellow, label: "Konfetti", value: "An 🎉", farbe: .yellow) {
                                    konfettiEnabled = false
                                }
                            }
                            if fokusSperrmodus {
                                activeStatusRow(dot: .indigo, label: "Sperrmodus", value: "Aktiv 🔒", farbe: .indigo) {
                                    fokusSperrmodus = false
                                }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(StoreTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { storeTab = tab }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon).font(.system(size: 15, weight: .semibold))
                            Text(tab.rawValue).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(storeTab == tab ? tab.farbe : .secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(storeTab == tab ? tab.farbe.opacity(0.12) : Color.clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            switch storeTab {
            case .themes:
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
    }

    // MARK: - Store Cells

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
                    Circle().fill(item.farbe.opacity(istFreigeschaltet ? 0.22 : 0.10)).frame(width: 44, height: 44)
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
                Text(item.name).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : .primary).lineLimit(1)
                if istAktiv {
                    Text("Aktiv").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(item.farbe.gradient, in: Capsule())
                } else if istFreigeschaltet {
                    Text("Aktivieren").font(.system(size: 10, weight: .semibold)).foregroundStyle(item.farbe)
                        .padding(.horizontal, 8).padding(.vertical, 2).background(item.farbe.opacity(0.15), in: Capsule())
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
        .shadow(color: istAktiv ? item.farbe.opacity(0.45) : (istFreigeschaltet ? item.farbe.opacity(0.15) : .clear),
                radius: istAktiv ? 12 : 6, x: 0, y: istAktiv ? 5 : 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: istAktiv)
        .onTapGesture {
            if istFreigeschaltet { aktiviereThema(item) }
            else if kannKaufen { kaufBestaetigung = item }
        }
        .contextMenu {
            if istFreigeschaltet {
                Button { aktiviereThema(item) } label: {
                    Label(istAktiv ? "Deaktivieren" : "Aktivieren", systemImage: istAktiv ? "xmark.circle" : "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) { verkaufBestaetigung = item } label: {
                    Label("Verkaufen (\(item.kosten / 2) FP zurück)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button { kaufBestaetigung = item } label: {
                    Label("Freischalten (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
            }
        }
    }

    private func timerModusZelle(_ item: StoreItem) -> some View {
        let istFreigeschaltet = freigeschalteteItems.contains(item.name)
        let istAktiv = aktiverTimerModus == item.name
        let kannKaufen = !istFreigeschaltet && fokuspunkteVerfuegbar >= item.kosten
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(istFreigeschaltet ? item.farbe.opacity(0.18) : item.farbe.opacity(0.07))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : item.farbe.opacity(0.35))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(istFreigeschaltet ? .primary : .secondary)
                    if istAktiv {
                        Text("Aktiv").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(item.farbe.gradient, in: Capsule())
                    }
                }
                Text(item.beschreibung).font(.system(size: 11)).foregroundStyle(.secondary)
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
                Button { if kannKaufen { kaufBestaetigung = item } } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("\(item.kosten)").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0).opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain).disabled(!kannKaufen)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(istAktiv ? item.farbe.opacity(0.5) : item.farbe.opacity(0.12), lineWidth: istAktiv ? 1.5 : 1))
        .opacity(istFreigeschaltet ? 1.0 : (kannKaufen ? 0.9 : 0.55))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: istAktiv)
        .contextMenu {
            if istFreigeschaltet {
                Button {
                    if istAktiv { deaktiviereTimerModus() } else { aktiverTimerModus = item.name; applyTimerModus(item.name) }
                } label: {
                    Label(istAktiv ? "Deaktivieren" : "Aktivieren", systemImage: istAktiv ? "xmark.circle" : "checkmark.circle")
                }
                Divider()
                Button(role: .destructive) { verkaufBestaetigung = item } label: {
                    Label("Verkaufen (\(item.kosten / 2) FP zurück)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button { kaufBestaetigung = item } label: {
                    Label("Freischalten (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
            }
        }
    }

    private func featureZelle(_ item: StoreItem) -> some View {
        let istFreigeschaltet = freigeschalteteItems.contains(item.name)
        let istAktiv: Bool = {
            switch item.name {
            case "Prioritäts-Emojis": return aktivePriorityStyle == "emoji"
            case "Konfetti-Effekt":   return konfettiEnabled
            case "Fokus-Sperrmodus":  return fokusSperrmodus
            default: return false
            }
        }()
        let kannKaufen = !istFreigeschaltet && fokuspunkteVerfuegbar >= item.kosten
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(istFreigeschaltet ? item.farbe.opacity(0.18) : item.farbe.opacity(0.07))
                    .frame(width: 52, height: 52)
                Image(systemName: item.icon).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(istFreigeschaltet ? item.farbe : item.farbe.opacity(0.35))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name).font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(istFreigeschaltet ? .primary : .secondary)
                    if istAktiv {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(item.farbe)
                    }
                }
                Text(item.beschreibung).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if istFreigeschaltet {
                let isToggleable = ["Prioritäts-Emojis", "Konfetti-Effekt", "Fokus-Sperrmodus"].contains(item.name)
                if isToggleable {
                    Button {
                        switch item.name {
                        case "Prioritäts-Emojis": aktivePriorityStyle = aktivePriorityStyle == "emoji" ? "standard" : "emoji"
                        case "Konfetti-Effekt":   konfettiEnabled.toggle()
                        case "Fokus-Sperrmodus":  fokusSperrmodus.toggle()
                        default: break
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle().fill(istAktiv ? item.farbe : Color.secondary.opacity(0.4)).frame(width: 6, height: 6)
                            Text(istAktiv ? "An" : "Aus").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(istAktiv ? item.farbe : .secondary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(istAktiv ? item.farbe.opacity(0.12) : Color.primary.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                        .foregroundStyle(item.farbe.opacity(0.7)).padding(.trailing, 4)
                }
            } else {
                Button { if kannKaufen { kaufBestaetigung = item } } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("\(item.kosten)").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(kannKaufen ? Color(red: 1, green: 0.55, blue: 0.0).opacity(0.12) : Color.primary.opacity(0.05), in: Capsule())
                }
                .buttonStyle(.plain).disabled(!kannKaufen)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(istAktiv ? item.farbe.opacity(0.5) : item.farbe.opacity(0.12), lineWidth: istAktiv ? 1.5 : 1))
        .opacity(istFreigeschaltet ? 1.0 : (kannKaufen ? 0.9 : 0.55))
        .contextMenu {
            if istFreigeschaltet {
                Button(role: .destructive) { verkaufBestaetigung = item } label: {
                    Label("Verkaufen (\(item.kosten / 2) FP zurück)", systemImage: "arrow.uturn.left.circle")
                }
            } else if kannKaufen {
                Button { kaufBestaetigung = item } label: {
                    Label("Freischalten (\(item.kosten) FP)", systemImage: "lock.open.fill")
                }
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
                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                bigStatCell(value: "\(totalTasks)",     label: "Gesamt",      icon: "list.bullet",              color: .blue)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(completedTasks)", label: "Erledigt",    icon: "checkmark.circle.fill",    color: .green)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(openTasks)",      label: "Offen",       icon: "square.and.pencil",         color: .orange)
                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 64)
                bigStatCell(value: "\(overdueTasks)",   label: "Überfällig",  icon: "exclamationmark.triangle",  color: .red)
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
                        Text("Abschlussrate \(Int(completionRate * 100))%").font(.system(size: 15))
                        Spacer()
                        Text("\(Int(completionRate * 100))%")
                            .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.purple)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.07)).frame(height: 12)
                            RoundedRectangle(cornerRadius: 8)
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
                    Text("Heute erledigt").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)

                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 60)

                VStack(spacing: 4) {
                    Text("\(todayOpenTasks)")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    Text("Heute fällig").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }

            Divider().padding(.leading, 58).opacity(0.45)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    iconBadge(icon: "sun.max.fill", color: .orange)
                    Text("Heute-Rate \(Int(todayCompletionRate * 100))%").font(.system(size: 15))
                    Spacer()
                    Text("\(Int(todayCompletionRate * 100))%")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.07)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 8)
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

    // MARK: - Focus Card

    private var focusCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                iconBadge(icon: "timer", color: .cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktuelle Phase").font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(timerMgr.mode.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(timerMgr.mode.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timerMgr.timeString)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(timerMgr.mode.color)
                    Text("verbleibend").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Divider().padding(.leading, 58).opacity(0.45)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(timerMgr.sessionCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    Text("Sessions").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)

                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    Text("\(timerMgr.focusDuration) min")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                    Text("Fokuszeit").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)

                Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1, height: 50)

                VStack(spacing: 4) {
                    Text("\(timerMgr.shortBreak) min")
                        .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.mint)
                    Text("Pause").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
        }
    }

    // MARK: - Rings Card

    private var ringsCard: some View {
        HStack(spacing: 0) {
            MacCompletionRing(title: "Heute",      value: todayCompletionRate, color: .orange)
            MacCompletionRing(title: "Gesamt",     value: completionRate,      color: .purple)
            MacCompletionRing(title: "Kritisch",   value: min(1.0, Double(overdueTasks) / Double(max(1, openTasks))), color: .red)
        }
        .padding(.horizontal, 16).padding(.vertical, 20)
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(spacing: 12) {
            let (c1, c2, _) = aktiveThemaFarben
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(last7Days, id: \.self) { day in
                    let count = completedOn(day)
                    let maxCount = max(last7Days.map { completedOn($0) }.max() ?? 1, 1)
                    let height = max(CGFloat(count) / CGFloat(maxCount) * 100, 4)
                    let isToday = cal.isDateInToday(day)
                    VStack(spacing: 4) {
                        if count > 0 {
                            Text("\(count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isToday
                                ? LinearGradient(colors: [c2, c1], startPoint: .bottom, endPoint: .top)
                                : LinearGradient(colors: [c1.opacity(0.4), c1.opacity(0.25)], startPoint: .bottom, endPoint: .top))
                            .frame(height: height)
                        Text(dayLabel(day)).font(.system(size: 10))
                            .foregroundStyle(isToday ? c1 : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    // MARK: - FP Info Sheet

    private var fokuspunkteInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Fokuspunkte verdienen", systemImage: "bolt.fill")
                            .font(.headline).foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        Text("Fokuspunkte werden für deine Produktivität gutgeschrieben und sinken niemals automatisch – nur Käufe im Fokus-Store reduzieren dein Guthaben.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 0) {
                        fpInfoRow(icon: "checkmark.circle.fill", color: .green,   title: "Aufgabe abschließen", points: "+10 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "timer",                 color: .cyan,    title: "Fokus-Session",       points: "+25 FP")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "star.fill",             color: .yellow,  title: "Favorisierte Aufgabe", points: "+5 FP")
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Fokus-Store", systemImage: "storefront.fill")
                            .font(.headline).foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                        Text("Im Fokus-Store kannst du Farbthemen für die Statistik-Ansicht freischalten. Jedes Theme verändert den Hintergrund dieser Seite.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    VStack(spacing: 0) {
                        fpInfoRow(icon: "lock.open.fill",        color: .blue,    title: "Theme freischalten",          points: "FP ausgeben")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "checkmark.circle",      color: .green,   title: "Theme aktivieren / wechseln", points: "kostenlos")
                        Divider().padding(.leading, 52)
                        fpInfoRow(icon: "arrow.uturn.left.circle", color: .orange, title: "Theme verkaufen",             points: "½ FP zurück")
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(20)
            }
            .navigationTitle("Fokuspunkte & Store")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showFPInfo = false }.fontWeight(.semibold)
                }
            }
        }
        .frame(width: 480, height: 520)
    }

    private func fpInfoRow(icon: String, color: Color, title: String, points: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: color.opacity(0.35), radius: 3, x: 0, y: 2)
            Text(title).font(.system(size: 15))
            Spacer()
            Text(points).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Design Helpers

    private func animatedSection<C: View>(delay: Double, @ViewBuilder content: () -> C) -> some View {
        content()
            .opacity(sectionsAppeared ? 1 : 0)
            .offset(y: sectionsAppeared ? 0 : 18)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: sectionsAppeared)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let hasTema = !aktivesThema.isEmpty
        let (c1, c2, _) = aktiveThemaFarben
        return VStack(spacing: 0) { content() }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [c1.opacity(isDark ? 0.14 : 0.09), c2.opacity(isDark ? 0.07 : 0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
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
        Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: color.opacity(0.38), radius: 4, x: 0, y: 2)
    }

    private func bigStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - symbolEffect availability shims

private struct BounceSymbolEffect: ViewModifier {
    let value: String
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.bounce, value: value)
        } else {
            content
        }
    }
}

private struct PulseSymbolEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.pulse)
        } else {
            content
        }
    }
}

// MARK: - MacCompletionRing

struct MacCompletionRing: View {
    var title: String
    var value: Double
    var color: Color
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
                Text("\(Int(clamped * 100))%").font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            .frame(width: 64, height: 64)
            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
