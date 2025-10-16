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
    
    // 🔹 Darkmode Einstellung aus AppStorage laden
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
        // 🔹 HIER wird das Farbschema auf die ganze App angewendet
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
