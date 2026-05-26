import Foundation

// Reads watch-initiated completions from the shared App Group and applies them to TodoStore.
// Call applyPendingWatchCompletions() whenever the app becomes active.
final class PhoneSessionManager {
    static let shared = PhoneSessionManager()

    private let defaults = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")
    weak var todoStore: TodoStore?

    private init() {}

    func applyPendingWatchCompletions() {
        guard let pending = defaults?.stringArray(forKey: "watchPendingCompletions"),
              !pending.isEmpty,
              let store = todoStore else { return }

        let ids = pending.compactMap { UUID(uuidString: $0) }
        var applied = false

        for id in ids {
            if let todo = store.todos.first(where: { $0.id == id }), !todo.isCompleted {
                store.toggleTodo(todo)
                applied = true
            }
        }

        defaults?.removeObject(forKey: "watchPendingCompletions")

        if applied { store.writeWidgetSnapshot() }
    }
}
