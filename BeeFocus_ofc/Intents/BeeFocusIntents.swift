//
//  BeeFocusIntents.swift
//  BeeFocus_ofc
//
//  App Intents: BeeFocus per Siri, Kurzbefehle, Action Button und
//  Automationen steuern – ohne die App zu öffnen.
//

import AppIntents
import Foundation
import SwiftUI

// MARK: - Aufgabe hinzufügen

struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Aufgabe hinzufügen"
    static var description = IntentDescription(
        "Legt eine neue Aufgabe in BeeFocus an. Apple Intelligence erkennt dabei Datum, Priorität und Kategorie automatisch.",
        categoryName: "Aufgaben"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Aufgabe", requestValueDialog: "Was soll auf die Liste? Du kannst Zeitangaben einfach mitsprechen.")
    var text: String

    @Parameter(title: "Fällig am")
    var dueDate: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Füge \(\.$text) hinzu") {
            \.$dueDate
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<TodoAppEntity> {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw $text.needsValueError("Was soll auf die Liste?")
        }

        // Basis: der regelbasierte Parser. Er versteht "um 23 Uhr schlafen gehen"
        // und "ich brauche Milch, Brot und Eier" auch ohne Apple Intelligence,
        // also auf jedem unterstützten Gerät.
        var draft = QuickTodoParser.parse(clean)

        // Ist Apple Intelligence da, verfasst es daraus eine saubere Aufgabe:
        // ein Titel, der Rest als Beschreibung, Aufzählungen als Unteraufgaben.
        if #available(iOS 26.0, *), AIAvailability.shared.isAvailable,
           let refined = try? await AITodoIntelligence.shared.compose(from: clean) {
            draft = refined
        }

        // Ein im Kurzbefehl gesetztes Datum schlägt alles Erkannte.
        if let dueDate {
            draft.dueDate = dueDate
            draft.hasTime = true
        }

        let todo = draft.makeTodo()
        TodoStore.shared.addTodo(todo)

        let entity = TodoAppEntity(todo)
        return .result(
            value: entity,
            dialog: IntentDialog(stringLiteral: Self.confirmation(
                title: todo.title,
                due: todo.dueDate,
                steps: todo.subTasks.count
            ))
        )
    }

    /// Sagt zurück, was wirklich eingetragen wurde – inklusive Uhrzeit
    /// und Anzahl der Unteraufgaben.
    private static func confirmation(title: String, due: Date?, steps: Int) -> String {
        let list: String
        switch steps {
        case 0:  list = ""
        case 1:  list = " mit einer Unteraufgabe"
        default: list = " mit \(steps) Unteraufgaben"
        }
        guard let due else { return "„\(title)“ wurde hinzugefügt\(list)." }

        let cal = Calendar.current
        let time = DateFormatter()
        time.locale = Locale.current
        time.dateFormat = "HH:mm"

        let dayLabel: String
        if cal.isDateInToday(due) {
            dayLabel = "heute"
        } else if cal.isDateInTomorrow(due) {
            dayLabel = "morgen"
        } else {
            let day = DateFormatter()
            day.locale = Locale.current
            day.dateFormat = "EEEE, d. MMMM"
            dayLabel = "am " + day.string(from: due)
        }

        return "„\(title)“ ist für \(dayLabel) um \(time.string(from: due)) Uhr eingetragen\(list)."
    }
}

// MARK: - Aufgabe abschließen

struct CompleteTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Aufgabe abschließen"
    static var description = IntentDescription("Markiert eine Aufgabe in BeeFocus als erledigt.", categoryName: "Aufgaben")
    static var openAppWhenRun = false

    @Parameter(title: "Aufgabe", requestValueDialog: "Welche Aufgabe ist erledigt?")
    var todo: TodoAppEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = TodoStore.shared
        guard let item = store.todos.first(where: { $0.id == todo.id }) else {
            return .result(dialog: IntentDialog("Die Aufgabe wurde nicht gefunden."))
        }
        store.setCompleted(todo: item, completed: true)
        return .result(dialog: IntentDialog("„\(item.title)“ ist abgehakt. Stark!"))
    }
}

// MARK: - Was ist heute wichtig?

struct TodaysFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Was ist heute wichtig?"
    static var description = IntentDescription(
        "Liest die wichtigsten offenen Aufgaben für heute vor.",
        categoryName: "Aufgaben"
    )
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let todos = AIContext.todaysTodos()
            .sorted { lhs, rhs in
                let order: [TodoPriority: Int] = [.high: 0, .medium: 1, .low: 2]
                if lhs.priority != rhs.priority {
                    return (order[lhs.priority] ?? 1) < (order[rhs.priority] ?? 1)
                }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }

        guard !todos.isEmpty else {
            return .result(
                dialog: IntentDialog("Für heute steht nichts Offenes an. Genieß den freien Kopf."),
                view: TodayFocusSnippet(todos: [])
            )
        }

        let top = Array(todos.prefix(3))
        let spoken: String
        if top.count == 1 {
            spoken = "Heute steht an: \(top[0].title)."
        } else {
            let list = top.dropLast().map(\.title).joined(separator: ", ")
            spoken = "Deine Top-Aufgaben heute: \(list) und \(top.last!.title)."
        }

        return .result(
            dialog: IntentDialog(stringLiteral: spoken),
            view: TodayFocusSnippet(todos: Array(todos.prefix(5)))
        )
    }
}

