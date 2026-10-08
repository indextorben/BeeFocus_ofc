//
//  AITodoIntelligence.swift
//  BeeFocus_ofc
//
//  Die kleinen Zauber: Auto-Kategorie und -Priorität beim Tippen,
//  Unteraufgaben-Vorschläge, Datumsangaben in normaler Sprache und
//  semantische Suche.
//

import Foundation
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
@MainActor
final class AITodoIntelligence: ObservableObject {
    static let shared = AITodoIntelligence()

    private init() {}

    // MARK: - Eine Aufgabe verfassen

    /// Verfasst aus freiem Text **genau eine** Aufgabe: Titel, Beschreibung,
    /// Unteraufgaben, Datum, Priorität und Kategorie.
    ///
    /// Grundlage ist immer der regelbasierte Parser – er versteht Zeitangaben
    /// wörtlich und liefert auch dann ein Ergebnis, wenn das Modell daneben
    /// greift. Apple Intelligence verfeinert dieses Ergebnis nur.
    func compose(from text: String, reference: Date = Date()) async throws -> QuickTodoDraft {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else { throw AIFeatureError.inputTooShort }

        let fallback = QuickTodoParser.parse(clean, reference: reference)
        guard AIAvailability.shared.isAvailable else { throw AIFeatureError.unavailable }

        let context = AIContext.dateContext + "\n" + AIContext.categoryContext
        let session = LanguageModelSession {
            BeeAIPrompts.composeInstructions
            context
        }
        let response = try await session.respond(
            to: "Verfasse genau eine Aufgabe aus dieser Eingabe:\n\n\(AIContext.sanitizeInput(clean))",
            generating: AIExtractedTodo.self,
            options: GenerationOptions(temperature: 0.3)
        )
        return QuickTodoDraft(model: response.content, fallback: fallback)
    }

    /// Verfeinert mehrere Entwürfe nacheinander. Schlägt einer fehl, bleibt der
    /// regelbasierte Entwurf stehen – es gehen also nie Eingaben verloren.
    func refine(_ drafts: [QuickTodoDraft], limit: Int = 6) async -> [QuickTodoDraft] {
        var result = drafts
        for index in result.indices.prefix(limit) {
            if Task.isCancelled { return result }
            let draft = result[index]
            let input = draft.source.isEmpty ? draft.title : draft.source
            guard input.count >= 3 else { continue }
            if let refined = try? await compose(from: input) {
                result[index] = refined
            }
        }
        return result
    }

    // MARK: - Automatische Einordnung

    /// Schlägt Kategorie, Priorität, Quadrant und Dauer für einen Titel vor.
    func classify(title: String) async throws -> AITodoClassification {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else { throw AIFeatureError.inputTooShort }

        let context = AIContext.categoryContext + "\n" + AIContext.dateContext
        let session = LanguageModelSession {
            BeeAIPrompts.classificationInstructions
            context
        }
        let response = try await session.respond(
            to: "Ordne diese Aufgabe ein: \(clean)",
            generating: AITodoClassification.self,
            options: GenerationOptions(temperature: 0.2)
        )
        return response.content
    }

    /// Wendet einen Vorschlag direkt auf eine Aufgabe an.
    func apply(_ classification: AITodoClassification, to todo: TodoItem) {
        var updated = todo
        let store = TodoStore.shared
        if let category = store.categories.first(where: {
            $0.name.localizedCaseInsensitiveCompare(classification.category) == .orderedSame
        }) {
            updated.category = category
            updated.categoryID = category.id
        }
        updated.priority = classification.mappedPriority
        updated.focusTimeInMinutes = Double(classification.estimatedMinutes)
        store.updateTodo(updated)

        if let quadrant = EisenhowerQuadrant(rawValue: classification.quadrant) {
            EisenhowerStore.shared.assign(updated.id, to: quadrant)
        }
    }

    // MARK: - Unteraufgaben

