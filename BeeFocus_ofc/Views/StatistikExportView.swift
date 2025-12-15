import SwiftUI

struct StatistikExportView: View {
    let todoStore: TodoStore

    // MARK: - Berechnungen
    var completed: Int {
        todoStore.todos.filter { $0.isCompleted }.count
    }

    var open: Int {
        todoStore.todos.filter { !$0.isCompleted }.count
    }

    var total: Int {
        todoStore.todos.count
    }

    var completionRate: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var overdue: Int {
        todoStore.todos.filter {
            !$0.isCompleted &&
            ($0.dueDate ?? .distantFuture) < Date()
        }.count
    }

    // MARK: - View
    var body: some View {
        VStack(spacing: 40) {

            // Header
            VStack(spacing: 8) {
                Text("Statistik Übersicht")
                    .font(.system(size: 48, weight: .bold))

                Text("Deine Produktivität auf einen Blick")
                    .font(.system(size: 22))
                    .foregroundColor(.gray)
            }

            // Donut Fortschritt
            CompletionDonut(completed: completed, total: total)

            // KPI Cards
            HStack(spacing: 20) {
                statBox(title: "Gesamt", value: total)
                statBox(title: "Erledigt", value: completed)
                statBox(title: "Offen", value: open)
                statBox(title: "Überfällig", value: overdue, highlight: .red)
            }

            Divider()

            // Footer
            VStack(spacing: 6) {
                Text("Exportiert aus BeeFocus")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)

                Text("Erstellt am \(Date().formatted(date: .numeric, time: .shortened))")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    // MARK: - Stat Card
    private func statBox(
        title: String,
        value: Int,
        highlight: Color = .blue
    ) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(highlight)

            Text(title)
                .font(.system(size: 18))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(20)
    }
}
