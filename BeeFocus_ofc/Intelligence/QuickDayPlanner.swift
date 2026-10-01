//
//  QuickDayPlanner.swift
//  BeeFocus_ofc
//
//  Tagesplaner ohne Apple Intelligence: Freitext rein, sortierter und
//  zeitgeblockter Tag raus. Baut auf `QuickTodoParser` auf und läuft darum
//  auch auf iOS 18 – dort ist das Foundation-Models-Framework nicht da.
//  Die Modell-Variante liegt in `AIPlanner`; die Oberflächen sind bewusst
//  gleich aufgebaut, damit der Wechsel nicht auffällt.
//

import Foundation
import SwiftUI

@MainActor
final class QuickDayPlanner: ObservableObject {

    // MARK: - Typen

    enum BlockKind: String {
        case focus
        case admin
        case pause
    }

    struct Candidate: Identifiable {
        let id = UUID()
        var draft: QuickTodoDraft
        var estimatedMinutes: Int
        var isSelected: Bool = true
        /// Zu einer bereits vorhandenen Aufgabe – die wird terminiert statt neu angelegt.
        var existingID: UUID?
    }

    struct Block: Identifiable, Equatable {
        let id = UUID()
        var start: Date
        var durationMinutes: Int
        var title: String
        var kind: BlockKind
        var priority: TodoPriority
        /// Der Nutzer hat eine Uhrzeit genannt – der Block ist unverschiebbar.
        var isFixed: Bool
        var note: String
        var existingID: UUID?

        var end: Date { start.addingTimeInterval(TimeInterval(durationMinutes * 60)) }

        static func == (lhs: Block, rhs: Block) -> Bool {
            lhs.id == rhs.id && lhs.start == rhs.start && lhs.durationMinutes == rhs.durationMinutes
        }
    }

    // MARK: - Zustand

    @Published var candidates: [Candidate] = []
    @Published private(set) var blocks: [Block] = []
    @Published private(set) var deferred: [String] = []
    @Published private(set) var summary: String = ""
    @Published private(set) var hasPlan = false
    @Published private(set) var errorMessage: String?

    /// Zeitfenster – dieselben Schlüssel wie beim KI-Planer, damit die
    /// Einstellung beim Wechsel auf ein neueres iPhone erhalten bleibt.
    @AppStorage("aiPlanStartHour") var startHour: Int = 9
    @AppStorage("aiPlanEndHour") var endHour: Int = 18

    var selectedCandidates: [Candidate] { candidates.filter(\.isSelected) }

    // MARK: - Stufe 1: Freitext zerlegen

    /// Zerlegt den Wortsalat in einzelne Aufgaben. Jede Zeile, jeder
    /// Aufzählungspunkt und jeder Satz wird für sich betrachtet.
    func extract(from text: String) {
        reset()
        let fragments = Self.fragments(in: text)
        guard !fragments.isEmpty else {
            errorMessage = AIL("ai_plan_nothing_found")
            return
        }

        var seen = Set<String>()
        candidates = fragments.compactMap { fragment in
            let draft = QuickTodoParser.parse(fragment)
            let key = draft.title.localizedLowercase
            guard !key.isEmpty, seen.insert(key).inserted else { return nil }
            return Candidate(draft: draft, estimatedMinutes: Self.estimateMinutes(for: draft))
        }

        if candidates.isEmpty {
            errorMessage = AIL("ai_plan_nothing_found")
        }
    }

    // MARK: - Stufe 2: Tagesplan bauen

