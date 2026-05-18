import SwiftUI

struct OrdnerView: View {
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingAddAlert = false
    @State private var newFolderName = ""
    @State private var isEditing = false

    private let standardFolders: [(title: String, icon: String, color: Color)] = [
        ("Heute",                    "sun.max.fill",                   .orange),
        ("Überfällig",               "exclamationmark.circle.fill",    .red),
        ("Diese Woche",              "calendar.badge.clock",           .blue),
        ("Dieser Monat",             "calendar",                       .purple),
        ("Später",                   "arrow.forward.circle.fill",      .teal),
        ("Allgemein",                "tray.fill",                      Color(.systemGray)),
        ("Geburtstage & Feiertage",  "calendar.badge.exclamationmark", .pink),
    ]

    private func taskCount(for standardTitle: String) -> Int {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let endOfToday   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: startOfToday) ?? now
        let endOfWeek    = cal.date(byAdding: .day, value: 6, to: endOfToday) ?? now
        let endOfMonth   = cal.date(byAdding: .day, value: 29, to: endOfToday) ?? now

        switch standardTitle {
        case "Heute":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return !$0.isCompleted && d >= startOfToday && d <= endOfToday
            }.count
        case "Überfällig":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return !$0.isCompleted && d < startOfToday
            }.count
        case "Diese Woche":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfToday && d <= endOfWeek
            }.count
        case "Dieser Monat":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfWeek && d <= endOfMonth
            }.count
        case "Später":
            return todoStore.todos.filter {
                guard let d = $0.dueDate else { return false }
                return d > endOfMonth
            }.count
        case "Allgemein":
            return todoStore.todos.filter { $0.dueDate == nil && $0.customFolder == nil }.count
        case "Geburtstage & Feiertage":
            let keywords = ["geburtstag", "birthday", "feiertag", "holiday"]
            return todoStore.todos.filter { todo in
                if let catName = todo.category?.name.lowercased(),
                   keywords.contains(where: { catName.contains($0) }) { return true }
                let title = todo.title.lowercased()
                return keywords.contains(where: { title.hasPrefix($0) })
            }.count
        default: return 0
        }
    }

    var body: some View {
        List {
            // MARK: Standard-Ordner
            Section {
                ForEach(Array(standardFolders.enumerated()), id: \.offset) { _, folder in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(folder.color.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: folder.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(folder.color)
                        }
                        Text(folder.title)
                            .font(.system(size: 16))
                        Spacer()
                        let count = taskCount(for: folder.title)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(folder.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(folder.color.opacity(0.12), in: Capsule())
                        }
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Standard-Ordner")
            } footer: {
                Text("Diese Ordner werden automatisch anhand der Fälligkeitsdaten befüllt.")
            }

            // MARK: Eigene Ordner
            Section {
                if todoStore.customFolders.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(.tertiaryLabel))
                            Text("Noch keine eigenen Ordner")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(todoStore.customFolders, id: \.self) { folder in
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.indigo.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.indigo)
                            }
                            Text(folder)
                                .font(.system(size: 16))
                            Spacer()
                            let count = todoStore.todos.filter { $0.customFolder == folder }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.indigo)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.indigo.opacity(0.12), in: Capsule())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            todoStore.removeCustomFolder(todoStore.customFolders[i])
                        }
                    }
                    .onMove { source, dest in
                        todoStore.moveCustomFolder(from: source, to: dest)
                    }
                }
            } header: {
                HStack {
                    Text("Eigene Ordner")
                    Spacer()
                    Button {
                        newFolderName = ""
                        showingAddAlert = true
                    } label: {
                        Label("Hinzufügen", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            } footer: {
                Text("Aufgaben kannst du über das Kontextmenü (langer Druck) oder den Auswahlmodus in Ordner verschieben.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ordner")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .alert("Neuer Ordner", isPresented: $showingAddAlert) {
            TextField("Ordnername", text: $newFolderName)
            Button("Erstellen") { todoStore.addCustomFolder(newFolderName) }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Gib einen Namen für den neuen Ordner ein.")
        }
    }
}
