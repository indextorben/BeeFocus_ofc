import SwiftUI

struct MacTimerView: View {
    @EnvironmentObject var mgr: MacTimerManager
    @Environment(\.activeTheme) private var activeTheme
    @Environment(\.colorScheme)  private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var appeared    = false
    @State private var showSettings = false

    private var isDark: Bool { colorScheme == .dark }

    private var accentColors: [Color] {
        if mgr.mode != .focus { return [Color(red: 0.2, green: 0.8, blue: 0.5), .mint] }
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return [c1, c2]
    }
    private var accent: Color { accentColors[0] }

    private var modeLabel: String {
        switch mgr.mode {
        case .focus:      return "Fokus · Sitzung \(mgr.sessionCount + 1)"
        case .shortBreak: return "Kurze Pause"
        case .longBreak:  return "Lange Pause"
        }
    }

    private var modeIcon: String {
        switch mgr.mode {
        case .focus:                 return "brain.head.profile"
        case .shortBreak, .longBreak: return "cup.and.saucer.fill"
        }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            VStack(spacing: 0) {
                modeChips
                    .padding(.top, 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: appeared)

                Spacer()

                timerRing
                    .scaleEffect(appeared ? 1 : 0.85)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.05), value: appeared)

                Spacer().frame(height: 28)

                modeBadge
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

                Spacer().frame(height: 36)

                controls
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.30), value: appeared)

                Spacer()

                if showSettings { settingsPanel }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation { appeared = true }
        }
    }

    // MARK: - Mode Chips

    private var modeChips: some View {
        HStack(spacing: 8) {
            modeChip("Fokus",       mode: .focus,      color: accent)
            modeChip("Kurze Pause", mode: .shortBreak, color: Color(red: 0.2, green: 0.8, blue: 0.5))
            modeChip("Lange Pause", mode: .longBreak,  color: Color(red: 0.3, green: 0.6, blue: 1.0))
        }
    }

    private func modeChip(_ label: String, mode: TimerMode, color: Color) -> some View {
        let active = mgr.mode == mode
        return Button { mgr.mode = mode; mgr.resetToCurrentMode() } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(active ? color : color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer Ring (identisch mit iOS)

    private var timerRing: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(RadialGradient(
                    colors: [accent.opacity(isDark ? 0.18 : 0.10), .clear],
                    center: .center, startRadius: 0, endRadius: 160))
                .frame(width: 320, height: 320)
                .blur(radius: 8)

            // Glass backing
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 260, height: 260)
                .overlay(Circle().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(isDark ? 0.15 : 0.70),
                                 Color.white.opacity(isDark ? 0.05 : 0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5))
                .shadow(color: Color.black.opacity(isDark ? 0.30 : 0.10), radius: 24, x: 0, y: 8)

            // Track
            Circle()
                .stroke(Color.primary.opacity(0.07), lineWidth: 18)
                .frame(width: 220, height: 220)

            // Progress arc
            Circle()
                .trim(from: 0, to: mgr.progress)
                .stroke(
                    LinearGradient(colors: accentColors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: mgr.progress)
                .shadow(color: accent.opacity(0.45), radius: 8, x: 0, y: 0)

            // Time + session dots inside ring
            VStack(spacing: 6) {
                Text(mgr.timeString)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.5)

                HStack(spacing: 7) {
                    ForEach(0..<mgr.sessionsUntilLong, id: \.self) { i in
                        Circle()
                            .fill(i < (mgr.sessionCount % mgr.sessionsUntilLong)
                                  ? accent
                                  : Color.primary.opacity(0.18))
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.3), value: mgr.sessionCount)
                    }
                }
            }
        }
    }

    // MARK: - Mode Badge (identisch mit iOS)

    private var modeBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: modeIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
            Text(modeLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18).padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(isDark ? 0.3 : 0.2), lineWidth: 1))
        .shadow(color: accent.opacity(0.15), radius: 8, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.4), value: mgr.mode)
    }

    // MARK: - Controls (identisch mit iOS: Abstände, Größen, Stil)

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton(icon: "arrow.clockwise", isPrimary: false)  { mgr.reset() }
            controlButton(icon: mgr.isRunning ? "pause.fill" : "play.fill", isPrimary: true) { mgr.startPause() }
                .keyboardShortcut(.space, modifiers: [])
            controlButton(icon: "gearshape.fill", isPrimary: false) {
                withAnimation(.spring(response: 0.35)) { showSettings.toggle() }
            }
        }
    }

    private func controlButton(icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isPrimary {
                    Circle()
                        .fill(LinearGradient(colors: accentColors,
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: accent.opacity(0.5), radius: 16, x: 0, y: 6)
                } else {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(isDark ? 0.15 : 0.65),
                                         Color.white.opacity(isDark ? 0.05 : 0.20)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1))
                        .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 10, x: 0, y: 4)
                }

                Image(systemName: icon)
                    .font(.system(size: isPrimary ? 30 : 22, weight: .semibold))
                    .foregroundStyle(isPrimary ? .white : .primary)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.4), value: mgr.mode)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(spacing: 12) {
            Divider()
            settingRow("Fokuszeit", value: $mgr.focusDuration, range: 5...90)
                .onChange(of: mgr.focusDuration) { v in
                    UserDefaults.standard.set(v, forKey: "mac_focusDuration")
                    if mgr.mode == .focus { mgr.resetToCurrentMode() }
                }
            settingRow("Kurze Pause", value: $mgr.shortBreak, range: 1...30)
                .onChange(of: mgr.shortBreak) { v in
                    UserDefaults.standard.set(v, forKey: "mac_shortBreak")
                    if mgr.mode == .shortBreak { mgr.resetToCurrentMode() }
                }
            settingRow("Lange Pause", value: $mgr.longBreak, range: 5...60)
                .onChange(of: mgr.longBreak) { v in
                    UserDefaults.standard.set(v, forKey: "mac_longBreak")
                    if mgr.mode == .longBreak { mgr.resetToCurrentMode() }
                }
            settingRow("Sitzungen bis lange Pause", value: $mgr.sessionsUntilLong, range: 2...8)
                .onChange(of: mgr.sessionsUntilLong) { v in
                    UserDefaults.standard.set(v, forKey: "mac_sessionsUntilLong")
                }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .themeGlass(cornerRadius: 16)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private func settingRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
            Spacer()
            Stepper("\(value.wrappedValue) min", value: value, in: range).font(.system(size: 13))
        }
    }
}
