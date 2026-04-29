//
//  TodoWidget.swift
//  BeeFocus_ofc
//
//  Created on 15.04.26.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct TodoWidgetProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            dueTodayCount: 3,
            overdueCount: 1,
            totalOpenCount: 10
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = TodoWidgetEntry(
            date: Date(),
            dueTodayCount: 3,
            overdueCount: 1,
            totalOpenCount: 10
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let currentDate = Date()
        
        // Lade die Todos aus UserDefaults (App Group erforderlich!)
        let todos = loadTodos()
        
        // Berechne die Anzahl der fälligen Aufgaben
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let dueTodayCount = todos.filter { todo in
            guard !todo.isCompleted, let dueDate = todo.dueDate else { return false }
            return dueDate >= today && dueDate < tomorrow
        }.count
        
        let overdueCount = todos.filter { todo in
            guard !todo.isCompleted, let dueDate = todo.dueDate else { return false }
            return dueDate < today
        }.count
        
        let totalOpenCount = todos.filter { !$0.isCompleted }.count
        
        let entry = TodoWidgetEntry(
            date: currentDate,
            dueTodayCount: dueTodayCount,
            overdueCount: overdueCount,
            totalOpenCount: totalOpenCount
        )
        
        // Aktualisiere das Widget alle 15 Minuten
        let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // Lade Todos aus UserDefaults
    private func loadTodos() -> [TodoItem] {
        // WICHTIG: Verwenden Sie die gleiche App Group wie in Ihrer Haupt-App
        let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.beefocus")
        
        guard let data = sharedDefaults?.data(forKey: "todos") else {
            // Fallback auf Standard UserDefaults
            guard let data = UserDefaults.standard.data(forKey: "todos") else {
                return []
            }
            return (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
        }
        
        return (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }
}

// MARK: - Widget Entry
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let dueTodayCount: Int
    let overdueCount: Int
    let totalOpenCount: Int
}

// MARK: - Widget Views

// Small Widget View
struct TodoWidgetSmallView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(
                    colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                
                Text("\(entry.dueTodayCount)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(entry.dueTodayCount == 1 ? "Aufgabe" : "Aufgaben")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("fällig heute")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
        }
    }
}

// Medium Widget View
struct TodoWidgetMediumView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(
                    colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            HStack(spacing: 20) {
                // Heute fällig
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("\(entry.dueTodayCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Heute")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.5))
                    .frame(height: 60)
                
                // Überfällig
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(entry.overdueCount > 0 ? .red : .white)
                    
                    Text("\(entry.overdueCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Überfällig")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .background(Color.white.opacity(0.5))
                    .frame(height: 60)
                
                // Gesamt offen
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("\(entry.totalOpenCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Gesamt")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

// Large Widget View
struct TodoWidgetLargeView: View {
    let entry: TodoWidgetEntry
    
    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(LinearGradient(
                    colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            
            VStack(spacing: 20) {
                // Kopfzeile
                HStack {
                    Image(systemName: "checklist")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                    
                    Text("Meine Aufgaben")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatDate(entry.date))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal)
                
                // Statistiken
                VStack(spacing: 16) {
                    // Heute fällig
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Heute fällig")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Aufgaben für heute")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("\(entry.dueTodayCount)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    
                    // Überfällig
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(entry.overdueCount > 0 ? .red : .white)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Überfällig")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Verpasste Aufgaben")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("\(entry.overdueCount)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                    
                    // Gesamt offen
                    HStack {
                        Image(systemName: "list.bullet.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gesamt offen")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Alle offenen Aufgaben")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("\(entry.totalOpenCount)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }
}

// MARK: - Main Widget Entry View
struct TodoWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: TodoWidgetEntry
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            TodoWidgetSmallView(entry: entry)
        case .systemMedium:
            TodoWidgetMediumView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            TodoWidgetLargeView(entry: entry)
        default:
            TodoWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration
struct TodoWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aufgaben-Übersicht")
        .description("Zeigt die Anzahl der fälligen Aufgaben an")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 3, overdueCount: 1, totalOpenCount: 10)
}

#Preview(as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 5, overdueCount: 2, totalOpenCount: 15)
}

#Preview(as: .systemLarge) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(date: .now, dueTodayCount: 7, overdueCount: 3, totalOpenCount: 20)
}
