import SwiftUI
import Charts

struct StatistikView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    
    // Farbdefinitionen
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.25) : Color.white
    }
    
    var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    // Berechnete Eigenschaften (werden automatisch aktualisiert)
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
    
    var timerWeeklyStats: [(day: Int, minutes: Int)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { offset -> (day: Int, minutes: Int) in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return (6 - offset, 0)
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
            
            return (6 - offset, totalMinutes)
        }
    }
    
    // Zeitraum-Daten (Beispielwerte - durch echte Daten ersetzen)
    var weeklyProgress: [(day: Int, progress: Double)] {
        Array(0..<7).map { day in
            (day: day, progress: Double.random(in: 0...1))
        }
    }
    
    var monthlyProgress: [(week: Int, progress: Double)] {
        Array(0..<4).map { week in
            (week: week, progress: Double.random(in: 0.2...1.0))
        }
    }
    
    var yearlyProgress: [(month: Int, progress: Double)] {
        Array(0..<12).map { month in
            (month: month, progress: Double.random(in: 0.2...1.0))
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header mit Gesamtstatistiken
                        VStack(spacing: 8) {
                            Text("Gesamtübersicht")
                                .font(.headline)
                                .padding(.bottom, 8)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack {
                                MiniStatCard(
                                    title: "Gesamt",
                                    value: "\(totalTasks)",
                                    icon: "list.bullet",
                                    color: .gray
                                )
                                
                                MiniStatCard(
                                    title: "Erledigt",
                                    value: "\(completedTasks)",
                                    icon: "checkmark.circle",
                                    color: .green
                                )
                                
                                MiniStatCard(
                                    title: "Offen",
                                    value: "\(openTasks)",
                                    icon: "square.and.pencil",
                                    color: .blue
                                )
                                
                                MiniStatCard(
                                    title: "Überfällig",
                                    value: "\(overdueTasks)",
                                    icon: "exclamationmark.triangle",
                                    color: .red
                                )
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
                        
                        // Heutige Aktivität
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
                                
                                Divider()
                                    .frame(height: 40)
                                
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
                        
                        // Kategorien
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
                        
                        // Timer-Statistik (Tag)
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
                                ForEach(0..<7, id: \.self) { index in
                                    let (day, minutes) = timerWeeklyStats[index]
                                    VStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(timerColor)
                                            .frame(height: max(CGFloat(minutes) * 2, 10)) // Mindesthöhe 10
                                        
                                        Text("\(minutes) min")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        
                                        Text(getGermanDayAbbreviation(day))
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
                        
                        // Fortschrittsübersicht in separater Box
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Fortschrittsübersicht")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack {
                                CompletionRing(
                                    title: "Heute",
                                    value: todayCompletionRate,
                                    color: .orange
                                )
                                
                                CompletionRing(
                                    title: "Gesamt",
                                    value: completionRate,
                                    color: .blue
                                )
                                
                                CompletionRing(
                                    title: "Kritisch",
                                    value: min(1.0, Double(overdueTasks) / Double(max(1, openTasks))),
                                    color: .red
                                )
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Wöchentlicher Fortschritt
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Wöchentlicher Fortschritt")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                ForEach(weeklyProgress, id: \.day) { data in
                                    VStack(spacing: 4) {
                                        Text(getGermanDayAbbreviation(data.day))
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
                                    .frame(width: 30)
                                }
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(15)
                        .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Monatlicher Fortschritt
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
                        
                        // Jahresfortschritt
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Jahresfortschritt")
                                .font(.headline)
                                .foregroundColor(textColor)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(yearlyProgress, id: \.month) { data in
                                        VStack(spacing: 4) {
                                            Text(getGermanMonthAbbreviation(data.month))
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
                                .padding(.horizontal, 5)
                            }
                            .padding(.top, 8)
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
    
    // Hilfsfunktionen für deutsche Bezeichnungen
    private func getGermanDayAbbreviation(_ day: Int) -> String {
        let germanDays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        return germanDays[day]
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
