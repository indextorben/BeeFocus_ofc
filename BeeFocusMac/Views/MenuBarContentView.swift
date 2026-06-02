import SwiftUI

// MARK: - Tab Enum

enum MenuTab: CaseIterable {
    case tasks, timer

    var label: String {
        switch self {
        case .tasks: return "Aufgaben"
        case .timer: return "Timer"
        }
    }

    var icon: String {
        switch self {
        case .tasks: return "checklist"
        case .timer: return "timer"
        }
    }
}

// MARK: - MenuBarContentView

struct MenuBarContentView: View {
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var timerMgr:  MacTimerManager

    @State private var selectedTab: MenuTab = .tasks

    private let accent = Color.orange

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider()
            tabContent
                .frame(minHeight: 320, maxHeight: 480)
            Divider()
            footer
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "hexagon.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
                .symbolRenderingMode(.hierarchical)
            Text("BeeFocus")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            if todoStore.isSyncing {
                ProgressView().scaleEffect(0.65)
            } else {
                Button {
                    Task { await todoStore.fetchTodos() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.label)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(selectedTab == tab ? accent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? accent.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            accent.frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .tasks: TasksTabView()
        case .timer: TimerTabView()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Einstellungen") {
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            Spacer()
            Button("Beenden") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
