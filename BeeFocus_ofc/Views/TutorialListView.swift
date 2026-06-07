import SwiftUI

struct TutorialListView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private var allItems: [(item: TutorialItem, section: TutorialSection, accent: Color)] {
        let accents: [Color] = [
            .blue, .indigo, Color(red: 0.15, green: 0.55, blue: 0.9),
            Color(red: 0.95, green: 0.3, blue: 0.3), .purple,
            Color(red: 0.15, green: 0.75, blue: 0.45), .pink,
            Color(red: 0.7, green: 0.45, blue: 0.2), Color(red: 0.95, green: 0.65, blue: 0.1),
            Color(red: 0.8, green: 0.2, blue: 0.9), .teal, .cyan
        ]
        let items = TutorialData.all(localizer: localizer)
        return items.enumerated().flatMap { idx, item in
            item.sections.map { section in
                (item: item, section: section, accent: accents[min(idx, accents.count - 1)])
            }
        }
    }

    private var filtered: [(item: TutorialItem, section: TutorialSection, accent: Color)] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return allItems }
        let q = searchText.lowercased()
        return allItems.filter { entry in
            entry.item.title.lowercased().contains(q) ||
            entry.section.heading.lowercased().contains(q) ||
            entry.section.text.lowercased().contains(q) ||
            (entry.section.highlights ?? []).contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    searchBar
                        .padding(.bottom, 4)

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { _, entry in
                            NavigationLink(destination: TutorialView(section: entry.section, tutorialTitle: entry.item.title)) {
                                tutorialCard(item: entry.item, section: entry.section, accent: entry.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Tutorials")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.45) : Color.secondary)

            TextField(localizer.localizedString(forKey: "tut_search_placeholder"), text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(isDark ? .white : .primary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(isDark ? .white.opacity(0.4) : Color.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .themeGlass(cornerRadius: 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(themeC1.opacity(0.5))
            Text(localizer.localizedString(forKey: "tut_search_empty"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tutorial Card

    private func tutorialCard(item: TutorialItem, section: TutorialSection, accent: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(isDark ? 0.22 : 0.12))
                    .frame(width: 50, height: 50)
                Image(systemName: item.icon)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [accent, accent.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                    .multilineTextAlignment(.leading)

                if let highlights = section.highlights, !highlights.isEmpty {
                    Text(highlights.prefix(3).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(isDark ? .white.opacity(0.45) : Color.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count = section.highlights?.count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent.opacity(isDark ? 0.2 : 0.1))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isDark ? .white.opacity(0.22) : Color.secondary.opacity(0.4))
        }
        .padding(14)
        .themeGlass(cornerRadius: 18)
    }
}
