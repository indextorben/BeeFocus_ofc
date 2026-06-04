import SwiftUI

// MARK: - Animated wave shape for theme backgrounds
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let baseline = h * 0.35
        path.move(to: CGPoint(x: 0, y: baseline + sin(phase) * amplitude))
        for x in stride(from: 0.0, through: w, by: 2) {
            let angle = (x / w) * .pi * 2 * frequency + phase
            path.addLine(to: CGPoint(x: x, y: baseline + sin(angle) * amplitude))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Wald swaying tree decoration
struct WaldDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var sway = false
    private var isDark: Bool { colorScheme == .dark }

    // Hintergrund-Bäume (kleiner, blasser = Tiefenwirkung)
    private let bgTrees: [(size: CGFloat, angle: Double, dur: Double, delay: Double)] = [
        (110, 2.5, 3.0, 0.15),
        (130, -3.0, 3.5, 0.55),
        (115, 3.5, 2.8, 0.90),
        (125, -2.0, 3.2, 0.35),
        (120, 3.0, 3.8, 0.70),
        (108, -3.5, 2.9, 0.10),
        (135, 2.0, 3.4, 0.50),
    ]

    // Vordergrund-Bäume (größer, dunkler)
    private let fgTrees: [(size: CGFloat, angle: Double, dur: Double, delay: Double)] = [
        (160, 4.0, 2.2, 0.00),
        (200, -4.5, 2.8, 0.30),
        (170, 5.0, 2.0, 0.60),
        (215, -3.5, 3.2, 0.10),
        (185, 4.5, 2.5, 0.80),
        (205, -5.0, 1.9, 0.40),
        (175, 3.5, 3.0, 0.70),
        (195, -4.0, 2.4, 0.20),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Hintergrund-Schicht
                HStack(alignment: .bottom, spacing: -18) {
                    ForEach(bgTrees.indices, id: \.self) { i in
                        let t = bgTrees[i]
                        Image(systemName: "tree.fill")
                            .font(.system(size: t.size))
                            .foregroundStyle(
                                Color(red: 0.06, green: 0.42, blue: 0.18)
                                    .opacity(isDark ? 0.22 : 0.14)
                            )
                            .rotationEffect(.degrees(sway ? t.angle : -t.angle), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: t.dur).repeatForever(autoreverses: true).delay(t.delay),
                                value: sway
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: geo.size.width)
                .offset(y: 40)

                // Vordergrund-Schicht
                HStack(alignment: .bottom, spacing: -22) {
                    ForEach(fgTrees.indices, id: \.self) { i in
                        let t = fgTrees[i]
                        Image(systemName: "tree.fill")
                            .font(.system(size: t.size))
                            .foregroundStyle(
                                Color(red: 0.04, green: 0.30, blue: 0.12)
                                    .opacity(isDark ? 0.40 : 0.28)
                            )
                            .rotationEffect(.degrees(sway ? t.angle : -t.angle), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: t.dur).repeatForever(autoreverses: true).delay(t.delay),
                                value: sway
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: geo.size.width)
                .offset(y: 55)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .onAppear { sway = true }
    }
}

// MARK: - Eis falling snowflake decoration
struct EisDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var fall = false
    @State private var rotate = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Flake {
        let x: CGFloat      // 0–1 relative screen width
        let size: CGFloat
        let speed: Double
        let delay: Double
        let rotSpeed: Double
        let drift: CGFloat  // horizontal wobble px
    }

    private let flakes: [Flake] = [
        Flake(x: 0.05, size: 28, speed: 6.5, delay: 0.0,  rotSpeed: 4.0, drift:  10),
        Flake(x: 0.15, size: 18, speed: 8.0, delay: 1.1,  rotSpeed: 7.0, drift:  -7),
        Flake(x: 0.25, size: 32, speed: 5.8, delay: 2.3,  rotSpeed: 3.5, drift:   8),
        Flake(x: 0.35, size: 14, speed: 9.0, delay: 0.6,  rotSpeed: 9.0, drift:  -5),
        Flake(x: 0.45, size: 24, speed: 6.2, delay: 3.5,  rotSpeed: 5.5, drift:  12),
        Flake(x: 0.55, size: 20, speed: 7.5, delay: 1.8,  rotSpeed: 6.0, drift:  -9),
        Flake(x: 0.62, size: 30, speed: 5.5, delay: 4.1,  rotSpeed: 3.0, drift:   6),
        Flake(x: 0.72, size: 16, speed: 8.5, delay: 0.9,  rotSpeed: 8.0, drift: -11),
        Flake(x: 0.80, size: 26, speed: 6.8, delay: 2.7,  rotSpeed: 4.5, drift:   9),
        Flake(x: 0.90, size: 22, speed: 7.2, delay: 5.0,  rotSpeed: 6.5, drift:  -6),
        Flake(x: 0.10, size: 12, speed: 9.5, delay: 3.0,  rotSpeed: 10.0, drift:  7),
        Flake(x: 0.50, size: 34, speed: 5.2, delay: 1.5,  rotSpeed: 2.5, drift: -10),
        Flake(x: 0.70, size: 15, speed: 8.8, delay: 4.6,  rotSpeed: 8.5, drift:   5),
        Flake(x: 0.88, size: 20, speed: 7.0, delay: 2.0,  rotSpeed: 5.0, drift:  -8),
        Flake(x: 0.32, size: 25, speed: 6.0, delay: 5.5,  rotSpeed: 4.0, drift:  11),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(flakes.indices, id: \.self) { i in
                let f = flakes[i]
                Image(systemName: "snowflake")
                    .font(.system(size: f.size, weight: .light))
                    .foregroundStyle(
                        Color(red: 0.65, green: 0.90, blue: 1.0)
                            .opacity(isDark ? 0.55 : 0.40)
                    )
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(
                        .linear(duration: f.rotSpeed).repeatForever(autoreverses: false),
                        value: rotate
                    )
                    .offset(
                        x: geo.size.width * f.x + (fall ? f.drift : -f.drift),
                        y: fall ? geo.size.height + 60 : -80
                    )
                    .animation(
                        .linear(duration: f.speed).repeatForever(autoreverses: false).delay(f.delay),
                        value: fall
                    )
            }
        }
        .onAppear {
            fall = true
            rotate = true
        }
    }
}

// MARK: - Nordlicht aurora decoration
struct NordlichtDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var sway1: CGFloat = 0
    @State private var sway2: CGFloat = 0
    @State private var sway3: CGFloat = 0
    @State private var glow: Double = 0.6

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let op = isDark ? 0.80 : 0.55

            ZStack {
                // Himmel-Wash — dunkelgrüner Schimmer oben
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.18, blue: 0.10).opacity(isDark ? 0.55 : 0.22),
                        .clear
                    ],
                    startPoint: .top, endPoint: .center
                )
                .frame(width: w, height: h * 0.48)
                .position(x: w * 0.5, y: h * 0.24)

                // Vorhang 1 — breites Hauptgrün
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.96, blue: 0.42).opacity(op),
                            Color(red: 0.0, green: 0.85, blue: 0.52).opacity(op * 0.55),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 1.45, height: h * 0.56)
                    .position(x: w * 0.44 + sway1, y: h * 0.18)
                    .blur(radius: 22)

                // Vorhang 2 — Türkis, leicht rechts
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.0, green: 0.82, blue: 0.72).opacity(op * 0.88),
                            Color(red: 0.0, green: 0.65, blue: 0.88).opacity(op * 0.42),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 1.25, height: h * 0.50)
                    .position(x: w * 0.60 - sway2, y: h * 0.15)
                    .blur(radius: 28)

                // Vorhang 3 — Lila oben
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.10, blue: 0.95).opacity(op * 0.65),
                            Color(red: 0.35, green: 0.05, blue: 0.80).opacity(op * 0.28),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 1.00, height: h * 0.38)
                    .position(x: w * 0.50 + sway3, y: h * 0.10)
                    .blur(radius: 35)

                // Vorhang 4 — helles Grün, schmaler Glanzstreifen
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 1.0, blue: 0.55).opacity(op * 0.80),
                            Color(red: 0.10, green: 0.95, blue: 0.42).opacity(op * 0.32),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 0.82, height: h * 0.30)
                    .position(x: w * 0.48 - sway1 * 0.55, y: h * 0.11)
                    .blur(radius: 16)

                // Vorhang 5 — Pink ganz oben (höhere Atmosphäre)
                Ellipse()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.28, blue: 0.65).opacity(op * 0.48),
                            .clear
                        ],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 0.72, height: h * 0.24)
                    .position(x: w * 0.55 + sway2 * 0.38, y: h * 0.06)
                    .blur(radius: 38)

                // Unterer Glanz (pulsierender Horizont-Schimmer)
                Ellipse()
                    .fill(Color(red: 0.0, green: 0.92, blue: 0.48)
                        .opacity((isDark ? 0.38 : 0.22) * glow))
                    .frame(width: w * 1.7, height: h * 0.13)
                    .position(x: w * 0.5, y: h * 0.36)
                    .blur(radius: 22)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) { sway1 = 55 }
            withAnimation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true).delay(1.5)) { sway2 = -50 }
            withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true).delay(2.8)) { sway3 = 40 }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.5)) { glow = 1.0 }
        }
    }
}

