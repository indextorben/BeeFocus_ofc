import SwiftUI

struct TutorialView: View {
    let section: TutorialSection
    let tutorialTitle: String

    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var heroAppeared = false

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroCard
                    if let highlights = section.highlights, !highlights.isEmpty {
                        highlightsSection(highlights)
                    }
                    if let bullets = section.bulletPoints, !bullets.isEmpty {
                        bulletsSection(bullets)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(tutorialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                heroAppeared = true
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(isDark ? 0.28 : 0.16), themeC2.opacity(isDark ? 0.14 : 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 88, height: 88)
                Circle()
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(isDark ? 0.18 : 0.10), themeC2.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 64, height: 64)
                Image(systemName: section.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [themeC1, themeC2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .scaleEffect(heroAppeared ? 1 : 0.6)
            .opacity(heroAppeared ? 1 : 0)

            VStack(spacing: 8) {
                Text(section.heading)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isDark ? .white : .primary)
                    .multilineTextAlignment(.center)

                Text(section.text)
                    .font(.subheadline)
                    .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: heroAppeared)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .themeGlass(cornerRadius: 22)
    }

    // MARK: - Highlights Section

    private func highlightsSection(_ highlights: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "sparkles",
                title: localizer.localizedString(forKey: "highlights_title"),
                color: themeC1
            )

            VStack(spacing: 10) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                    if let data = section.highlightData?[highlight] {
                        NavigationLink(destination: SubFunctionView(data: data)) {
                            highlightRow(
                                title: highlight,
                                icon: section.highlightIcons?[highlight] ?? "sparkles",
                                index: index
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func highlightRow(title: String, icon: String, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(themeC1.opacity(isDark ? 0.22 : 0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(themeC1)
            }

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isDark ? .white.opacity(0.25) : Color.secondary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .themeGlass(cornerRadius: 14)
    }

    // MARK: - Bullets Section

    private func bulletsSection(_ bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                icon: "checkmark.seal.fill",
                title: localizer.localizedString(forKey: "summary_title"),
                color: themeC2
            )

            VStack(spacing: 10) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { index, point in
                    bulletRow(text: point, index: index)
                }
            }
        }
    }

    private func bulletRow(text: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeC2.opacity(isDark ? 0.22 : 0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(themeC2)
            }

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isDark ? .white.opacity(0.8) : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .themeGlass(cornerRadius: 14)
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isDark ? .white.opacity(0.55) : .secondary)
        }
        .padding(.leading, 2)
    }
}