    /// Legt die ausgewählten Aufgaben – und auf Wunsch die heute fälligen –
    /// in das eingestellte Zeitfenster. Aufgaben mit genannter Uhrzeit bleiben
    /// auf ihrer Uhrzeit, alles andere füllt die Lücken dazwischen.
    func buildPlan(includeExistingTodos: Bool) {
        errorMessage = nil
        let calendar = Calendar.current
        let today = Date()

        var items = selectedCandidates
        if includeExistingTodos {
            items.append(contentsOf: Self.todaysOpenTodos(reference: today, excluding: items))
        }

        guard !items.isEmpty else {
            blocks = []
            deferred = []
            summary = ""
            hasPlan = true
            errorMessage = AIL("ai_plan_nothing_to_plan")
            return
        }

        // Feste Termine zuerst – sie bestimmen, wo noch Platz ist.
        let fixed = items.filter { $0.draft.hasTime && $0.draft.dueDate != nil }
            .sorted { ($0.draft.dueDate ?? today) < ($1.draft.dueDate ?? today) }
        var flexible = items.filter { !($0.draft.hasTime && $0.draft.dueDate != nil) }

        // Wichtiges zuerst, danach das mit der näheren Fälligkeit.
        flexible.sort { lhs, rhs in
            if lhs.draft.priority != rhs.draft.priority {
                return Self.weight(lhs.draft.priority) > Self.weight(rhs.draft.priority)
            }
            switch (lhs.draft.dueDate, rhs.draft.dueDate) {
            case let (l?, r?): return l < r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }

        var result: [Block] = fixed.map { candidate in
            Block(start: candidate.draft.dueDate ?? today,
                  durationMinutes: candidate.estimatedMinutes,
                  title: candidate.draft.title,
                  kind: Self.kind(for: candidate.draft.title),
                  priority: candidate.draft.priority,
                  isFixed: true,
                  note: AIL("quick_plan_note_fixed"),
                  existingID: candidate.existingID)
        }

        let windowStart = calendar.date(bySettingHour: min(startHour, endHour - 1), minute: 0, second: 0, of: today) ?? today
        let windowEnd = calendar.date(bySettingHour: max(endHour, startHour + 1), minute: 0, second: 0, of: today) ?? today

        // Innerhalb des Fensters nie in der Vergangenheit anfangen.
        var cursor = max(windowStart, Self.roundedUp(today, to: 5))
        if cursor >= windowEnd { cursor = windowStart }

        var notPlanned: [String] = []
        var minutesSinceBreak = 0

        for candidate in flexible {
            let duration = candidate.estimatedMinutes

            // Nach rund 90 Minuten am Stück eine kurze Pause einschieben.
            if minutesSinceBreak >= 90 {
                if let slot = Self.nextFreeSlot(from: cursor, minutes: 15, blocked: result, until: windowEnd) {
                    result.append(Block(start: slot,
                                        durationMinutes: 15,
                                        title: AIL("quick_plan_break"),
                                        kind: .pause,
                                        priority: .low,
                                        isFixed: false,
                                        note: AIL("quick_plan_break_note"),
                                        existingID: nil))
                    cursor = slot.addingTimeInterval(15 * 60)
                }
                minutesSinceBreak = 0
            }

            guard let slot = Self.nextFreeSlot(from: cursor, minutes: duration, blocked: result, until: windowEnd) else {
                notPlanned.append(candidate.draft.title)
                continue
            }

            result.append(Block(start: slot,
                                durationMinutes: duration,
                                title: candidate.draft.title,
                                kind: Self.kind(for: candidate.draft.title),
                                priority: candidate.draft.priority,
                                isFixed: false,
                                note: Self.note(for: candidate.draft),
                                existingID: candidate.existingID))
            cursor = slot.addingTimeInterval(TimeInterval(duration * 60))
            minutesSinceBreak += duration
        }

        result.sort { $0.start < $1.start }
        blocks = result
        deferred = notPlanned
        summary = Self.makeSummary(blocks: result, deferred: notPlanned)
        hasPlan = true
    }

    // MARK: - Übernahme

    /// Legt nur die ausgewählten Aufgaben an, ohne Tagesplan.
    @discardableResult
    func applyCandidates() -> Int {
        let store = TodoStore.shared
        var created = 0
        for candidate in selectedCandidates where candidate.existingID == nil {
            store.addTodo(candidate.draft.makeTodo())
            created += 1
        }
        return created
    }

    /// Übernimmt den Tagesplan: je Block eine terminierte Aufgabe, zusätzlich
    /// einsortiert in die Eisenhower-Matrix. Pausen werden nicht angelegt.
    @discardableResult
    func applyPlan() -> Int {
        let store = TodoStore.shared
        let eisenhower = EisenhowerStore.shared
        var created = 0

        for block in blocks where block.kind != .pause {
            // Vorhandene Aufgabe nur terminieren statt ein Duplikat anzulegen.
            let existing = store.todos.first {
                if let id = block.existingID { return $0.id == id }
                return !$0.isCompleted && !$0.isDeleted &&
                    $0.title.localizedCaseInsensitiveCompare(block.title) == .orderedSame
            }

            if var todo = existing {
                todo.dueDate = block.start
                todo.endDate = block.end
                todo.focusTimeInMinutes = Double(block.durationMinutes)
                if todo.reminderOffsetMinutes == nil { todo.reminderOffsetMinutes = 0 }
                store.updateTodo(todo)
                eisenhower.assign(todo.id, to: Self.quadrant(for: block))
                created += 1
                continue
            }

            let todo = TodoItem(
                title: block.title,
                dueDate: block.start,
                reminderOffsetMinutes: 0,
                priority: block.priority,
                focusTimeInMinutes: Double(block.durationMinutes),
                endDate: block.end
            )
            store.addTodo(todo)
            eisenhower.assign(todo.id, to: Self.quadrant(for: block))
            created += 1
        }

        // Was nicht mehr ins Fenster passt, landet ohne Termin in der Liste.
        for title in deferred {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            guard !store.todos.contains(where: {
                !$0.isDeleted && $0.title.localizedCaseInsensitiveCompare(clean) == .orderedSame
            }) else { continue }
            store.addTodo(TodoItem(title: clean, priority: .low))
        }

        return created
    }

    func reset() {
        candidates = []
        blocks = []
        deferred = []
        summary = ""
        hasPlan = false
        errorMessage = nil
    }

    // MARK: - Zerlegen

    /// Trennt an Zeilen, Aufzählungszeichen, Satzzeichen und an Bindewörtern,
    /// die im Diktat typischerweise zwei Aufgaben verbinden.
    ///
    /// Punkt und Komma trennen nur dort, wo keine Zahl dranhängt – sonst
    /// zerfallen "12.03.", "23.30 Uhr" und "Freitag, 14:30" in Bruchstücke
    /// und `QuickTodoParser` findet die Zeitangabe nicht mehr.
    private static let fragmentSeparators = #"[\n•*;!?]|(?<!\d)\.(?=\s|$)|,(?!\s*\d)"#

    private static func fragments(in text: String) -> [String] {
        return text
            .replacingOccurrences(of: #"\s+und\s+dann\s+"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+danach\s+"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: fragmentSeparators, with: "\n", options: .regularExpression)
            .components(separatedBy: "\n")
            .map { fragment -> String in
                var clean = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
                // Führende Listenstriche entfernen, ohne "E-Mail" zu zerlegen.
                while clean.hasPrefix("-") || clean.hasPrefix("–") {
                    clean = String(clean.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                return clean
            }
            .filter { $0.count >= 3 }
    }

    // MARK: - Dauer und Art

    /// Grobe Dauer nach Stichwort. Lieber knapp schätzen als den Tag zubauen.
    private static let durationHints: [(words: [String], minutes: Int)] = [
        (["anrufen", "rückruf", "call", "mail", "e-mail", "email", "schreiben an", "nachricht", "termin machen", "buchen", "kurz"], 15),
        (["einkaufen", "sport", "workout", "laufen", "joggen", "putzen", "aufräumen", "wäsche", "kochen", "lernen", "üben", "clean", "study", "workout"], 60),
        (["steuer", "bewerbung", "präsentation", "konzept", "hausarbeit", "projekt", "report", "bericht"], 90)
    ]

    private static func estimateMinutes(for draft: QuickTodoDraft) -> Int {
        let title = draft.title.localizedLowercase
        for hint in durationHints where hint.words.contains(where: { title.contains($0) }) {
            return hint.minutes
        }
        return draft.priority == .high ? 45 : 30
    }

    private static let adminWords = ["mail", "e-mail", "email", "anrufen", "call", "rechnung", "formular",
                                     "termin", "papierkram", "steuer", "bank", "versicherung", "admin"]

    private static func kind(for title: String) -> BlockKind {
        let lower = title.localizedLowercase
        return adminWords.contains(where: { lower.contains($0) }) ? .admin : .focus
    }

    private static func note(for draft: QuickTodoDraft) -> String {
        switch draft.priority {
        case .high: return AIL("quick_plan_note_high")
        case .low:  return AIL("quick_plan_note_low")
        case .medium:
            return draft.dueDate != nil ? AIL("quick_plan_note_due") : ""
        }
    }

    private static func weight(_ priority: TodoPriority) -> Int {
        switch priority {
        case .high:   return 3
        case .medium: return 2
        case .low:    return 1
        }
    }

    // MARK: - Platz suchen

    /// Nächster freier Zeitraum ab `start`, der `minutes` lang ist und keinen
    /// festen Termin überlappt. `nil`, wenn das Fenster voll ist.
    private static func nextFreeSlot(from start: Date, minutes: Int, blocked: [Block], until end: Date) -> Date? {
        var candidate = start
        let needed = TimeInterval(minutes * 60)
        // Mehr Durchläufe als Blöcke sind nie nötig: jeder Konflikt schiebt
        // hinter genau einen belegten Block.
        for _ in 0...(blocked.count + 1) {
            guard candidate.addingTimeInterval(needed) <= end else { return nil }
            if let conflict = blocked.first(where: { candidate < $0.end && $0.start < candidate.addingTimeInterval(needed) }) {
                candidate = conflict.end
                continue
            }
            return candidate
        }
        return nil
    }

    private static func roundedUp(_ date: Date, to minutes: Int) -> Date {
        let interval = TimeInterval(minutes * 60)
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / interval).rounded(.up) * interval)
    }

    // MARK: - Vorhandene Aufgaben

    /// Heute fällige, offene Aufgaben als Kandidaten – ohne die, die schon
    /// über den Freitext hereingekommen sind.
    private static func todaysOpenTodos(reference: Date, excluding existing: [Candidate]) -> [Candidate] {
        let calendar = Calendar.current
        let known = Set(existing.map { $0.draft.title.localizedLowercase })

        return TodoStore.shared.todos.compactMap { todo -> Candidate? in
            guard !todo.isCompleted, !todo.isDeleted else { return nil }
            guard let due = todo.dueDate, calendar.isDate(due, inSameDayAs: reference) else { return nil }
            guard !known.contains(todo.title.localizedLowercase) else { return nil }

            // 00:00 und 09:00 setzt die App selbst, wenn nur ein Tag bekannt
            // ist – das ist kein vom Nutzer gewollter Termin.
            let parts = calendar.dateComponents([.hour, .minute], from: due)
            let isPlaceholder = parts.minute == 0 && (parts.hour == 0 || parts.hour == 9)

            let draft = QuickTodoDraft(title: todo.title,
                                       dueDate: due,
                                       hasTime: !isPlaceholder,
                                       priority: todo.priority)
            let minutes = todo.focusTimeInMinutes.map { Int($0) } ?? estimateMinutes(for: draft)
            return Candidate(draft: draft,
                             estimatedMinutes: max(10, minutes),
                             existingID: todo.id)
        }
    }

    // MARK: - Eisenhower

    /// Feste Uhrzeit heißt dringend, hohe Priorität heißt wichtig.
    private static func quadrant(for block: Block) -> EisenhowerQuadrant {
        switch (block.priority, block.isFixed) {
        case (.high, true):  return .q1
        case (.high, false): return .q2
        case (_, true):      return .q3
        default:             return .q4
        }
    }

    // MARK: - Zusammenfassung

    private static func makeSummary(blocks: [Block], deferred: [String]) -> String {
        let work = blocks.filter { $0.kind != .pause }
        guard let last = work.last else { return AIL("quick_plan_summary_empty") }

        let minutes = work.reduce(0) { $0 + $1.durationMinutes }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "HH:mm"

        var text = AIL("quick_plan_summary", work.count, durationText(minutes), formatter.string(from: last.end))
        let important = work.filter { $0.priority == .high }.count
        if important > 0 {
            text += " " + AIL("quick_plan_summary_important", important)
        }
        if !deferred.isEmpty {
            text += " " + AIL("quick_plan_summary_deferred", deferred.count)
        }
        return text
    }

    private static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }
}