// MARK: - Galaxie stars & planets decoration
struct GalaxieDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var twinkle = false
    @State private var o1: CGFloat = 0   // planet orbit offsets
    @State private var o2: CGFloat = 0
    @State private var o3: CGFloat = 0
    @State private var ov1: CGFloat = 0
    @State private var ov2: CGFloat = 0

    private var isDark: Bool { colorScheme == .dark }

    private struct Star {
        let x: CGFloat; let y: CGFloat
        let size: CGFloat
        let minOp: Double; let maxOp: Double
        let speed: Double; let delay: Double
        let symbol: String
    }

    private let stars: [Star] = [
        Star(x:0.06, y:0.10, size: 8,  minOp:0.20, maxOp:0.90, speed:1.8, delay:0.0,  symbol:"star.fill"),
        Star(x:0.18, y:0.28, size: 5,  minOp:0.15, maxOp:0.70, speed:2.5, delay:0.4,  symbol:"star.fill"),
        Star(x:0.30, y:0.07, size:11,  minOp:0.25, maxOp:0.95, speed:1.5, delay:0.9,  symbol:"sparkle"),
        Star(x:0.42, y:0.18, size: 6,  minOp:0.10, maxOp:0.65, speed:3.0, delay:0.2,  symbol:"star.fill"),
        Star(x:0.55, y:0.05, size: 9,  minOp:0.20, maxOp:0.85, speed:2.0, delay:1.1,  symbol:"star.fill"),
        Star(x:0.68, y:0.14, size: 5,  minOp:0.15, maxOp:0.60, speed:2.8, delay:0.6,  symbol:"star.fill"),
        Star(x:0.80, y:0.09, size:12,  minOp:0.30, maxOp:0.90, speed:1.6, delay:0.3,  symbol:"sparkle"),
        Star(x:0.92, y:0.22, size: 7,  minOp:0.20, maxOp:0.75, speed:2.3, delay:0.8,  symbol:"star.fill"),
        Star(x:0.12, y:0.45, size: 5,  minOp:0.10, maxOp:0.55, speed:3.2, delay:1.4,  symbol:"star.fill"),
        Star(x:0.25, y:0.55, size: 8,  minOp:0.20, maxOp:0.80, speed:1.9, delay:0.5,  symbol:"star.fill"),
        Star(x:0.38, y:0.40, size: 6,  minOp:0.15, maxOp:0.65, speed:2.6, delay:1.0,  symbol:"star.fill"),
        Star(x:0.50, y:0.35, size:10,  minOp:0.25, maxOp:0.88, speed:1.7, delay:0.1,  symbol:"sparkle"),
        Star(x:0.62, y:0.48, size: 5,  minOp:0.10, maxOp:0.60, speed:3.0, delay:1.6,  symbol:"star.fill"),
        Star(x:0.75, y:0.38, size: 8,  minOp:0.20, maxOp:0.78, speed:2.1, delay:0.7,  symbol:"star.fill"),
        Star(x:0.88, y:0.52, size: 6,  minOp:0.15, maxOp:0.70, speed:2.7, delay:1.3,  symbol:"star.fill"),
        Star(x:0.08, y:0.70, size: 9,  minOp:0.20, maxOp:0.82, speed:2.0, delay:0.9,  symbol:"star.fill"),
        Star(x:0.22, y:0.78, size: 5,  minOp:0.10, maxOp:0.55, speed:3.3, delay:0.3,  symbol:"star.fill"),
        Star(x:0.45, y:0.72, size:11,  minOp:0.25, maxOp:0.90, speed:1.6, delay:1.8,  symbol:"sparkle"),
        Star(x:0.60, y:0.65, size: 6,  minOp:0.15, maxOp:0.65, speed:2.4, delay:0.6,  symbol:"star.fill"),
        Star(x:0.78, y:0.75, size: 8,  minOp:0.20, maxOp:0.80, speed:1.9, delay:1.2,  symbol:"star.fill"),
        Star(x:0.93, y:0.68, size: 5,  minOp:0.10, maxOp:0.58, speed:2.9, delay:0.4,  symbol:"star.fill"),
        Star(x:0.35, y:0.88, size: 7,  minOp:0.18, maxOp:0.72, speed:2.2, delay:1.5,  symbol:"star.fill"),
        Star(x:0.65, y:0.85, size: 9,  minOp:0.22, maxOp:0.85, speed:1.8, delay:0.8,  symbol:"sparkle"),
        Star(x:0.85, y:0.90, size: 5,  minOp:0.12, maxOp:0.60, speed:3.1, delay:2.0,  symbol:"star.fill"),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let op = isDark ? 1.0 : 0.65

            ZStack {
                // Planeten
                planet(color: Color(red: 0.45, green: 0.15, blue: 0.95),
                       size: 80, x: w * 0.82 + o1, y: h * 0.12 + ov1,
                       glow: Color(red: 0.4, green: 0.1, blue: 0.9), op: op * 0.55)

                planet(color: Color(red: 0.15, green: 0.05, blue: 0.60),
                       size: 52, x: w * 0.12 + o2, y: h * 0.35 + ov2,
                       glow: Color(red: 0.3, green: 0.1, blue: 0.8), op: op * 0.45)

                planet(color: Color(red: 0.30, green: 0.08, blue: 0.75),
                       size: 36, x: w * 0.60 + o3, y: h * 0.78 - ov1,
                       glow: Color(red: 0.5, green: 0.2, blue: 1.0), op: op * 0.40)

                // Sterne
                ForEach(stars.indices, id: \.self) { i in
                    let s = stars[i]
                    Image(systemName: s.symbol)
                        .font(.system(size: s.size, weight: .light))
                        .foregroundStyle(
                            s.symbol == "sparkle"
                                ? Color(red: 0.75, green: 0.55, blue: 1.0).opacity(twinkle ? s.maxOp * op : s.minOp * op)
                                : Color.white.opacity(twinkle ? s.maxOp * op : s.minOp * op)
                        )
                        .animation(
                            .easeInOut(duration: s.speed).repeatForever(autoreverses: true).delay(s.delay),
                            value: twinkle
                        )
                        .position(x: w * s.x, y: h * s.y)
                }
            }
        }
        .onAppear {
            twinkle = true
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true))           { o1 =  30; ov1 =  18 }
            withAnimation(.easeInOut(duration: 11.0).repeatForever(autoreverses: true).delay(2)) { o2 = -25; ov2 = -15 }
            withAnimation(.easeInOut(duration: 9.5).repeatForever(autoreverses: true).delay(1))  { o3 =  20 }
        }
    }

    private func planet(color: Color, size: CGFloat, x: CGFloat, y: CGFloat, glow: Color, op: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(op * 0.6), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 1.4))
                .frame(width: size * 2.8, height: size * 2.8)
                .blur(radius: 18)
            Circle()
                .fill(RadialGradient(
                    colors: [color.opacity(op), color.opacity(op * 0.7), color.opacity(op * 0.25)],
                    center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.5
                ))
                .frame(width: size, height: size)
        }
        .position(x: x, y: y)
    }
}

// MARK: - Vulkan lava & fire decoration
struct VulkanDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rise = false       // embers steigen auf
    @State private var flicker = false    // Flammen flackern
    @State private var lava1: CGFloat = 0
    @State private var lava2: CGFloat = 0
    @State private var lava3: CGFloat = 0

    private var isDark: Bool { colorScheme == .dark }

    private struct Ember {
        let x: CGFloat; let size: CGFloat
        let speed: Double; let delay: Double; let drift: CGFloat
        let color: Color
    }

    private let embers: [Ember] = [
        Ember(x:0.08, size: 6,  speed:4.5, delay:0.0,  drift:  8, color:.orange),
        Ember(x:0.16, size: 4,  speed:5.5, delay:0.7,  drift: -6, color:.red),
        Ember(x:0.24, size: 8,  speed:3.8, delay:1.4,  drift:  5, color:Color(red:1,green:0.55,blue:0)),
        Ember(x:0.32, size: 5,  speed:6.0, delay:0.3,  drift: -9, color:.orange),
        Ember(x:0.40, size: 7,  speed:4.2, delay:2.1,  drift:  7, color:.red),
        Ember(x:0.48, size: 4,  speed:5.8, delay:0.9,  drift: -5, color:Color(red:1,green:0.55,blue:0)),
        Ember(x:0.56, size: 9,  speed:3.5, delay:1.7,  drift:  6, color:.orange),
        Ember(x:0.64, size: 5,  speed:5.2, delay:0.5,  drift: -8, color:.red),
        Ember(x:0.72, size: 7,  speed:4.8, delay:2.5,  drift:  4, color:Color(red:1,green:0.55,blue:0)),
        Ember(x:0.80, size: 4,  speed:6.2, delay:1.1,  drift: -6, color:.orange),
        Ember(x:0.88, size: 8,  speed:4.0, delay:0.4,  drift:  9, color:.red),
        Ember(x:0.94, size: 5,  speed:5.5, delay:1.9,  drift: -4, color:Color(red:1,green:0.55,blue:0)),
        Ember(x:0.12, size: 4,  speed:6.5, delay:2.8,  drift:  7, color:.red),
        Ember(x:0.36, size: 6,  speed:4.3, delay:1.5,  drift: -5, color:.orange),
        Ember(x:0.58, size: 4,  speed:5.8, delay:3.0,  drift:  8, color:Color(red:1,green:0.55,blue:0)),
        Ember(x:0.76, size: 7,  speed:3.9, delay:0.8,  drift: -7, color:.orange),
        Ember(x:0.96, size: 5,  speed:5.0, delay:2.2,  drift:  5, color:.red),
    ]

    private let flames: [(size: CGFloat, angle: Double, dur: Double, delay: Double, scale: Double)] = [
        (75,  2.5, 1.8, 0.0, 1.15),
        (110, -3.0, 2.2, 0.3, 1.20),
        (85,  3.5, 1.6, 0.7, 1.18),
        (130, -2.0, 2.5, 0.1, 1.12),
        (95,  3.0, 1.9, 0.9, 1.22),
        (120, -3.5, 2.0, 0.5, 1.16),
        (80,  2.0, 2.3, 0.4, 1.14),
        (105, -2.5, 1.7, 0.8, 1.19),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let op = isDark ? 0.55 : 0.38

            ZStack {
                // Lava-Glüh-Blobs am Boden
                lavaBlob(color: Color(red:0.9,green:0.15,blue:0.0), w: w*0.65, h: h*0.22,
                         x: w*0.35 + lava1, y: h*0.92, blur: 40, op: op)
                lavaBlob(color: Color(red:1.0,green:0.40,blue:0.0), w: w*0.55, h: h*0.18,
                         x: w*0.68 + lava2, y: h*0.94, blur: 35, op: op*0.80)
                lavaBlob(color: Color(red:0.8,green:0.05,blue:0.0), w: w*0.50, h: h*0.15,
                         x: w*0.18 + lava3, y: h*0.95, blur: 38, op: op*0.70)

                // Flammen-Reihe unten
                HStack(alignment: .bottom, spacing: -14) {
                    ForEach(flames.indices, id: \.self) { i in
                        let f = flames[i]
                        Image(systemName: "flame.fill")
                            .font(.system(size: f.size))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red:1,green:0.55,blue:0).opacity(op*1.2),
                                             Color.red.opacity(op*0.9)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .scaleEffect(flicker ? f.scale : 1.0 / f.scale,
                                         anchor: .bottom)
                            .rotationEffect(.degrees(flicker ? f.angle : -f.angle), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: f.dur).repeatForever(autoreverses: true).delay(f.delay),
                                value: flicker
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: w)
                .position(x: w * 0.5, y: h + 20)

                // Aufsteigende Glut-Partikel
                ForEach(embers.indices, id: \.self) { i in
                    let e = embers[i]
                    Circle()
                        .fill(e.color.opacity(rise ? (isDark ? 0.75 : 0.55) : 0))
                        .frame(width: e.size, height: e.size)
                        .blur(radius: e.size * 0.4)
                        .offset(x: w * e.x + (rise ? e.drift : -e.drift),
                                y: rise ? -60 : h + 30)
                        .animation(
                            .linear(duration: e.speed).repeatForever(autoreverses: false).delay(e.delay),
                            value: rise
                        )
                }
            }
        }
        .onAppear {
            rise    = true
            flicker = true
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true))           { lava1 =  45 }
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true).delay(1.5)){ lava2 = -38 }
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true).delay(0.8)){ lava3 =  30 }
        }
    }

    private func lavaBlob(color: Color, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat, op: Double) -> some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [color.opacity(op), color.opacity(op * 0.5), .clear],
                center: .center, startRadius: 0, endRadius: max(w, h) * 0.5
            ))
            .frame(width: w, height: h)
            .position(x: x, y: y)
            .blur(radius: blur)
    }
}