/// Kleine Vorschau, die Siri nach der Abfrage einblendet.
struct TodayFocusSnippet: View {
    let todos: [TodoItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Heute", systemImage: "sun.max.fill")
                .font(.headline)

            if todos.isEmpty {
                Text("Nichts Offenes. Kopf frei.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todos) { todo in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(priorityColor(todo.priority))
                            .frame(width: 8, height: 8)
                        Text(todo.title)
                            .lineLimit(1)
                        Spacer()
                        if todo.isOverdue {
                            Text("überfällig")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func priorityColor(_ priority: TodoPriority) -> Color {
        switch priority {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .green
        }
    }
}

// MARK: - Fokus-Timer

struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Fokus starten"
    static var description = IntentDescription("Startet eine neue Fokus-Sitzung in BeeFocus.", categoryName: "Fokus")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let timer = TimerManager.shared
        timer.startNewSession()
        let minutes = max(1, Int(timer.timeRemaining / 60))
        return .result(dialog: IntentDialog("Fokus läuft – \(minutes) Minuten. Los geht's."))
    }
}

struct StopFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Fokus beenden"
    static var description = IntentDescription("Beendet die laufende Fokus-Sitzung.", categoryName: "Fokus")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerManager.shared.reset()
        return .result(dialog: IntentDialog("Fokus beendet."))
    }
}

struct FocusStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Wie lange läuft der Fokus noch?"
    static var description = IntentDescription("Sagt, wie viel Zeit die laufende Sitzung noch hat.", categoryName: "Fokus")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let timer = TimerManager.shared
        guard timer.isRunning else {
            return .result(dialog: IntentDialog("Gerade läuft kein Timer."))
        }
        let minutes = Int(timer.timeRemaining / 60)
        let phase = timer.isBreak ? "Pause" : "Fokus"
        return .result(dialog: IntentDialog("\(phase): noch \(minutes) Minuten."))
    }
}

// MARK: - Fokusmodus

struct ToggleFocusModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Fokusmodus umschalten"
    static var description = IntentDescription(
        "Schaltet die Blockierung ablenkender Apps und Websites ein oder aus.",
        categoryName: "Fokus"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Einschalten")
    var enabled: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = FokusModeManager.shared
        let target = enabled ?? !manager.isFocusModeActive
        if target {
            manager.enableFocusMode()
            return .result(dialog: IntentDialog("Fokusmodus an. Ablenkungen sind blockiert."))
        } else {
            manager.disableFocusMode()
            return .result(dialog: IntentDialog("Fokusmodus aus."))
        }
    }
}

// MARK: - Tracker

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser eintragen"
    static var description = IntentDescription("Trägt getrunkenes Wasser im Tracker ein.", categoryName: "Tracker")
    static var openAppWhenRun = false

    @Parameter(title: "Menge in ml", default: 250, inclusiveRange: (50, 2000))
    var milliliters: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = WasserStore.shared
        store.add(ml: milliliters)
        let today = store.last7DaysTotals().last?.ml ?? milliliters
        return .result(dialog: IntentDialog("\(milliliters) ml eingetragen. Heute: \(today) von \(store.tagesziel) ml."))
    }
}

struct LogMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Stimmung eintragen"
    static var description = IntentDescription("Hält die aktuelle Stimmung im Tracker fest.", categoryName: "Tracker")
    static var openAppWhenRun = false

    @Parameter(title: "Stimmung (1–5)", default: 3, inclusiveRange: (1, 5))
    var level: Int

    @Parameter(title: "Notiz")
    var note: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        StimmungsStore.shared.set(stufe: level, notiz: note ?? "")
        return .result(dialog: IntentDialog("Stimmung notiert: \(stimmungsLabel(level))."))
    }
}

struct BrainDumpIntent: AppIntent {
    static var title: LocalizedStringResource = "Gedanken notieren"
    static var description = IntentDescription(
        "Schreibt einen Gedanken in den Brain Dump, ohne dass daraus gleich eine Aufgabe wird.",
        categoryName: "Aufgaben"
    )
    static var openAppWhenRun = false

    @Parameter(title: "Gedanke", requestValueDialog: "Was hast du im Kopf?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw $text.needsValueError("Was hast du im Kopf?") }
        BrainDumpStore.shared.add(text: clean, tag: .idee)
        return .result(dialog: IntentDialog("Notiert. Der Kopf ist wieder frei."))
    }
}

// MARK: - Bee Voice öffnen

struct OpenBeeVoiceIntent: AppIntent {
    static var title: LocalizedStringResource = "Bee Voice öffnen"
    static var description = IntentDescription(
        "Öffnet den Sprach-Assistenten von BeeFocus, um freihändig Aufgaben zu erfassen.",
        categoryName: "Apple Intelligence"
    )
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Ohne Apple Intelligence gibt es kein Bee Voice – dann öffnet
        // stattdessen "Schnell erfassen", das überall funktioniert.
        AIRouter.shared.request(AIFeature.isReady ? .voice : .quickCapture)
        return .result()
    }
}

// MARK: - Schnell erfassen öffnen

struct QuickCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Schnell erfassen"
    static var description = IntentDescription(
        "Öffnet die Schnellerfassung: einen Satz sprechen oder tippen, BeeFocus erkennt Tag, Uhrzeit und Priorität.",
        categoryName: "Aufgaben"
    )
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AIRouter.shared.request(.quickCapture)
        return .result()
    }
}

struct OpenDayPlannerIntent: AppIntent {
    static var title: LocalizedStringResource = "Tag planen lassen"
    static var description = IntentDescription(
        "Öffnet den KI-Tagesplaner, der aus offenen Aufgaben einen zeitgeblockten Tag baut.",
        categoryName: "Apple Intelligence"
    )
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AIRouter.shared.request(.planner)
        return .result()
    }
}
