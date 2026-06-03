import SwiftUI

struct PomodoroSettingsView: View {

    @Binding var focusTime: Int
    @Binding var shortBreakTime: Int
    @Binding var longBreakTime: Int
    @Binding var sessionsUntilLongBreak: Int
    @AppStorage("dailyFocusGoalMinutes") private var dailyGoal: Int = 60
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var appeared = false

    private var isDark: Bool { colorScheme == .dark }
    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                dragHandle
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        settingsCard(
                            icon: "brain.head.profile",
                            gradient: [c1, c2],
                            title: localizer.localizedString(forKey: "focus"),
                            sectionIndex: 0
                        ) {
                            stepperRow(
                                icon: "timer",
                                color: c1,
                                label: localizer.localizedString(forKey: "focus_time"),
                                value: $focusTime,
                                range: 5...120,
                                step: 5,
                                unit: "min",
                                rowIndex: 0,
                                sectionIndex: 0
                            )
                        }

                        settingsCard(
                            icon: "cup.and.heat.waves.fill",
                            gradient: [.teal, Color(red: 0.0, green: 0.55, blue: 0.65)],
                            title: localizer.localizedString(forKey: "breaks"),
                            sectionIndex: 1
                        ) {
                            stepperRow(
                                icon: "arrow.trianglehead.counterclockwise",
                                color: .teal,
                                label: localizer.localizedString(forKey: "short_break"),
                                value: $shortBreakTime,
                                range: 1...30,
                                step: 1,
                                unit: "min",
                                rowIndex: 0,
                                sectionIndex: 1
                            )
                            Divider().opacity(0.25).padding(.leading, 58)
                            stepperRow(
                                icon: "moon.zzz.fill",
                                color: .indigo,
                                label: localizer.localizedString(forKey: "long_break"),
                                value: $longBreakTime,
                                range: 5...60,
                                step: 5,
                                unit: "min",
                                rowIndex: 1,
                                sectionIndex: 1
                            )
                        }

                        settingsCard(
                            icon: "repeat.circle.fill",
                            gradient: [Color(red: 0.55, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.15, blue: 0.85)],
                            title: localizer.localizedString(forKey: "cycles"),
                            sectionIndex: 2
                        ) {
                            stepperRow(
                                icon: "arrow.3.trianglepath",
                                color: Color(red: 0.55, green: 0.35, blue: 1.0),
                                label: localizer.localizedString(forKey: "sessions_until_long_break"),
                                value: $sessionsUntilLongBreak,
                                range: 2...10,
                                step: 1,
                                unit: "×",
                                rowIndex: 0,
                                sectionIndex: 2
                            )
                        }

                        settingsCard(
                            icon: "target",
                            gradient: [.orange, Color(red: 0.85, green: 0.4, blue: 0.0)],
                            title: "Tagesziel",
                            sectionIndex: 3
                        ) {
                            stepperRow(
                                icon: "flame.fill",
                                color: .orange,
                                label: "Fokuszeit-Ziel",
                                value: $dailyGoal,
                                range: 0...480,
                                step: 5,
                                unit: "min",
                                rowIndex: 0,
                                sectionIndex: 3
                            )
                            if dailyGoal == 0 {
                                Text("Kein Tagesziel gesetzt")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
        .onChange(of: focusTime)              { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
        .onChange(of: shortBreakTime)         { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
        .onChange(of: longBreakTime)          { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
        .onChange(of: sessionsUntilLongBreak) { _ in TimerManager.shared.applyUpdatedSettingsIfNeeded() }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .scaleEffect(x: appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7).delay(0.0), value: appeared)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizer.localizedString(forKey: "settings"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text("Timer & Fokuszeiten anpassen")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -12)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.06), value: appeared)
    }

    // MARK: - Settings Card

    @ViewBuilder
    private func settingsCard<Content: View>(
        icon: String,
        gradient: [Color],
        title: String,
        sectionIndex: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let delay = 0.10 + Double(sectionIndex) * 0.07
        VStack(alignment: .leading, spacing: 0) {
            // Section label
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(gradient.first ?? c1)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 10)

            // Card
            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
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
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 28)
        .animation(.spring(response: 0.55, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    // MARK: - Stepper Row

    private func stepperRow(
        icon: String,
        color: Color,
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        rowIndex: Int,
        sectionIndex: Int
    ) -> some View {
        let delay = 0.16 + Double(sectionIndex) * 0.07 + Double(rowIndex) * 0.055
        return HStack(spacing: 14) {
            // Icon badge
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(isDark ? 0.18 : 0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            // Custom stepper
            HStack(spacing: 0) {
                Button {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(value.wrappedValue <= range.lowerBound ? .secondary.opacity(0.3) : color)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)\(unit)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDark ? .white : .primary)
                    .frame(minWidth: 46)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value.wrappedValue)

                Button {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(value.wrappedValue >= range.upperBound ? .secondary.opacity(0.3) : color)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
            .background(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.05),
                        in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay), value: appeared)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            LinearGradient(
                colors: [c1.opacity(isDark ? 0.13 : 0.07),
                         c2.opacity(isDark ? 0.06 : 0.03)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}
