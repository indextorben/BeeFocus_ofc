//
//  AIGeneratedTypes.swift
//  BeeFocus_ofc
//
//  @Generable-Schemata: garantiert strukturierte Ausgaben des On-Device-Modells.
//  Kein Text-Parsing, keine kaputten JSON-Antworten.
//

import Foundation
import FoundationModels

// MARK: - Aufgaben-Extraktion

@available(iOS 26.0, *)
@Generable(description: "Eine einzelne, konkrete Aufgabe, die aus Freitext extrahiert wurde")
struct AIExtractedTodo: Equatable {
    @Guide(description: "Kurzer, handlungsorientierter Titel im Imperativ, maximal 60 Zeichen. Ohne Datum, ohne Uhrzeit und ohne Aufzählung der Einzelteile.")
    var title: String

    @Guide(description: "Alles Zusätzliche, was der Nutzer gesagt hat: Ort, Personen, Grund, Hinweise – in ganzen Sätzen. Leerer String, wenn es nichts gibt. Was als Unteraufgabe steht, hier nicht wiederholen.")
    var details: String

    @Guide(description: "Priorität der Aufgabe", .anyOf(["low", "medium", "high"]))
    var priority: String

    @Guide(description: "Name der passenden Kategorie aus der vorgegebenen Liste. Leerer String, wenn keine passt.")
    var category: String

    @Guide(description: "Fälligkeitsdatum im Format yyyy-MM-dd. Leerer String, wenn kein Datum genannt oder ableitbar ist.")
    var dueDate: String

    @Guide(description: "Uhrzeit im Format HH:mm (24 Stunden). Leerer String, wenn keine Uhrzeit genannt wurde.")
    var dueTime: String

    @Guide(description: "Geschätzte Dauer in Minuten, realistisch zwischen 5 und 480", .range(5...480))
    var estimatedMinutes: Int

    @Guide(description: "Die Einzelteile der Aufgabe: bei Einkaufs-, Besorgungs- oder Packlisten je genanntes Ding ein Eintrag mit dem Namen des Dings (ohne \"kaufen\" davor), sonst die Arbeitsschritte mit einem Verb am Anfang. Leer, wenn die Aufgabe nur aus einer Sache besteht.", .maximumCount(20))
    var subtasks: [String]
}

@available(iOS 26.0, *)
@Generable(description: "Liste aller Aufgaben, die im Text stecken")
struct AIExtractedTodoBatch {
    @Guide(description: "Jede genannte Aufgabe genau einmal. Nichts erfinden, was nicht im Text steht.", .maximumCount(15))
    var todos: [AIExtractedTodo]
}

// MARK: - Aufgaben-Anreicherung (Feature 5)

@available(iOS 26.0, *)
@Generable(description: "Automatische Einordnung einer Aufgabe")
struct AITodoClassification {
    @Guide(description: "Name der am besten passenden Kategorie aus der vorgegebenen Liste. Leerer String, wenn keine passt.")
    var category: String

    @Guide(description: "Priorität", .anyOf(["low", "medium", "high"]))
    var priority: String

    @Guide(description: "Eisenhower-Quadrant: wichtig und dringend = q1, wichtig aber nicht dringend = q2, dringend aber nicht wichtig = q3, keins von beidem = q4", .anyOf(["q1", "q2", "q3", "q4"]))
    var quadrant: String

    @Guide(description: "Geschätzte Dauer in Minuten", .range(5...480))
    var estimatedMinutes: Int
}

@available(iOS 26.0, *)
@Generable(description: "Vorgeschlagene Unteraufgaben zur Zerlegung einer Aufgabe")
struct AISubtaskSuggestions {
    @Guide(description: "Konkrete, einzeln abhakbare Einträge in sinnvoller Reihenfolge. Arbeitsschritte beginnen mit einem Verb; bei Einkaufs- oder Packlisten steht nur der Name des Dings.", .count(3...12))
    var subtasks: [String]
}

// MARK: - Tagesplan (Feature 2)

