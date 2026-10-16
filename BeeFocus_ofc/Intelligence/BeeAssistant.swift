//
//  BeeAssistant.swift
//  BeeFocus_ofc
//
//  "Bee Voice": Der sprachgesteuerte Assistent. Nimmt gesprochene oder
//  getippte Befehle, lässt das On-Device-Modell die passenden Werkzeuge
//  aufrufen und liest die Bestätigung vor.
//

import Combine
import Foundation
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
@MainActor
final class BeeAssistant: ObservableObject {

    enum Phase: Equatable {
        case idle
        case listening
        case thinking
        case answering
        case done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// Live-Transkript während des Sprechens bzw. der getippte Befehl.
    @Published var transcript: String = ""
    /// Antwort des Assistenten, während sie eintrifft.
    @Published private(set) var reply: String = ""
    /// Soll die Antwort vorgelesen werden?
    @AppStorage("aiSpeakReplies") var speakReplies: Bool = true

    let log = AIActionLog()

    private let speech = SpeechManager.shared
    private var session: LanguageModelSession?
    private var task: Task<Void, Never>?
    /// Das Protokoll ist ein eigenes ObservableObject – seine Änderungen
    /// müssen hier weitergemeldet werden, sonst bemerkt die Ansicht eine neue
    /// Aktion nur zufällig, wenn sich gleichzeitig Antwort oder Phase ändern.
    private var logObserver: AnyCancellable?

    init() {
        logObserver = log.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var isBusy: Bool { phase == .thinking || phase == .answering }

    private var languageCode: String {
        switch LocalizationManager.shared.currentLanguageCode {
        case "en": return "en-US"
        case "fr": return "fr-FR"
        case "es": return "es-ES"
        default:   return "de-DE"
        }
    }

    // MARK: - Aufnahme

    func requestPermissions() {
        speech.requestPermissions()
    }

    func startListening() {
        guard AIAvailability.shared.isAvailable else {
            phase = .failed(AIAvailability.shared.message)
            return
        }
        log.reset()
        reply = ""
        transcript = ""
        speech.stopSpeaking()
        // Der Nutzer darf länger und mit Pausen sprechen.
        speech.autoStopOnFinal = false
        speech.startRecording(languageCode: languageCode)
        phase = .listening
    }

    /// Beendet die Aufnahme und schickt das Transkript ans Modell.
    func stopListeningAndSubmit() {
        guard phase == .listening else { return }
        speech.stopRecording()
        let text = speech.liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = text
        guard !text.isEmpty else {
            phase = .idle
            return
        }
        submit(text)
    }

    func cancelListening() {
        speech.stopRecording()
        phase = .idle
    }

    /// Spiegelt das Live-Transkript in die UI, solange aufgenommen wird.
    func syncLiveTranscript() {
        guard phase == .listening else { return }
        transcript = speech.liveText
    }

    var audioLevel: Double { speech.audioLevel }

    // MARK: - Ausführung

    func submit(_ command: String) {
        let text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard AIAvailability.shared.isAvailable else {
            phase = .failed(AIAvailability.shared.message)
            return
        }

        task?.cancel()
        transcript = text
        reply = ""
        log.reset()
        phase = .thinking

        task = Task { [weak self] in
            guard let self else { return }
            await self.run(command: text)
        }
    }

    private func run(command: String) async {
        // Für jeden Befehl eine frische Session: die Werkzeuge schreiben in ein
        // neues Protokoll, und der Kontext ist immer aktuell.
        let tools = BeeAIToolbox.all(log: log)
        let context = AIContext.assistantContext
        let session = LanguageModelSession(tools: tools) {
            BeeAIPrompts.assistantInstructions
            context
        }
        self.session = session
        speech.stopSpeaking()

        do {
            // Bewusst ohne Streaming: Erst wenn der Werkzeug-Durchlauf fertig
            // ist, steht fest, was wirklich passiert ist. Nur das wird
            // angezeigt und vorgelesen – und nicht eine Ankündigung, die das
            // Modell danach doch nicht einlöst.
            let response = try await session.respond(
                to: command,
                options: GenerationOptions(temperature: 0.3)
            )
            if Task.isCancelled { return }
            var text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // Hat das Modell kein Werkzeug aufgerufen, obwohl eine Aufgabe
            // entstehen sollte, legt der Parser sie an – derselbe Weg wie bei
            // "Schnell erfassen". Sonst bliebe nur eine Antwort, die etwas
            // bestätigt, was nie passiert ist.
            if log.entries.isEmpty, BeeAssistantFallback.looksLikeTodoRequest(command) {
                let created = BeeAssistantFallback.createTodos(from: command, log: log)
                if !created.isEmpty {
                    text = created.joined(separator: ". ") + "."
                }
            } else if BeeAssistantFallback.looksLikeTodoRequest(command) {
                // Das Modell hat angelegt – aber vielleicht nicht alles. Nennt der
                // Nutzer drei Vorhaben und es ruft das Werkzeug nur einmal auf,
                // wird der Rest hier nachgetragen.
                let added = BeeAssistantFallback.createMissingTodos(from: command, log: log)
                if !added.isEmpty {
                    text += (text.isEmpty ? "" : " ") + added.joined(separator: ". ") + "."
                }
            }

            // Kein Text zurück: Protokoll als Antwort nutzen.
            if text.isEmpty {
                text = log.entries.isEmpty
                    ? AIL("ai_voice_no_action")
                    : log.entries.map(\.text).joined(separator: ". ") + "."
            }

            reply = text
            phase = .done
            if speakReplies { speech.speak(text, languageCode: languageCode) }
        } catch is CancellationError {
            phase = .idle
        } catch {
            phase = .failed(AIErrorText.describe(error))
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        speech.stopSpeaking()
        speech.stopRecording()
        phase = .idle
    }

    func reset() {
        cancel()
        transcript = ""
        reply = ""
        log.reset()
    }

    func undoLastRun() {
        log.undoAll()
        reply = AIL("ai_voice_undone")
    }
}
