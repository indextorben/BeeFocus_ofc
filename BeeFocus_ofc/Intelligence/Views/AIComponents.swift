//
//  AIComponents.swift
//  BeeFocus_ofc
//
//  Wiederverwendbare Bausteine der Intelligence-Oberflächen.
//

import SwiftUI

// MARK: - Akzentfarbe

/// Liest die Akzentfarbe des aktiven App-Themes.
struct AIAccent {
    static func color(for thema: String) -> Color {
        thema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(thema).0
    }

    static func secondary(for thema: String) -> Color {
        thema.isEmpty ? Color(red: 0.35, green: 0.55, blue: 1.0) : appThemaFarben(thema).2
    }
}

// MARK: - Apple-Intelligence-Schimmer

/// Die Farben, die Apple-Intelligence-Funktionen kennzeichnen.
enum AIPalette {
    static let colors: [Color] = [
        Color(red: 0.42, green: 0.36, blue: 0.99),
        Color(red: 0.94, green: 0.35, blue: 0.62),
        Color(red: 1.00, green: 0.62, blue: 0.29),
        Color(red: 0.36, green: 0.73, blue: 0.99),
        Color(red: 0.42, green: 0.36, blue: 0.99)
    ]

    /// Als `ShapeStyle` verwendbar – für `fill`, `foregroundStyle` und `background`.
    static let gradient = LinearGradient(
        colors: colors,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Derselbe Farbverlauf, aber als View mit langsamer Wanderbewegung.
/// Für Flächen, bei denen `AIPalette.gradient` als Stil genügt, diesen nutzen.
struct AIGradient: View {
    var animated: Bool = true
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: AIPalette.colors,
            startPoint: UnitPoint(x: phase, y: 0),
            endPoint: UnitPoint(x: phase + 1, y: 1)
        )
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) {
                phase = -1
            }
        }
    }
}

/// Umrandung im Apple-Intelligence-Look.
struct AIGlowBorder: ViewModifier {
    var cornerRadius: CGFloat = 20
    var lineWidth: CGFloat = 1.5
    var active: Bool = true

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.clear, lineWidth: lineWidth)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(lineWidth: lineWidth)
                        .foregroundStyle(.clear)
                        .overlay(
                            AIGradient(animated: active)
                                .mask(
                                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                        .stroke(lineWidth: lineWidth)
                                )
                        )
                )
        )
    }
}

extension View {
    func aiGlowBorder(cornerRadius: CGFloat = 20, lineWidth: CGFloat = 1.5, active: Bool = true) -> some View {
        modifier(AIGlowBorder(cornerRadius: cornerRadius, lineWidth: lineWidth, active: active))
    }
}

// MARK: - Kleines Kennzeichen

/// Markiert eine Funktion als Apple-Intelligence-Funktion.
struct AIBadge: View {
    var text: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            if let text {
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(AIPalette.gradient, in: Capsule())
    }
}

// MARK: - Waveform

/// Reagiert auf den Mikrofonpegel und zeigt, dass zugehört wird.
struct AIWaveform: View {
    var level: Double
    var isActive: Bool
    var barCount: Int = 28

    @State private var seeds: [Double] = []

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(AIPalette.gradient)
                    .frame(width: 3, height: height(for: index))
                    .animation(.easeOut(duration: 0.12), value: level)
            }
        }
        .frame(height: 56)
        .onAppear {
            if seeds.isEmpty {
                seeds = (0..<barCount).map { _ in Double.random(in: 0.35...1.0) }
            }
        }
        .opacity(isActive ? 1 : 0.35)
    }

    private func height(for index: Int) -> CGFloat {
        guard isActive else { return 4 }
        let seed = seeds.indices.contains(index) ? seeds[index] : 0.6
        // Mitte höher als die Ränder, damit es wie ein Pegel wirkt.
        let center = Double(barCount) / 2
        let distance = abs(Double(index) - center) / center
        let falloff = 1 - distance * 0.55
        let value = max(0.06, level * seed * falloff)
        return CGFloat(4 + value * 48)
    }
}

// MARK: - Denkindikator

/// Pulsierende Punkte, solange das Modell rechnet.
struct AIThinkingIndicator: View {
    var label: String
    @State private var animating = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AIPalette.gradient)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animating ? 1.0 : 0.45)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.18),
                            value: animating
                        )
                }
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .onAppear { animating = true }
    }
}

// MARK: - Hinweis, wenn Apple Intelligence fehlt

/// Erklärt in einer Karte, warum die Funktion gerade nicht verfügbar ist.
@available(iOS 26.0, *)
struct AIUnavailableCard: View {
    @ObservedObject private var availability = AIAvailability.shared

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: availability.symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AIPalette.gradient)

            Text(availability.headline)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text(availability.message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            if availability.state == .notEnabled {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(AIL("ai_open_settings"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(AIPalette.gradient, in: Capsule())
                }
                .padding(.top, 2)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .aiGlowBorder(active: false)
        .onAppear { availability.refresh() }
    }
}

// MARK: - Fehlerzeile

struct AIErrorRow: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let retry {
                Button(AIL("ai_retry"), action: retry)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.orange.opacity(0.12))
        )
    }
}
