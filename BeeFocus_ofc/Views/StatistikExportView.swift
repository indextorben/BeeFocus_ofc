import SwiftUI

struct StatistikExportView: View {
    let completed: Int
    let open: Int
    let total: Int
    let overdue: Int

    var completionRate: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 40) {

            Text("Statistics Overview")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)

            CompletionDonut(completed: completed, total: total)

            HStack(spacing: 20) {
                statBox(title: "Total", value: total)
                statBox(title: "Completed", value: completed)
                statBox(title: "Open", value: open)
                statBox(title: "Overdue", value: overdue, highlight: .red)
            }

            Spacer()
        }
        .padding(60)
        .frame(width: 1240, height: 1754)
        .background(Color.white) // ❗ FEST
    }

    private func statBox(
        title: String,
        value: Int,
        highlight: Color = .blue
    ) -> some View {
        VStack {
            Text("\(value)")
                .font(.largeTitle.bold())
                .foregroundColor(highlight)

            Text(title)
                .foregroundColor(.gray)
        }
    }
}
