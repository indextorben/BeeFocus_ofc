//
//  AIPlanner.swift
//  BeeFocus_ofc
//
//  "Bee Brain": Wortsalat rein, sortierter Tagesplan raus.
//  Zwei Stufen: Freitext → Aufgaben, Aufgaben → zeitgeblockter Tagesplan.
//

import Foundation
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
@MainActor
final class AIPlanner: ObservableObject {

    enum Phase: Equatable {
        case idle
        case extracting
        case planning
        case ready
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// Extrahierte Aufgaben mit Auswahl-Status für die Übernahme.
    @Published var candidates: [Candidate] = []
    /// Der erzeugte Tagesplan, sobald er vorliegt.
    @Published private(set) var plan: AIDayPlan?
    /// Teilweise eintreffender Plan, damit die UI live mitwächst.
    @Published private(set) var streamingBlocks: [AIPlanBlock] = []
    @Published private(set) var summary: String = ""

    struct Candidate: Identifiable {
        let id = UUID()
        var todo: AIExtractedTodo
        var isSelected: Bool = true
    }

    /// Zeitfenster, in das geplant wird.
    @AppStorage("aiPlanStartHour") var startHour: Int = 9
    @AppStorage("aiPlanEndHour") var endHour: Int = 18

    private var task: Task<Void, Never>?

    /// Aufgaben, für die der Nutzer eine konkrete Uhrzeit genannt hat.
    /// Diese Termine sind unverschiebbar: Das Modell darf sie nicht umlegen,
    /// und die Übernahme in die App behält die echte Uhrzeit bei.
    /// Schlüssel ist der normalisierte Titel.
    private var fixedTimes: [String: TimeOfDay] = [:]

    struct TimeOfDay: Equatable {
        var hour: Int
        var minute: Int
        var text: String { String(format: "%02d:%02d", hour, minute) }
        var minutesOfDay: Int { hour * 60 + minute }
    }

    var isBusy: Bool { phase == .extracting || phase == .planning }
    var selectedCandidates: [Candidate] { candidates.filter(\.isSelected) }

    // MARK: - Stufe 1: Freitext zerlegen

