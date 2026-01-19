import SwiftUI

struct TrashView: View {
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        List {
            Section(header: Text(localizer.localizedString(forKey: "Papierkorb"))) {
                if let last = todoStore.lastDeletedTodo {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(last.title).font(.headline)
                            if !last.description.isEmpty {
                                Text(last.description).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        Button(localizer.localizedString(forKey: "Wiederherstellen")) {
                            todoStore.undoLastDeleted()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    Text(localizer.localizedString(forKey: "Keine gelöschten Aufgaben zum Wiederherstellen."))
                        .foregroundColor(.secondary)
                }
            }

            Section(footer: Text(localizer.localizedString(forKey: "Hinweis: Der Papierkorb zeigt aktuell nur die zuletzt gelöschte Aufgabe an. Mehrfaches Wiederherstellen/Löschen kann über die Toolbar-Undo/Redo genutzt werden."))) {
                EmptyView()
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "Papierkorb"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TrashView().environmentObject(TodoStore())
}
