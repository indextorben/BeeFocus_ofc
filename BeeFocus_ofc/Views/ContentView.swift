//
//  ContentView.swift
//  ToDo
//
//  Created by Torben Lehneke on 12.06.25.
//

import SwiftUI
import SwiftData
import UserNotifications
import CloudKit

struct ContentView: View {
    @StateObject private var todoStore = TodoStore()
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: - Aufgaben Tab
            Group {
                if sizeClass == .compact {
                    NavigationView {
                        TodoListView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        TodoListView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label(LocalizedStringKey("Aufgaben"), systemImage: "list.bullet")
            }
            .tag(0)
            
            // MARK: - Timer Tab
            Group {
                if sizeClass == .compact {
                    NavigationView {
                        TimerView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        TimerView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label(LocalizedStringKey("Timer"), systemImage: "timer")
            }
            .tag(1)
            
            // MARK: - Statistik Tab
            Group {
                if sizeClass == .compact {
                    NavigationView {
                        StatistikView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        StatistikView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .tabItem {
                Label(LocalizedStringKey("Statistik"), systemImage: "chart.bar")
            }
            .tag(2)
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
        // 🔹 CloudKit Test beim Start
        .onAppear {
            // Test-Todo erstellen
            let testTodo = TodoItem(title: "CloudKit Test")
            CloudKitManager.shared.saveTodo(testTodo)
            
            // Todos abrufen
            CloudKitManager.shared.fetchTodos { todos in
                print("Gefundene Todos:", todos.map { $0.title })
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