@available(iOS 26.0, *)
@Generable(description: "Ein Zeitblock im Tagesplan")
struct AIPlanBlock: Equatable {
    @Guide(description: "Titel der Aufgabe für diesen Block")
    var title: String

    @Guide(description: "Startzeit im Format HH:mm (24 Stunden)")
    var start: String

    @Guide(description: "Dauer des Blocks in Minuten", .range(10...240))
    var durationMinutes: Int

    @Guide(description: "Blocktyp: deep für konzentrierte Arbeit, admin für Kleinkram, break für Pausen", .anyOf(["deep", "admin", "break"]))
    var kind: String

    @Guide(description: "Ein kurzer Satz, warum der Block gerade hier liegt")
    var reason: String

    @Guide(description: "Priorität", .anyOf(["low", "medium", "high"]))
    var priority: String

    @Guide(description: "Eisenhower-Quadrant", .anyOf(["q1", "q2", "q3", "q4"]))
    var quadrant: String
}

@available(iOS 26.0, *)
@Generable(description: "Ein vollständig durchgeplanter Tag")
struct AIDayPlan {
    @Guide(description: "Ein motivierender Satz, der den Tag zusammenfasst. Maximal 140 Zeichen.")
    var summary: String

    @Guide(description: "Die Blöcke in chronologischer Reihenfolge, ohne Überlappungen, mit Pausen nach längeren Fokusblöcken.", .count(2...14))
    var blocks: [AIPlanBlock]

    @Guide(description: "Aufgaben, die heute keinen Platz mehr haben und auf später verschoben werden sollten.", .maximumCount(10))
    var deferred: [String]
}

// MARK: - Sprach-Assistent (Feature 1)

@available(iOS 26.0, *)
@Generable(description: "Interpretation eines gesprochenen Befehls, wenn keine Aktion ausgeführt werden konnte")
struct AICommandFallback {
    @Guide(description: "Kurze, freundliche Antwort in der Sprache des Nutzers. Maximal 200 Zeichen.")
    var reply: String
}

// MARK: - Semantische Suche (Feature 5)

@available(iOS 26.0, *)
@Generable(description: "Treffer einer semantischen Aufgabensuche")
struct AISearchResult {
    @Guide(description: "Die Nummern der passenden Aufgaben aus der vorgegebenen Liste, beste zuerst.", .maximumCount(10))
    var matches: [Int]
}

// MARK: - Mapping-Helfer

@available(iOS 26.0, *)
extension AIExtractedTodo {
    var mappedPriority: TodoPriority {
        TodoPriority(rawValue: priority.lowercased()) ?? .medium
    }

    /// Kombiniert `dueDate` und `dueTime` zu einem echten `Date`.
    var mappedDueDate: Date? {
        AIDateFormat.date(day: dueDate, time: dueTime)
    }

    var mappedEndDate: Date? {
        guard let start = mappedDueDate, !dueTime.isEmpty else { return nil }
        return start.addingTimeInterval(TimeInterval(estimatedMinutes * 60))
    }

    var mappedSubTasks: [SubTask] {
        subtasks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { SubTask(title: $0) }
    }
}

@available(iOS 26.0, *)
extension AITodoClassification {
    var mappedPriority: TodoPriority {
        TodoPriority(rawValue: priority.lowercased()) ?? .medium
    }
}

/// Einheitliche Datumsformate für die Kommunikation mit dem Modell.
enum AIDateFormat {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let dayTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func string(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// Baut aus Tages- und Zeit-String ein `Date`. Beide Teile dürfen leer sein.
    static func date(day: String, time: String) -> Date? {
        let d = day.trimmingCharacters(in: .whitespaces)
        let t = time.trimmingCharacters(in: .whitespaces)

        if !d.isEmpty && !t.isEmpty {
            if let combined = dayTimeFormatter.date(from: "\(d) \(t)") { return combined }
        }
        if !d.isEmpty {
            if let dayOnly = dayFormatter.date(from: d) {
                // Ohne Uhrzeit: 9:00 morgens als neutraler Standard
                return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayOnly) ?? dayOnly
            }
        }
        if !t.isEmpty {
            // Nur Uhrzeit genannt -> heute, oder morgen falls schon vorbei
            let parts = t.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            let cal = Calendar.current
            guard let today = cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) else { return nil }
            return today > Date() ? today : cal.date(byAdding: .day, value: 1, to: today)
        }
        return nil
    }

    /// Wandelt "HH:mm" relativ zu einem Bezugstag in ein `Date`.
    static func time(_ hhmm: String, on day: Date) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }
}

