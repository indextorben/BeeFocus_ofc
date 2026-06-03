import SwiftUI

struct EllipsisMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    let showFolderOption: Bool
    let onMoveToFolder: () -> Void
    let onVorlagen: () -> Void
    let onDeleteByDate: () -> Void
    let onTrashCompleted: () -> Void
    let onRemoveDuplicates: () -> Void

    @State private var appeared = false
    @State private var pressedRow: String? = nil

    private var isDark: Bool { colorScheme == .dark }
    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if showFolderOption {
                        sectionHeader(label: "AUSWAHL", icon: "checkmark.circle.fill", color: c1)
                        folderCard
                    }

                    sectionHeader(label: "AUFGABEN", icon: "ellipsis.circle.fill", color: c1)
                        .padding(.top, showFolderOption ? 4 : 0)
                    actionsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .background(backgroundView)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .scaleEffect(x: appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.0), value: appeared)
    }

    private func sectionHeader(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -16)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)
    }

    private var folderCard: some View {
        menuCard(startIndex: 0) {
            row(id: "folder", index: 0,
                icon: "folder.badge.plus",
                gradient: [c1, c2],
                title: "In Ordner verschieben",
                description: "Ausgewählte Aufgaben verschieben",
                isDestructive: false
            ) { onMoveToFolder(); dismiss() }
        }
    }

    private var actionsCard: some View {
        menuCard(startIndex: showFolderOption ? 1 : 0) {
            row(id: "vorlagen", index: showFolderOption ? 1 : 0,
                icon: "rectangle.stack.fill",
                gradient: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.15, blue: 0.85)],
                title: "Aufgaben-Vorlagen",
                description: "Vorgefertigte Aufgaben verwenden",
                isDestructive: false
            ) { onVorlagen(); dismiss() }

            Divider().opacity(0.25).padding(.leading, 74)

            row(id: "bydate", index: showFolderOption ? 2 : 1,
                icon: "calendar.badge.minus",
                gradient: [.teal, Color(red: 0.0, green: 0.55, blue: 0.65)],
                title: "Nach Zeitraum löschen",
                description: "Abgeschlossene nach Datum entfernen",
                isDestructive: false
            ) { onDeleteByDate(); dismiss() }

            Divider().opacity(0.25).padding(.leading, 74)

            row(id: "trash", index: showFolderOption ? 3 : 2,
                icon: "trash.fill",
                gradient: [.red, Color(red: 0.75, green: 0.1, blue: 0.1)],
                title: "Abgeschlossene in Papierkorb",
                description: "Erledigte Aufgaben verschieben",
                isDestructive: true
            ) { onTrashCompleted(); dismiss() }

            Divider().opacity(0.25).padding(.leading, 74)

            row(id: "dupes", index: showFolderOption ? 4 : 3,
                icon: "doc.on.doc.fill",
                gradient: [.orange, Color(red: 0.85, green: 0.4, blue: 0.0)],
                title: "Duplikate entfernen",
                description: "Doppelte Aufgaben löschen",
                isDestructive: true
            ) { onRemoveDuplicates(); dismiss() }
        }
    }

    @ViewBuilder
    private func menuCard(startIndex: Int, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [c1.opacity(isDark ? 0.14 : 0.09), c2.opacity(isDark ? 0.07 : 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [c1.opacity(isDark ? 0.50 : 0.32), c2.opacity(isDark ? 0.22 : 0.16)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
        .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
        .offset(y: appeared ? 0 : 30)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.10 + Double(startIndex) * 0.04), value: appeared)
    }

    @ViewBuilder
    private func row(id: String, index: Int, icon: String, gradient: [Color], title: String, description: String, isDestructive: Bool, action: @escaping () -> Void) -> some View {
        let delay = 0.14 + Double(index) * 0.055
        let isPressed = pressedRow == id
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressedRow = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { action() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                    .shadow(color: (gradient.first ?? .clear).opacity(isPressed ? 0.55 : 0.35), radius: isPressed ? 8 : 5, x: 0, y: isPressed ? 4 : 2)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isPressed)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDestructive ? .red : .primary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(isPressed ? 0.8 : 0.4))
                    .offset(x: isPressed ? 3 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .background((gradient.first ?? .clear).opacity(isPressed ? 0.08 : 0))
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -24)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    private var backgroundView: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [c1.opacity(isDark ? 0.13 : 0.07), c2.opacity(isDark ? 0.06 : 0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
