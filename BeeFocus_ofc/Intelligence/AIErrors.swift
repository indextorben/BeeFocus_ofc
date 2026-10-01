//
//  AIErrors.swift
//  BeeFocus_ofc
//
//  Übersetzt Fehler des Sprachmodells in verständliche Nutzertexte.
//  Ab iOS 27 wird `LanguageModelError` verwendet; auf iOS 26.x greift der
//  Fallback über das dort noch gültige `GenerationError`.
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
enum AIErrorText {

    static func describe(_ error: Error) -> String {
        if error is CancellationError { return "" }

        if #available(iOS 27.0, *) {
            if let modelError = error as? LanguageModelError {
                return describe(modelError)
            }
        }
        if let legacy = error as? LanguageModelSession.GenerationError {
            return describeLegacy(legacy)
        }
        return AIL("ai_error_generic")
    }

    @available(iOS 27.0, *)
    private static func describe(_ error: LanguageModelError) -> String {
        switch error {
        case .contextSizeExceeded:           return AIL("ai_error_context")
        case .rateLimited:                   return AIL("ai_error_ratelimit")
        case .guardrailViolation, .refusal:  return AIL("ai_error_guardrail")
        case .unsupportedLanguageOrLocale:   return AIL("ai_error_language")
        case .timeout:                       return AIL("ai_error_timeout")
        case .unsupportedCapability,
             .unsupportedTranscriptContent,
             .unsupportedGenerationGuide:    return AIL("ai_error_generic")
        @unknown default:                    return AIL("ai_error_generic")
        }
    }

    // Der Typ ist ab iOS 27 als veraltet markiert, wird für iOS 26.x aber
    // weiterhin geworfen und muss darum behandelt werden.
    @available(iOS, deprecated: 27.0)
    private static func describeLegacy(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:    return AIL("ai_error_context")
        case .rateLimited:                  return AIL("ai_error_ratelimit")
        case .guardrailViolation, .refusal: return AIL("ai_error_guardrail")
        case .unsupportedLanguageOrLocale:  return AIL("ai_error_language")
        case .assetsUnavailable:            return AIL("ai_error_assets")
        case .decodingFailure:              return AIL("ai_error_decoding")
        case .concurrentRequests:           return AIL("ai_error_busy")
        case .unsupportedGuide:             return AIL("ai_error_generic")
        @unknown default:                   return AIL("ai_error_generic")
        }
    }
}
