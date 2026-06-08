import SwiftUI

struct MacMainWindowView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager
    @Environment(\.activeTheme) private var activeTheme
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @State private var selectedTab: Int = 0

    private var accent: Color { activeTheme.isEmpty ? .orange : activeTheme.themeAccent }

    var body: some View {
        VStack(spacing: 0) {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            bottomTabBar
        }
        .frame(minWidth: 390, minHeight: 700)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            MacTasksView()
                .environmentObject(todoStore)
        case 1:
            MacTagesplanerView()
                .environmentObject(todoStore)
        case 2:
            MacTimerView()
                .environmentObject(timerMgr)
        case 3:
            MacStatistikView()
                .environmentObject(todoStore)
                .environmentObject(timerMgr)
        case 4:
            MacBrainDumpView()
                .environmentObject(todoStore)
        default:
            MacSettingsView()
                .environmentObject(timerMgr)
                .environmentObject(todoStore)
        }
    }

    // MARK: - Bottom Tab Bar (iOS-Style)

    private struct TabItem {
        let icon: String
        let label: String
        let tag: Int
    }

    private let tabs: [TabItem] = [
        .init(icon: "checklist",                   label: "Aufgaben",   tag: 0),
        .init(icon: "calendar.day.timeline.left",  label: "Tag",        tag: 1),
        .init(icon: "timer",                       label: "Timer",      tag: 2),
        .init(icon: "chart.bar.fill",              label: "Statistik",  tag: 3),
        .init(icon: "brain",                       label: "Brain",      tag: 4),
        .init(icon: "gearshape.fill",              label: "Mehr",       tag: 5),
    ]

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedTab = tab.tag
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                            .symbolVariant(selectedTab == tab.tag ? .fill : .none)
                            .scaleEffect(selectedTab == tab.tag ? 1.1 : 1.0)
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab.tag ? accent : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
    }
}
