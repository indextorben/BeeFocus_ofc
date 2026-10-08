//
//  BeeAITools.swift
//  BeeFocus_ofc
//
//  Werkzeuge, die das On-Device-Modell aufrufen kann, um echte Aktionen in
//  BeeFocus auszuführen. Jedes Werkzeug meldet zurück, was es getan hat –
//  einmal für das Modell (Rückgabewert) und einmal für die UI (AIActionLog).
//

import Foundation
import FoundationModels

// MARK: - Protokoll der ausgeführten Aktionen

/// Sammelt, was der Assistent während eines Befehls tatsächlich verändert hat.
/// Dient als Quittung in der UI und als Basis für "Rückgängig".
@MainActor
final class AIActionLog: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let symbol: String
        let text: String
        /// Wenn gesetzt, kann diese Aktion rückgängig gemacht werden.
        let undo: (@MainActor () -> Void)?
    }

    @Published private(set) var entries: [Entry] = []

    func record(symbol: String, text: String, undo: (@MainActor () -> Void)? = nil) {
        entries.append(Entry(symbol: symbol, text: text, undo: undo))
    }

    func reset() { entries.removeAll() }

    var canUndo: Bool { entries.contains { $0.undo != nil } }

    func undoAll() {
        for entry in entries.reversed() {
            entry.undo?()
        }
        entries.removeAll()
    }
}

// MARK: - Aufgabe anlegen

@available(iOS 26.0, *)
@Generable
nonisolated struct AICreateTodoArgs {
    @Guide(description: "Kurzer Titel der Aufgabe im Imperativ, ohne Datumsangabe und ohne Aufzählung der Einzelteile")
    var title: String

    @Guide(description: "Alles Zusätzliche, was der Nutzer zu dieser Aufgabe gesagt hat: Ort, Personen, Grund, Hinweise. Leer lassen, wenn es nichts gibt. Was als Unteraufgabe steht, hier nicht wiederholen.")
    var details: String

    @Guide(description: "Fälligkeitsdatum als yyyy-MM-dd. Leer lassen, wenn kein Datum genannt wurde.")
    var dueDate: String

    @Guide(description: "Uhrzeit als HH:mm im 24-Stunden-Format. Leer lassen, wenn keine Uhrzeit genannt wurde.")
    var dueTime: String

    @Guide(description: "Priorität der Aufgabe", .anyOf(["low", "medium", "high"]))
    var priority: String

    @Guide(description: "Name einer vorhandenen Kategorie. Leer lassen, wenn keine passt.")
    var category: String

    @Guide(description: "Die Einzelteile dieser einen Aufgabe: bei Einkaufs-, Besorgungs- oder Packlisten je genanntes Ding ein Eintrag mit dem Namen des Dings, sonst die genannten Arbeitsschritte. Sonst leer.", .maximumCount(20))
    var subtasks: [String]
}

@available(iOS 26.0, *)
nonisolated struct AICreateTodoTool: Tool {
    let name = "aufgabe_anlegen"
    let description = """
    Legt eine neue Aufgabe in BeeFocus an. Für jedes genannte Vorhaben einmal aufrufen. \
    Zählt der Nutzer Dinge auf, die zu einem Vorhaben gehören (Einkauf, Besorgungen, \
    Packliste), ist das ein einziger Aufruf mit diesen Dingen als Unteraufgaben.
    """

    let log: AIActionLog

    func call(arguments: AICreateTodoArgs) async throws -> String {
        let title = arguments.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Fehler: Der Titel war leer, es wurde nichts angelegt." }

        return await MainActor.run {
            let store = TodoStore.shared
            let category = store.categories.first {
                $0.name.localizedCaseInsensitiveCompare(arguments.category) == .orderedSame
            }
            let due = AIDateFormat.date(day: arguments.dueDate, time: arguments.dueTime)
            let tidied = QuickTodoDraft.tidyTitle(title)
            let cleanTitle = tidied.isEmpty ? title : tidied
            let items = QuickTodoDraft.tidyItems(arguments.subtasks, title: cleanTitle)
            let details = QuickTodoDraft.tidyDetails(arguments.details, title: cleanTitle, items: items)
            let subTasks = items.map { SubTask(title: $0) }

            let todo = TodoItem(
                title: cleanTitle,
                description: details,
                dueDate: due,
                category: category,
                categoryID: category?.id,
                priority: TodoPriority(rawValue: arguments.priority.lowercased()) ?? .medium,
                subTasks: subTasks
            )
            store.addTodo(todo)

            var confirmation = "Aufgabe „\(cleanTitle)“ angelegt"
            if let due {
                let f = DateFormatter()
                f.locale = LocalizationManager.shared.currentLocale
                f.dateStyle = .medium
                f.timeStyle = arguments.dueTime.isEmpty ? .none : .short
                confirmation += ", fällig \(f.string(from: due))"
            }
            if let category { confirmation += ", Kategorie \(category.name)" }
            if !subTasks.isEmpty { confirmation += ", \(subTasks.count) Schritte" }

            log.record(symbol: "checkmark.circle.fill", text: confirmation) {
                TodoStore.shared.deleteTodo(todo)
            }
            return confirmation + "."
        }
    }
}

