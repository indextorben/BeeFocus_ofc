//
//  BeeAssistantFallback.swift
//  BeeFocus_ofc
//
//  Sicherheitsnetz für "Bee Voice": Das On-Device-Modell behauptet manchmal,
//  eine Aufgabe angelegt zu haben, ohne das Werkzeug wirklich aufzurufen –
//  dann wäre der Wunsch des Nutzers verloren, obwohl die Antwort das Gegenteil
//  sagt. Greift kein Werkzeug, legt dieser regelbasierte Weg die Aufgabe an:
//  derselbe Parser, der "Schnell erfassen" trägt und darum ohne Apple
//  Intelligence auskommt.
//

import Foundation

@MainActor
enum BeeAssistantFallback {

    /// Wörter, die eine Frage einleiten. Darauf antwortet das Modell, daraus
    /// entsteht keine Aufgabe.
    private static let questionMarkers = [
        "was ", "wie ", "welche", "welcher", "welches", "wann ", "wo ", "wieso",
        "warum", "wer ", "zeig", "liste", "nenne", "sag mir", "habe ich", "hab ich",
        "steht an", "ist los", "gibt es",
        "what", "which", "when ", "where", "why ", "who ", "show ", "list ",
        "tell me", "do i have", "how many", "how much"
    ]

    /// Wortfelder der übrigen Werkzeuge. Hier hält sich der Rückfallweg heraus:
    /// Aus "zwei Gläser Wasser getrunken" darf keine Aufgabe werden.
    private static let otherDomainMarkers = [
        // Wasser
        "wasser", "getrunken", "trinke", "glas ", "gläser", "water", "drank", "sip",
        // Stimmung
        "stimmung", "laune", "fühle mich", "geht mir", "mood", "feeling",
        // Gewohnheiten
        "gewohnheit", "abhaken", "hake ", "streak", "habit", "check off",
        // Timer
        "timer", "pomodoro", "fokuszeit", "fokus-timer", "stoppuhr",
        // Fokusmodus
        "fokusmodus", "fokus modus", "focus mode", "blockier", "ablenkung",
        // Brain Dump
        "brain dump", "braindump", "gedanke", "notier", "merk dir", "idee",
        "thought", "note down", "remind me that",
        // Abschließen
        "erledigt", "abgeschlossen", "abschließen", "fertig mit", "geschafft",
        "done with", "completed", "mark as done",
        // Rückgängig
        "rückgängig", "undo", "lösch", "delete", "entferne"
    ]

    /// Klingt der Befehl danach, dass eine Aufgabe entstehen soll?
    /// Bewusst vorsichtig: Im Zweifel greift der Rückfallweg nicht.
    static func looksLikeTodoRequest(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return false }
        guard !trimmed.hasSuffix("?") else { return false }

        let lower = " " + trimmed.localizedLowercase + " "
        if questionMarkers.contains(where: { lower.contains(" " + $0) }) { return false }
        if otherDomainMarkers.contains(where: { lower.contains($0) }) { return false }
        return true
    }

    /// Legt die Aufgaben aus dem Befehl an und protokolliert jede einzelne.
    /// - Returns: Die Quittungen der angelegten Aufgaben, leer wenn nichts entstand.
    @discardableResult
    static func createTodos(from command: String, log: AIActionLog) -> [String] {
        let drafts = QuickTodoParser.drafts(from: command)
            .filter { $0.title.count >= 2 }
        guard !drafts.isEmpty else { return [] }

        var confirmations: [String] = []
        for draft in drafts {
            let todo = draft.makeTodo()
            TodoStore.shared.addTodo(todo)
            let confirmation = AITodoConfirmation.text(for: todo, hasTime: draft.hasTime)
            confirmations.append(confirmation)
            log.record(symbol: "checkmark.circle.fill", text: confirmation) {
                TodoStore.shared.deleteTodo(todo)
            }
        }
        return confirmations
    }
}
