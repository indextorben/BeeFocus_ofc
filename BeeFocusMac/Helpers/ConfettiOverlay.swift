import SwiftUI
import AppKit

// MARK: - Manager

@MainActor
final class ConfettiOverlayManager {
    static let shared = ConfettiOverlayManager()
    private var overlayWindow: NSPanel?

    private init() {}

    func trigger() {
        overlayWindow?.close()
        overlayWindow = nil

        guard let screen = NSScreen.main else { return }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = false

        let hv = NSHostingView(rootView: ConfettiView {
            Task { @MainActor [weak self] in
                self?.overlayWindow?.close()
                self?.overlayWindow = nil
            }
        })
        hv.frame = NSRect(origin: .zero, size: screen.frame.size)
        panel.contentView = hv
        panel.orderFrontRegardless()
        overlayWindow = panel
    }
}

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let startY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let rotationStart: Double
    let rotationEnd: Double
    let driftX: CGFloat
    let fallDuration: Double
    let delay: Double
    let isCircle: Bool
}

// MARK: - Confetti View

struct ConfettiView: View {
    let onFinish: () -> Void

    private let palette: [Color] = [
        Color(red: 1.0, green: 0.22, blue: 0.37),
        Color(red: 1.0, green: 0.60, blue: 0.00),
        Color(red: 1.0, green: 0.90, blue: 0.10),
        Color(red: 0.20, green: 0.85, blue: 0.45),
        Color(red: 0.20, green: 0.60, blue: 1.00),
        Color(red: 0.65, green: 0.25, blue: 1.00),
        Color(red: 1.00, green: 0.35, blue: 0.80),
        Color(red: 0.10, green: 0.85, blue: 0.85),
    ]

    @State private var particles: [Particle] = []
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                ForEach(particles) { p in
                    Group {
                        if p.isCircle {
                            Circle().fill(p.color)
                        } else {
                            RoundedRectangle(cornerRadius: 2).fill(p.color)
                        }
                    }
                    .frame(width: p.width, height: p.height)
                    .rotationEffect(.degrees(falling ? p.rotationEnd : p.rotationStart))
                    .position(
                        x: p.x + (falling ? p.driftX : 0),
                        y: falling ? geo.size.height + 80 : p.startY
                    )
                    .animation(
                        .timingCurve(0.3, 0.0, 0.8, 1.0, duration: p.fallDuration)
                            .delay(p.delay),
                        value: falling
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { setup() }
    }

    private func setup() {
        guard let screen = NSScreen.main else { return }
        let w = screen.frame.width

        particles = (0..<130).map { _ in
            let size = CGFloat.random(in: 7...15)
            return Particle(
                x: CGFloat.random(in: -40...(w + 40)),
                startY: CGFloat.random(in: -350...(-8)),
                width: size,
                height: Bool.random() ? size : size * CGFloat.random(in: 1.2...2.0),
                color: palette.randomElement()!.opacity(Double.random(in: 0.75...1.0)),
                rotationStart: Double.random(in: 0...360),
                rotationEnd: Double.random(in: 800...2200),
                driftX: CGFloat.random(in: -120...120),
                fallDuration: Double.random(in: 2.2...4.5),
                delay: Double.random(in: 0...1.8),
                isCircle: Bool.random()
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            falling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            onFinish()
        }
    }
}