    func extract(from text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        guard AIAvailability.shared.isAvailable else {
            phase = .failed(AIAvailability.shared.message)
            return
        }

        task?.cancel()
        candidates = []
        plan = nil
        streamingBlocks = []
        summary = ""
        phase = .extracting

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let context = AIContext.dateContext + "\n" + AIContext.categoryContext
                let session = LanguageModelSession {
                    BeeAIPrompts.extractionInstructions
                    context
                }
                let stream = session.streamResponse(
                    to: "Zerlege den folgenden Text in Aufgaben:\n\n\(input)",
                    generating: AIExtractedTodoBatch.self
                )

                for try await snapshot in stream {
                    if Task.isCancelled { return }
                    // Aufgaben live anzeigen, sobald ihr Titel vollständig ist.
                    let todos = (snapshot.content.todos ?? []).compactMap { AIExtractedTodo(partial: $0) }
                    self.candidates = todos.map { Candidate(todo: $0) }
                }

                if self.candidates.isEmpty {
                    self.phase = .failed(AIL("ai_plan_nothing_found"))
                } else {
                    self.phase = .ready
                }
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(AIErrorText.describe(error))
            }
        }
    }

    // MARK: - Stufe 2: Tagesplan bauen

    /// Plant die ausgewählten Kandidaten plus optional die heute fälligen Aufgaben.
    func buildPlan(includeExistingTodos: Bool = true) {
        var fixed: [String: TimeOfDay] = [:]
        var appointments: [(title: String, time: TimeOfDay)] = []
        var lines: [String] = []

        /// Eine Aufgabe mit genannter Uhrzeit wandert als fester Termin in den Prompt.
        func append(title: String, priority: String, minutes: Int, time: TimeOfDay?) {
            if let time {
                fixed[Self.titleKey(title)] = time
                appointments.append((title, time))
                lines.append("- \(title) (FESTER TERMIN um \(time.text), geschätzt \(minutes) Minuten)")
            } else {
                lines.append("- \(title) (Priorität \(priority), geschätzt \(minutes) Minuten)")
            }
        }

        for item in selectedCandidates.map(\.todo) {
            append(
                title: item.title,
                priority: item.priority,
                minutes: item.estimatedMinutes,
                time: Self.parseTime(item.dueTime)
            )
        }

        if includeExistingTodos {
            for todo in AIContext.todaysTodos() {
                append(
                    title: todo.title,
                    priority: todo.priority.rawValue,
                    minutes: todo.focusTimeInMinutes.map { Int($0) } ?? 30,
                    time: todo.dueDate.flatMap(Self.userChosenTime)
                )
            }
        }

        fixedTimes = fixed

        guard !lines.isEmpty else {
            phase = .failed(AIL("ai_plan_nothing_to_plan"))
            return
        }
        guard AIAvailability.shared.isAvailable else {
            phase = .failed(AIAvailability.shared.message)
            return
        }

        task?.cancel()
        streamingBlocks = []
        summary = ""
        plan = nil
        phase = .planning

        let fixedNote: String = appointments.isEmpty ? "" : {
            let list = appointments
                .sorted { $0.time.minutesOfDay < $1.time.minutesOfDay }
                .map { "\($0.title) um \($0.time.text)" }
                .joined(separator: ", ")
            return " Diese Termine liegen fest und dürfen nicht verschoben werden: \(list)."
        }()
        let window = "Plane ausschließlich zwischen \(String(format: "%02d:00", startHour)) "
            + "und \(String(format: "%02d:00", endHour)) Uhr." + fixedNote
        let taskList = lines.joined(separator: "\n")

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let context = AIContext.plannerContext
                let session = LanguageModelSession {
                    BeeAIPrompts.plannerInstructions
                    context
                }
                let stream = session.streamResponse(
                    to: "\(window)\n\nDiese Aufgaben sollen heute untergebracht werden:\n\(taskList)",
                    generating: AIDayPlan.self
                )

                var deferred: [String] = []
                for try await snapshot in stream {
                    if Task.isCancelled { return }
                    let content = snapshot.content
                    if let text = content.summary { self.summary = text }
                    let blocks = (content.blocks ?? []).compactMap { AIPlanBlock(partial: $0) }
                    self.streamingBlocks = Self.pinFixedTimes(in: blocks, fixed: self.fixedTimes)
                    if let list = content.deferred { deferred = list }
                }

                // Der letzte Snapshot enthält den vollständigen Plan.
                self.streamingBlocks = Self.pinFixedTimes(in: self.streamingBlocks, fixed: self.fixedTimes)
                self.plan = AIDayPlan(
                    summary: self.summary,
                    blocks: self.streamingBlocks,
                    deferred: deferred
                )
                self.phase = .ready
            } catch is CancellationError {
                self.phase = .idle
            } catch {
                self.phase = .failed(AIErrorText.describe(error))
            }
        }
    }

    // MARK: - Übernahme in die App

    /// Legt die ausgewählten Aufgaben als Todos an (ohne Zeitblöcke).
    @discardableResult
    func applyCandidates() -> Int {
        let store = TodoStore.shared
        var created = 0
        for candidate in selectedCandidates {
            let extracted = candidate.todo
            let category = store.categories.first {
                $0.name.localizedCaseInsensitiveCompare(extracted.category) == .orderedSame
            }
            let todo = TodoItem(
                title: extracted.title,
                description: extracted.details,
                dueDate: extracted.mappedDueDate,
                category: category,
                categoryID: category?.id,
                priority: extracted.mappedPriority,
                subTasks: extracted.mappedSubTasks,
                focusTimeInMinutes: Double(extracted.estimatedMinutes),
                endDate: extracted.mappedEndDate
            )
            store.addTodo(todo)
            created += 1
        }
        return created
    }

    /// Übernimmt den Tagesplan: legt je Block eine terminierte Aufgabe an und
    /// trägt sie zusätzlich in die Eisenhower-Matrix ein.
    @discardableResult
    func applyPlan() -> Int {
        guard let plan else { return 0 }
        let store = TodoStore.shared
        let eisenhower = EisenhowerStore.shared
        let today = Date()
        var created = 0

        for block in plan.blocks where block.kind != "break" {
            guard let start = AIDateFormat.time(block.start, on: today) else { continue }
            let end = start.addingTimeInterval(TimeInterval(block.durationMinutes * 60))

            // Bereits vorhandene Aufgabe mit gleichem Titel nur terminieren,
            // statt ein Duplikat anzulegen.
            if var existing = store.todos.first(where: {
                !$0.isCompleted && !$0.isDeleted &&
                $0.title.localizedCaseInsensitiveCompare(block.title) == .orderedSame
            }) {
                existing.dueDate = start
                existing.endDate = end
                existing.focusTimeInMinutes = Double(block.durationMinutes)
                store.updateTodo(existing)
                if let quadrant = EisenhowerQuadrant(rawValue: block.quadrant) {
                    eisenhower.assign(existing.id, to: quadrant)
                }
                created += 1
                continue
            }

            let todo = TodoItem(
                title: block.title,
                description: block.reason,
                dueDate: start,
                priority: TodoPriority(rawValue: block.priority) ?? .medium,
                focusTimeInMinutes: Double(block.durationMinutes),
                endDate: end
            )
            store.addTodo(todo)
            if let quadrant = EisenhowerQuadrant(rawValue: block.quadrant) {
                eisenhower.assign(todo.id, to: quadrant)
            }
            created += 1
        }

        // Was nicht mehr passt, landet als undatierte Aufgabe in der Liste.
        for title in plan.deferred {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }
            guard !store.todos.contains(where: {
                !$0.isDeleted && $0.title.localizedCaseInsensitiveCompare(clean) == .orderedSame
            }) else { continue }
            // Ein fester Termin wird nicht "auf später verschoben" – er behält seine Uhrzeit.
            if let time = fixedTimes[Self.titleKey(clean)] {
                let due = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: today)
                store.addTodo(TodoItem(title: clean, dueDate: due, priority: .medium))
            } else {
                store.addTodo(TodoItem(title: clean, priority: .low))
            }
        }

        return created
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    func reset() {
        cancel()
        candidates = []
        plan = nil
        streamingBlocks = []
        summary = ""
        fixedTimes = [:]
    }

    // MARK: - Feste Termine

    /// Setzt Blöcke mit fester Uhrzeit auf genau diese Zeit zurück, falls das
    /// Modell sie trotz Anweisung verschoben hat, und sortiert danach wieder
    /// chronologisch. Eine falsche Uhrzeit ist schlimmer als eine Lücke im Plan.
    private static func pinFixedTimes(in blocks: [AIPlanBlock], fixed: [String: TimeOfDay]) -> [AIPlanBlock] {
        guard !fixed.isEmpty else { return blocks }
        var result = blocks
        for index in result.indices {
            guard let time = fixed[titleKey(result[index].title)] else { continue }
            result[index].start = time.text
        }
        return result.sorted { startMinutes($0.start) < startMinutes($1.start) }
    }

    private static func titleKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    /// Liest "HH:mm". Leerer oder unplausibler Text bedeutet: keine Uhrzeit genannt.
    private static func parseTime(_ hhmm: String) -> TimeOfDay? {
        let parts = hhmm.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return TimeOfDay(hour: parts[0], minute: parts[1])
    }

    private static func startMinutes(_ hhmm: String) -> Int {
        parseTime(hhmm)?.minutesOfDay ?? Int.max
    }

    /// Erkennt, ob an einer Fälligkeit eine vom Nutzer gewollte Uhrzeit hängt.
    /// 00:00 und 09:00 setzt die App selbst, wenn nur ein Tag bekannt ist
    /// (siehe `AIDateFormat.date(day:time:)`) - alles andere ist ein echter Termin.
    private static func userChosenTime(of date: Date) -> TimeOfDay? {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return nil }
        if minute == 0, hour == 0 || hour == 9 { return nil }
        return TimeOfDay(hour: hour, minute: minute)
    }
}
