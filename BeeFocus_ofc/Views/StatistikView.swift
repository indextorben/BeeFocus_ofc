import SwiftUI
import Charts

struct StatistikView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    
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
        if let date = UserDefaults.standard.object(forKey: "AppStartDate") as? Date {
            return date
        } else {
            let now = Date()
            UserDefaults.standard.set(now, forKey: "AppStartDate")
            return now
        }
    }
    
    var timerWeeklyStats: [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { offset -> (date: Date, minutes: Int) in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return (today, 0)
            }
            
            let filteredTodos = todoStore.todos.filter {
                $0.isCompleted &&
                $0.completedAt != nil &&
                calendar.isDate($0.completedAt!, inSameDayAs: date)
            }
            
            let totalMinutes = filteredTodos.reduce(0) { sum, todo in
                let minutes = (todo.focusTimeInMinutes as? Double).map { Int($0) } ?? 0
                return sum + minutes
            }
            
            return (date, totalMinutes)
        }
    }
    
    var weeklyProgress: [(date: Date, progress: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return (0..<7).map { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return (date: today, progress: 0)
            }
            
            let todosForDay = todoStore.todos.filter { todo in
                guard let due = todo.dueDate else { return false }
                return calendar.isDate(due, inSameDayAs: date)
            }
            let completed = todosForDay.filter { $0.isCompleted }.count
            let total = todosForDay.count
            let progress = total > 0 ? Double(completed) / Double(total) : 0
            
            return (date: date, progress: progress)
        }
    }
    
    var monthlyProgress: [(week: Int, progress: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [(week: Int, progress: Double)] = []
        
        for weekIndex in 0..<4 {
            guard let startOfWeek = calendar.date(byAdding: .weekOfYear, value: -weekIndex, to: today) else { continue }
            
            let weekTodos = todoStore.todos.filter { todo in
                guard let due = todo.dueDate else { return false }
                return due >= appStartDate && due <= today &&
                calendar.isDate(due, equalTo: startOfWeek, toGranularity: .weekOfYear)
            }
            
            let completed = weekTodos.filter { $0.isCompleted }.count
            let total = weekTodos.count
            let progress = total > 0 ? Double(completed) / Double(total) : 0
            result.insert((week: 3 - weekIndex, progress: progress), at: 0)
        }
        
        return result
    }
    
    var yearlyProgress: [(month: Int, progress: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [(month: Int, progress: Double)] = []
        
        for monthIndex in 0..<12 {
            guard let startOfMonth = calendar.date(byAdding: .month, value: -monthIndex, to: today) else { continue }
            
            let monthTodos = todoStore.todos.filter { todo in
                guard let due = todo.dueDate else { return false }
                return due >= appStartDate && due <= today &&
                calendar.isDate(due, equalTo: startOfMonth, toGranularity: .month)
            }
            
            let completed = monthTodos.filter { $0.isCompleted }.count
            let total = monthTodos.count
            let progress = total > 0 ? Double(completed) / Double(total) : 0
            result.insert((month: 11 - monthIndex, progress: progress), at: 0)
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: Header mit Gesamtstatistiken
                        VStack(spacing: 8) {
                            Text("Gesamtübersicht")
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack {
                                MiniStatCard(title: "Gesamt", value: "\(totalTasks)", icon: "list.bullet", color: .gray)
                                MiniStatCard(title: "Erledigt", value: "\(completedTasks)", icon: "checkmark.circle", color: .green)
                                MiniStatCard(title: "Offen", value: "\(openTasks)", icon: "square.and.pencil", color: .blue)
                                MiniStatCard(title: "Überfällig", value: "\(overdueTasks)", icon: "exclamationmark.triangle", color: .red)
                            }
                            
                            ProgressBar(value: completionRate, color: .blue)
                                .frame(height: 8)
                                .padding(.horizontal, 20)
                            
                            Text("\(Int(completionRate * 100))% aller Aufgaben erledigt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Heutige Aktivität
                        VStack(alignment: .leading) {
                            Text("Heutige Aktivität")
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
                                    Text("Heute erledigt")
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
                                    Text("Heute fällig")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            ProgressBar(value: todayCompletionRate, color: .orange)
                                .frame(height: 6)
                                .padding(.top, 8)
                            
                            Text("\(Int(todayCompletionRate * 100))% der heutigen Aufgaben erledigt")
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
                            Text("Verteilung nach Kategorien")
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            if todoStore.categories.isEmpty {
                                Text("Keine Kategorien vorhanden")
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
                                                Text(category)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(12)
                                            .background(cardBackground)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                            .overlay(Circle().fill(color).frame(width: 12, height: 12).offset(x: 0, y: -20), alignment: .top)
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
                                Text("Fokuszeit - ")
                                    .font(.title2)
                                    .bold()
                                Text("in min")
                                    .font(.title3)
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 5)
                            
                            let timerColor = Color.accentColor
                            HStack(alignment: .bottom, spacing: 10) {
                                ForEach(timerWeeklyStats, id: \.date) { entry in
                                    VStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(timerColor)
                                            .frame(height: max(CGFloat(entry.minutes) * 2, 10))
                                        Text("\(entry.minutes) min")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text(getGermanDayAbbreviation(for: entry.date))
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
                            Text("Fortschrittsübersicht")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack {
                                CompletionRing(title: "Heute", value: todayCompletionRate, color: .orange)
                                CompletionRing(title: "Gesamt", value: completionRate, color: .blue)
                                CompletionRing(title: "Kritisch", value: min(1.0, Double(overdueTasks) / Double(max(1, openTasks))), color: .red)
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Wöchentlicher Fortschritt
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Wöchentlicher Fortschritt")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                ForEach(weeklyProgress, id: \.date) { data in
                                    VStack(spacing: 4) {
                                        Text(getGermanDayAbbreviation(for: data.date))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        VStack(spacing: 0) {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 4)
                                                .frame(width: 20, height: CGFloat(data.progress) * 60)
                                                .foregroundColor(.blue)
                                        }
                                        .frame(height: 60)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                        Text("\(Int(data.progress * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(textColor)
                                    }
                                    .frame(width: 40)
                                }
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Monatlicher Fortschritt
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Monatlicher Fortschritt")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(textColor)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                ForEach(monthlyProgress, id: \.week) { data in
                                    VStack(spacing: 4) {
                                        Text("W \(data.week + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        VStack(spacing: 0) {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 4)
                                                .frame(width: 20, height: CGFloat(data.progress) * 60)
                                                .foregroundColor(.green)
                                        }
                                        .frame(height: 60)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                        Text("\(Int(data.progress * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(textColor)
                                    }
                                    .frame(width: 40)
                                }
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // MARK: Jahresfortschritt
                        VStack(spacing: 12) {
                            Text("Jahresfortschritt")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                // iPad: Alle Monate sichtbar
                                let columns = Array(repeating: GridItem(.flexible(), spacing: 15), count: 6) // 6 Spalten pro Reihe
                                LazyVGrid(columns: columns, spacing: 15) {
                                    ForEach(yearlyProgress, id: \.month) { data in
                                        VStack(spacing: 4) {
                                            Text(getGermanMonthAbbreviation((data.month) % 12))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            VStack(spacing: 0) {
                                                Spacer()
                                                RoundedRectangle(cornerRadius: 4)
                                                    .frame(width: 20, height: CGFloat(data.progress) * 60)
                                                    .foregroundColor(.purple)
                                            }
                                            .frame(height: 60)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(4)
                                            Text("\(Int(data.progress * 100))%")
                                                .font(.caption2)
                                                .foregroundColor(textColor)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                            } else {
                                // iPhone: Horizontal scrollen
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(yearlyProgress, id: \.month) { data in
                                            VStack(spacing: 4) {
                                                Text(getGermanMonthAbbreviation((data.month) % 12))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                VStack(spacing: 0) {
                                                    Spacer()
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .frame(width: 20, height: CGFloat(data.progress) * 60)
                                                        .foregroundColor(.purple)
                                                }
                                                .frame(height: 60)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(4)
                                                Text("\(Int(data.progress * 100))%")
                                                    .font(.caption2)
                                                    .foregroundColor(textColor)
                                            }
                                            .frame(width: 40)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Statistik")
        }
    }
    
    // MARK: - Hilfsfunktionen
    private func getGermanDayAbbreviation(for date: Date) -> String {
        let germanDays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        let weekday = Calendar.current.component(.weekday, from: date) // 1 = So, 7 = Sa
        return germanDays[weekday - 1]
    }
    
    private func getGermanMonthAbbreviation(_ month: Int) -> String {
        let germanMonths = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
        return germanMonths[month]
    }
}

// MARK: - Hilfs-Views
struct MiniStatCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.2))
                .cornerRadius(15)
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .contentTransition(.numericText())
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.1)
                    .foregroundColor(.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(value) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(color)
                    .animation(.linear, value: value)
            }
            .cornerRadius(45)
        }
    }
}

struct CompletionRing: View {
    var title: String
    var value: Double
    var color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.1)
                    .foregroundColor(color)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(value, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.easeInOut, value: value)
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 60, height: 60)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
