import SwiftUI

struct BreathingPattern: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let inhale: Double
    let hold1: Double
    let exhale: Double
    let hold2: Double
    let color: Color

    var totalDuration: Double { inhale + hold1 + exhale + hold2 }

    static let all: [BreathingPattern] = [
        BreathingPattern(
            id: "box",
            name: "Box Breathing",
            subtitle: "Stressabbau & Fokus",
            icon: "square",
            inhale: 4, hold1: 4, exhale: 4, hold2: 4,
            color: Color(red: 0.3, green: 0.65, blue: 1.0)
        ),
        BreathingPattern(
            id: "478",
            name: "4-7-8 Methode",
            subtitle: "Entspannung & Schlaf",
            icon: "moon.fill",
            inhale: 4, hold1: 7, exhale: 8, hold2: 0,
            color: Color(red: 0.55, green: 0.35, blue: 1.0)
        ),
        BreathingPattern(
            id: "calm",
            name: "Ruhiges Atmen",
            subtitle: "Entspannter Einstieg",
            icon: "leaf.fill",
            inhale: 5, hold1: 0, exhale: 5, hold2: 0,
            color: Color(red: 0.2, green: 0.8, blue: 0.5)
        ),
        BreathingPattern(
            id: "power",
            name: "Energie-Atem",
            subtitle: "Aktivierung & Wachheit",
            icon: "bolt.fill",
            inhale: 2, hold1: 0, exhale: 2, hold2: 0,
            color: Color(red: 1.0, green: 0.6, blue: 0.2)
        )
    ]
}

enum BreathPhase {
    case idle, inhale, hold1, exhale, hold2

    var label: String {
        switch self {
        case .idle:   return "Ready?"
        case .inhale: return "Inhale"
        case .hold1:  return "Hold"
        case .exhale: return "Exhale"
        case .hold2:  return "Hold"
        }
    }
}

struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var selectedPattern: BreathingPattern = BreathingPattern.all[0]
    @State private var phase: BreathPhase = .idle
    @State private var countdown: Double = 0
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0.4
    @State private var cyclesCompleted: Int = 0
    @State private var isRunning: Bool = false
    @State private var timer: Timer? = nil
    @State private var phaseTimer: Double = 0

    private var accent: Color { selectedPattern.color }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.12),
                         accent.opacity(0.15)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Breathing Exercise")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { stopSession(); dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Breathing circle
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(accent.opacity(0.06 - Double(i) * 0.015), lineWidth: 20)
                            .frame(width: 220 + CGFloat(i * 30), height: 220 + CGFloat(i * 30))
                            .scaleEffect(scale)
                    }

                    // Main circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.5), accent.opacity(0.15)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(scale)
                        .overlay(
                            Circle()
                                .stroke(accent.opacity(0.5), lineWidth: 2)
                                .frame(width: 220, height: 220)
                                .scaleEffect(scale)
                        )

                    // Phase text
                    VStack(spacing: 8) {
                        Text(phase.label)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)

                        if isRunning && countdown > 0 {
                            Text(String(format: "%.0f", countdown))
                                .font(.system(size: 44, weight: .thin, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .contentTransition(.numericText())
                        } else if !isRunning {
                            Text("Tap to start")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .onTapGesture {
                    if isRunning { stopSession() } else { startSession() }
                }

                Spacer().frame(height: 20)

                // Cycles counter
                if cyclesCompleted > 0 {
                    Text("\(cyclesCompleted) Runde\(cyclesCompleted == 1 ? "" : "n") abgeschlossen")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .transition(.opacity)
                }

                Spacer()

                // Pattern selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("Atemmuster")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.leading, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(BreathingPattern.all) { pattern in
                                PatternCard(
                                    pattern: pattern,
                                    isSelected: selectedPattern.id == pattern.id,
                                    isRunning: isRunning
                                ) {
                                    guard !isRunning else { return }
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPattern = pattern
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: cyclesCompleted)
    }

    // MARK: - Session Control

    private func startSession() {
        isRunning = true
        runPhase(.inhale)
    }

    private func stopSession() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        phase = .idle
        countdown = 0
        withAnimation(.easeInOut(duration: 0.8)) {
            scale = 0.6
            opacity = 0.4
        }
    }

    private func runPhase(_ p: BreathPhase) {
        let duration: Double
        switch p {
        case .inhale: duration = selectedPattern.inhale
        case .hold1:  duration = selectedPattern.hold1
        case .exhale: duration = selectedPattern.exhale
        case .hold2:  duration = selectedPattern.hold2
        case .idle:   return
        }

        guard duration > 0 else {
            nextPhase(after: p)
            return
        }

        phase = p
        countdown = duration

        let targetScale: CGFloat
        let targetOpacity: Double
        switch p {
        case .inhale: targetScale = 1.0; targetOpacity = 0.9
        case .hold1:  targetScale = 1.0; targetOpacity = 0.9
        case .exhale: targetScale = 0.55; targetOpacity = 0.35
        case .hold2:  targetScale = 0.55; targetOpacity = 0.35
        case .idle:   targetScale = 0.6; targetOpacity = 0.4
        }

        withAnimation(.easeInOut(duration: duration)) {
            scale = targetScale
            opacity = targetOpacity
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            countdown -= 0.1
            if countdown <= 0.05 {
                t.invalidate()
                nextPhase(after: p)
            }
        }
    }

    private func nextPhase(after current: BreathPhase) {
        switch current {
        case .inhale:
            if selectedPattern.hold1 > 0 { runPhase(.hold1) } else { runPhase(.exhale) }
        case .hold1:
            runPhase(.exhale)
        case .exhale:
            if selectedPattern.hold2 > 0 { runPhase(.hold2) } else {
                cyclesCompleted += 1
                runPhase(.inhale)
            }
        case .hold2:
            cyclesCompleted += 1
            runPhase(.inhale)
        case .idle:
            break
        }
    }
}

// MARK: - Pattern Card

struct PatternCard: View {
    let pattern: BreathingPattern
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: pattern.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(pattern.color)
                    Text(pattern.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(pattern.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))

                HStack(spacing: 4) {
                    rhythmChip("\(Int(pattern.inhale))s", "In", pattern.color)
                    if pattern.hold1 > 0 { rhythmChip("\(Int(pattern.hold1))s", "H", pattern.color.opacity(0.7)) }
                    rhythmChip("\(Int(pattern.exhale))s", "Ex", pattern.color)
                    if pattern.hold2 > 0 { rhythmChip("\(Int(pattern.hold2))s", "H", pattern.color.opacity(0.7)) }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 160)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? pattern.color.opacity(0.18) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? pattern.color.opacity(0.6) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
            .opacity(isRunning && !isSelected ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func rhythmChip(_ time: String, _ lbl: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(time)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(lbl)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }
}
