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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                TodoListView()
                    .environmentObject(todoStore)
            }
            .tabItem {
                Label("Aufgaben", systemImage: "list.bullet")
            }
            .tag(0)
            
            NavigationView {
                TimerView()
            }
            .tabItem {
                Label("Timer", systemImage: "timer")
            }
            .tag(1)
            
            NavigationView {
                StatistikView()
                    .environmentObject(todoStore)
            }
            .tabItem {
                Label("Statistik", systemImage: "chart.bar")
            }
            .tag(2)
        }
    }
}
#Preview {
    ContentView()
}
