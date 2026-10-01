//
//  AIAvailability.swift
//  BeeFocus_ofc
//
//  Zentrale Verfügbarkeitsprüfung für Apple Intelligence (Foundation Models).
//

import Foundation
import FoundationModels
import SwiftUI

/// Beobachtbarer Wrapper um `SystemLanguageModel`, damit die UI auf
/// Verfügbarkeitsänderungen reagieren kann (z. B. Modell wird gerade geladen).
@available(iOS 26.0, *)
@MainActor
final class AIAvailability: ObservableObject {
    static let shared = AIAvailability()

    enum State: Equatable {
        case available
        case deviceNotEligible
        case notEnabled
        case modelNotReady

        var isAvailable: Bool { self == .available }
    }

    @Published private(set) var state: State = .modelNotReady

    private let model = SystemLanguageModel.default
    private var pollTask: Task<Void, Never>?

    private init() {
        refresh()
    }

    var isAvailable: Bool { state.isAvailable }

    func refresh() {
        switch model.availability {
        case .available:
            state = .available
            pollTask?.cancel()
            pollTask = nil
        case .unavailable(.deviceNotEligible):
            state = .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            state = .notEnabled
        case .unavailable(.modelNotReady):
            state = .modelNotReady
            startPollingIfNeeded()
        @unknown default:
            state = .modelNotReady
        }
    }

    /// Lädt das Modell im Voraus in den Speicher, damit die erste Antwort schnell kommt.
    func prewarm() {
        guard isAvailable else { return }
        let session = LanguageModelSession(instructions: BeeAIPrompts.assistantInstructions)
        session.prewarm()
    }

    /// Solange das Modell noch heruntergeladen wird, in Intervallen neu prüfen.
    private func startPollingIfNeeded() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(for: .seconds(15))
                if Task.isCancelled { return }
                guard let self else { return }
                if case .available = self.model.availability {
                    self.state = .available
                    self.pollTask = nil
                    return
                }
            }
            self?.pollTask = nil
        }
    }

    // MARK: - Nutzertexte

    var headline: String {
        switch state {
        case .available:      return AIL("ai_state_available_title")
        case .deviceNotEligible: return AIL("ai_state_device_title")
        case .notEnabled:     return AIL("ai_state_disabled_title")
        case .modelNotReady:  return AIL("ai_state_loading_title")
        }
    }

    var message: String {
        switch state {
        case .available:      return AIL("ai_state_available_body")
        case .deviceNotEligible: return AIL("ai_state_device_body")
        case .notEnabled:     return AIL("ai_state_disabled_body")
        case .modelNotReady:  return AIL("ai_state_loading_body")
        }
    }

    var symbol: String {
        switch state {
        case .available:      return "apple.intelligence"
        case .deviceNotEligible: return "iphone.slash"
        case .notEnabled:     return "gearshape"
        case .modelNotReady:  return "arrow.down.circle"
        }
    }
}