// MARK: - Modellantwort in einen Entwurf übersetzen

@available(iOS 26.0, *)
extension QuickTodoDraft {

    /// Baut aus der Modellantwort einen Entwurf und bügelt die typischen
    /// Schwächen aus: leerer oder geschwätziger Titel, Datum im Titel, doppelte
    /// Einträge, Einzelteile, die zusätzlich in der Beschreibung stehen.
    ///
    /// `fallback` ist der regelbasierte Entwurf derselben Eingabe. Er springt
    /// überall ein, wo das Modell nichts geliefert hat – und bei Datum und
    /// Priorität geht er sogar vor, weil er sich an den Wortlaut hält.
    init(model: AIExtractedTodo, fallback: QuickTodoDraft) {
        var title = QuickTodoDraft.tidyTitle(model.title)
        if title.count < 3 { title = fallback.title }

        var items = QuickTodoDraft.tidyItems(model.subtasks, title: title)
        if items.isEmpty { items = QuickTodoDraft.tidyItems(fallback.subtasks, title: title) }

        var details = QuickTodoDraft.tidyDetails(model.details, title: title, items: items)
        if details.isEmpty {
            details = QuickTodoDraft.tidyDetails(fallback.details, title: title, items: items)
        }

        // Eine vom Nutzer wörtlich genannte Zeit schlägt die Rechnung des Modells.
        let modelDue = model.mappedDueDate
        let due = fallback.dueDate ?? modelDue
        let hasTime: Bool
        if fallback.dueDate != nil {
            hasTime = fallback.hasTime
        } else {
            hasTime = !model.dueTime.trimmingCharacters(in: .whitespaces).isEmpty
        }

        self.init(
            title: title,
            details: details,
            subtasks: items,
            dueDate: due,
            hasTime: hasTime,
            priority: fallback.priority == .medium ? model.mappedPriority : fallback.priority,
            categoryName: model.category.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedMinutes: max(5, min(480, model.estimatedMinutes)),
            isAIRefined: true,
            source: fallback.source
        )
    }
}

// MARK: - Teilweise generierte Werte

// Während des Streamings liefert das Modell `PartiallyGenerated`-Werte, in
// denen jedes Feld optional ist. Diese Initializer bauen daraus einen
// vollständigen Wert, sobald genug Felder vorliegen – damit die UI live
// mitwachsen kann, ohne halbe Einträge anzuzeigen.

@available(iOS 26.0, *)
extension AIPlanBlock {
    init?(partial: AIPlanBlock.PartiallyGenerated) {
        guard
            let title = partial.title, !title.isEmpty,
            let start = partial.start, start.contains(":"),
            let duration = partial.durationMinutes
        else { return nil }

        self.init(
            title: title,
            start: start,
            durationMinutes: duration,
            kind: partial.kind ?? "deep",
            reason: partial.reason ?? "",
            priority: partial.priority ?? "medium",
            quadrant: partial.quadrant ?? "q2"
        )
    }
}

@available(iOS 26.0, *)
extension AIExtractedTodo {
    init?(partial: AIExtractedTodo.PartiallyGenerated) {
        guard let title = partial.title, !title.isEmpty else { return nil }
        self.init(
            title: title,
            details: partial.details ?? "",
            priority: partial.priority ?? "medium",
            category: partial.category ?? "",
            dueDate: partial.dueDate ?? "",
            dueTime: partial.dueTime ?? "",
            estimatedMinutes: partial.estimatedMinutes ?? 30,
            subtasks: partial.subtasks ?? []
        )
    }
}
