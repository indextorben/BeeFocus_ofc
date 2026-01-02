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
    @State private var syncWorkItem: DispatchWorkItem? = nil
    @State private var showingDeleteByDateSheet = false
    @State private var deleteStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var deleteEndDate: Date = Date()
    @State private var showingDeletionToast = false
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @ObservedObject private var localizer = LocalizationManager.shared
    let languages = ["Deutsch", "Englisch"]
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("didSeedCloud") private var didSeedCloud = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // MARK: - Aufgaben Tab
            Group {
                if sizeClass == .compact {
                    NavigationStack {
                        TodoListView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        showingDeleteByDateSheet = true
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .help("Vergangene Todos löschen (nach Erstellungsdatum)")
                                }
                            }
                    }
                } else {
                    NavigationStack {
                        TodoListView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button {
                                        showingDeleteByDateSheet = true
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .help("Vergangene Todos löschen (nach Erstellungsdatum)")
                                }
                            }
                    }
                }
            }
            .tabItem {
                Label(localizer.localizedString(forKey: "Aufgaben"), systemImage: "list.bullet")
            }
            .tag(0)
            
            //MARK - Kalender Tab
            Group {
                if sizeClass == .compact {
                    NavigationStack {
                        CalendarView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NavigationStack {
                        CalendarView()
                            .environmentObject(todoStore)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .tabItem {
                Label(localizer.localizedString(forKey: "Kalender"), systemImage: "calendar.badge.clock")
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
        }
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
        .onAppear {
            CloudKitManager.shared.runDiagnosticsOnLaunch()
            CloudKitManager.shared.fetchTodos { cloudTodos in
                if !cloudTodos.isEmpty {
                    // Cloud ist Quelle der Wahrheit: mit Cloud mergen/ersetzen
                    todoStore.mergeFromCloud(cloudTodos)
                } else {
                    // Cloud ist leer: lokale Daten nicht überschreiben
                    // Einmaliges Seeding: Nur wenn lokal Daten vorhanden sind und noch nicht geseedet wurde
                    if !todoStore.todos.isEmpty && !didSeedCloud {
                        CloudKitManager.shared.uploadTodosIfNeeded(from: todoStore)
                        didSeedCloud = true
                    } else {
                        // Nichts tun: lokale Daten sichtbar lassen
                        print("ℹ️ Cloud leer. Lokale Daten bleiben erhalten. didSeedCloud=\(didSeedCloud)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingDeleteByDateSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("Zeitraum")) {
                        DatePicker("Von", selection: $deleteStartDate, displayedComponents: [.date])
                        DatePicker("Bis", selection: $deleteEndDate, in: deleteStartDate...Date(), displayedComponents: [.date])
                    }

                    Section(footer: Text("Alle Todos, deren Erstellungsdatum in diesem Zeitraum liegt, werden endgültig gelöscht.")) {
                        Button(role: .destructive) {
                            // Schutz: Stelle sicher, dass Start <= Ende
                            let start = min(deleteStartDate, deleteEndDate)
                            let end = max(deleteStartDate, deleteEndDate)
                            let toDelete = todoStore.todos.filter { $0.createdAt >= start && $0.createdAt <= end }
                            for todo in toDelete {
                                CloudKitManager.shared.deleteTodo(todo)
                                if let idx = todoStore.todos.firstIndex(where: { $0.id == todo.id }) {
                                    todoStore.todos.remove(at: idx)
                                }
                            }
                            // Persist and refresh UI
                            todoStore.saveTodos()
                            DispatchQueue.main.async { todoStore.objectWillChange.send() }
                            showingDeleteByDateSheet = false
                            showingDeletionToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showingDeletionToast = false }
                            }
                        } label: {
                            Label("Todos im Zeitraum löschen", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Vergangene Todos löschen")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { showingDeleteByDateSheet = false }
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showingDeletionToast {
                Text("Löschung abgeschlossen")
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
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
