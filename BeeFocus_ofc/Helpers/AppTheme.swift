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

    private let waveThemes: [String] = ["", "Wald", "Eis", "Nordlicht", "Galaxie", "Vulkan",
                                        "Herbst", "Nacht", "Solar", "Kirschblüte", "Lavendel", "Sonnenuntergang"]

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

            if aktivesThema == "Wald"           { WaldDecorationLayer().transition(.opacity) }
            if aktivesThema == "Eis"            { EisDecorationLayer().transition(.opacity) }
            if aktivesThema == "Nordlicht"      { NordlichtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Galaxie"        { GalaxieDecorationLayer().transition(.opacity) }
            if aktivesThema == "Vulkan"         { VulkanDecorationLayer().transition(.opacity) }
            if aktivesThema == "Herbst"         { HerbstDecorationLayer().transition(.opacity) }
            if aktivesThema == "Nacht"          { NachtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Solar"          { SolarDecorationLayer().transition(.opacity) }
            if aktivesThema == "Kirschblüte"    { KirschblueteDecorationLayer().transition(.opacity) }
            if aktivesThema == "Lavendel"       { LavendelDecorationLayer().transition(.opacity) }
            if aktivesThema == "Sonnenuntergang"{ SonnenuntergangDecorationLayer().transition(.opacity) }
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
    case "Ozean":          return (.cyan, .teal, Color(red: 0.0, green: 0.6, blue: 0.9))
    case "Wald":           return (.green, Color(red: 0.1, green: 0.5, blue: 0.2), .mint)
    case "Nacht":          return (.indigo, Color(red: 0.1, green: 0.0, blue: 0.3), .purple)
    case "Solar":          return (.orange, .yellow, Color(red: 1.0, green: 0.4, blue: 0.0))
    case "Kirschblüte":    return (.pink, Color(red: 1.0, green: 0.4, blue: 0.6), .red)
    case "Vulkan":         return (.red, Color(red: 0.8, green: 0.1, blue: 0.0), .orange)
    case "Eis":            return (Color(red: 0.6, green: 0.9, blue: 1.0), .cyan, .white)
    case "Herbst":         return (Color(red: 0.8, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.3, blue: 0.05), .orange)
    case "Lavendel":       return (.purple, Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.85, green: 0.7, blue: 1.0))
    case "Sonnenuntergang":return (Color(red: 1.0, green: 0.4, blue: 0.2), .pink, Color(red: 1.0, green: 0.65, blue: 0.0))
    case "Galaxie":        return (Color(red: 0.62, green: 0.32, blue: 1.0), Color(red: 0.42, green: 0.12, blue: 0.95), Color(red: 0.80, green: 0.58, blue: 1.0))
    case "Nordlicht":      return (.green, Color(red: 0.0, green: 0.8, blue: 0.6), Color(red: 0.2, green: 0.4, blue: 1.0))
    default:               return (.purple, .blue, Color(red: 0.4, green: 0.2, blue: 0.9))
    }
}