// MARK: - Herbst falling leaves decoration
struct HerbstDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var fall   = false
    @State private var rotate = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Leaf {
        let x: CGFloat; let size: CGFloat
        let speed: Double; let delay: Double
        let drift: CGFloat; let rotSpeed: Double
        let color: Color
    }

    private let leaves: [Leaf] = [
        Leaf(x:0.05, size:18, speed:5.0, delay:0.0,  drift:  12, rotSpeed:2.5, color:Color(red:0.85,green:0.35,blue:0.05)),
        Leaf(x:0.13, size:14, speed:6.5, delay:0.8,  drift: -10, rotSpeed:3.8, color:.orange),
        Leaf(x:0.22, size:22, speed:4.5, delay:1.6,  drift:   9, rotSpeed:2.0, color:Color(red:0.70,green:0.20,blue:0.05)),
        Leaf(x:0.31, size:16, speed:7.0, delay:0.4,  drift: -13, rotSpeed:4.2, color:Color(red:0.60,green:0.28,blue:0.04)),
        Leaf(x:0.40, size:20, speed:5.5, delay:2.2,  drift:  10, rotSpeed:3.0, color:Color(red:1.0,green:0.55,blue:0.0)),
        Leaf(x:0.49, size:15, speed:6.0, delay:1.0,  drift:  -8, rotSpeed:3.5, color:Color(red:0.85,green:0.35,blue:0.05)),
        Leaf(x:0.58, size:24, speed:4.2, delay:3.1,  drift:  11, rotSpeed:1.8, color:.orange),
        Leaf(x:0.66, size:17, speed:6.8, delay:0.6,  drift: -12, rotSpeed:4.0, color:Color(red:0.70,green:0.20,blue:0.05)),
        Leaf(x:0.74, size:21, speed:5.2, delay:1.8,  drift:   8, rotSpeed:2.8, color:Color(red:1.0,green:0.55,blue:0.0)),
        Leaf(x:0.82, size:13, speed:7.5, delay:0.3,  drift: -10, rotSpeed:5.0, color:Color(red:0.60,green:0.28,blue:0.04)),
        Leaf(x:0.90, size:19, speed:5.8, delay:2.6,  drift:   7, rotSpeed:3.2, color:Color(red:0.85,green:0.35,blue:0.05)),
        Leaf(x:0.96, size:16, speed:6.3, delay:1.3,  drift:  -9, rotSpeed:3.7, color:.orange),
        Leaf(x:0.08, size:12, speed:7.8, delay:3.5,  drift:  11, rotSpeed:4.5, color:Color(red:0.70,green:0.20,blue:0.05)),
        Leaf(x:0.27, size:20, speed:4.8, delay:2.0,  drift:  -7, rotSpeed:2.3, color:Color(red:1.0,green:0.55,blue:0.0)),
        Leaf(x:0.45, size:14, speed:6.5, delay:4.0,  drift:  10, rotSpeed:4.8, color:Color(red:0.85,green:0.35,blue:0.05)),
        Leaf(x:0.63, size:23, speed:4.0, delay:1.5,  drift:  -9, rotSpeed:1.6, color:.orange),
        Leaf(x:0.79, size:16, speed:6.0, delay:2.8,  drift:   8, rotSpeed:3.4, color:Color(red:0.60,green:0.28,blue:0.04)),
        Leaf(x:0.93, size:12, speed:7.2, delay:0.7,  drift: -11, rotSpeed:4.6, color:Color(red:0.70,green:0.20,blue:0.05)),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(leaves.indices, id: \.self) { i in
                let l = leaves[i]
                Image(systemName: "leaf.fill")
                    .font(.system(size: l.size))
                    .foregroundStyle(l.color.opacity(isDark ? 0.70 : 0.55))
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(
                        .linear(duration: l.rotSpeed).repeatForever(autoreverses: false),
                        value: rotate
                    )
                    .offset(
                        x: geo.size.width * l.x + (fall ? l.drift : -l.drift),
                        y: fall ? geo.size.height + 60 : -80
                    )
                    .animation(
                        .linear(duration: l.speed).repeatForever(autoreverses: false).delay(l.delay),
                        value: fall
                    )
            }
        }
        .onAppear {
            fall   = true
            rotate = true
        }
    }
}

// MARK: - Nacht: Mond + Sterne + Sternschnuppe
struct NachtDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var twinkle = false
    @State private var moonPulse = false
    @State private var shoot1: CGFloat = 0
    @State private var shoot2: CGFloat = 0
    private var isDark: Bool { colorScheme == .dark }

    private struct Star { let x, y, size, minOp, maxOp, speed, delay: Double }
    private let stars: [Star] = [
        Star(x:0.07,y:0.06,size: 7,minOp:0.25,maxOp:0.90,speed:1.9,delay:0.0),
        Star(x:0.18,y:0.14,size: 5,minOp:0.15,maxOp:0.70,speed:2.6,delay:0.5),
        Star(x:0.30,y:0.08,size: 9,minOp:0.30,maxOp:0.95,speed:1.6,delay:1.0),
        Star(x:0.42,y:0.20,size: 6,minOp:0.20,maxOp:0.75,speed:2.3,delay:0.3),
        Star(x:0.55,y:0.05,size: 8,minOp:0.25,maxOp:0.88,speed:1.8,delay:1.4),
        Star(x:0.25,y:0.30,size: 5,minOp:0.10,maxOp:0.60,speed:3.0,delay:0.8),
        Star(x:0.68,y:0.12,size: 7,minOp:0.20,maxOp:0.80,speed:2.1,delay:0.2),
        Star(x:0.10,y:0.40,size: 6,minOp:0.15,maxOp:0.65,speed:2.7,delay:1.7),
        Star(x:0.38,y:0.38,size: 9,minOp:0.28,maxOp:0.90,speed:1.5,delay:0.6),
        Star(x:0.50,y:0.28,size: 5,minOp:0.12,maxOp:0.55,speed:3.2,delay:2.0),
        Star(x:0.72,y:0.35,size: 7,minOp:0.22,maxOp:0.82,speed:2.0,delay:0.9),
        Star(x:0.85,y:0.18,size: 6,minOp:0.18,maxOp:0.72,speed:2.5,delay:1.2),
        Star(x:0.15,y:0.55,size: 5,minOp:0.10,maxOp:0.58,speed:3.1,delay:0.4),
        Star(x:0.60,y:0.50,size: 8,minOp:0.25,maxOp:0.85,speed:1.7,delay:1.5),
        Star(x:0.92,y:0.42,size: 5,minOp:0.12,maxOp:0.62,speed:2.9,delay:0.7),
        Star(x:0.45,y:0.60,size: 7,minOp:0.20,maxOp:0.78,speed:2.2,delay:2.3),
        Star(x:0.78,y:0.55,size: 6,minOp:0.15,maxOp:0.68,speed:2.8,delay:1.1),
        Star(x:0.22,y:0.68,size: 5,minOp:0.10,maxOp:0.55,speed:3.3,delay:0.3),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let op = isDark ? 1.0 : 0.7
            ZStack {
                // Mond
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color(red:0.95,green:0.95,blue:0.75).opacity(isDark ? 0.30 : 0.15), .clear],
                                             center: .center, startRadius: 0, endRadius: 55))
                        .frame(width: 110, height: 110)
                        .scaleEffect(moonPulse ? 1.12 : 1.0)
                        .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: moonPulse)
                    Circle()
                        .fill(RadialGradient(colors: [Color(red:0.98,green:0.97,blue:0.85).opacity(op*0.75),
                                                       Color(red:0.85,green:0.82,blue:0.65).opacity(op*0.55)],
                                             center: .init(x:0.35,y:0.35), startRadius: 0, endRadius: 24))
                        .frame(width: 48, height: 48)
                }
                .position(x: w * 0.82, y: h * 0.10)

                // Sternschnuppen
                Capsule()
                    .fill(LinearGradient(colors: [Color.white.opacity(op*0.85), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 80 + shoot1 * 0, height: 2)
                    .rotationEffect(.degrees(-30))
                    .offset(x: w * 0.15 + shoot1 * 0.7, y: h * 0.08 + shoot1 * 0.4)
                    .opacity(shoot1 > 0 && shoot1 < w ? 1 : 0)
                    .animation(.linear(duration: 0.6).repeatForever(autoreverses: false).delay(4.0), value: shoot1)

                // Sterne
                ForEach(stars.indices, id: \.self) { i in
                    let s = stars[i]
                    Image(systemName: "star.fill")
                        .font(.system(size: s.size, weight: .ultraLight))
                        .foregroundStyle(Color.white.opacity(twinkle ? s.maxOp * op : s.minOp * op))
                        .animation(.easeInOut(duration: s.speed).repeatForever(autoreverses: true).delay(s.delay), value: twinkle)
                        .position(x: w * s.x, y: h * s.y)
                }
            }
        }
        .onAppear {
            twinkle   = true
            moonPulse = true
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false).delay(4.0)) { shoot1 = 400 }
        }
    }
}