// MARK: - Aufgabe abschließen

@available(iOS 26.0, *)
@Generable
nonisolated struct AICompleteTodoArgs {
    @Guide(description: "Titel oder Teil des Titels der Aufgabe, die abgeschlossen werden soll")
    var title: String
}

@available(iOS 26.0, *)
nonisolated struct AICompleteTodoTool: Tool {
    let name = "aufgabe_abschliessen"
    let description = "Markiert eine vorhandene Aufgabe als erledigt. Sucht anhand des Titels."

    let log: AIActionLog

    func call(arguments: AICompleteTodoArgs) async throws -> String {
        await MainActor.run {
            let store = TodoStore.shared
            let query = arguments.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidates = store.todos.filter { !$0.isCompleted && !$0.isDeleted }

            guard let match = candidates.first(where: {
                $0.title.localizedCaseInsensitiveCompare(query) == .orderedSame
            }) ?? candidates.first(where: {
                $0.title.localizedCaseInsensitiveContains(query)
            }) else {
                return "Es wurde keine offene Aufgabe gefunden, die zu „\(query)“ passt."
            }

            store.setCompleted(todo: match, completed: true)
            let text = "„\(match.title)“ als erledigt markiert"
            log.record(symbol: "checkmark.seal.fill", text: text) {
                TodoStore.shared.setCompleted(todo: match, completed: false)
            }
            return text + "."
        }
    }
}

// MARK: - Aufgaben abfragen

@available(iOS 26.0, *)
@Generable
nonisolated struct AIQueryTodosArgs {
    @Guide(description: "Zeitraum der Abfrage", .anyOf(["heute", "morgen", "diese_woche", "ueberfaellig", "alle"]))
    var timeframe: String
}

@available(iOS 26.0, *)
nonisolated struct AIQueryTodosTool: Tool {
    let name = "aufgaben_abfragen"
    let description = "Liest die offenen Aufgaben des Nutzers für einen Zeitraum. Nutze das, wenn der Nutzer fragt, was zu tun ist."

    func call(arguments: AIQueryTodosArgs) async throws -> String {
        await MainActor.run {
            let cal = Calendar.current
            let open = TodoStore.shared.todos.filter { !$0.isCompleted && !$0.isDeleted }

            let filtered: [TodoItem]
            switch arguments.timeframe.lowercased() {
            case "heute":
                filtered = open.filter { $0.dueDate.map { cal.isDateInToday($0) || $0 < Date() } ?? false }
            case "morgen":
                filtered = open.filter { $0.dueDate.map { cal.isDateInTomorrow($0) } ?? false }
            case "diese_woche":
                filtered = open.filter {
                    guard let due = $0.dueDate else { return false }
                    return due <= Date().addingTimeInterval(7 * 86_400) && due >= cal.startOfDay(for: Date())
                }
            case "ueberfaellig":
                filtered = open.filter { $0.isOverdue }
            default:
                filtered = open
            }

            guard !filtered.isEmpty else { return "Für diesen Zeitraum sind keine Aufgaben offen." }

            let sorted = filtered.sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    let order: [TodoPriority: Int] = [.high: 0, .medium: 1, .low: 2]
                    return (order[lhs.priority] ?? 1) < (order[rhs.priority] ?? 1)
                }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
            let list = sorted.prefix(10).map { "\($0.title) (Priorität \($0.priority.rawValue))" }
            return "\(filtered.count) offene Aufgaben: " + list.joined(separator: "; ") + "."
        }
    }
}

// MARK: - Fokus-Timer

