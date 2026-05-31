import AVFoundation
import SwiftUI

enum AmbientSound: String, CaseIterable, Identifiable {
    case off            = "off"
    case whiteNoise     = "white"
    case brownNoise     = "brown"
    case binauralFocus  = "binaural_focus"
    case binauralRelax  = "binaural_relax"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:           return "Stille"
        case .whiteNoise:    return "Weißes Rauschen"
        case .brownNoise:    return "Ozean-Wellen"
        case .binauralFocus: return "Fokus-Beats"
        case .binauralRelax: return "Relax-Beats"
        }
    }

    var subtitle: String {
        switch self {
        case .off:           return "Kein Sound"
        case .whiteNoise:    return "Gleichmäßig, ablenkungsfrei"
        case .brownNoise:    return "Tiefes, warmes Rauschen"
        case .binauralFocus: return "40 Hz Gamma · Konzentration"
        case .binauralRelax: return "6 Hz Theta · Entspannung"
        }
    }

    var icon: String {
        switch self {
        case .off:           return "moon.stars.fill"
        case .whiteNoise:    return "wind"
        case .brownNoise:    return "water.waves"
        case .binauralFocus: return "waveform.path"
        case .binauralRelax: return "leaf.fill"
        }
    }

    var color: Color {
        switch self {
        case .off:           return .gray
        case .whiteNoise:    return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .brownNoise:    return Color(red: 0.2, green: 0.75, blue: 0.85)
        case .binauralFocus: return Color(red: 0.65, green: 0.3, blue: 1.0)
        case .binauralRelax: return Color(red: 0.2, green: 0.8, blue: 0.5)
        }
    }

    var needsHeadphones: Bool {
        self == .binauralFocus || self == .binauralRelax
    }
}

final class AmbientSoundManager: ObservableObject {
    static let shared = AmbientSoundManager()

    @Published var currentSound: AmbientSound = .off
    @Published var volume: Float = 0.65
    @Published var isPlaying: Bool = false

    private var engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44100

    // Audio-thread-only state (written only from audio callback)
    private var phaseL: Float = 0
    private var phaseR: Float = 0
    private var brownPrev: Float = 0

    private init() {
        setupSession()
    }

    private func setupSession() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
            try s.setActive(true)
        } catch {
            print("AmbientSound session error: \(error)")
        }
    }

    func play(_ sound: AmbientSound) {
        teardown()
        currentSound = sound
        guard sound != .off else {
            isPlaying = false
            return
        }
        buildEngine(sound: sound)
        do {
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
            print("AmbientSound engine error: \(error)")
        }
    }

    func stop() {
        teardown()
        currentSound = .off
    }

    func toggle(_ sound: AmbientSound) {
        if currentSound == sound && isPlaying { stop() } else { play(sound) }
    }

    func updateVolume() {
        guard isPlaying else { return }
        engine.mainMixerNode.outputVolume = volume
    }

    private func teardown() {
        engine.stop()
        if let node = sourceNode {
            engine.detach(node)
        }
        sourceNode = nil
        isPlaying = false
    }

    private func buildEngine(sound: AmbientSound) {
        engine = AVAudioEngine()
        phaseL = 0; phaseR = 0; brownPrev = 0

        let sr = Float(sampleRate)
        let initialVol = volume

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let lPtr = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let rPtr = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

            for i in 0..<Int(frameCount) {
                var l: Float = 0
                var r: Float = 0

                switch sound {
                case .off:
                    break

                case .whiteNoise:
                    let s = Float.random(in: -1...1) * 0.85
                    l = s; r = s

                case .brownNoise:
                    // Voss-McCartney pink/brown noise approximation
                    let white = Float.random(in: -1...1)
                    self.brownPrev = (self.brownPrev + 0.018 * white) / 1.018
                    let s = min(max(self.brownPrev * 4.0, -1.0), 1.0)
                    l = s; r = s

                case .binauralFocus:
                    // 40 Hz Gamma: L=200 Hz, R=240 Hz
                    l = sin(self.phaseL) * 0.8
                    r = sin(self.phaseR) * 0.8
                    self.phaseL += 2 * .pi * 200 / sr
                    self.phaseR += 2 * .pi * 240 / sr
                    if self.phaseL > 2 * .pi { self.phaseL -= 2 * .pi }
                    if self.phaseR > 2 * .pi { self.phaseR -= 2 * .pi }

                case .binauralRelax:
                    // 6 Hz Theta: L=200 Hz, R=206 Hz
                    l = sin(self.phaseL) * 0.75
                    r = sin(self.phaseR) * 0.75
                    self.phaseL += 2 * .pi * 200 / sr
                    self.phaseR += 2 * .pi * 206 / sr
                    if self.phaseL > 2 * .pi { self.phaseL -= 2 * .pi }
                    if self.phaseR > 2 * .pi { self.phaseR -= 2 * .pi }
                }

                lPtr[i] = l
                rPtr[i] = r
            }
            return noErr
        }

        sourceNode = node
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = initialVol
    }
}
