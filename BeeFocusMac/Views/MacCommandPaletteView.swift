import SwiftUI

// MARK: - Action Model

struct MacPaletteAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let icon: String
    let shortcut: String?
    let action: () -> Void
}

// MARK: - Command Palette View

struct MacCommandPaletteView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0

    let actions: [MacPaletteAction]

    private var filtered: [MacPaletteAction] {
        guard !searchText.isEmpty else { return actions }
        return actions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.subtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().opacity(0.15)
            actionList
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        // Navigation shortcuts (hidden buttons — macOS 13+ compatible)
        .background(keyboardControls)
        .onChange(of: searchText) { _ in selectedIndex = 0 }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Aktion suchen…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Button {
                withAnimation(.spring(response: 0.22)) { isPresented = false }
            } label: {
                Text("esc")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.primary.opacity(0.09), in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Action list

    @ViewBuilder
    private var actionList: some View {
        if filtered.isEmpty {
            Text("Keine Aktionen gefunden")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, act in
                            actionRow(act, isSelected: idx == selectedIndex, index: idx)
                        }
                    }
                }
                .onChange(of: selectedIndex) { _ in
                    guard selectedIndex < filtered.count else { return }
                    withAnimation { proxy.scrollTo(filtered[selectedIndex].id, anchor: .center) }
                }
            }
        }
    }

    private func actionRow(_ act: MacPaletteAction, isSelected: Bool, index: Int) -> some View {
        Button {
            act.action()
            withAnimation(.spring(response: 0.22)) { isPresented = false }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color.orange.opacity(0.2) : Color.primary.opacity(0.07))
                        .frame(width: 30, height: 30)
                    Image(systemName: act.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? .orange : .primary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(act.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    if let sub = act.subtitle {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let sh = act.shortcut {
                    Text(sh)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? Color.orange.opacity(0.09) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(act.id)
        .onHover { if $0 { selectedIndex = index } }
    }

    // MARK: - Keyboard controls (hidden buttons)

    private var keyboardControls: some View {
        Group {
            Button("") {
                selectedIndex = max(0, selectedIndex - 1)
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .opacity(0)

            Button("") {
                selectedIndex = min(filtered.count - 1, selectedIndex + 1)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .opacity(0)

            Button("") {
                guard selectedIndex < filtered.count else { return }
                filtered[selectedIndex].action()
                withAnimation(.spring(response: 0.22)) { isPresented = false }
            }
            .keyboardShortcut(.return, modifiers: [])
            .opacity(0)
        }
    }
}
