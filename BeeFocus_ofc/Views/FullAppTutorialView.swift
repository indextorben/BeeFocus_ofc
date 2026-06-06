//
//  FullAppTutorialView.swift
//  BeeFocus_ofc
//
//  Glassmorphism Tutorial – 9 Seiten, floating orbs, glass cards
//

import SwiftUI
import UIKit

// MARK: - Model

struct TutorialPage {
    let title: String
    let description: String
    let systemImage: String
    let bulletPoints: [String]?
    let accentColor: Color
}

extension TutorialPage {
    static var allPages: [TutorialPage] {
        let l = LocalizationManager.shared
        return [
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_welcome_title"),
                description: l.localizedString(forKey: "tutorial_welcome_desc"),
                systemImage: "sparkles",
                bulletPoints: nil,
                accentColor: .purple
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_create_title"),
                description: l.localizedString(forKey: "tutorial_create_desc"),
                systemImage: "plus.circle.fill",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_create_bullet1"),
                    l.localizedString(forKey: "tutorial_create_bullet2"),
                    l.localizedString(forKey: "tutorial_create_bullet3")
                ],
                accentColor: .blue
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_priority_title"),
                description: l.localizedString(forKey: "tutorial_priority_desc2"),
                systemImage: "flag.fill",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_priority_bullet1"),
                    l.localizedString(forKey: "tutorial_priority_bullet2"),
                    l.localizedString(forKey: "tutorial_priority_bullet3")
                ],
                accentColor: .orange
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_pomodoro_title"),
                description: l.localizedString(forKey: "tutorial_pomodoro_desc"),
                systemImage: "timer.circle.fill",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_pomodoro_focus"),
                    l.localizedString(forKey: "tutorial_pomodoro_break"),
                    l.localizedString(forKey: "tutorial_pomodoro_repeat")
                ],
                accentColor: Color(red: 0.95, green: 0.3, blue: 0.3)
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_focus_title"),
                description: l.localizedString(forKey: "tutorial_focus_desc"),
                systemImage: "brain.head.profile",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_focus_bullet1"),
                    l.localizedString(forKey: "tutorial_focus_bullet2"),
                    l.localizedString(forKey: "tutorial_focus_bullet3")
                ],
                accentColor: .indigo
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_ki_title"),
                description: l.localizedString(forKey: "tutorial_ki_desc"),
                systemImage: "sparkles.rectangle.stack.fill",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_ki_bullet1"),
                    l.localizedString(forKey: "tutorial_ki_bullet2"),
                    l.localizedString(forKey: "tutorial_ki_bullet3")
                ],
                accentColor: Color(red: 0.8, green: 0.2, blue: 0.9)
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_stats_title"),
                description: l.localizedString(forKey: "tutorial_stats_desc"),
                systemImage: "chart.bar.xaxis",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_stats_bullet1"),
                    l.localizedString(forKey: "tutorial_stats_bullet2"),
                    l.localizedString(forKey: "tutorial_stats_bullet3")
                ],
                accentColor: Color(red: 0.15, green: 0.75, blue: 0.45)
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_goals_title"),
                description: l.localizedString(forKey: "tutorial_goals_desc"),
                systemImage: "target",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_goals_bullet1"),
                    l.localizedString(forKey: "tutorial_goals_bullet2"),
                    l.localizedString(forKey: "tutorial_goals_bullet3")
                ],
                accentColor: Color(red: 0.95, green: 0.75, blue: 0.1)
            ),
            TutorialPage(
                title: l.localizedString(forKey: "tutorial_ready_title"),
                description: l.localizedString(forKey: "tutorial_ready_desc"),
                systemImage: "checkmark.seal.fill",
                bulletPoints: [
                    l.localizedString(forKey: "tutorial_ready_productive"),
                    l.localizedString(forKey: "tutorial_ready_goals")
                ],
                accentColor: .purple
            )
        ]
    }
}

// MARK: - Main View