// MARK: - Solar: Sonnenstrahlen + Lichtpartikel
struct SolarDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rotation: Double = 0
    @State private var rise = false
    @State private var pulse = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Particle { let x: CGFloat; let speed, delay, drift: Double }
    private let particles: [Particle] = [
        Particle(x:0.08, speed:4.5, delay:0.0,  drift:  8),
        Particle(x:0.20, speed:5.5, delay:0.6,  drift: -7),
        Particle(x:0.33, speed:3.8, delay:1.3,  drift:  6),
        Particle(x:0.47, speed:6.0, delay:0.2,  drift: -9),
        Particle(x:0.60, speed:4.2, delay:2.0,  drift:  7),
        Particle(x:0.73, speed:5.2, delay:0.9,  drift: -5),
        Particle(x:0.86, speed:3.5, delay:1.7,  drift:  8),
        Particle(x:0.14, speed:5.8, delay:0.4,  drift: -6),
        Particle(x:0.40, speed:4.8, delay:2.5,  drift:  5),
        Particle(x:0.65, speed:6.2, delay:1.1,  drift: -8),
        Particle(x:0.92, speed:4.0, delay:0.8,  drift:  7),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let op = isDark ? 0.50 : 0.35
            ZStack {
                // Sonnen-Glüh-Orb
                Circle()
                    .fill(RadialGradient(colors: [Color.yellow.opacity(op*0.8), Color.orange.opacity(op*0.4), .clear],
                                         center: .center, startRadius: 0, endRadius: 90))
                    .frame(width: 180, height: 180)
                    .scaleEffect(pulse ? 1.10 : 0.95)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulse)
                    .position(x: w * 0.50, y: h * 0.06)

                // Rotierende Strahlen
                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(colors: [Color.yellow.opacity(op*0.6), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 60 + CGFloat(i % 3) * 15, height: 3)
                        .rotationEffect(.degrees(rotation + Double(i) * 30))
                        .position(x: w * 0.50, y: h * 0.06)
                }

                // Aufsteigende Licht-Partikel
                ForEach(particles.indices, id: \.self) { i in
                    let p = particles[i]
                    Circle()
                        .fill(Color(red:1,green:0.85,blue:0.2).opacity(rise ? (isDark ? 0.65 : 0.45) : 0))
                        .frame(width: 6, height: 6)
                        .blur(radius: 2)
                        .offset(x: geo.size.width * CGFloat(p.x) + CGFloat(rise ? p.drift : -p.drift),
                                y: rise ? -60 : h + 30)
                        .animation(.linear(duration: p.speed).repeatForever(autoreverses: false).delay(p.delay), value: rise)
                }
            }
        }
        .onAppear {
            rise  = true
            pulse = true
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - Kirschblüte: Fallende Kirschblütenblätter
struct KirschblueteDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var fall = false
    @State private var rotate = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Petal {
        let x: CGFloat; let size: CGFloat
        let speed, delay, drift, rotSpeed: Double; let color: Color
    }
    private let petals: [Petal] = [
        Petal(x:0.05, size:16, speed:5.5, delay:0.0,  drift: 14, rotSpeed:2.5, color:Color(red:1.0,green:0.75,blue:0.80)),
        Petal(x:0.14, size:12, speed:7.0, delay:0.7,  drift:-10, rotSpeed:3.8, color:Color(red:1.0,green:0.60,blue:0.72)),
        Petal(x:0.23, size:20, speed:4.8, delay:1.5,  drift: 11, rotSpeed:2.0, color:Color(red:1.0,green:0.82,blue:0.88)),
        Petal(x:0.32, size:14, speed:6.5, delay:0.3,  drift:-12, rotSpeed:4.2, color:Color(red:0.98,green:0.65,blue:0.78)),
        Petal(x:0.41, size:18, speed:5.0, delay:2.1,  drift: 10, rotSpeed:3.0, color:Color(red:1.0,green:0.75,blue:0.80)),
        Petal(x:0.50, size:13, speed:6.2, delay:0.9,  drift: -8, rotSpeed:3.5, color:Color(red:1.0,green:0.82,blue:0.88)),
        Petal(x:0.59, size:22, speed:4.3, delay:3.0,  drift: 12, rotSpeed:1.8, color:Color(red:1.0,green:0.60,blue:0.72)),
        Petal(x:0.68, size:15, speed:6.8, delay:0.5,  drift:-11, rotSpeed:4.0, color:Color(red:0.98,green:0.65,blue:0.78)),
        Petal(x:0.77, size:19, speed:5.3, delay:1.8,  drift:  9, rotSpeed:2.8, color:Color(red:1.0,green:0.75,blue:0.80)),
        Petal(x:0.86, size:12, speed:7.5, delay:0.4,  drift:-10, rotSpeed:5.0, color:Color(red:1.0,green:0.82,blue:0.88)),
        Petal(x:0.93, size:17, speed:5.8, delay:2.5,  drift:  8, rotSpeed:3.2, color:Color(red:0.98,green:0.65,blue:0.78)),
        Petal(x:0.10, size:11, speed:7.8, delay:3.5,  drift: 10, rotSpeed:4.5, color:Color(red:1.0,green:0.60,blue:0.72)),
        Petal(x:0.28, size:18, speed:5.0, delay:2.0,  drift: -8, rotSpeed:2.3, color:Color(red:1.0,green:0.75,blue:0.80)),
        Petal(x:0.46, size:13, speed:6.5, delay:4.0,  drift: 11, rotSpeed:4.8, color:Color(red:1.0,green:0.82,blue:0.88)),
        Petal(x:0.64, size:21, speed:4.1, delay:1.4,  drift: -9, rotSpeed:1.6, color:Color(red:0.98,green:0.65,blue:0.78)),
        Petal(x:0.80, size:15, speed:6.0, delay:2.8,  drift:  9, rotSpeed:3.4, color:Color(red:1.0,green:0.60,blue:0.72)),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(petals.indices, id: \.self) { i in
                let p = petals[i]
                Image(systemName: "leaf.fill")
                    .font(.system(size: p.size))
                    .foregroundStyle(p.color.opacity(isDark ? 0.75 : 0.60))
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: p.rotSpeed).repeatForever(autoreverses: false), value: rotate)
                    .offset(x: geo.size.width * p.x + CGFloat(fall ? p.drift : -p.drift),
                            y: fall ? geo.size.height + 60 : -80)
                    .animation(.linear(duration: p.speed).repeatForever(autoreverses: false).delay(p.delay), value: fall)
            }
        }
        .onAppear { fall = true; rotate = true }
    }
}

// MARK: - Lavendel: Aufsteigende Blasen + Funken
struct LavendelDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var rise = false
    @State private var sparkle = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Bubble {
        let x: CGFloat; let size: CGFloat
        let speed, delay, drift: Double; let color: Color
    }
    private let bubbles: [Bubble] = [
        Bubble(x:0.07, size:14, speed:5.0, delay:0.0,  drift:  8, color:Color(red:0.75,green:0.45,blue:0.95)),
        Bubble(x:0.18, size: 9, speed:6.5, delay:0.8,  drift: -7, color:Color(red:0.85,green:0.60,blue:1.0)),
        Bubble(x:0.29, size:18, speed:4.5, delay:1.6,  drift:  9, color:Color(red:0.65,green:0.35,blue:0.88)),
        Bubble(x:0.40, size:11, speed:7.0, delay:0.4,  drift:-10, color:Color(red:0.75,green:0.45,blue:0.95)),
        Bubble(x:0.51, size:16, speed:5.5, delay:2.2,  drift:  7, color:Color(red:0.85,green:0.60,blue:1.0)),
        Bubble(x:0.62, size:10, speed:6.0, delay:1.0,  drift: -8, color:Color(red:0.65,green:0.35,blue:0.88)),
        Bubble(x:0.73, size:20, speed:4.2, delay:3.0,  drift:  6, color:Color(red:0.75,green:0.45,blue:0.95)),
        Bubble(x:0.84, size:12, speed:6.8, delay:0.6,  drift:-11, color:Color(red:0.85,green:0.60,blue:1.0)),
        Bubble(x:0.93, size:15, speed:5.2, delay:1.8,  drift:  8, color:Color(red:0.65,green:0.35,blue:0.88)),
        Bubble(x:0.12, size: 8, speed:7.5, delay:3.5,  drift:-6,  color:Color(red:0.85,green:0.60,blue:1.0)),
        Bubble(x:0.35, size:17, speed:4.8, delay:2.0,  drift:  9, color:Color(red:0.75,green:0.45,blue:0.95)),
        Bubble(x:0.58, size:11, speed:6.5, delay:4.0,  drift:-7,  color:Color(red:0.65,green:0.35,blue:0.88)),
        Bubble(x:0.78, size:13, speed:5.8, delay:1.4,  drift:  8, color:Color(red:0.85,green:0.60,blue:1.0)),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(bubbles.indices, id: \.self) { i in
                let b = bubbles[i]
                Circle()
                    .fill(b.color.opacity(rise ? (isDark ? 0.55 : 0.40) : 0))
                    .frame(width: b.size, height: b.size)
                    .blur(radius: b.size * 0.25)
                    .overlay(Circle().strokeBorder(b.color.opacity(rise ? 0.35 : 0), lineWidth: 1))
                    .offset(x: geo.size.width * b.x + CGFloat(rise ? b.drift : -b.drift),
                            y: rise ? -60 : geo.size.height + 40)
                    .animation(.easeInOut(duration: b.speed).repeatForever(autoreverses: false).delay(b.delay), value: rise)
            }
            // Schwebende Funken
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat([10,14,8,16,12,10,14,9][i])))
                    .foregroundStyle(Color(red:0.75,green:0.45,blue:0.95).opacity(sparkle ? (isDark ? 0.60 : 0.40) : (isDark ? 0.20 : 0.12)))
                    .animation(.easeInOut(duration: [2.0,2.8,1.8,3.2,2.5,2.2,3.0,1.9][i]).repeatForever(autoreverses: true).delay(Double(i)*0.35), value: sparkle)
                    .position(x: geo.size.width * [0.10,0.25,0.42,0.58,0.70,0.82,0.92,0.35][i],
                              y: geo.size.height * [0.15,0.30,0.20,0.40,0.25,0.15,0.35,0.50][i])
            }
        }
        .onAppear { rise = true; sparkle = true }
    }
}

