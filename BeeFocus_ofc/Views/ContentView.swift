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
    @EnvironmentObject var todoStore: TodoStore
    @State private var selectedTab = 0
    @State private var syncWorkItem: DispatchWorkItem? = nil
    @State private var showingDeleteByDateSheet = false
    @State private var deleteStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var deleteEndDate: Date = Date()
    @State private var showingDeletionToast = false
    @State private var showingConfirmMoveCompleted = false
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("didSeedCloud") private var didSeedCloud = false
    @AppStorage("morningSummaryEnabled") private var morningSummaryEnabled: Bool = true
    @AppStorage("morningSummaryTime") private var morningSummaryTime: Double = 6 * 3600
    @AppStorage("filterCurrentMonthOnly") private var filterCurrentMonthOnly: Bool = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: - Aufgaben Tab
            Group {
                if sizeClass == .compact {
                    NavigationStack {
                        TodoListView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        TodoListView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label(localizer.localizedString(forKey: "Aufgaben"), systemImage: "list.bullet")
            }
            .tag(0)
            
            // MARK: - Tagesplaner Tab
            NavigationStack {
                TagesplanerView()
                    .environmentObject(todoStore)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .tabItem {
                Label("Tag", systemImage: "calendar.day.timeline.left")
            }
            .tag(1)
            
            // MARK: - Timer Tab
            Group {
                if sizeClass == .compact {
                    NavigationStack {
                        TimerView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        TimerView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label(localizer.localizedString(forKey: "Timer"), systemImage: "timer")
            }
            .tag(2)
            
            // MARK: - Statistik Tab
            Group {
                if sizeClass == .compact {
                    NavigationStack {
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
                }
            }
            .tabItem {
                Label(localizer.localizedString(forKey: "Statistik"), systemImage: "chart.bar")
            }
            .tag(3)
            
            // MARK: - Fokusmodus Tab
            Group {
                if #available(iOS 16, *) {
                    NavigationStack {
                        FokusModeView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label("Fokus", systemImage: "shield.fill")
            }
            .tag(4)
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
        .onAppear {
            CloudKitManager.shared.runDiagnosticsOnLaunch()
            CloudKitManager.shared.fetchTodos { cloudTodos in
                if !cloudTodos.isEmpty {
                    todoStore.mergeFromCloud(cloudTodos)
                } else {
                    if !todoStore.todos.isEmpty && !didSeedCloud {
                        CloudKitManager.shared.uploadTodosIfNeeded(from: todoStore)
                        didSeedCloud = true
                    } else {
                        print("ℹ️ Cloud leer. Lokale Daten bleiben erhalten. didSeedCloud=\(didSeedCloud)")
                    }
                }
                todoStore.writeWidgetSnapshot()
            }
            CloudKitManager.shared.fetchDailyStats { cloudDaily in
                todoStore.applyDailyStatsFromCloud(cloudDaily)
            }
            CloudKitManager.shared.fetchFocusStats { cloudFocus in
                todoStore.applyFocusStatsFromCloud(cloudFocus)
            }
            CloudKitManager.shared.fetchCategories { cloudCategories in
                todoStore.applyCategoriesFromCloud(cloudCategories)
            }
            // 🔔 Planen der morgendlichen Übersicht (konfigurierbar)
            if morningSummaryEnabled {
                NotificationManager.shared.requestAuthorization { granted in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? Date()
                        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? today
                        let currentMonthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: currentMonthStart) ?? endOfDay

                        let dueTodayOrOverdueNotCompleted = todoStore.todos.filter { todo in
                            guard !todo.isCompleted else { return false }
                            guard let due = todo.dueDate else { return false }
                            if filterCurrentMonthOnly && (due < currentMonthStart || due > currentMonthEnd) { return false }
                            return due <= endOfDay
                        }

                        let count = dueTodayOrOverdueNotCompleted.count
                        let body: String
                        if count == 0 {
                            body = localizer.localizedString(forKey: "morning_summary_body_none")
                        } else if count == 1 {
                            body = localizer.localizedString(forKey: "morning_summary_body_one")
                        } else {
                            body = String(format: localizer.localizedString(forKey: "morning_summary_body_many"), count)
                        }

                        let seconds = Int(morningSummaryTime)
                        let hour = max(0, min(23, seconds / 3600))
                        let minute = max(0, min(59, (seconds % 3600) / 60))
                        NotificationManager.shared.scheduleDailyMorningSummary(hour: hour, minute: minute, body: body)
                    }
                }
            } else {
                NotificationManager.shared.cancelDailyMorningSummary()
            }
        }
        .sheet(isPresented: $showingDeleteByDateSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("Date range")) {
                        DatePicker("From", selection: $deleteStartDate, displayedComponents: [.date])
                        DatePicker("To", selection: $deleteEndDate, in: deleteStartDate...Date(), displayedComponents: [.date])
                    }

                    Section(footer: Text("All todos whose creation date falls within this range will be permanently deleted.")) {
                        Button(role: .destructive) {
                            let start = min(deleteStartDate, deleteEndDate)
                            let end = max(deleteStartDate, deleteEndDate)
                            let toDelete = todoStore.todos.filter { $0.createdAt >= start && $0.createdAt <= end }
                            for todo in toDelete {
                                todoStore.deleteTodo(todo)
                            }
                            showingDeleteByDateSheet = false
                            showingDeletionToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showingDeletionToast = false }
                            }
                        } label: {
                            Label("Delete todos in range", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Delete past todos")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingDeleteByDateSheet = false }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showingDeletionToast {
                Text("Deletion complete")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog(
            "Abgeschlossene in den Papierkorb verschieben?",
            isPresented: $showingConfirmMoveCompleted,
            titleVisibility: .visible
        ) {
            Button("Verschieben", role: .destructive) {
                let completed = todoStore.todos.filter { $0.isCompleted }
                for t in completed {
                    todoStore.deleteTodo(t)
                }
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Alle erledigten Aufgaben werden in den Papierkorb verschoben und können dort wiederhergestellt werden.")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                CloudKitManager.shared.fetchTodos { cloudTodos in
                    todoStore.mergeFromCloud(cloudTodos)
                    todoStore.writeWidgetSnapshot()
                }
                CloudKitManager.shared.fetchDailyStats { cloudDaily in
                    todoStore.applyDailyStatsFromCloud(cloudDaily)
                }
                CloudKitManager.shared.fetchFocusStats { cloudFocus in
                    todoStore.applyFocusStatsFromCloud(cloudFocus)
                }
                CloudKitManager.shared.fetchCategories { cloudCategories in
                    todoStore.applyCategoriesFromCloud(cloudCategories)
                }
                // 🔄 Beim Aktivieren neu planen, damit die Zusammenfassung aktuell bleibt
                if morningSummaryEnabled {
                    NotificationManager.shared.requestAuthorization { granted in
                        guard granted else { return }
                        DispatchQueue.main.async {
                            let cal2 = Calendar.current
                            let today2 = cal2.startOfDay(for: Date())
                            let endOfDay2 = cal2.date(bySettingHour: 23, minute: 59, second: 59, of: today2) ?? Date()
                            let monthStart2 = cal2.date(from: cal2.dateComponents([.year, .month], from: Date())) ?? today2
                            let monthEnd2 = cal2.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart2) ?? endOfDay2
                            let dueTodayOrOverdueNotCompleted = todoStore.todos.filter { todo in
                                guard !todo.isCompleted else { return false }
                                guard let due = todo.dueDate else { return false }
                                if filterCurrentMonthOnly && (due < monthStart2 || due > monthEnd2) { return false }
                                return due <= endOfDay2
                            }
                            let count = dueTodayOrOverdueNotCompleted.count
                            let body: String
                            if count == 0 {
                                body = localizer.localizedString(forKey: "morning_summary_body_none")
                            } else if count == 1 {
                                body = localizer.localizedString(forKey: "morning_summary_body_one")
                            } else {
                                body = String(format: localizer.localizedString(forKey: "morning_summary_body_many"), count)
                            }
                            let seconds = Int(morningSummaryTime)
                            let hour = max(0, min(23, seconds / 3600))
                            let minute = max(0, min(59, (seconds % 3600) / 60))
                            NotificationManager.shared.scheduleDailyMorningSummary(hour: hour, minute: minute, body: body)
                        }
                    }
                } else {
                    NotificationManager.shared.cancelDailyMorningSummary()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}

