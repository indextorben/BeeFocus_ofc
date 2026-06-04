import SwiftUI

struct PlusActionMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    let onNeu: () -> Void
    let onKalender: () -> Void
    let onImport: () -> Void

    @State private var appeared = false
    @State private var pressedRow: Int? = nil

    private var isDark: Bool { colorScheme == .dark }
    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }

    private struct ActionItem {
        let icon: String
        let gradient: [Color]
        let title: String
        let description: String
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle

            VStack(alignment: .leading, spacing: 14) {
                sectionHeader
                actionsCard
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(backgroundGradient)
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
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.0), value: appeared)
    }

    private var sectionHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(c1)
            Text("NEUE AUFGABE")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .offset(x: appeared ? 0 : -20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.08), value: appeared)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            row(index: 0,
                item: ActionItem(icon: "plus.circle.fill", gradient: [c1, c2],
                                 title: "Neue Aufgabe", description: "Aufgabe manuell erstellen")
            ) { onNeu(); dismiss() }

            divider

            row(index: 1,
                item: ActionItem(icon: "calendar.badge.plus",
                                 gradient: [.indigo, Color(red: 0.3, green: 0.2, blue: 0.9)],
                                 title: "Aus Kalender importieren",
                                 description: "Add appointments as tasks")
            ) { onKalender(); dismiss() }

            divider

            row(index: 2,
                item: ActionItem(icon: "square.and.arrow.down.fill",
                                 gradient: [.green, Color(red: 0.1, green: 0.65, blue: 0.35)],
                                 title: "Datei importieren",
                                 description: "Aufgaben aus JSON-Datei laden")
            ) { onImport(); dismiss() }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(
                    colors: [c1.opacity(isDark ? 0.14 : 0.09),
                             c2.opacity(isDark ? 0.07 : 0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [c1.opacity(isDark ? 0.50 : 0.32),
                                 c2.opacity(isDark ? 0.22 : 0.16)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
        .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
        .offset(y: appeared ? 0 : 30)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.12), value: appeared)
    }

    private var divider: some View {
        Divider().opacity(0.25).padding(.leading, 74)
    }

    @ViewBuilder
    private func row(index: Int, item: ActionItem, action: @escaping () -> Void) -> some View {
        let isPressed = pressedRow == index
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pressedRow = index
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                action()
            }
        } label: {
            HStack(spacing: 14) {
                iconBadge(icon: item.icon, gradient: item.gradient, isPressed: isPressed)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(item.description)
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
            .background(
                isPressed
                    ? item.gradient.first?.opacity(0.08) ?? Color.clear
                    : Color.clear
            )
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .offset(x: appeared ? 0 : -24)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.78)
                .delay(0.14 + Double(index) * 0.06),
            value: appeared
        )
    }

    private func iconBadge(icon: String, gradient: [Color], isPressed: Bool) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .shadow(
                color: gradient.first?.opacity(isPressed ? 0.55 : 0.35) ?? .clear,
                radius: isPressed ? 8 : 5,
                x: 0, y: isPressed ? 4 : 2
            )
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isPressed)
    }

    private var backgroundGradient: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [c1.opacity(isDark ? 0.13 : 0.07),
                         c2.opacity(isDark ? 0.06 : 0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