// MARK: - Sonnenuntergang: Warme Lichtstrahlen + Partikel
struct SonnenuntergangDecorationLayer: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var s1: CGFloat = 0
    @State private var s2: CGFloat = 0
    @State private var s3: CGFloat = 0
    @State private var v1: CGFloat = 0
    @State private var rise = false
    private var isDark: Bool { colorScheme == .dark }

    private struct Spark { let x: CGFloat; let speed, delay, drift: Double }
    private let sparks: [Spark] = [
        Spark(x:0.08, speed:4.5, delay:0.0,  drift:  8),
        Spark(x:0.22, speed:5.5, delay:0.7,  drift: -7),
        Spark(x:0.36, speed:4.0, delay:1.4,  drift:  6),
        Spark(x:0.50, speed:6.0, delay:0.3,  drift: -9),
        Spark(x:0.64, speed:4.8, delay:2.1,  drift:  7),
        Spark(x:0.78, speed:5.2, delay:1.0,  drift: -6),
        Spark(x:0.92, speed:3.8, delay:1.8,  drift:  8),
        Spark(x:0.15, speed:5.8, delay:2.8,  drift: -5),
        Spark(x:0.44, speed:4.3, delay:0.6,  drift:  9),
        Spark(x:0.72, speed:6.3, delay:3.2,  drift: -7),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            let op = isDark ? 0.55 : 0.38
            ZStack {
                // Warme Aurora-Bänder am Horizont (untere Hälfte)
                sunBand(color: Color(red:1.0,green:0.45,blue:0.15), op: op,
                        w: w*0.60, h: h*0.50, x: w*0.35+s1, y: h*0.82+v1, blur: 40)
                sunBand(color: Color(red:1.0,green:0.25,blue:0.50), op: op*0.80,
                        w: w*0.50, h: h*0.42, x: w*0.65+s2, y: h*0.85, blur: 45)
                sunBand(color: Color(red:1.0,green:0.65,blue:0.0),  op: op*0.70,
                        w: w*0.45, h: h*0.38, x: w*0.20+s3, y: h*0.88-v1, blur: 38)

                // Aufsteigende Licht-Partikel
                ForEach(sparks.indices, id: \.self) { i in
                    let sp = sparks[i]
                    let colors: [Color] = [.orange, Color(red:1,green:0.4,blue:0.2), .pink, Color(red:1,green:0.65,blue:0)]
                    Circle()
                        .fill(colors[i % 4].opacity(rise ? (isDark ? 0.65 : 0.45) : 0))
                        .frame(width: 7, height: 7).blur(radius: 2.5)
                        .offset(x: w * sp.x + CGFloat(rise ? sp.drift : -sp.drift),
                                y: rise ? -60 : h + 30)
                        .animation(.linear(duration: sp.speed).repeatForever(autoreverses: false).delay(sp.delay), value: rise)
                }
            }
        }
        .onAppear {
            rise = true
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true))           { s1 =  55; v1 =  20 }
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true).delay(1.5)){ s2 = -48 }
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true).delay(0.8)){ s3 =  40 }
        }
    }

    private func sunBand(color: Color, op: Double, w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat, blur: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: w * 0.5, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(op * 0.3), color.opacity(op), color.opacity(op * 0.5), .clear],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: w, height: h)
            .position(x: x, y: y)
            .blur(radius: blur)
    }
}

// MARK: - Reusable themed background
struct ThemeBackgroundView: View {
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme
    @State private var glowPulse = false
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0

    private var isDark: Bool { colorScheme == .dark }
    private var c1: Color { appThemaFarben(aktivesThema).0 }
    private var c2: Color { appThemaFarben(aktivesThema).1 }

    private let waveThemes: [String] = ["", "Forest", "Ice", "Northern Lights", "Galaxy", "Volcano",
                                        "Autumn", "Night", "Solar", "Cherry Blossom", "Lavender", "Sunset"]

    var body: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(
                        colors: [c1.opacity(isDark ? (glowPulse ? 0.28 : 0.16) : (glowPulse ? 0.14 : 0.08)), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width, height: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.42)
                    .blur(radius: 35)
                    .animation(.easeInOut(duration: 0.6), value: aktivesThema)

                Circle()
                    .fill(RadialGradient(
                        colors: [c2.opacity(isDark ? 0.15 : 0.08), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.75)
                    .blur(radius: 22)
                    .animation(.easeInOut(duration: 0.6), value: aktivesThema)
            }

            GeometryReader { geo in
                WaveShape(phase: wavePhase2, amplitude: 16, frequency: 1.5)
                    .fill(c2.opacity(isDark ? 0.09 : 0.06))
                    .frame(width: geo.size.width, height: geo.size.height * 0.38)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.38 * 0.5)
                WaveShape(phase: wavePhase1, amplitude: 11, frequency: 2.2)
                    .fill(c1.opacity(isDark ? 0.14 : 0.09))
                    .frame(width: geo.size.width, height: geo.size.height * 0.25)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.25 * 0.5)
            }
            .opacity(waveThemes.contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)

            if aktivesThema == "Forest"           { WaldDecorationLayer().transition(.opacity) }
            if aktivesThema == "Ice"            { EisDecorationLayer().transition(.opacity) }
            if aktivesThema == "Northern Lights"      { NordlichtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Galaxy"        { GalaxieDecorationLayer().transition(.opacity) }
            if aktivesThema == "Volcano"         { VulkanDecorationLayer().transition(.opacity) }
            if aktivesThema == "Autumn"         { HerbstDecorationLayer().transition(.opacity) }
            if aktivesThema == "Night"          { NachtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Solar"          { SolarDecorationLayer().transition(.opacity) }
            if aktivesThema == "Cherry Blossom"    { KirschblueteDecorationLayer().transition(.opacity) }
            if aktivesThema == "Lavender"       { LavendelDecorationLayer().transition(.opacity) }
            if aktivesThema == "Sunset"{ SonnenuntergangDecorationLayer().transition(.opacity) }
            if aktivesThema == "Aurora"         { AuroraDecorationLayer().transition(.opacity) }
            if aktivesThema == "Obsidian"       { ObsidianDecorationLayer().transition(.opacity) }
            if aktivesThema == "Nebula"         { NebulaDecorationLayer().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.8), value: aktivesThema)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glowPulse = true }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { wavePhase1 = .pi * 2 }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { wavePhase2 = .pi * 2 }
        }
    }
}

// MARK: - Shared themed glass card modifier
struct ThemeGlassModifier: ViewModifier {
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    private var isDark: Bool { colorScheme == .dark }
    private var hasTema: Bool { !aktivesThema.isEmpty }

    func body(content: Content) -> some View {
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [c1.opacity(isDark ? 0.14 : 0.09),
                                 c2.opacity(isDark ? 0.07 : 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .opacity(hasTema ? 1.0 : 0.0)
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: hasTema
                                ? [c1.opacity(isDark ? 0.50 : 0.32), c2.opacity(isDark ? 0.22 : 0.16)]
                                : [Color.white.opacity(isDark ? 0.13 : 0.65), Color.white.opacity(isDark ? 0.04 : 0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
            .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.5), value: aktivesThema)
    }
}

extension View {
    func themeGlass(cornerRadius: CGFloat = 18) -> some View {
        modifier(ThemeGlassModifier(cornerRadius: cornerRadius))
    }
}

func appThemaFarben(_ name: String) -> (Color, Color, Color) {
    switch name {
    case "Ocean":          return (.cyan, .teal, Color(red: 0.0, green: 0.6, blue: 0.9))
    case "Forest":           return (.green, Color(red: 0.1, green: 0.5, blue: 0.2), .mint)
    case "Night":          return (.indigo, Color(red: 0.1, green: 0.0, blue: 0.3), .purple)
    case "Solar":          return (.orange, .yellow, Color(red: 1.0, green: 0.4, blue: 0.0))
    case "Cherry Blossom":    return (.pink, Color(red: 1.0, green: 0.4, blue: 0.6), .red)
    case "Volcano":         return (.red, Color(red: 0.8, green: 0.1, blue: 0.0), .orange)
    case "Ice":            return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan, .white)
    case "Autumn":         return (Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.3, blue: 0.05), .orange)
    case "Lavender":       return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.85, green: 0.7, blue: 1.0))
    case "Sunset":return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink, Color(red: 1.0, green: 0.65, blue: 0.0))
    case "Galaxy":        return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95), Color(red: 0.80, green: 0.58, blue: 1.0))
    case "Northern Lights":      return (.green, Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 1.0))
    case "Aurora":         return (Color(red: 0.0, green: 0.9, blue: 0.8), Color(red: 0.5, green: 0.0, blue: 1.0), Color(red: 0.9, green: 0.0, blue: 1.0))
    case "Obsidian":       return (Color(red: 0.85, green: 0.65, blue: 0.1), Color(red: 0.6, green: 0.42, blue: 0.04), Color(red: 1.0, green: 0.85, blue: 0.3))
    case "Nebula":         return (Color(red: 1.0, green: 0.15, blue: 0.6), Color(red: 0.45, green: 0.0, blue: 0.85), Color(red: 0.1, green: 0.55, blue: 1.0))
    default:               return (.purple, .blue, Color(red: 0.4, green: 0.2, blue: 0.9))
    }
}

// MARK: - Active Card Pulse (animierter Glow-Rand für laufende Aufgaben)

struct ActiveCardPulseModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isActive ? (pulse ? 0.62 : 0.28) : 0),
                    radius: isActive ? 18 : 0, x: 0, y: isActive ? 7 : 0)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { pulse = true }
            }
    }
}

// MARK: - Task Card Theme Decoration

struct TaskCardThemeDecoration: View {
    let theme: String
    let isDark: Bool
    let isActive: Bool