@available(iOS 26.0, *)
@Generable
nonisolated struct AIFocusTimerArgs {
    @Guide(description: "Was mit dem Timer passieren soll", .anyOf(["starten", "pausieren", "fortsetzen", "zuruecksetzen", "status"]))
    var action: String
}

@available(iOS 26.0, *)
nonisolated struct AIFocusTimerTool: Tool {
    let name = "fokus_timer"
    let description = "Steuert den Pomodoro-Fokus-Timer: starten, pausieren, fortsetzen, zurücksetzen oder Status abfragen."

    let log: AIActionLog

    func call(arguments: AIFocusTimerArgs) async throws -> String {
        await MainActor.run {
            let timer = TimerManager.shared
            switch arguments.action.lowercased() {
            case "starten":
                timer.startNewSession()
                let minutes = Int(timer.timeRemaining / 60)
                let text = "Fokus-Timer für \(minutes) Minuten gestartet"
                log.record(symbol: "timer", text: text) { TimerManager.shared.reset() }
                return text + "."
            case "pausieren":
                timer.pause()
                log.record(symbol: "pause.circle.fill", text: "Timer pausiert") { TimerManager.shared.resume() }
                return "Timer pausiert."
            case "fortsetzen":
                timer.resume()
                log.record(symbol: "play.circle.fill", text: "Timer fortgesetzt") { TimerManager.shared.pause() }
                return "Timer läuft weiter."
            case "zuruecksetzen":
                timer.reset()
                log.record(symbol: "arrow.counterclockwise", text: "Timer zurückgesetzt")
                return "Timer zurückgesetzt."
            default:
                guard timer.isRunning else { return "Es läuft gerade kein Timer." }
                let minutes = Int(timer.timeRemaining / 60)
                let seconds = Int(timer.timeRemaining) % 60
                let phase = timer.isBreak ? "Pause" : "Fokus"
                return "\(phase) läuft noch \(minutes) Minuten und \(seconds) Sekunden."
            }
        }
    }
}

// MARK: - Wasser

@available(iOS 26.0, *)
@Generable
nonisolated struct AIWaterArgs {
    @Guide(description: "Menge in Millilitern. Ein Glas entspricht 250, eine Flasche 500, eine Tasse 200.", .range(50...2000))
    var milliliters: Int
}

@available(iOS 26.0, *)
nonisolated struct AIWaterTool: Tool {
    let name = "wasser_eintragen"
    let description = "Trägt getrunkenes Wasser im Wasser-Tracker ein."

    let log: AIActionLog

    func call(arguments: AIWaterArgs) async throws -> String {
        await MainActor.run {
            let store = WasserStore.shared
            store.add(ml: arguments.milliliters)
            let today = store.last7DaysTotals().last?.ml ?? arguments.milliliters
            let text = "\(arguments.milliliters) ml Wasser eingetragen"
            log.record(symbol: "drop.fill", text: text)
            return text + ". Heute insgesamt \(today) von \(store.tagesziel) ml."
        }
    }
}

// MARK: - Gewohnheiten

@available(iOS 26.0, *)
@Generable
nonisolated struct AIHabitArgs {
    @Guide(description: "Name der Gewohnheit oder ein Teil davon")
    var habit: String
}

@available(iOS 26.0, *)
nonisolated struct AIHabitTool: Tool {
    let name = "gewohnheit_abhaken"
    let description = "Hakt eine Gewohnheit für heute ab oder nimmt den Haken zurück."

    let log: AIActionLog

    func call(arguments: AIHabitArgs) async throws -> String {
        await MainActor.run {
            let store = HabitStore.shared
            let query = arguments.habit.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let match = store.habits.first(where: {
                $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame
            }) ?? store.habits.first(where: {
                $0.name.localizedCaseInsensitiveContains(query)
            }) else {
                let available = store.habits.map(\.name).joined(separator: ", ")
                return available.isEmpty
                    ? "Es sind noch keine Gewohnheiten angelegt."
                    : "„\(query)“ wurde nicht gefunden. Vorhanden sind: \(available)."
            }

            store.toggle(match)
            let done = store.habits.first(where: { $0.id == match.id })?.isCompleted(on: Date()) ?? true
            let text = done ? "Gewohnheit „\(match.name)“ abgehakt" : "Haken bei „\(match.name)“ entfernt"
            log.record(symbol: "flame.fill", text: text) { HabitStore.shared.toggle(match) }
            return text + "."
        }
    }
}

