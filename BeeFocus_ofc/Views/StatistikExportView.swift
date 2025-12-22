import SwiftUI

struct StatistikExportView: View {
    let completed: Int
    let open: Int
    let total: Int
    let overdue: Int
    
    // LocalizationManager einbinden
    @ObservedObject private var localizer = LocalizationManager.shared

    var completionRate: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }

    var body: some View {
        VStack(spacing: 40) {

            Text(localizer.localizedString(forKey: "statistics_overview_title")) // statt "Statistics Overview"
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)

            CompletionDonut(completed: completed, total: total)

            HStack(spacing: 20) {
                statBox(titleKey: "total", value: total)
                statBox(titleKey: "completed", value: completed)
                statBox(titleKey: "open", value: open)
                statBox(titleKey: "overdue", value: overdue, highlight: .red)
            }

            Spacer()
        }
        .padding(60)
        .frame(width: 1240, height: 1754)
        .background(Color.white)
    }

    private func statBox(
        titleKey: String,
        value: Int,
        highlight: Color = .blue
    ) -> some View {
        VStack {
            Text("\(value)")
                .font(.largeTitle.bold())
                .foregroundColor(highlight)

            Text(localizer.localizedString(forKey: titleKey))
                .foregroundColor(.gray)
        }
    }
}