    @ViewBuilder
    var body: some View {
        if      theme == "Ocean"            { OzeanCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Forest"             { WaldCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Night"            { NachtCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Solar"            { SolarCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Cherry Blossom"      { KirschCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Volcano"           { VulkanCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Ice"             { EisCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Autumn"           { HerbstCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Lavender"         { LavendelCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Sunset"  { SunsetCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Galaxy"          { GalaxieCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Northern Lights"        { NordlichtCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Aurora"           { AuroraCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Obsidian"         { ObsidianCardDeco(isDark: isDark, isActive: isActive) }
        else if theme == "Nebula"           { NebulaCardDeco(isDark: isDark, isActive: isActive) }
    }
}

// MARK: - Ozean

private struct OzeanCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var sway  = false
    @State private var pulse = false

    private struct Weed { let x: CGFloat; let h: CGFloat; let spd: Double; let ang: Double; let dly: Double }
    private let weeds: [Weed] = [
        Weed(x: 0.02, h: 38, spd: 2.6, ang:  9.0, dly: 0.0),
        Weed(x: 0.06, h: 26, spd: 3.2, ang: -8.0, dly: 0.4),
        Weed(x: 0.10, h: 44, spd: 2.4, ang: 10.5, dly: 0.9),
        Weed(x: 0.14, h: 20, spd: 3.7, ang: -7.0, dly: 1.4),
        Weed(x: 0.18, h: 32, spd: 2.9, ang:  8.0, dly: 0.6),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.50 : 0.28) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0, green:0.55, blue:0.75).opacity(isDark ? 0.20 : 0.10), .clear],
                    startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.45)
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.14), .clear],
                        center: .bottomLeading, startRadius: 0, endRadius: h * 0.7
                    )
                }
                ForEach(weeds.indices, id: \.self) { i in
                    let s = weeds[i]
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red:0, green:0.72, blue:0.78).opacity(op),
                                     Color.cyan.opacity(op * 0.5)],
                            startPoint: .bottom, endPoint: .top
                        ))
                        .frame(width: 4.5, height: s.h)
                        .rotationEffect(.degrees(sway ? s.ang : -s.ang), anchor: .bottom)
                        .animation(.easeInOut(duration: s.spd).repeatForever(autoreverses: true).delay(s.dly), value: sway)
                        .position(x: w * s.x + 6, y: h - s.h * 0.5 + 4)
                }
                ForEach(0..<3, id: \.self) { i in
                    let sizes: [CGFloat] = [9, 6, 4]
                    let xs: [CGFloat]    = [0.38, 0.54, 0.47]
                    let ys: [CGFloat]    = [0.30, 0.46, 0.18]
                    let spds: [Double]   = [2.6, 3.4, 2.0]
                    let dlys: [Double]   = [0.8, 0.0, 1.3]
                    Circle()
                        .strokeBorder(Color.cyan.opacity(pulse ? op * 0.75 : op * 0.18), lineWidth: 1.2)
                        .frame(width: sizes[i], height: sizes[i])
                        .position(x: w * xs[i], y: h * ys[i])
                        .animation(.easeInOut(duration: spds[i]).repeatForever(autoreverses: true).delay(dlys[i]), value: pulse)
                }
            }
        }
        .onAppear { sway = true; pulse = true }
    }
}

// MARK: - Wald

private struct WaldCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var sway  = false
    @State private var light = false

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.46 : 0.25) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.05, green:0.45, blue:0.15).opacity(isDark ? 0.18 : 0.09), .clear],
                    startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.50)
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.green.opacity(0.12), .clear],
                        center: .topTrailing, startRadius: 0, endRadius: h * 0.65
                    )
                }
                let leafData: [(CGFloat, CGFloat, CGFloat, Double, Double, Double)] = [
                    (0.90, 0.18, 16, 2.5,  7.0, 0.0),
                    (0.82, 0.50, 11, 3.0, -6.0, 0.6),
                    (0.93, 0.64,  9, 2.2,  5.5, 1.1),
                    (0.86, 0.80,  7, 2.8, -4.5, 1.7),
                ]
                ForEach(leafData.indices, id: \.self) { i in
                    let (x, y, sz, spd, ang, dly) = leafData[i]
                    Image(systemName: "leaf.fill")
                        .font(.system(size: sz))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(op), Color.mint.opacity(op * 0.65)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(sway ? ang : -ang * 0.7), anchor: .bottom)
                        .animation(.easeInOut(duration: spd).repeatForever(autoreverses: true).delay(dly), value: sway)
                        .position(x: w * x, y: h * y)
                }
                ForEach(0..<3, id: \.self) { i in
                    let lxs: [CGFloat] = [0.60, 0.35, 0.75]
                    let lys: [CGFloat] = [0.25, 0.55, 0.68]
                    let lsz: [CGFloat] = [22,   16,   12  ]
                    Circle()
                        .fill(Color.yellow.opacity(light ? (isDark ? 0.12 : 0.07) : 0.02))
                        .frame(width: lsz[i], height: lsz[i])
                        .blur(radius: 5)
                        .position(x: w * lxs[i], y: h * lys[i])
                        .animation(.easeInOut(duration: 2.8 + Double(i) * 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.5), value: light)
                }
            }
        }
        .onAppear { sway = true; light = true }
    }
}

// MARK: - Nacht

private struct NachtCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var twinkle = false
    @State private var moonGlow = false

    private let stars: [(CGFloat, CGFloat, CGFloat, Double, Double, Bool)] = [
        (0.88, 0.14,  8, 0.28, 0.0,  false),
        (0.78, 0.33,  5, 0.18, 0.7,  true),
        (0.94, 0.52,  6, 0.24, 1.3,  false),
        (0.83, 0.70,  4, 0.16, 0.4,  true),
        (0.96, 0.30,  5, 0.20, 1.8,  false),
        (0.73, 0.55,  7, 0.22, 0.9,  true),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.5 : 1.0
        let op = (isDark ? 1.0 : 0.60) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.08, green:0.03, blue:0.30).opacity(isDark ? 0.20 : 0.08), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                Circle()
                    .fill(Color(red:0.95, green:0.95, blue:0.80).opacity(moonGlow ? (isDark ? 0.26 : 0.14) : (isDark ? 0.14 : 0.07)))
                    .frame(width: 18, height: 18)
                    .blur(radius: isActive ? 6 : 3)
                    .position(x: w * 0.88, y: h * 0.18)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: moonGlow)
                Image(systemName: "moonphase.waxing.crescent")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundStyle(Color(red:0.95, green:0.95, blue:0.80).opacity(isDark ? 0.55 : 0.35))
                    .position(x: w * 0.88, y: h * 0.18)
                ForEach(stars.indices, id: \.self) { i in
                    let (x, y, sz, minOp, dly, isSparkle) = stars[i]
                    Image(systemName: isSparkle ? "sparkle" : "star.fill")
                        .font(.system(size: sz, weight: .ultraLight))
                        .foregroundStyle(Color.white.opacity(twinkle ? min(minOp * 4.2 * op, 1.0) : minOp * op))
                        .animation(.easeInOut(duration: 1.8 + Double(i) * 0.4).repeatForever(autoreverses: true).delay(dly), value: twinkle)
                        .position(x: w * x, y: h * y)
                }
            }
        }
        .onAppear { twinkle = true; moonGlow = true }
    }
}

// MARK: - Solar

private struct SolarCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var rotation: Double = 0
    @State private var pulse = false
    @State private var haze = false

    var body: some View {
        let boost: Double = isActive ? 1.6 : 1.0
        let op = (isDark ? 0.40 : 0.20) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:1.0, green:0.80, blue:0.10).opacity(isDark ? 0.16 : 0.08), .clear],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.18), .clear],
                        center: UnitPoint(x: 0.87, y: 0.0),
                        startRadius: 0, endRadius: h * 0.6
                    )
                }
                ForEach(0..<10, id: \.self) { i in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.yellow.opacity(op * 0.80), Color(red:1,green:0.65,blue:0).opacity(op * 0.35)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 2.5, height: 12 + CGFloat(i % 3) * 8)
                        .rotationEffect(.degrees(rotation + Double(i) * 36))
                        .position(x: w * 0.87, y: 20)
                }
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.yellow.opacity(pulse ? op * 1.0 : op * 0.45), .clear],
                        center: .center, startRadius: 0, endRadius: 14
                    ))
                    .frame(width: 22, height: 22)
                    .blur(radius: 4)
                    .position(x: w * 0.87, y: 20)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
                if isActive {
                    ForEach(0..<3, id: \.self) { i in
                        let hys: [CGFloat] = [h * 0.40, h * 0.60, h * 0.75]
                        Circle()
                            .fill(Color.yellow.opacity(haze ? (isDark ? 0.08 : 0.04) : 0.01))
                            .frame(width: 28 + CGFloat(i) * 10, height: 8)
                            .blur(radius: 5)
                            .position(x: w * 0.5, y: hys[i])
                            .animation(.easeInOut(duration: 3.5 + Double(i) * 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.4), value: haze)
                    }
                }
            }
        }
        .onAppear {
            pulse = true
            haze  = true
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - Kirschblüte

private struct KirschCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var drift = false
    @State private var bloom = false

    private let petals: [(CGFloat, CGFloat, CGFloat, Double, Double, Double)] = [
        (0.87, 0.16, 13, 3.0,  18.0, 0.0),
        (0.76, 0.44, 10, 2.6, -14.0, 0.8),
        (0.93, 0.60,  9, 3.4,  20.0, 1.5),
        (0.80, 0.76, 11, 2.8, -16.0, 0.4),
        (0.95, 0.36,  8, 3.2,  12.0, 1.1),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.55 : 0.32) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:1.0, green:0.72, blue:0.80).opacity(isDark ? 0.16 : 0.08), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.pink.opacity(0.16), .clear],
                        center: .topTrailing, startRadius: 0, endRadius: h * 0.70
                    )
                }
                ForEach(petals.indices, id: \.self) { i in
                    let (x, y, sz, spd, ang, dly) = petals[i]
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red:1.0, green:0.82, blue:0.88).opacity(op),
                                     Color.pink.opacity(op * 0.65)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: sz * 0.60, height: sz)
                        .rotationEffect(.degrees(drift ? ang : -ang * 0.6))
                        .animation(.easeInOut(duration: spd).repeatForever(autoreverses: true).delay(dly), value: drift)
                        .position(x: w * x, y: h * y)
                }
                Circle()
                    .fill(Color.pink.opacity(bloom ? (isDark ? 0.14 : 0.08) : 0.02))
                    .frame(width: 32, height: 32)
                    .blur(radius: 10)
                    .position(x: w * 0.88, y: h * 0.22)
                    .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: bloom)
            }
        }
        .onAppear { drift = true; bloom = true }
    }
}

// MARK: - Vulkan

