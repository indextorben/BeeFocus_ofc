import SwiftUI

struct MacTimerView: View {
    @EnvironmentObject var mgr: MacTimerManager
    @Environment(\.activeTheme) private var activeTheme
    @Environment(\.colorScheme)  private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0
    @State private var appeared = false
    @State private var showSettings = false

    private var isDark: Bool { colorScheme == .dark }

    private var accentColors: [Color] {
        if mgr.mode != .focus { return [Color(red: 0.2, green: 0.8, blue: 0.5), .mint] }
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return [c1, c2]
    }
    private var accent: Color { accentColors[0] }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

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

                Spacer().frame(height: 24)

                sessionDots
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                Spacer().frame(height: 36)

                controls
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.3), value: appeared)

                Spacer()

                if showSettings { settingsPanel }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { wavePhase1 = .pi * 2 }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { wavePhase2 = .pi * 2 }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(
                        colors: [accent.opacity(isDark ? 0.30 : 0.16), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width, height: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.4)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 0.6), value: mgr.mode)

                GeometryReader { g in
                    WaveShape(phase: wavePhase2, amplitude: 18, frequency: 1.5)
                        .fill(accentColors[1].opacity(isDark ? 0.09 : 0.06))
                        .frame(width: g.size.width, height: g.size.height * 0.38)
                        .position(x: g.size.width * 0.5, y: g.size.height - g.size.height * 0.19)
                    WaveShape(phase: wavePhase1, amplitude: 12, frequency: 2.2)
                        .fill(accentColors[0].opacity(isDark ? 0.14 : 0.09))
                        .frame(width: g.size.width, height: g.size.height * 0.25)
                        .position(x: g.size.width * 0.5, y: g.size.height - g.size.height * 0.125)
                }
            }
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

    // MARK: - Timer Ring

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.15), lineWidth: 14)
                .frame(width: 220, height: 220)

            Circle()
                .trim(from: 0, to: mgr.progress)
                .stroke(
                    AngularGradient(colors: [accentColors[1].opacity(0.7), accentColors[0]],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: mgr.progress)
                .shadow(color: accent.opacity(0.4), radius: 8)

            VStack(spacing: 6) {
                Text(mgr.timeString)
                    .font(.system(size: 52, weight: .bold, design: .monospaced))
                    .foregroundStyle(accent)
                Text(mgr.mode.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Session Dots

    private var sessionDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<mgr.sessionsUntilLong, id: \.self) { i in
                let filled = i < (mgr.sessionCount % mgr.sessionsUntilLong)
                Circle()
                    .fill(filled ? accent : Color.primary.opacity(0.15))
                    .frame(width: 8, height: 8)
                    .scaleEffect(filled ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: filled)
            }
            Text("Sitzung \(mgr.sessionCount + 1)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(spacing: 24) {
            // Reset
            Button { mgr.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button { mgr.startPause() } label: {
                Image(systemName: mgr.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: accentColors,
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    )
                    .shadow(color: accent.opacity(0.5), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            // Skip
            Button { mgr.skipToNext() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, height: 52)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            // Settings toggle
            Button {
                withAnimation(.spring(response: 0.35)) { showSettings.toggle() }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(showSettings ? accent : .secondary)
                    .frame(width: 52, height: 52)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
