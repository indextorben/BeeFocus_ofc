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
        GeometryReader { geo in
            // Compute dynamic sizes based on available export size
            let width = geo.size.width
            let height = geo.size.height
            let minSide = min(width, height)

            // Scale factors
            let titleFontSize = minSide * 0.06 // ~6% of smaller side
            let statNumberFontSize = minSide * 0.05
            let spacing = minSide * 0.04
            let horizontalPadding = width * 0.06
            let verticalPadding = height * 0.06

            VStack(spacing: spacing) {
                Text(localizer.localizedString(forKey: "statistics_overview_title"))
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Donut sized proportionally
                CompletionDonut(completed: completed, total: total)
                    .frame(width: minSide * 0.5, height: minSide * 0.5)

                // Stats row
                HStack(spacing: spacing) {
                    statBox(titleKey: "total", value: total, numberFontSize: statNumberFontSize, subtitleFontSize: statNumberFontSize * 0.4)
                    statBox(titleKey: "completed", value: completed, numberFontSize: statNumberFontSize, subtitleFontSize: statNumberFontSize * 0.4)
                    statBox(titleKey: "open", value: open, numberFontSize: statNumberFontSize, subtitleFontSize: statNumberFontSize * 0.4)
                    statBox(titleKey: "overdue", value: overdue, highlight: .red, numberFontSize: statNumberFontSize, subtitleFontSize: statNumberFontSize * 0.4)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
        }
    }

    private func statBox(
        titleKey: String,
        value: Int,
        highlight: Color = .blue,
        numberFontSize: CGFloat? = nil,
        subtitleFontSize: CGFloat? = nil
    ) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(numberFontSize != nil ? .system(size: numberFontSize!, weight: .bold) : .largeTitle.bold())
                .foregroundColor(highlight)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(localizer.localizedString(forKey: titleKey))
                .font(subtitleFontSize != nil ? .system(size: subtitleFontSize!, weight: .regular) : .body)
                .foregroundColor(.gray)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