private struct VulkanCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var glow   = false
    @State private var flicker = false

    var body: some View {
        let boost: Double = isActive ? 1.6 : 1.0
        let op = (isDark ? 0.52 : 0.28) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.72, green:0.05, blue:0.0).opacity(isDark ? 0.24 : 0.12),
                             Color.orange.opacity(isDark ? 0.12 : 0.06), .clear],
                    startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.45)
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.red.opacity(0.20), .clear],
                        center: .bottom, startRadius: 0, endRadius: h * 0.55
                    )
                }
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red:1,green:0.45,blue:0).opacity(glow ? op * 0.90 : op * 0.28), .clear],
                        center: .center, startRadius: 0, endRadius: 18
                    ))
                    .frame(width: 28, height: 28)
                    .blur(radius: 6)
                    .position(x: w * 0.86, y: h * 0.72)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glow)
                let embers: [(CGFloat, CGFloat, CGFloat, Double, Double)] = [
                    (0.80, 0.52, 10, 2.2, 0.0),
                    (0.90, 0.38,  7, 1.8, 0.5),
                    (0.76, 0.62,  8, 2.6, 0.9),
                    (0.93, 0.58,  6, 1.4, 0.3),
                ]
                ForEach(embers.indices, id: \.self) { i in
                    let (ex, ey, esz, espd, edl) = embers[i]
                    Circle()
                        .fill(Color(red:1, green:0.45 + CGFloat(i) * 0.08, blue:0)
                            .opacity(glow ? op * 0.65 : op * 0.18))
                        .frame(width: esz, height: esz)
                        .blur(radius: 3)
                        .position(x: w * ex, y: h * ey)
                        .animation(.easeInOut(duration: espd).repeatForever(autoreverses: true).delay(edl), value: glow)
                }
                Image(systemName: "flame.fill")
                    .font(.system(size: isActive ? 18 : 14))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.orange.opacity(flicker ? op * 1.1 : op * 0.55),
                                 Color.red.opacity(flicker ? op * 0.70 : op * 0.30)],
                        startPoint: .bottom, endPoint: .top
                    ))
                    .scaleEffect(flicker ? 1.08 : 0.92)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: flicker)
                    .position(x: w * 0.86, y: h * 0.60)
            }
        }
        .onAppear { glow = true; flicker = true }
    }
}

// MARK: - Eis

private struct EisCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var shimmer   = false
    @State private var rotation: Double = 0

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.55 : 0.30) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.65, green:0.92, blue:1.0).opacity(isDark ? 0.16 : 0.09), .clear],
                    startPoint: .topTrailing, endPoint: UnitPoint(x: 0.3, y: 0.6)
                )
                LinearGradient(
                    colors: [Color.white.opacity(isDark ? 0.08 : 0.04), .clear],
                    startPoint: .topLeading, endPoint: .center
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.14), .clear],
                        center: .topTrailing, startRadius: 0, endRadius: h * 0.65
                    )
                }
                Image(systemName: "snowflake")
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundStyle(Color.cyan.opacity(shimmer ? op : op * 0.38))
                    .rotationEffect(.degrees(rotation))
                    .position(x: w * 0.89, y: 22)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: shimmer)
                let miniFlakes: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.75, 0.48, 9), (0.83, 0.70, 7), (0.93, 0.38, 6),
                ]
                ForEach(miniFlakes.indices, id: \.self) { i in
                    let (fx, fy, fsz) = miniFlakes[i]
                    Image(systemName: "snowflake")
                        .font(.system(size: fsz, weight: .ultraLight))
                        .foregroundStyle(Color.white.opacity(shimmer ? op * 0.75 : op * 0.25))
                        .position(x: w * fx, y: h * fy)
                        .animation(.easeInOut(duration: 2.5 + Double(i) * 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.5), value: shimmer)
                }
                ForEach(0..<4, id: \.self) { i in
                    let fxs: [CGFloat] = [0.20, 0.45, 0.62, 0.80]
                    let fys: [CGFloat] = [h * 0.85, h * 0.90, h * 0.82, h * 0.88]
                    Capsule()
                        .fill(Color.white.opacity(shimmer ? (isDark ? 0.18 : 0.10) : 0.03))
                        .frame(width: 28 + CGFloat(i) * 6, height: 2)
                        .position(x: w * fxs[i], y: fys[i])
                        .animation(.easeInOut(duration: 2.8 + Double(i) * 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.3), value: shimmer)
                }
            }
        }
        .onAppear {
            shimmer = true
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - Herbst

private struct HerbstCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var sway  = false
    @State private var glow  = false

    private let leafData: [(CGFloat, CGFloat, CGFloat, Double, Double, Double, Color)] = [
        (0.88, 0.18, 17, 2.8,  9.0, 0.0, .orange),
        (0.79, 0.50, 12, 2.5, -7.5, 0.5, Color(red:0.82, green:0.32, blue:0.04)),
        (0.93, 0.62,  9, 3.0,  6.5, 1.0, Color(red:1.0,  green:0.52, blue:0.0)),
        (0.84, 0.78,  7, 2.3, -5.5, 1.5, Color(red:0.90, green:0.65, blue:0.0)),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.52 : 0.28) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.82, green:0.38, blue:0.06).opacity(isDark ? 0.20 : 0.10), .clear],
                    startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.48)
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.orange.opacity(0.14), .clear],
                        center: .bottomTrailing, startRadius: 0, endRadius: h * 0.65
                    )
                }
                ForEach(leafData.indices, id: \.self) { i in
                    let (x, y, sz, spd, ang, dly, clr) = leafData[i]
                    Image(systemName: "leaf.fill")
                        .font(.system(size: sz))
                        .foregroundStyle(clr.opacity(op))
                        .rotationEffect(.degrees(sway ? ang : -ang * 0.7))
                        .animation(.easeInOut(duration: spd).repeatForever(autoreverses: true).delay(dly), value: sway)
                        .position(x: w * x, y: h * y)
                }
                Circle()
                    .fill(Color(red:1.0, green:0.60, blue:0.0).opacity(glow ? (isDark ? 0.18 : 0.10) : 0.02))
                    .frame(width: 36, height: 36)
                    .blur(radius: 12)
                    .position(x: w * 0.3, y: h * 0.5)
                    .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: glow)
            }
        }
        .onAppear { sway = true; glow = true }
    }
}

// MARK: - Lavendel

private struct LavendelCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var sparkle = false
    @State private var mist    = false

    private let dots: [(CGFloat, CGFloat, CGFloat, Double, Double)] = [
        (0.82, 0.14, 12, 0.30, 0.0),
        (0.92, 0.38,  9, 0.22, 0.6),
        (0.75, 0.56, 11, 0.28, 1.2),
        (0.88, 0.72,  8, 0.18, 0.3),
        (0.96, 0.26,  7, 0.20, 1.6),
        (0.70, 0.80, 10, 0.25, 0.9),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 1.0 : 0.65) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.55, green:0.20, blue:0.80).opacity(isDark ? 0.18 : 0.08), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                if isActive {
                    RadialGradient(
                        colors: [Color.purple.opacity(0.16), .clear],
                        center: .topTrailing, startRadius: 0, endRadius: h * 0.70
                    )
                }
                Ellipse()
                    .fill(Color(red:0.65, green:0.35, blue:0.90)
                        .opacity(mist ? (isDark ? 0.12 : 0.06) : 0.02))
                    .frame(width: w * 0.55, height: 30)
                    .blur(radius: 12)
                    .position(x: w * 0.4, y: h * 0.5)
                    .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: mist)
                ForEach(dots.indices, id: \.self) { i in
                    let (x, y, sz, minOp, dly) = dots[i]
                    Image(systemName: i % 2 == 0 ? "sparkle" : "sparkles")
                        .font(.system(size: sz))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red:0.82, green:0.52, blue:1.0).opacity(sparkle ? min(minOp * 3.0 * op, 1.0) : minOp * op),
                                         Color(red:0.60, green:0.30, blue:0.90).opacity(sparkle ? min(minOp * 2.0 * op, 0.8) : minOp * op * 0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(sparkle ? 1.08 : 0.94)
                        .animation(.easeInOut(duration: 1.8 + Double(i) * 0.4).repeatForever(autoreverses: true).delay(dly), value: sparkle)
                        .position(x: w * x, y: h * y)
                }
            }
        }
        .onAppear { sparkle = true; mist = true }
    }
}

// MARK: - Sonnenuntergang

private struct SunsetCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var pulse  = false
    @State private var rays   = false
    @State private var rotation: Double = 0

    var body: some View {
        let boost: Double = isActive ? 1.55 : 1.0
        let op = (isDark ? 0.46 : 0.24) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.95, green:0.38, blue:0.15).opacity(isDark ? 0.22 : 0.11), .clear],
                    startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.42)
                )
                LinearGradient(
                    colors: [.clear, Color(red:0.95, green:0.30, blue:0.55).opacity(isDark ? 0.12 : 0.06)],
                    startPoint: .bottomLeading, endPoint: .topTrailing
                )
                if isActive {
                    RadialGradient(
                        colors: [Color(red:1.0, green:0.50, blue:0.15).opacity(0.22), .clear],
                        center: UnitPoint(x: 0.86, y: 0.22),
                        startRadius: 0, endRadius: h * 0.60
                    )
                }
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red:1.0, green:0.60, blue:0.20).opacity(pulse ? op * 1.0 : op * 0.35), .clear],
                        center: .center, startRadius: 0, endRadius: 18
                    ))
                    .frame(width: 26, height: 26)
                    .blur(radius: 6)
                    .position(x: w * 0.86, y: h * 0.20)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(Color(red:1.0, green:0.62, blue:0.22)
                            .opacity(rays ? op * (0.55 - Double(i) * 0.06) : op * 0.15))
                        .frame(width: 1.5, height: 10 + CGFloat(i) * 5)
                        .rotationEffect(.degrees(rotation + Double(i) * 30))
                        .position(x: w * 0.86, y: h * 0.20)
                        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(Double(i) * 0.2), value: rays)
                }
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red:1.0, green:0.50, blue:0.20).opacity(isDark ? 0.22 : 0.11),
                                 Color.pink.opacity(isDark ? 0.12 : 0.06), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w * 0.60, height: 3)
                    .blur(radius: 2)
                    .position(x: w * 0.4, y: h * 0.38)
            }
        }
        .onAppear {
            pulse = true
            rays  = true
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - Galaxie

private struct GalaxieCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var twinkle  = false
    @State private var nebula: CGFloat = 0

    private let stars: [(CGFloat, CGFloat, CGFloat, Double, Double, Bool)] = [
        (0.87, 0.12,  9, 0.26, 0.0,  false),
        (0.93, 0.36,  6, 0.18, 0.5,  true),
        (0.78, 0.58, 11, 0.30, 1.1,  true),
        (0.91, 0.70,  5, 0.15, 0.8,  false),
        (0.96, 0.24,  7, 0.22, 1.9,  false),
        (0.74, 0.44,  8, 0.20, 0.4,  true),
    ]

    var body: some View {
        let boost: Double = isActive ? 1.50 : 1.0
        let op = (isDark ? 1.0 : 0.62) * boost
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red:0.28, green:0.08, blue:0.72).opacity(isDark ? 0.18 : 0.08), .clear],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                )
                Ellipse()
                    .fill(LinearGradient(
                        colors: [Color(red:0.55, green:0.20, blue:0.90).opacity(isDark ? 0.16 : 0.08),
                                 Color(red:0.30, green:0.10, blue:0.70).opacity(isDark ? 0.08 : 0.04),
                                 .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: w * 0.65, height: h * 0.55)
                    .blur(radius: 14)
                    .position(x: w * 0.75 + nebula, y: h * 0.45)
                    .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: nebula)
                ForEach(stars.indices, id: \.self) { i in
                    let (x, y, sz, minOp, dly, isSparkle) = stars[i]
                    Image(systemName: isSparkle ? "sparkle" : "star.fill")
                        .font(.system(size: sz, weight: .ultraLight))
                        .foregroundStyle(
                            (isSparkle ? Color(red:0.80, green:0.60, blue:1.0) : Color.white)
                                .opacity(twinkle ? min(minOp * 4.0 * op, 1.0) : minOp * op)
                        )
                        .animation(.easeInOut(duration: 1.5 + Double(i) * 0.45).repeatForever(autoreverses: true).delay(dly), value: twinkle)
                        .position(x: w * x, y: h * y)
                }
            }
        }
        .onAppear {
            twinkle = true
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) { nebula = 18 }
        }
    }
}

