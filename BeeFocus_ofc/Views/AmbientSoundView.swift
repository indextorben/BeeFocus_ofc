import SwiftUI

struct AmbientSoundView: View {
    @ObservedObject private var manager = AmbientSoundManager.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }
    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1 }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                         Color(red: 0.1,  green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerSection.padding(.top, 32)

                    waveformCanvas
                        .frame(height: 70)
                        .padding(.horizontal, 20)

                    soundGrid
                        .padding(.horizontal, 20)

                    volumeSection
                        .padding(.horizontal, 20)

                    if manager.currentSound.needsHeadphones && manager.isPlaying {
                        headphonesHint
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    binauralInfo
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.isPlaying)
        .animation(.easeInOut(duration: 0.2), value: manager.currentSound)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.4)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: accent.opacity(0.45), radius: 18)
                Image(systemName: "headphones")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Ambient Sounds")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Text("Steigere deine Konzentration mit Klang")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Animated Waveform Canvas

    private var waveformCanvas: some View {
        let sound = manager.currentSound
        let playing = manager.isPlaying

        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !playing)) { timeline in
            let t = playing ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { ctx, size in
                let mid = size.height / 2
                let w   = size.width
                let color = playing ? sound.color : Color.white.opacity(0.15)

                func wave(freq: Double, amp: Double, phaseOffset: Double, opacity: Double) {
                    var path = Path()
                    let steps = 300
                    for i in 0...steps {
                        let x = CGFloat(i) / CGFloat(steps) * w
                        let pct = Double(i) / Double(steps)
                        let y: CGFloat

                        switch sound {
                        case .whiteNoise, .brownNoise:
                            // Noisy multi-harmonic wave
                            let v = sin(pct * freq * .pi * 2 + t * 3 + phaseOffset)
                                  + sin(pct * freq * 2.7 * .pi * 2 + t * 1.9 + phaseOffset * 1.4) * 0.4
                                  + sin(pct * freq * 4.1 * .pi * 2 + t * 4.3 + phaseOffset * 0.7) * 0.25
                            y = mid - CGFloat(v * amp / 1.65)
                        case .binauralFocus:
                            // Beating pattern (two close frequencies)
                            let envelope = (1 + sin(t * 40 * .pi * 2)) / 2
                            let v = sin(pct * freq * .pi * 2 + t * 2 + phaseOffset) * (0.5 + 0.5 * envelope)
                            y = mid - CGFloat(v * amp)
                        case .binauralRelax:
                            // Slow 6Hz beat envelope
                            let envelope = (1 + sin(t * 6 * .pi * 2)) / 2
                            let v = sin(pct * freq * .pi * 2 + t * 1.5 + phaseOffset) * (0.4 + 0.6 * envelope)
                            y = mid - CGFloat(v * amp)
                        case .off:
                            y = mid
                        }

                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else      { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }

                wave(freq: 4,  amp: mid * 0.62, phaseOffset: 0,   opacity: 0.85)
                wave(freq: 6,  amp: mid * 0.35, phaseOffset: 1.2, opacity: 0.45)
                wave(freq: 9,  amp: mid * 0.18, phaseOffset: 2.5, opacity: 0.25)
            }
        }
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Sound Grid

    private var soundGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AmbientSound.allCases) { sound in
                soundCard(sound)
            }
        }
    }

    private func soundCard(_ sound: AmbientSound) -> some View {
        let isActive   = manager.currentSound == sound && manager.isPlaying
        let isOff      = sound == .off

        return Button { manager.toggle(sound) } label: {
            VStack(spacing: 10) {
                ZStack {
                    // Pulse ring
                    if isActive && !isOff {
                        Circle()
                            .stroke(sound.color.opacity(0.25), lineWidth: 6)
                            .frame(width: 62, height: 62)
                            .scaleEffect(1.08)
                            .animation(
                                .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                value: isActive
                            )
                    }

                    Circle()
                        .fill(isActive
                              ? (isOff ? Color.white.opacity(0.1) : sound.color.opacity(0.22))
                              : Color.white.opacity(0.07))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle()
                                .stroke(isActive ? sound.color.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1.5)
                        )

                    Image(systemName: sound.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isActive ? sound.color : Color.white.opacity(0.65))
                }

                VStack(spacing: 2) {
                    Text(sound.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(sound.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isActive
                          ? (isOff ? Color.white.opacity(0.07) : sound.color.opacity(0.1))
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isActive ? sound.color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
    }

    // MARK: - Volume

    private var volumeSection: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { Double(manager.volume) },
                        set: { manager.volume = Float($0); manager.updateVolume() }
                    ),
                    in: 0...1
                )
                .tint(manager.isPlaying ? manager.currentSound.color : Color.white.opacity(0.4))
                .animation(.easeInOut(duration: 0.3), value: manager.currentSound)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 24)
            }

            Text("Lautstärke")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hints

    private var headphonesHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "headphones")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow)
            Text("Kopfhörer verwenden für optimale Binaural-Beats")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.yellow.opacity(0.2), lineWidth: 1))
    }

    private var binauralInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Was sind Binaural Beats?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text("Binaural Beats entstehen, wenn zwei leicht unterschiedliche Töne – je einer pro Ohr – gespielt werden. Das Gehirn nimmt die Differenz wahr und kann damit in bestimmte Zustände wie Fokus (40 Hz Gamma) oder Tiefenentspannung (6 Hz Theta) versetzt werden.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.35))
                .lineSpacing(3)
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
}
