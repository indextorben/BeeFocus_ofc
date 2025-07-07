//
//  StatisticView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.06.25.
//

import Foundation
import SwiftUI
import SwiftData

//Statistik Fenster
struct StatisticView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var todoStore: TodoStore
    
    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.2) : Color(red: 0.95, green: 0.97, blue: 1.0)
    }
    
    var completedTasks: Int {
        todoStore.todos.filter { $0.isCompleted }.count
    }
    
    var totalTasks: Int {
        todoStore.todos.count
    }
    
    var completionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks)
    }
    
    var tasksByCategory: [(String, Int)] {
        let categories = TaskCategory.allCases.map { $0.rawValue }
        return categories.map { categoryName in
            let count = todoStore.todos.filter { $0.category?.name == categoryName }.count
            return (categoryName, count)
        }.sorted { $0.1 > $1.1 }
    }
    
    var groupedPriorities: [(String, Int)] {
        let grouped = Dictionary(grouping: todoStore.todos, by: { $0.priority })
        return grouped.map { ($0.key.rawValue.capitalized, $0.value.count) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Gesamtübersicht
                        StatCard(title: "Gesamtübersicht") {
                            VStack(spacing: 15) {
                                HStack {
                                    StatItem(
                                        title: "Gesamt",
                                        value: "\(totalTasks)",
                                        icon: "list.bullet", color: .blue,
                                    )
                                    
                                    StatItem(
                                        title: "Erledigt",
                                        value: "\(completedTasks)",
                                        icon: "checkmark.circle",
                                        color: .green
                                    )
                                }
                                
                                // Fortschrittsbalken
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Erledigungsrate")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 20)
                                            
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.blue)
                                                .frame(width: geometry.size.width * completionRate, height: 20)
                                        }
                                    }
                                    .frame(height: 20)
                                    
                                    Text("\(Int(completionRate * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Kategorien
                        StatCard(title: "Aufgaben nach Kategorie") {
                            VStack(spacing: 12) {
                                ForEach(tasksByCategory, id: \.0) { category, count in
                                    HStack {
                                        Text(category)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(count)")
                                            .foregroundColor(.secondary)
                                    }
                                    if category != tasksByCategory.last?.0 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        
                        // Prioritäten
                        StatCard(title: "Aufgaben nach Priorität") {
                            VStack(spacing: 12) {
                                ForEach(Array(groupedPriorities.enumerated()), id: \.offset) { index, element in
                                    let (priority, count) = element
                                    HStack {
                                        Text(priority)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(count)")
                                            .foregroundColor(.secondary)
                                    }
                                    if index < groupedPriorities.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .navigationTitle("Statistik")
            }
        }
    }
}