    /// Zerlegt eine Aufgabe in konkrete Schritte.
    func suggestSubtasks(for title: String, details: String = "") async throws -> [String] {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else { throw AIFeatureError.inputTooShort }

        let session = LanguageModelSession(instructions: BeeAIPrompts.subtaskInstructions)
        var prompt = "Zerlege diese Aufgabe in Schritte: \(clean)"
        if !details.isEmpty { prompt += "\n\nZusätzliche Details: \(details)" }

        let response = try await session.respond(
            to: prompt,
            generating: AISubtaskSuggestions.self,
            options: GenerationOptions(temperature: 0.4)
        )
        return response.content.subtasks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Streamt Unteraufgaben-Vorschläge, damit sie einzeln in der UI erscheinen.
    func streamSubtasks(for title: String, details: String = "") -> AsyncThrowingStream<[String], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: BeeAIPrompts.subtaskInstructions)
                    var prompt = "Zerlege diese Aufgabe in Schritte: \(title)"
                    if !details.isEmpty { prompt += "\n\nZusätzliche Details: \(details)" }

                    let stream = session.streamResponse(
                        to: prompt,
                        generating: AISubtaskSuggestions.self,
                        options: GenerationOptions(temperature: 0.4)
                    )
                    for try await snapshot in stream {
                        let items = (snapshot.content.subtasks ?? [])
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        continuation.yield(items)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Datum in normaler Sprache

    /// Versteht Eingaben wie "nächsten Dienstag früh" oder "in drei Tagen".
    /// Nutzt zuerst den System-Datumsparser und fragt nur bei Bedarf das Modell.
    func parseDate(from text: String) async -> Date? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        // Schnellweg: Der System-Parser erkennt viele Formulierungen ohne Modell.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(
               in: clean,
               range: NSRange(clean.startIndex..., in: clean)
           ),
           let date = match.date {
            return date
        }

        guard AIAvailability.shared.isAvailable else { return nil }

        do {
            let context = AIContext.dateContext
            let session = LanguageModelSession {
                """
                Du wandelst Zeitangaben in normaler Sprache in ein konkretes Datum um.
                Antworte ausschließlich mit den Feldern des Schemas.
                Ist keine Zeitangabe erkennbar, bleiben beide Felder leer.
                """
                context
            }
            let response = try await session.respond(
                to: "Welches Datum und welche Uhrzeit ist gemeint: \(clean)",
                generating: AIParsedDate.self,
                options: GenerationOptions(temperature: 0.1)
            )
            return AIDateFormat.date(day: response.content.day, time: response.content.time)
        } catch {
            return nil
        }
    }

    // MARK: - Semantische Suche

    /// Findet Aufgaben, die inhaltlich zur Anfrage passen, auch ohne Wortgleichheit.
    func semanticSearch(query: String, in todos: [TodoItem]) async throws -> [TodoItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2, !todos.isEmpty else { return [] }

        // Wörtliche Treffer brauchen kein Modell.
        let literal = todos.filter { $0.title.localizedCaseInsensitiveContains(clean) }
        if !literal.isEmpty { return literal }
        guard AIAvailability.shared.isAvailable else { return [] }

        let candidates = Array(todos.prefix(50))
        let list = candidates.enumerated()
            .map { "\($0.offset + 1). \($0.element.title)" }
            .joined(separator: "\n")

        let session = LanguageModelSession(instructions: BeeAIPrompts.searchInstructions)
        let response = try await session.respond(
            to: "Suchanfrage: \(clean)\n\nAufgabenliste:\n\(list)",
            generating: AISearchResult.self,
            options: GenerationOptions(temperature: 0.1)
        )

        return response.content.matches.compactMap { index in
            let i = index - 1
            guard candidates.indices.contains(i) else { return nil }
            return candidates[i]
        }
    }
}

// MARK: - Zusätzliches Schema

@available(iOS 26.0, *)
@Generable(description: "Ein aus normaler Sprache aufgelöstes Datum")
struct AIParsedDate {
    @Guide(description: "Datum als yyyy-MM-dd. Leerer String, wenn kein Datum erkennbar ist.")
    var day: String

    @Guide(description: "Uhrzeit als HH:mm im 24-Stunden-Format. Leerer String, wenn keine Uhrzeit genannt wurde.")
    var time: String
}

// MARK: - Fehler

nonisolated enum AIFeatureError: LocalizedError {
    case inputTooShort
    case unavailable

    var errorDescription: String? {
        switch self {
        case .inputTooShort: return AIL("ai_error_too_short")
        case .unavailable:   return AIL("ai_error_unavailable")
        }
    }
}
