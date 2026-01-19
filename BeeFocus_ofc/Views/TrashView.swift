import SwiftUI

struct TrashView: View {
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared

    var body: some View {
        List {
            if todoStore.deletedTodos.isEmpty {
                Text(localizer.localizedString(forKey: "Keine gelöschten Aufgaben."))
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(todoStore.deletedTodos.enumerated()), id: \.element.todo.id) { index, entry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.todo.title).font(.headline)
                            if !entry.todo.description.isEmpty {
                                Text(entry.todo.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Text(dateString(entry.deletedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(spacing: 8) {
                            Button(localizer.localizedString(forKey: "Wiederherstellen")) {
                                todoStore.restoreDeleted(at: index)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                todoStore.removeFromTrash(at: index)
                            } label: {
                                Text(localizer.localizedString(forKey: "Endgültig löschen"))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "Papierkorb"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !todoStore.deletedTodos.isEmpty {
                    Button(role: .destructive) {
                        todoStore.emptyTrash()
                    } label: {
                        Label(localizer.localizedString(forKey: "Papierkorb leeren"), systemImage: "trash.slash")
                    }
                }
            }
        }
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return String(format: localizer.localizedString(forKey: "Gelöscht am %@"), df.string(from: date))
    }
}

#Preview {
    TrashView().environmentObject(TodoStore())
}
