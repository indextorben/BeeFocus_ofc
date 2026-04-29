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
    @AppStorage("fokuspunkteAusgegeben") private var fokuspunkteAusgegeben: Int = 0

    var isDark: Bool { colorScheme == .dark }

    // MARK: - Store Item Model
    struct StoreItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let kosten: Int
        let farbe: Color
    }

    var storeItems: [StoreItem] {[
        StoreItem(name: "Ozean",       icon: "water.waves",       kosten: 500,  farbe: .cyan),
        StoreItem(name: "Wald",        icon: "leaf.fill",         kosten: 750,  farbe: .green),
        StoreItem(name: "Nacht",       icon: "moon.stars.fill",   kosten: 1000, farbe: .indigo),
        StoreItem(name: "Solar",       icon: "sun.max.fill",      kosten: 1500, farbe: .orange),
        StoreItem(name: "Kirschblüte", icon: "camera.macro",      kosten: 2000, farbe: .pink),
        StoreItem(name: "Vulkan",      icon: "flame.fill",        kosten: 3000, farbe: .red),
    ]}

    // MARK: - Basisstatistiken
    var completedTasks: Int { todoStore.todos.filter { $0.isCompleted }.count }
    var openTasks: Int     { todoStore.todos.filter { !$0.isCompleted }.count }
    var totalTasks: Int    { openTasks + completedTasks }
    var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }

    var todayOpenTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.todos.filter { item in
            guard let due = item.dueDate else { return false }
            return !item.isCompleted && Calendar.current.isDate(due, inSameDayAs: today)
        }.count
    }

    var todayCompletedTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.todos.filter { item in
            guard let due = item.dueDate else { return false }
            return item.isCompleted && Calendar.current.isDate(due, inSameDayAs: today)
        }.count
    }

    var overdueTasks: Int {
        todoStore.todos.filter { item in
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
            let count = todoStore.todos.filter { $0.category?.id == cat.id && !$0.isCompleted }.count
            return (cat.name, count, cat.color)
        }.sorted { $0.count > $1.count }
    }

    // MARK: - Fokus
    private var focusTodayMinutes: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.dailyFocusMinutes[today] ?? 0
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

    // MARK: - Fokuspunkte System
    var fokuspunkteGesamt: Int {
        completedTasks * 10
        + totalFocusMinutesAll * 2
        + currentStreak * 50
        + todoStore.todos.filter { $0.isFavorite }.count * 5
        + todoStore.todos.filter { $0.isRecurring }.count * 3
    }

    var fokuspunkteVerfuegbar: Int { max(0, fokuspunkteGesamt - fokuspunkteAusgegeben) }

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

    var motivationText: String {
        switch completionRate {
        case 0:      return "Los geht's – du schaffst das!"
        case ..<0.25: return "Guter Start, weiter so!"
        case ..<0.5:  return "Du bist auf dem richtigen Weg!"
        case ..<0.75: return "Mehr als die Hälfte geschafft!"
        case ..<1.0:  return "Fast am Ziel – stark!"
        default:      return "Alles erledigt – fantastisch!"
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerHero.padding(.bottom, 4)

                        // Motivations-Banner
                        motivationBanner
                            .opacity(sectionsAppeared ? 1 : 0)
                            .offset(y: sectionsAppeared ? 0 : 12)
                            .animation(.easeOut(duration: 0.4).delay(0.1), value: sectionsAppeared)

                        // Fokuspunkte
                        animatedSection(delay: 0.05) { fokuspunkteCard }

                        // Store
                        animatedSection(delay: 0.10) {
                            sectionGroup(icon: "storefront.fill", label: "Fokus-Store", color: Color(red: 1, green: 0.55, blue: 0.0)) {
                                storeCard
                            }
                        }

                        // Übersicht
                        animatedSection(delay: 0.15) {
                            sectionGroup(icon: "chart.bar.fill", label: localizer.localizedString(forKey: "overview_title"), color: .purple) {
                                overviewCard
                            }
                        }

                        // Heutige Aktivität
                        animatedSection(delay: 0.20) {
                            sectionGroup(icon: "sun.max.fill", label: localizer.localizedString(forKey: "today_activity_title"), color: .orange) {
                                glassCard { todayCard }
                            }
                        }

                        // Kategorien
                        animatedSection(delay: 0.25) {
                            sectionGroup(icon: "tag.fill", label: localizer.localizedString(forKey: "category_distribution_title"), color: .blue) {
                                glassCard { categoryCard }
                            }
                        }

                        // Fokuszeit
                        animatedSection(delay: 0.30) {
                            sectionGroup(icon: "timer", label: "Fokuszeit", color: .cyan) {
                                glassCard { focusCard }
                            }
                        }

                        // Ringe
                        animatedSection(delay: 0.35) {
                            sectionGroup(icon: "circle.dashed", label: localizer.localizedString(forKey: "progress_overview_title"), color: .indigo) {
                                glassCard { ringsCard }
                            }
                        }
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
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { headerAppeared = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { sectionsAppeared = true }
        }
    }

    // MARK: - Animated Section

    private func animatedSection<C: View>(delay: Double, @ViewBuilder content: () -> C) -> some View {
        content()
            .opacity(sectionsAppeared ? 1 : 0)
            .offset(y: sectionsAppeared ? 0 : 18)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: sectionsAppeared)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
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
                    .fill(RadialGradient(colors: [Color.purple.opacity(isDark ? 0.28 : 0.13), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.45))
                    .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                    .position(x: geo.size.width * 0.1, y: geo.size.height * 0.10)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [Color.blue.opacity(isDark ? 0.20 : 0.10), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.4))
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .position(x: geo.size.width * 0.88, y: geo.size.height * 0.60)
                    .blur(radius: 12)
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.2).opacity(isDark ? 0.14 : 0.08), .clear],
                                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.82)
                    .blur(radius: 14)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Hero Header

    private var headerHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.1)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(headerAppeared ? 1 : 0.5).opacity(headerAppeared ? 1 : 0)

                Circle()
                    .trim(from: 0, to: headerAppeared ? completionRate : 0)
                    .stroke(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 82, height: 82)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.4), value: headerAppeared)

                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue.opacity(0.85)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: .purple.opacity(0.45), radius: 18, x: 0, y: 8)

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(headerAppeared ? 1 : 0.6).opacity(headerAppeared ? 1 : 0)

            VStack(spacing: 5) {
                Text(localizer.localizedString(forKey: "Statistik"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
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
            .strokeBorder(LinearGradient(colors: [Color.purple.opacity(isDark ? 0.3 : 0.2),
                                                   Color.blue.opacity(isDark ? 0.1 : 0.05)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: Color.purple.opacity(isDark ? 0.15 : 0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - Fokuspunkte Card

    private var fokuspunkteCard: some View {
        let stufe = fokuspunkteStufe
        return ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: isDark
                        ? [Color(red: 0.18, green: 0.08, blue: 0.35), Color(red: 0.08, green: 0.08, blue: 0.25)]
                        : [Color(red: 0.55, green: 0.25, blue: 0.95), Color(red: 0.30, green: 0.15, blue: 0.80)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.purple.opacity(0.45), radius: 20, x: 0, y: 8)

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
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fokuspunkte").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
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
        VStack(spacing: 10) {
            glassCard {
                HStack(spacing: 12) {
                    iconBadge(icon: "bolt.fill", color: Color(red: 1, green: 0.55, blue: 0.0))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dein Guthaben").font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("\(fokuspunkteVerfuegbar) Fokuspunkte")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                    }
                    Spacer()
                    Text("Bald verfügbar").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(storeItems) { item in
                    storeCell(item)
                }
            }
        }
    }

    private func storeCell(_ item: StoreItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LinearGradient(
                        colors: [item.farbe.opacity(isDark ? 0.4 : 0.3), item.farbe.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))

            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Circle().fill(item.farbe.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .semibold)).foregroundStyle(item.farbe.opacity(0.5))
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                        .padding(4).background(Color.black.opacity(0.4), in: Circle())
                }

                Text(item.name).font(.system(size: 12, weight: .semibold))

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.0))
                    Text("\(item.kosten)").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(fokuspunkteVerfuegbar >= item.kosten
                                         ? Color(red: 1, green: 0.55, blue: 0.0) : .secondary)
                }
            }
            .padding(.vertical, 12)
        }
        .frame(height: 110)
        .opacity(0.75)
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
            HStack(spacing: 12) {
                iconBadge(icon: "flame.fill", color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(focusTodayDateText).font(.system(size: 13)).foregroundStyle(.secondary)
                    Text("Heute: \(focusTodayMinutes) Min.")
                        .font(.system(size: 16, weight: .semibold))
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            cardDivider()

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
        VStack(spacing: 0) { content() }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(isDark ? 0.13 : 0.65),
                             Color.white.opacity(isDark ? 0.04 : 0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
            .shadow(color: Color.purple.opacity(isDark ? 0.10 : 0.04), radius: 18, x: 0, y: 2)
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
