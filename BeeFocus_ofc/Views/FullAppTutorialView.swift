//
//  FullAppTutorialView.swift
//  BeeFocus_ofc
//
//  Premium Tutorial mit Fireworks, Confetti & Haptics
//

import SwiftUI
import UIKit

// MARK: - Main View
struct FullAppTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0
    @State private var showFireworks = false
    @State private var buttonExploded = false

    private let pages = TutorialPage.allPages

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.2),
                    Color.blue.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                progressBar

                TabView(selection: $selectedIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        ZStack {
                            TutorialPageView(page: pages[index])

                            if index == pages.count - 1 {
                                FireworksView(trigger: $showFireworks)
                                    .ignoresSafeArea()
                                ConfettiView(trigger: $showFireworks)
                                    .ignoresSafeArea()
                            }
                        }
                        .tag(index)
                        .padding(.horizontal)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedIndex) { newValue in
                    if newValue == pages.count - 1 {
                        showFireworks = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showFireworks = true
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                }

                primaryButton
            }
            .padding(.vertical)
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= selectedIndex ? Color.blue : Color.blue.opacity(0.25))
                    .frame(height: 6)
            }
        }
        .padding(.horizontal, 40)
        .animation(.easeInOut, value: selectedIndex)
    }

    // MARK: - Button
    private var primaryButton: some View {
        Button {
            if selectedIndex < pages.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedIndex += 1
                }
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    buttonExploded.toggle()
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        } label: {
            Text(selectedIndex < pages.count - 1 ? "Weiter" : "Los geht's 🚀")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        if buttonExploded {
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 4)
                                .scaleEffect(2.5)
                                .opacity(0)
                                .animation(.easeOut(duration: 0.6), value: buttonExploded)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 6)
                .scaleEffect(buttonExploded ? 1.2 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: buttonExploded)
        }
        .padding(.horizontal)
    }
}

// MARK: - Tutorial Page
struct TutorialPageView: View {
    let page: TutorialPage
    @State private var animateIn = false
    @State private var float = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 26) {
                Spacer()

                Image(systemName: page.systemImage)
                    .font(.system(size: 70, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(28)
                    .background(
                        Circle().fill(Color.blue.opacity(0.15))
                    )
                    .scaleEffect(animateIn ? 1 : 0.6)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -30)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateIn)
                    .offset(y: float ? -6 : 6)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: float
                    )

                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: animateIn)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 30)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: animateIn)

                if let bullets = page.bulletPoints {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text(bullet)
                            }
                            .opacity(animateIn ? 1 : 0)
                            .offset(x: animateIn ? 0 : -20)
                            .animation(
                                .easeOut(duration: 0.35).delay(0.35 + Double(index) * 0.08),
                                value: animateIn
                            )
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .frame(width: geo.size.width, height: geo.size.height * 0.75)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
            .rotation3DEffect(
                .degrees(Double((geo.frame(in: .global).minX - CGFloat(30)) / CGFloat(-20))),
                axis: (x: 0, y: 1, z: 0)
            )
            .scaleEffect(0.92 + (abs(geo.frame(in: .global).minX) / geo.size.width) * 0.08)
            .onAppear {
                animateIn = true
                float = true
            }
            .onDisappear { animateIn = false }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - Fireworks
struct FireworksView: View {
    @Binding var trigger: Bool
    @State private var particles: [FireworkParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onChange(of: trigger) { newValue in
            if newValue { explode() }
        }
    }

    private func explode() {
        particles.removeAll()
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.35)
        for i in 0..<90 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...240)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let particle = FireworkParticle(
                position: center,
                target: CGPoint(x: center.x + dx, y: center.y + dy),
                color: [.blue, .purple, .pink, .green, .yellow].randomElement()!,
                size: CGFloat.random(in: 6...10)
            )
            particles.append(particle)
            withAnimation(.easeOut(duration: 1.3)) {
                particles[i].position = particles[i].target
                particles[i].opacity = 0
                particles[i].scale = 0.2
            }
        }
    }
}

struct FireworkParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var target: CGPoint
    var color: Color
    var size: CGFloat
    var opacity: Double = 1
    var scale: CGFloat = 1
}

// MARK: - Confetti
struct ConfettiView: View {
    @Binding var trigger: Bool
    @State private var confettis: [ConfettiParticle] = []

    var body: some View {
        ZStack {
            ForEach(confettis) { confetti in
                Rectangle()
                    .fill(confetti.color)
                    .frame(width: confetti.size.width, height: confetti.size.height)
                    .rotationEffect(confetti.rotation)
                    .position(confetti.position)
                    .opacity(confetti.opacity)
            }
        }
        .onChange(of: trigger) { newValue in
            if newValue { explode() }
        }
    }

    private func explode() {
        confettis.removeAll()
        let center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.height * 0.35)
        for i in 0..<120 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 80...250)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let confetti = ConfettiParticle(
                position: center,
                target: CGPoint(x: center.x + dx, y: center.y + dy),
                color: [.red, .blue, .green, .yellow, .purple].randomElement()!,
                size: CGSize(width: CGFloat.random(in: 6...12), height: CGFloat.random(in: 12...20)),
                rotation: .degrees(Double.random(in: 0...360))
            )
            confettis.append(confetti)
            withAnimation(.easeOut(duration: 1.6)) {
                confettis[i].position = confettis[i].target
                confettis[i].opacity = 0
                confettis[i].rotation = .degrees(Double.random(in: 0...720))
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var target: CGPoint
    var color: Color
    var size: CGSize
    var rotation: Angle
    var opacity: Double = 1
}

// MARK: - Model
struct TutorialPage {
    let title: String
    let description: String
    let systemImage: String
    let bulletPoints: [String]?
}

// MARK: - Pages
extension TutorialPage {
    static let allPages: [TutorialPage] = [
        TutorialPage(title: "Willkommen bei BeeFocus", description: "Behalte deine Aufgaben im Griff und bleib fokussiert.", systemImage: "sparkles", bulletPoints: nil),
        TutorialPage(title: "Aufgaben erstellen", description: "Erstelle neue Aufgaben mit nur einem Tap.", systemImage: "plus.circle.fill", bulletPoints: ["Titel festlegen", "Beschreibung hinzufügen", "Kategorie wählen"]),
        TutorialPage(title: "Prioritäten setzen", description: "Wichtiges zuerst erledigen.", systemImage: "exclamationmark.triangle.fill", bulletPoints: ["Niedrig", "Mittel", "Hoch"]),
        TutorialPage(title: "Deadlines planen", description: "Nie wieder Termine vergessen.", systemImage: "calendar.circle.fill", bulletPoints: ["Datum auswählen", "Erinnerungen aktivieren"]),
        TutorialPage(title: "Unteraufgaben", description: "Große Aufgaben klein machen.", systemImage: "list.bullet.rectangle", bulletPoints: ["Struktur schaffen", "Fortschritt sehen"]),
        TutorialPage(title: "Pomodoro Fokus", description: "Arbeite konzentriert in Sessions.", systemImage: "timer.circle.fill", bulletPoints: ["Fokus", "Pause", "Wiederholen"]),
        TutorialPage(title: "Alles bereit", description: "Du bist startklar. Viel Erfolg!", systemImage: "checkmark.seal.fill", bulletPoints: ["Produktiv bleiben", "Ziele erreichen"])
    ]
}

