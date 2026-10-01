//
//  BeeVoiceSheet.swift
//  BeeFocus_ofc
//
//  "Bee Voice": Reden statt tippen. Der Nutzer spricht frei, das On-Device-
//  Modell führt die passenden Aktionen aus und bestätigt sie – auf Wunsch
//  auch vorgelesen.
//

import SwiftUI

@available(iOS 26.0, *)
struct BeeVoiceSheet: View {
    @StateObject private var assistant = BeeAssistant()
    @ObservedObject private var availability = AIAvailability.shared
    @ObservedObject private var speech = SpeechManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var typedCommand = ""
    @State private var showExamples = true
    @FocusState private var inputFocused: Bool

    private var accent: Color { AIAccent.color(for: aktivesThema) }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                if availability.isAvailable {
                    content
                } else {
                    ScrollView {
                        AIUnavailableCard()
                            .padding(20)
                    }
                }
            }
            .navigationTitle("Bee Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "brain_close")) {
                        assistant.cancel()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        assistant.speakReplies.toggle()
                        if !assistant.speakReplies { speech.stopSpeaking() }
                    } label: {
                        Image(systemName: assistant.speakReplies ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundStyle(assistant.speakReplies ? accent : .white.opacity(0.4))
                    }
                }
            }
            .onAppear {
                assistant.requestPermissions()
                availability.refresh()
                AIAvailability.shared.prewarm()
            }
            .onDisappear { assistant.cancel() }
        }
    }

    // MARK: - Inhalt

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if showExamples && assistant.transcript.isEmpty && assistant.reply.isEmpty {
                        examplesCard
                    }

                    if !assistant.transcript.isEmpty {
                        transcriptCard
                    }

                    if case .failed(let message) = assistant.phase {
                        AIErrorRow(message: message) {
                            assistant.submit(assistant.transcript)
                        }
                    }

                    if assistant.phase == .thinking {
                        AIThinkingIndicator(label: AIL("ai_voice_thinking"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    if !assistant.reply.isEmpty {
                        replyCard
                    }

                    if !assistant.log.entries.isEmpty {
                        actionsCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }

            micArea
        }
    }

    // MARK: - Beispiele

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AIBadge(text: "Apple Intelligence")
                Spacer()
                Button {
                    withAnimation { showExamples = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Text(AIL("ai_voice_examples_title"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(exampleKeys, id: \.self) { key in
                    Button {
                        let text = AIL(key)
                        typedCommand = ""
                        assistant.submit(text)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 10))
                                .foregroundStyle(accent)
                            Text(AIL(key))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .aiGlowBorder(cornerRadius: 18, active: false)
    }

    private var exampleKeys: [String] {
        ["ai_voice_example_1", "ai_voice_example_2", "ai_voice_example_3", "ai_voice_example_4"]
    }

    // MARK: - Karten

    private var transcriptCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 2)
            Text(assistant.transcript)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var replyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(accent)
                .padding(.top, 2)
            Text(assistant.reply)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .aiGlowBorder(cornerRadius: 16, lineWidth: 1, active: assistant.phase == .answering)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AIL("ai_voice_actions_title"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if assistant.log.canUndo {
                    Button {
                        withAnimation { assistant.undoLastRun() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text(AIL("ai_undo"))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            ForEach(assistant.log.entries) { entry in
                HStack(spacing: 10) {
                    Image(systemName: entry.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(accent)
                        .frame(width: 20)
                    Text(entry.text)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    // MARK: - Mikrofon und Eingabe

    private var micArea: some View {
        VStack(spacing: 12) {
            if assistant.phase == .listening {
                AIWaveform(level: assistant.audioLevel, isActive: true)
                    .padding(.horizontal, 30)
                    .onReceive(of: speech.liveText) {
                        assistant.syncLiveTranscript()
                    }
            }

            HStack(spacing: 10) {
                TextField(AIL("ai_voice_placeholder"), text: $typedCommand, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.08))
                    )
                    .onSubmit(submitTyped)
                    .disabled(assistant.phase == .listening)

                if !typedCommand.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: submitTyped) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AIPalette.gradient, in: Circle())
                    }
                    .disabled(assistant.isBusy)
                } else {
                    micButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(.black.opacity(0.25))
    }

    private var micButton: some View {
        Button {
            switch assistant.phase {
            case .listening:
                assistant.stopListeningAndSubmit()
            default:
                if assistant.isBusy {
                    assistant.cancel()
                } else {
                    withAnimation { showExamples = false }
                    inputFocused = false
                    assistant.startListening()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(assistant.phase == .listening ? AnyShapeStyle(Color.red) : AnyShapeStyle(AIPalette.gradient))
                    .frame(width: 52, height: 52)

                Image(systemName: micSymbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: (assistant.phase == .listening ? Color.red : accent).opacity(0.45), radius: 12, y: 3)
            .scaleEffect(assistant.phase == .listening ? 1.06 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: assistant.phase)
        }
    }

    private var micSymbol: String {
        switch assistant.phase {
        case .listening:            return "stop.fill"
        case .thinking, .answering: return "xmark"
        default:                    return "mic.fill"
        }
    }

    private func submitTyped() {
        let text = typedCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        typedCommand = ""
        inputFocused = false
        withAnimation { showExamples = false }
        assistant.submit(text)
    }
}

// MARK: - Hilfsmodifier

private extension View {
    /// Führt eine Aktion aus, wenn sich ein beobachteter Wert ändert.
    func onReceive(of value: String, perform action: @escaping () -> Void) -> some View {
        onChange(of: value) { _, _ in action() }
    }
}
