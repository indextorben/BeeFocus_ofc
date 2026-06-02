import SwiftUI

struct TimerTabView: View {
    @EnvironmentObject var mgr: MacTimerManager
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            modeChips
            Divider()
            timerDisplay
            controlButtons
            if showSettings {
                Divider()
                settingsPanel
            }
            Divider()
            HStack {
                sessionCounter
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { showSettings.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13))
                        .foregroundStyle(showSettings ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Mode Chips

    private var modeChips: some View {
        HStack(spacing: 6) {
            modeChip("Fokus", mode: .focus,      mins: mgr.focusDuration)
            modeChip("Kurze Pause", mode: .shortBreak, mins: mgr.shortBreak)
            modeChip("Lange Pause", mode: .longBreak,  mins: mgr.longBreak)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func modeChip(_ label: String, mode: TimerMode, mins: Int) -> some View {
        let active = mgr.mode == mode
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
            Text("\(mins) min")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(active ? mode.color : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(active ? mode.color.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(active ? mode.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(mgr.mode.color.opacity(0.12), lineWidth: 8)
                .frame(width: 140, height: 140)

            // Progress ring
            Circle()
                .trim(from: 0, to: mgr.progress)
                .stroke(
                    AngularGradient(
                        colors: [mgr.mode.color.opacity(0.6), mgr.mode.color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: mgr.progress)

            VStack(spacing: 4) {
                Text(mgr.timeString)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(mgr.mode.color)
                Text(mgr.mode.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 16) {
            Button {
                mgr.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)

            Button {
                mgr.startPause()
            } label: {
                Image(systemName: mgr.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(mgr.mode.color, in: Circle())
                    .shadow(color: mgr.mode.color.opacity(0.4), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                mgr.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Session Counter

    private var sessionCounter: some View {
        HStack(spacing: 4) {
            ForEach(0..<mgr.sessionsUntilLong, id: \.self) { i in
                Circle()
                    .fill(i < (mgr.sessionCount % mgr.sessionsUntilLong) || (mgr.sessionCount > 0 && mgr.sessionCount % mgr.sessionsUntilLong == 0 && i < mgr.sessionsUntilLong)
                          ? mgr.mode.color
                          : Color.primary.opacity(0.12))
                    .frame(width: 7, height: 7)
            }
            Text("Session \(mgr.sessionCount + 1)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        VStack(spacing: 10) {
            durationRow("Fokus", value: $mgr.focusDuration, range: 5...90)
            durationRow("Kurze Pause", value: $mgr.shortBreak, range: 1...30)
            durationRow("Lange Pause", value: $mgr.longBreak, range: 5...60)
            HStack {
                Text("Sitzungen bis lange Pause")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper("\(mgr.sessionsUntilLong)", value: $mgr.sessionsUntilLong, in: 2...8)
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func durationRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Stepper("\(value.wrappedValue) min", value: value, in: range)
                .font(.system(size: 12))
        }
    }
}