// MARK: - Stimmung

@available(iOS 26.0, *)
@Generable
nonisolated struct AIMoodArgs {
    @Guide(description: "Stimmung von 1 (sehr schlecht) bis 5 (sehr gut)", .range(1...5))
    var level: Int

    @Guide(description: "Optionale kurze Notiz des Nutzers zur Stimmung. Leer lassen, wenn nichts genannt wurde.")
    var note: String
}

@available(iOS 26.0, *)
nonisolated struct AIMoodTool: Tool {
    let name = "stimmung_eintragen"
    let description = "Trägt die aktuelle Stimmung des Nutzers im Stimmungs-Tracker ein."

    let log: AIActionLog

    func call(arguments: AIMoodArgs) async throws -> String {
        await MainActor.run {
            let level = min(max(arguments.level, 1), 5)
            StimmungsStore.shared.set(stufe: level, notiz: arguments.note)
            let text = "Stimmung \(stimmungsLabel(level)) eingetragen"
            log.record(symbol: "face.smiling", text: text)
            return text + "."
        }
    }
}

// MARK: - Brain Dump

@available(iOS 26.0, *)
@Generable
nonisolated struct AIBrainDumpArgs {
    @Guide(description: "Der Gedanke, wörtlich so, wie der Nutzer ihn formuliert hat")
    var text: String

    @Guide(description: "Art des Gedankens", .anyOf(["idee", "aufgabe", "frage", "sorge", "danke"]))
    var tag: String
}

@available(iOS 26.0, *)
nonisolated struct AIBrainDumpTool: Tool {
    let name = "gedanke_notieren"
    let description = "Schreibt einen Gedanken, eine Idee oder eine Sorge in den Brain Dump, ohne daraus eine Aufgabe zu machen."

    let log: AIActionLog

    func call(arguments: AIBrainDumpArgs) async throws -> String {
        await MainActor.run {
            let text = arguments.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return "Der Gedanke war leer, es wurde nichts notiert." }
            let tag = BrainDumpTag(rawValue: arguments.tag.lowercased()) ?? .idee
            BrainDumpStore.shared.add(text: text, tag: tag)
            log.record(symbol: "brain.head.profile", text: "Im Brain Dump notiert: \(text)")
            return "Als \(tag.label) im Brain Dump notiert."
        }
    }
}

// MARK: - Fokusmodus

@available(iOS 26.0, *)
@Generable
nonisolated struct AIFocusModeArgs {
    @Guide(description: "Ob der Fokusmodus mit Website-Blockierung ein- oder ausgeschaltet werden soll", .anyOf(["ein", "aus"]))
    var state: String
}

@available(iOS 26.0, *)
nonisolated struct AIFocusModeTool: Tool {
    let name = "fokusmodus"
    let description = "Schaltet den Fokusmodus ein oder aus, der ablenkende Apps und Websites blockiert."

    let log: AIActionLog

    func call(arguments: AIFocusModeArgs) async throws -> String {
        await MainActor.run {
            let manager = FokusModeManager.shared
            if arguments.state.lowercased() == "aus" {
                manager.disableFocusMode()
                log.record(symbol: "shield.slash.fill", text: "Fokusmodus ausgeschaltet") {
                    FokusModeManager.shared.enableFocusMode()
                }
                return "Fokusmodus ausgeschaltet."
            } else {
                manager.enableFocusMode()
                log.record(symbol: "shield.fill", text: "Fokusmodus eingeschaltet") {
                    FokusModeManager.shared.disableFocusMode()
                }
                return "Fokusmodus eingeschaltet, Ablenkungen sind blockiert."
            }
        }
    }
}

// MARK: - Sammlung

@available(iOS 26.0, *)
@MainActor
enum BeeAIToolbox {
    /// Alle Werkzeuge, die der Sprach-Assistent nutzen darf.
    static func all(log: AIActionLog) -> [any Tool] {
        [
            AICreateTodoTool(log: log),
            AICompleteTodoTool(log: log),
            AIQueryTodosTool(),
            AIFocusTimerTool(log: log),
            AIWaterTool(log: log),
            AIHabitTool(log: log),
            AIMoodTool(log: log),
            AIBrainDumpTool(log: log),
            AIFocusModeTool(log: log)
        ]
    }
}
