import Speech
import AVFoundation

@MainActor
final class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()

    // MARK: - STT
    @Published var isRecording = false
    @Published var liveText = ""
    @Published var sttAuthorized = false

    // MARK: - TTS
    @Published var isSpeaking = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    // Streaming TTS buffer
    private var streamBuffer = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        sttAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Permissions

    func requestPermissions() {
        AVAudioApplication.requestRecordPermission { _ in }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in self?.sttAuthorized = status == .authorized }
        }
    }

    // MARK: - STT

    func startRecording(languageCode: String = "de-DE") {
        guard !isRecording else { return }
        recognitionTask?.cancel()
        recognitionTask = nil
        liveText = ""

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
        guard speechRecognizer?.isAvailable == true else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else { return }
        req.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result { self?.liveText = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true { self?.stopRecording() }
            }
        }

        let inputNode = audioEngine.inputNode
        inputNode.installTap(onBus: 0, bufferSize: 1024,
                             format: inputNode.outputFormat(forBus: 0)) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch { return }
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - TTS: Streaming (satzweise während Stream)

    func resetStream() {
        streamBuffer = ""
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func appendToStream(_ newText: String, languageCode: String) {
        streamBuffer += newText
        flushSentences(languageCode: languageCode)
    }

    func finishStream(languageCode: String) {
        let trimmed = streamBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { enqueue(trimmed, languageCode: languageCode) }
        streamBuffer = ""
    }

    private func flushSentences(languageCode: String) {
        let terminators: [Character] = [".", "!", "?", "\n"]
        var cutIndex = streamBuffer.startIndex

        for idx in streamBuffer.indices {
            if terminators.contains(streamBuffer[idx]) {
                cutIndex = streamBuffer.index(after: idx)
            }
        }

        guard cutIndex > streamBuffer.startIndex else { return }
        let sentence = String(streamBuffer[..<cutIndex])
        streamBuffer = String(streamBuffer[cutIndex...])
        enqueue(sentence, languageCode: languageCode)
    }

    private func enqueue(_ text: String, languageCode: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if !synthesizer.isSpeaking {
            activatePlaybackSession()
        }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.voice = bestMaleVoice(languageCode: languageCode)
        utterance.rate = 0.54
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.04
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    // MARK: - TTS: Einmalig (manueller Speaker-Button)

    func speak(_ text: String, languageCode: String = "de-DE") {
        synthesizer.stopSpeaking(at: .immediate)
        activatePlaybackSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestMaleVoice(languageCode: languageCode)
        utterance.rate = 0.54
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        streamBuffer = ""
    }

    // MARK: - Helpers

    private func activatePlaybackSession() {
        try? AVAudioSession.sharedInstance()
            .setCategory(.playback, mode: .default, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func bestMaleVoice(languageCode: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(languageCode.prefix(2))
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) && $0.gender == .male }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
        return voices.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = synthesizer.isSpeaking }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