// MARK: - Nordlicht

private struct NordlichtCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var sway: CGFloat = 0
    @State private var glow: Double  = 0.50
    @State private var wave: CGFloat = 0

    var body: some View {
        let glowBoost: Double = isActive ? 1.6 : 1.0
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(red:0, green:0.18, blue:0.22).opacity(isDark ? 0.18 : 0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                Ellipse()
                    .fill(LinearGradient(
                        colors: [Color(red:0, green:0.95, blue:0.45).opacity((isDark ? 0.22 : 0.11) * glowBoost),
                                 Color(red:0, green:0.70, blue:0.85).opacity((isDark ? 0.14 : 0.07) * glowBoost),
                                 .clear],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 1.25, height: 40)
                    .position(x: w * 0.5 + sway, y: 14)
                    .blur(radius: 11)
                    .opacity(glow)
                Ellipse()
                    .fill(LinearGradient(
                        colors: [Color(red:0.20, green:0.75, blue:1.0).opacity((isDark ? 0.14 : 0.07) * glowBoost),
                                 .clear],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: w * 0.80, height: 24)
                    .position(x: w * 0.5 - sway * 0.5 + wave, y: 30)
                    .blur(radius: 8)
                    .opacity(glow * 0.75)
                if isActive {
                    Ellipse()
                        .fill(Color(red:0.55, green:0.20, blue:0.90)
                            .opacity((isDark ? 0.10 : 0.05) * glowBoost))
                        .frame(width: w * 0.50, height: 16)
                        .position(x: w * 0.6 + wave * 0.7, y: 44)
                        .blur(radius: 6)
                        .opacity(glow * 0.65)
                }
                LinearGradient(
                    colors: [.clear,
                             Color(red:0, green:0.80, blue:0.55).opacity((isDark ? 0.10 : 0.05) * glowBoost)],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true))              { sway = 24 }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.5))   { glow = 1.0 }
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true).delay(1.0))   { wave = -16 }
        }
    }
}

// MARK: - Aurora Decoration

struct AuroraDecorationLayer: View {
    @State private var shift: CGFloat = 0
    @State private var pulse: Double  = 0.55

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    let colors: [(Color, Color)] = [
                        (Color(red: 0.0, green: 0.9, blue: 0.8), Color(red: 0.5, green: 0.0, blue: 1.0)),
                        (Color(red: 0.9, green: 0.0, blue: 1.0), Color(red: 0.0, green: 0.9, blue: 0.8)),
                        (Color(red: 0.4, green: 0.0, blue: 1.0), Color(red: 0.0, green: 0.85, blue: 0.7)),
                        (Color(red: 0.0, green: 0.8, blue: 0.9), Color(red: 0.85, green: 0.0, blue: 0.9)),
                        (Color(red: 0.6, green: 0.0, blue: 1.0), Color(red: 0.0, green: 1.0, blue: 0.75)),
                    ]
                    let (c1, c2) = colors[i]
                    let yFrac = 0.08 + Double(i) * 0.06
                    Ellipse()
                        .fill(LinearGradient(colors: [c1.opacity(0.30), c2.opacity(0.18), .clear],
                                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: w * 1.3, height: h * 0.12)
                        .offset(x: shift * CGFloat(i % 2 == 0 ? 1 : -1) * 0.7,
                                y: h * yFrac - h * 0.15)
                        .blur(radius: 22)
                        .opacity(pulse)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true))            { shift = 30 }
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.8)) { pulse = 1.0 }
        }
    }
}

// MARK: - Obsidian Decoration

struct ObsidianDecorationLayer: View {
    @State private var shimmer: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.04, blue: 0.06).opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                ForEach(0..<8, id: \.self) { i in
                    let y = h * (0.1 + Double(i) * 0.11)
                    let angle = Double(i) * 22.5
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.0),
                                         Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.18),
                                         Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: w * 1.6, height: 1.5)
                        .rotationEffect(.degrees(angle))
                        .offset(x: (shimmer * w) - w * 0.3, y: y - h * 0.5)
                }
                RadialGradient(
                    colors: [Color(red: 0.85, green: 0.65, blue: 0.1).opacity(0.22), .clear],
                    center: .center, startRadius: 0, endRadius: min(w, h) * 0.6
                )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) { shimmer = 2.0 }
        }
    }
}

// MARK: - Nebula Decoration

struct NebulaDecorationLayer: View {
    @State private var drift: CGFloat = 0
    @State private var glow: Double   = 0.45

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                let nebulaColors: [(CGFloat, CGFloat, Color, Double)] = [
                    (0.25, 0.30, Color(red: 1.0, green: 0.15, blue: 0.6), 0.28),
                    (0.70, 0.55, Color(red: 0.45, green: 0.0, blue: 0.85), 0.22),
                    (0.50, 0.75, Color(red: 0.1, green: 0.55, blue: 1.0), 0.18),
                    (0.15, 0.65, Color(red: 0.9, green: 0.0, blue: 0.5), 0.15),
                    (0.80, 0.25, Color(red: 0.3, green: 0.0, blue: 0.9), 0.20),
                ]
                ForEach(0..<5, id: \.self) { i in
                    let (xFrac, yFrac, color, opacity) = nebulaColors[i]
                    let driftDir: CGFloat = i % 2 == 0 ? 1 : -1
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [color.opacity(opacity * glow / 0.45), .clear],
                            center: .center, startRadius: 0, endRadius: min(w, h) * 0.4
                        ))
                        .frame(width: min(w, h) * 0.75, height: min(w, h) * 0.5)
                        .position(x: w * xFrac + drift * driftDir * 14,
                                  y: h * yFrac + drift * driftDir * 8)
                        .blur(radius: 28)
                }
                ForEach(0..<60, id: \.self) { i in
                    let xPos = CGFloat(i * 127 % Int(w == 0 ? 1 : w))
                    let yPos = CGFloat(i * 83  % Int(h == 0 ? 1 : h))
                    let size = CGFloat(1 + i % 3) * 0.6
                    Circle()
                        .fill(Color.white.opacity(Double(i % 5) * 0.04 + 0.04))
                        .frame(width: size, height: size)
                        .position(x: xPos, y: yPos)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true))            { drift = 1.0 }
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true).delay(1.0)) { glow = 1.0 }
        }
    }
}

// MARK: - Aurora Card Deco

private struct AuroraCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var shift: CGFloat = 0
    @State private var glow: Double   = 0.55

    var body: some View {
        let boost: Double = isActive ? 1.6 : 1.0
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.0, green: 0.15, blue: 0.18).opacity(isDark ? 0.20 : 0.08), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                Ellipse()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.0, green: 0.9, blue: 0.8).opacity((isDark ? 0.28 : 0.14) * boost * glow),
                                 Color(red: 0.5, green: 0.0, blue: 1.0).opacity((isDark ? 0.18 : 0.09) * boost * glow),
                                 .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w * 1.2, height: 36)
                    .position(x: w * 0.5 + shift, y: 12)
                    .blur(radius: 12)
                Ellipse()
                    .fill(Color(red: 0.9, green: 0.0, blue: 1.0).opacity((isDark ? 0.16 : 0.08) * boost * glow))
                    .frame(width: w * 0.7, height: 20)
                    .position(x: w * 0.5 - shift * 0.6, y: 28)
                    .blur(radius: 9)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true))            { shift = 20 }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(0.5)) { glow = 1.0 }
        }
    }
}

// MARK: - Obsidian Card Deco

private struct ObsidianCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var shimmer: CGFloat = -1.0

    var body: some View {
        let boost: Double = isActive ? 1.6 : 1.0
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.05, blue: 0.08).opacity(isDark ? 0.30 : 0.12), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.clear,
                                 Color(red: 1.0, green: 0.85, blue: 0.3).opacity((isDark ? 0.40 : 0.22) * boost),
                                 Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: w * 0.55, height: 44)
                    .offset(x: shimmer * w, y: -6)
                    .blur(radius: 6)
                    .clipped()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) { shimmer = 1.8 }
        }
    }
}

// MARK: - Nebula Card Deco

private struct NebulaCardDeco: View {
    let isDark: Bool
    let isActive: Bool
    @State private var glow: Double = 0.50

    var body: some View {
        let boost: Double = isActive ? 1.6 : 1.0
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.0, blue: 0.18).opacity(isDark ? 0.22 : 0.10), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                Ellipse()
                    .fill(Color(red: 1.0, green: 0.15, blue: 0.6).opacity((isDark ? 0.22 : 0.11) * boost * glow))
                    .frame(width: w * 0.6, height: 30)
                    .position(x: w * 0.3, y: 14)
                    .blur(radius: 13)
                Ellipse()
                    .fill(Color(red: 0.45, green: 0.0, blue: 0.85).opacity((isDark ? 0.18 : 0.09) * boost * glow))
                    .frame(width: w * 0.55, height: 26)
                    .position(x: w * 0.72, y: 20)
                    .blur(radius: 10)
                Ellipse()
                    .fill(Color(red: 0.1, green: 0.55, blue: 1.0).opacity((isDark ? 0.14 : 0.07) * boost * glow))
                    .frame(width: w * 0.40, height: 18)
                    .position(x: w * 0.5, y: 32)
                    .blur(radius: 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { glow = 1.0 }
        }
    }
}
