import SwiftUI
import Charts
import UIKit
import MessageUI

struct StatistikView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    
    @ObservedObject private var localizer = LocalizationManager.shared
    
    @StateObject private var mailShare = MailShareService()
    
    @State private var refresh = false
    
    // MARK: - Farben
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.25) : Color.white
    }
    
    var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    // MARK: - Basisstatistiken
    var completedTasks: Int { todoStore.todos.filter { $0.isCompleted }.count }
    var openTasks: Int { todoStore.todos.filter { !$0.isCompleted }.count }
    var totalTasks: Int { openTasks + completedTasks }
    var completionRate: Double { totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0 }
    
    var todayOpenTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.todos.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && Calendar.current.isDate(dueDate, inSameDayAs: today)
        }.count
    }
    
    var todayCompletedTasks: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return todoStore.todos.filter { item in
            guard let completionDate = item.completedAt else { return false }
            return Calendar.current.isDate(completionDate, inSameDayAs: today)
        }.count
    }
    
    var overdueTasks: Int {
        let now = Date()
        return todoStore.todos.filter { item in
            guard let dueDate = item.dueDate, !item.isCompleted else { return false }
            return dueDate < now
        }.count
    }
    
    var todayCompletionRate: Double {
        let totalToday = todayOpenTasks + todayCompletedTasks
        return totalToday > 0 ? Double(todayCompletedTasks) / Double(totalToday) : 0
    }
    
    var tasksByCategory: [(name: String, count: Int, color: Color)] {
        todoStore.categories.map { category in
            let count = todoStore.todos.filter {
                $0.category?.id == category.id && !$0.isCompleted
            }.count
            return (category.name, count, category.color)
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - Erster App-Start
    private var appStartDate: Date {
        let defaults = UserDefaults.standard
        let timestamp = defaults.double(forKey: "AppStartDate")
        if timestamp > 0 {
            return Date(timeIntervalSince1970: timestamp)
        } else {
            let now = Date()
            defaults.set(now.timeIntervalSince1970, forKey: "AppStartDate")
            return now
        }
    }
    
    func localizedDayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: LocalizationManager.shared.currentLanguageCode
        )
        formatter.dateFormat = "EEE" // Mo / Mon / Lun
        return formatter.string(from: date)
    }
    
    // MARK: - Timer- und Fortschrittsstatistiken
    
    var timerWeeklyStats: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { offset -> (date: Date, minutes: Int) in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return (today, 0)
            }
            
            let filteredTodos = todoStore.todos.filter { todo in
                guard todo.isCompleted, let completedAt = todo.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: date)
            }
            
            let totalMinutes = filteredTodos.reduce(0) { sum, todo in
                let minutes = Int(todo.focusTimeInMinutes ?? 0)
                return sum + minutes
            }
            
            return (date: date, minutes: totalMinutes)
        }
    }
    
    // MARK: - Mail Export

    /// Öffentliche Helferfunktion: Rufe diese mit deinen ausgewählten Todos auf
    func shareTodosByMail(_ todos: [TodoItem], recipients: [String]? = nil) {
        mailShare.shareTodosByMail(todos, languageCode: LocalizationManager.shared.currentLanguageCode, recipients: recipients)
    }
    
    private func exportStatistics() {
        DispatchQueue.main.async {
            let exportView = StatistikExportView(
                completed: completedTasks,
                open: openTasks,
                total: totalTasks,
                overdue: overdueTasks
            )
            .frame(width: 1240, height: 1754)
            .background(Color.white)

            let renderer = ImageRenderer(content: exportView)
            renderer.scale = 3

            guard let image = renderer.uiImage else { return }

            mailShare.exportData = ShareData(image: image)
            // ⬅️ ERST JETZT Sheet triggern
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: Header mit Gesamtstatistiken
                        VStack(spacing: 8) {
                            Text(localizer.localizedString(forKey: "overview_title"))
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)

                            HStack {
                                MiniStatCard(
                                    title: localizer.localizedString(forKey: "overview_total"),
                                    value: "\(totalTasks)",
                                    icon: "list.bullet",
                                    color: .gray
                                )
                                MiniStatCard(
                                    title: localizer.localizedString(forKey: "overview_completed"),
                                    value: "\(completedTasks)",
                                    icon: "checkmark.circle",
                                    color: .green
                                )
                                MiniStatCard(
                                    title: localizer.localizedString(forKey: "overview_open"),
                                    value: "\(openTasks)",
                                    icon: "square.and.pencil",
                                    color: .blue
                                )
                                MiniStatCard(
                                    title: localizer.localizedString(forKey: "overview_overdue"),
                                    value: "\(overdueTasks)",
                                    icon: "exclamationmark.triangle",
                                    color: .red
                                )
                            }

                            ProgressBar(value: completionRate, color: .blue)
                                .frame(height: 8)
                                .padding(.horizontal, 20)

                            Text(
                                String(
                                    format: localizer.localizedString(forKey: "overview_completion_rate"),
                                    Int(completionRate * 100)
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Heutige Aktivität
                        VStack(alignment: .leading) {
                            Text(localizer.localizedString(forKey: "today_activity_title"))
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(todayCompletedTasks)")
                                        .font(.title)
                                        .bold()
                                        .foregroundColor(.green)
                                        .contentTransition(.numericText())

                                    Text(localizer.localizedString(forKey: "today_completed"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider().frame(height: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(todayOpenTasks)")
                                        .font(.title)
                                        .bold()
                                        .foregroundColor(.orange)
                                        .contentTransition(.numericText())

                                    Text(localizer.localizedString(forKey: "today_due"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ProgressBar(value: todayCompletionRate, color: .orange)
                                .frame(height: 6)
                                .padding(.top, 8)

                            Text(
                                String(
                                    format: localizer.localizedString(forKey: "today_completion_rate"),
                                    Int(todayCompletionRate * 100)
                                )
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Kategorien
                        VStack(alignment: .leading) {
                            Text(localizer.localizedString(forKey: "category_distribution_title"))
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)

                            if todoStore.categories.isEmpty {
                                Text(localizer.localizedString(forKey: "category_distribution_empty"))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(tasksByCategory, id: \.name) { category, count, color in
                                            VStack {
                                                Text("\(count)")
                                                    .font(.title2)
                                                    .bold()
                                                    .foregroundColor(textColor)
                                                    .contentTransition(.numericText())

                                                Text(category) // Kategorienamen bleiben bewusst unübersetzt
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(12)
                                            .background(cardBackground)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                            .overlay(
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 12, height: 12)
                                                    .offset(x: 0, y: -20),
                                                alignment: .top
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 5)
                                }
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Timer-Statistik (Tag)
                        VStack(alignment: .leading) {
                            HStack(spacing: 5) {
                                Text(localizer.localizedString(forKey: "focus_time_title"))
                                    .font(.title2)
                                    .bold()

                                Text(localizer.localizedString(forKey: "focus_time_unit"))
                                    .font(.title3)
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 5)

                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(timerWeeklyStats, id: \.date) { entry in
                                    VStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.accentColor)
                                            .frame(height: max(CGFloat(entry.minutes) * 2, 10))

                                        Text(
                                            "\(entry.minutes) " +
                                            localizer.localizedString(forKey: "minutes_short")
                                        )
                                        .font(.caption2)
                                        .foregroundColor(.blue)

                                        Text(localizedDayAbbreviation(for: entry.date))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Fortschrittsübersicht
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localizer.localizedString(forKey: "progress_overview_title"))
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 20) {
                                CompletionRing(
                                    title: localizer.localizedString(forKey: "progress_today"),
                                    value: todayCompletionRate,
                                    color: .orange
                                )

                                CompletionRing(
                                    title: localizer.localizedString(forKey: "progress_total"),
                                    value: completionRate,
                                    color: .blue
                                )

                                CompletionRing(
                                    title: localizer.localizedString(forKey: "progress_critical"),
                                    value: min(1.0, Double(overdueTasks) / Double(max(1, openTasks))),
                                    color: .red
                                )
                            }
                            .padding(.top, 16)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                    }
                    .padding(.horizontal)
                }
                .sheet(item: $mailShare.exportData) { data in
                    ShareActivityView(activityItems: [data.image])
                }
                .sheet(item: $mailShare.mailComposerData) { data in
                    MailComposerWrapperView(subject: data.subject, body: data.body, recipients: data.recipients)
                }
            }
            .navigationTitle(localizer.localizedString(forKey: "Statistik"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        exportStatistics()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                // State toggle erzwingt einmalige Neurenderung
                refresh.toggle()
            }
        }
    }
    
    
    // MARK: - Hilfsfunktionen
    private func getGermanDayAbbreviation(for date: Date) -> String {
        let germanDays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        let weekday = Calendar.current.component(.weekday, from: date) // 1 = So, 7 = Sa
        guard weekday >= 1 && weekday <= 7 else { return "?" }
        return germanDays[weekday - 1]
    }
}

struct MiniStatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.2))
                .clipShape(Circle())
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .contentTransition(.numericText()) // iOS 17+
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
    }
}

// MARK: - Share Data Model
struct ShareData: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Share Sheet
struct ShareActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ProgressBar: View {
    var value: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                
                Capsule()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: geometry.size.height)
                
                Capsule()
                    .fill(color)
                    .frame(
                        width: max(0, min(CGFloat(value), 1)) * geometry.size.width,
                        height: geometry.size.height
                    )
                    .animation(.easeInOut(duration: 0.4), value: value)
            }
        }
        .frame(height: 8) // 🔥 WICHTIG: feste Höhe
    }
}

struct CompletionRing: View {
    var title: String
    var value: Double
    var color: Color
    
    private var clampedValue: Double {
        max(0, min(value, 1))
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                
                // Hintergrund
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 8)
                
                // Fortschritt
                Circle()
                    .trim(from: 0, to: clampedValue)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.7),
                                color
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: clampedValue)
                
                // Prozent
                Text("\(Int(clampedValue * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 64, height: 64)
            .shadow(color: color.opacity(0.25), radius: 6, x: 0, y: 3)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