struct FullAppTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var selectedIndex = 0
    @State private var showCelebration = false
    @State private var buttonPulse = false
    @State private var backgroundAccent: Color = .purple

    private let pages = TutorialPage.allPages

    var body: some View {
        ZStack {
            GlassBackgroundView(accentColor: $backgroundAccent)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                GlassProgressBar(total: pages.count, current: selectedIndex)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                TabView(selection: $selectedIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        GlassPageView(page: pages[index])
                            .tag(index)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedIndex) { newValue in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        backgroundAccent = pages[newValue].accentColor
                    }
                    if newValue == pages.count - 1 {
                        showCelebration = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showCelebration = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }

                nextButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            if showCelebration {
                CelebrationView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            backgroundAccent = pages[0].accentColor
        }
    }

    // MARK: - Next Button

    private var nextButton: some View {
        let isLast = selectedIndex == pages.count - 1
        let accent = pages[selectedIndex].accentColor

        return Button {
            if isLast {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    buttonPulse = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    dismiss()
                }
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedIndex += 1
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(0.85)

                Text(isLast
                     ? localizer.localizedString(forKey: "tutorial_start")
                     : localizer.localizedString(forKey: "tutorial_next"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(accent.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.4), radius: 16, x: 0, y: 8)
            .scaleEffect(buttonPulse ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: buttonPulse)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Background

struct GlassBackgroundView: View {
    @Binding var accentColor: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.16),
                    Color(red: 0.19, green: 0.17, blue: 0.39),
                    Color(red: 0.14, green: 0.14, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(0..<5, id: \.self) { i in
                OrbView(
                    color: accentColor,
                    size: CGFloat([220, 160, 280, 180, 240][i]),
                    xFactor: [0.15, 0.75, 0.5, 0.25, 0.85][i],
                    yFactor: [0.2, 0.35, 0.65, 0.8, 0.15][i],
                    animOffset: Double(i) * 0.7
                )
            }
        }
        .animation(.easeInOut(duration: 0.8), value: accentColor)
    }
}

struct OrbView: View {
    let color: Color
    let size: CGFloat
    let xFactor: CGFloat
    let yFactor: CGFloat
    let animOffset: Double

    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: size, height: size)
                .blur(radius: size * 0.4)
                .position(
                    x: geo.size.width * xFactor + drift,
                    y: geo.size.height * yFactor + drift * 0.6
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 4 + animOffset)
                        .repeatForever(autoreverses: true)
                    ) {
                        drift = CGFloat.random(in: -30...30)
                    }
                }
        }
    }
}

// MARK: - Glass Progress Bar

struct GlassProgressBar: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .fill(i <= current ? Color.white.opacity(0.85) : Color.clear)
                    )
                    .frame(height: 5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
            }
        }
    }
}

// MARK: - Glass Page View

struct GlassPageView: View {
    let page: TutorialPage
    @State private var appeared = false
    @State private var floating = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(page.accentColor.opacity(0.1))
                            .frame(width: 130, height: 130)
                        Circle()
                            .fill(page.accentColor.opacity(0.18))
                            .frame(width: 100, height: 100)
                        Image(systemName: page.systemImage)
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, page.accentColor.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: floating ? -6 : 6)
                    .animation(.spring(response: 0.6, dampingFraction: 0.65), value: appeared)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: floating)

                    // Text
                    VStack(spacing: 10) {
                        Text(page.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.12), value: appeared)

                        Text(page.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)
                    }
                    .padding(.horizontal, 8)

                    // Bullets
                    if let bullets = page.bulletPoints {
                        VStack(spacing: 10) {
                            ForEach(Array(bullets.enumerated()), id: \.offset) { i, bullet in
                                GlassBulletRow(text: bullet, accent: page.accentColor, index: i, appeared: appeared)
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 4)
                .frame(minHeight: geo.size.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(page.accentColor.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 30, x: 0, y: 12)
            .rotation3DEffect(
                .degrees(Double((geo.frame(in: .global).minX) / CGFloat(-40))),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .onAppear {
            appeared = true
            floating = true
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Glass Bullet Row

struct GlassBulletRow: View {
    let text: String
    let accent: Color
    let index: Int
    let appeared: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accent)
            }

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.opacity(0.2), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -24)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.09),
            value: appeared
        )
        .padding(.horizontal, 4)
    }
}

// MARK: - Celebration (Fireworks + Confetti)

struct CelebrationView: View {
    @State private var particles: [CelebrationParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                p.shape
                    .fill(p.color)
                    .frame(width: p.size, height: p.isRect ? p.size * 1.8 : p.size)
                    .rotationEffect(p.rotation)
                    .position(p.position)
                    .opacity(p.opacity)
                    .scaleEffect(p.scale)
            }
        }
        .onAppear { burst() }
    }

    private func burst() {
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.38)
        let colors: [Color] = [.blue, .purple, .pink, .green, .yellow, .orange, .cyan, .white]
        var newParticles: [CelebrationParticle] = []

        for i in 0..<90 {
            let angle = Double.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 70...220)
            let target = CGPoint(x: center.x + cos(angle) * dist, y: center.y + sin(angle) * dist)
            newParticles.append(CelebrationParticle(
                position: center, target: target,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 5...11),
                isRect: i % 3 == 0,
                rotation: .degrees(Double.random(in: 0...360))
            ))
        }
        particles = newParticles

        for i in particles.indices {
            withAnimation(.easeOut(duration: Double.random(in: 1.1...1.6)).delay(Double.random(in: 0...0.15))) {
                particles[i].position = particles[i].target
                particles[i].opacity = 0
                particles[i].scale = 0.15
                particles[i].rotation = .degrees(Double.random(in: 0...720))
            }
        }
    }
}

struct CelebrationParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let target: CGPoint
    let color: Color
    let size: CGFloat
    let isRect: Bool
    var rotation: Angle
    var opacity: Double = 1
    var scale: CGFloat = 1

    var shape: AnyShape {
        isRect ? AnyShape(RoundedRectangle(cornerRadius: 2)) : AnyShape(Circle())
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = shape.path(in:) }
    func path(in rect: CGRect) -> Path { _path(rect) }
}
