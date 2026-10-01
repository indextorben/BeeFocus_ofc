//
//  QuickTodoParser.swift
//  BeeFocus_ofc
//
//  Wandelt einen gesprochenen oder getippten Satz in eine fertige Aufgabe um –
//  ohne Apple Intelligence, also auch auf iOS 18. Beispiel:
//  "schlafen gehen um 23 Uhr" → Titel "Schlafen gehen", fällig heute 23:00.
//

import Foundation

/// Ergebnis der Satzanalyse.
struct QuickTodoDraft: Equatable {
    var title: String
    var dueDate: Date?
    /// Wurde eine konkrete Uhrzeit genannt (und nicht nur ein Tag)?
    var hasTime: Bool = false
    var priority: TodoPriority = .medium

    /// Baut daraus die echte Aufgabe. Bei genannter Uhrzeit wird die
    /// Erinnerung punktgenau zur Fälligkeit gesetzt.
    func makeTodo(category: Category? = nil) -> TodoItem {
        TodoItem(
            title: title,
            dueDate: dueDate,
            reminderOffsetMinutes: dueDate != nil ? 0 : nil,
            category: category,
            categoryID: category?.id,
            priority: priority
        )
    }
}

/// Regelbasierte Erkennung von Zeitangaben und Priorität in normaler Sprache.
/// Deckt Deutsch und Englisch ab und braucht kein Sprachmodell.
enum QuickTodoParser {

    // MARK: - Öffentliche API

    /// Zerlegt einen Satz in Titel, Fälligkeit und Priorität.
    /// - Parameter reference: Bezugszeitpunkt (für Tests überschreibbar).
    static func parse(_ input: String, reference: Date = Date()) -> QuickTodoDraft {
        var working = " " + input.trimmingCharacters(in: .whitespacesAndNewlines) + " "

        let priority = extractPriority(from: &working)
        let time = extractTime(from: &working)
        let day = extractDay(from: &working, reference: reference)

        // Bindewörter nur aufräumen, wenn überhaupt eine Zeitangabe entfernt
        // wurde – sonst verliert "am Auto arbeiten" sein "am".
        let title = cleanTitle(working, fallback: input, trimEdges: day != nil || time != nil)

        var due: Date?
        var hasTime = false
        let cal = Calendar.current

        switch (day, time) {
        case let (day?, time?):
            due = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
            hasTime = true
        case let (day?, nil):
            // Nur ein Tag genannt: als Tagesziel auf 9:00 legen.
            due = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        case let (nil, time?):
            // Nur eine Uhrzeit: heute, und wenn schon vorbei, dann morgen.
            let today = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: reference)
            if let today, today <= reference {
                due = cal.date(byAdding: .day, value: 1, to: today)
            } else {
                due = today
            }
            hasTime = true
        case (nil, nil):
            due = nil
        }

        return QuickTodoDraft(title: title, dueDate: due, hasTime: hasTime, priority: priority)
    }

    // MARK: - Priorität

    private static let highWords = [
        "ganz wichtig", "sehr wichtig", "wichtig", "dringend", "eilt", "asap",
        "important", "urgent", "high priority"
    ]
    private static let lowWords = [
        "unwichtig", "irgendwann", "kann warten", "nicht dringend",
        "someday", "low priority", "whenever"
    ]

    private static func extractPriority(from text: inout String) -> TodoPriority {
        for word in lowWords where remove(word, from: &text) { return .low }
        for word in highWords where remove(word, from: &text) { return .high }
        if text.contains("!!") {
            text = text.replacingOccurrences(of: "!", with: "")
            return .high
        }
        return .medium
    }

    // MARK: - Uhrzeit

    private struct TimeOfDay { var hour: Int; var minute: Int }

    /// Feste Tageszeiten als Rückfallebene, wenn keine Zahl genannt wurde.
    private static let namedTimes: [(String, Int, Int)] = [
        ("heute nacht", 23, 0), ("mitternacht", 0, 0), ("midnight", 0, 0),
        ("am morgen", 8, 0), ("morgens", 8, 0), ("früh", 8, 0), ("in the morning", 8, 0),
        ("mittags", 12, 0), ("zu mittag", 12, 0), ("at noon", 12, 0), ("noon", 12, 0),
        ("nachmittags", 15, 0), ("am nachmittag", 15, 0), ("in the afternoon", 15, 0),
        ("abends", 19, 0), ("am abend", 19, 0), ("in the evening", 19, 0),
        ("nachts", 22, 0), ("at night", 22, 0),
        ("halb eins", 12, 30), ("halb zwei", 13, 30), ("halb drei", 14, 30),
        ("halb vier", 15, 30), ("halb fünf", 16, 30), ("halb sechs", 17, 30),
        ("halb sieben", 18, 30), ("halb acht", 19, 30), ("halb neun", 20, 30),
        ("halb zehn", 21, 30), ("halb elf", 22, 30), ("halb zwölf", 23, 30)
    ]

    /// Zahlwörter eins–zwölf, damit "um acht Uhr" erkannt wird.
    private static let numberWords: [String: Int] = [
        "ein": 1, "eins": 1, "zwei": 2, "drei": 3, "vier": 4, "fünf": 5, "sechs": 6,
        "sieben": 7, "acht": 8, "neun": 9, "zehn": 10, "elf": 11, "zwölf": 12,
        "eine": 1, "einer": 1, "einem": 1,
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
        "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12
    ]

    private static func extractTime(from text: inout String) -> TimeOfDay? {
        // Tageshälfte merken, bevor sie beim Aufräumen verloren geht.
        let lower = text.lowercased()
        let saysEvening = lower.contains("abend") || lower.contains(" pm") || lower.contains("nachmittag")
        let saysMorning = lower.contains("morgens") || lower.contains(" am ") || lower.contains("früh")

        // 1. "23:30", "23.30 Uhr", "8:05"
        if let match = firstMatch(#"(?:um\s+)?(\d{1,2})[:.](\d{2})(?:\s*uhr)?"#, in: text),
           let hour = match.int(1), let minute = match.int(2),
           hour <= 23, minute <= 59 {
            text = text.replacingCharacters(in: match.range, with: " ")
            return TimeOfDay(hour: adjust(hour, evening: saysEvening, morning: saysMorning), minute: minute)
        }

        // 2. "um 23 Uhr", "23 Uhr", "um 7"
        if let match = firstMatch(#"(?:um|gegen|ab)\s+(\d{1,2})(?:\s*uhr)?(?![:.\d])"#, in: text),
           let hour = match.int(1), hour <= 23 {
            text = text.replacingCharacters(in: match.range, with: " ")
            return TimeOfDay(hour: adjust(hour, evening: saysEvening, morning: saysMorning), minute: 0)
        }
        if let match = firstMatch(#"(\d{1,2})\s*uhr"#, in: text),
           let hour = match.int(1), hour <= 23 {
            text = text.replacingCharacters(in: match.range, with: " ")
            return TimeOfDay(hour: adjust(hour, evening: saysEvening, morning: saysMorning), minute: 0)
        }

        // 3. "8 pm", "8am"
        if let match = firstMatch(#"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#, in: text),
           let hour = match.int(1), hour <= 12 {
            let minute = match.int(2) ?? 0
            let isPM = match.string(3)?.lowercased() == "pm"
            text = text.replacingCharacters(in: match.range, with: " ")
            let resolved = isPM ? (hour == 12 ? 12 : hour + 12) : (hour == 12 ? 0 : hour)
            return TimeOfDay(hour: resolved, minute: minute)
        }

        // 4. "halb acht", "abends", "mittags"
        for (phrase, hour, minute) in namedTimes where remove(phrase, from: &text) {
            return TimeOfDay(hour: hour, minute: minute)
        }

        // 5. "um acht Uhr", "um acht"
        for (word, value) in numberWords {
            if let match = firstMatch(#"(?:um|gegen|at)\s+\#(word)(?:\s*uhr)?\b"#, in: text) {
                text = text.replacingCharacters(in: match.range, with: " ")
                return TimeOfDay(hour: adjust(value, evening: saysEvening, morning: saysMorning), minute: 0)
            }
        }

        return nil
    }

    /// "um 8" abends bedeutet 20 Uhr – kleine Zahlen sinnvoll verschieben.
    private static func adjust(_ hour: Int, evening: Bool, morning: Bool) -> Int {
        guard evening, !morning, hour >= 1, hour <= 11 else { return hour }
        return hour + 12
    }

    // MARK: - Tag

    private static let weekdayWords: [(String, Int)] = [
        ("montag", 2), ("monday", 2),
        ("dienstag", 3), ("tuesday", 3),
        ("mittwoch", 4), ("wednesday", 4),
        ("donnerstag", 5), ("thursday", 5),
        ("freitag", 6), ("friday", 6),
        ("samstag", 7), ("sonnabend", 7), ("saturday", 7),
        ("sonntag", 1), ("sunday", 1)
    ]

    private static func extractDay(from text: inout String, reference: Date) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: reference)

        // "übermorgen" vor "morgen" prüfen, sonst schlägt die kürzere Regel zu.
        if remove("übermorgen", from: &text) || remove("day after tomorrow", from: &text) {
            return cal.date(byAdding: .day, value: 2, to: today)
        }
        if remove("morgen abend", from: &text) || remove("morgen früh", from: &text)
            || remove("morgen", from: &text) || remove("tomorrow", from: &text) {
            return cal.date(byAdding: .day, value: 1, to: today)
        }
        if remove("heute abend", from: &text) || remove("heute", from: &text)
            || remove("tonight", from: &text) || remove("today", from: &text) {
            return today
        }

        // "in drei Tagen", "in 2 Wochen"
        // Längere Formen zuerst, sonst bleibt bei "Wochen" ein "n" im Titel stehen.
        if let match = firstMatch(#"in\s+(\d{1,2})\s*(tagen|tage|tag|days|day|wochen|woche|weeks|week)\b"#, in: text),
           let amount = match.int(1), let unit = match.string(2)?.lowercased() {
            text = text.replacingCharacters(in: match.range, with: " ")
            let component: Calendar.Component = unit.hasPrefix("w") ? .weekOfYear : .day
            return cal.date(byAdding: component, value: amount, to: today)
        }
        for (word, value) in numberWords where value <= 12 {
            if let match = firstMatch(#"in\s+\#(word)\s*(tagen|tage|tag|days|day|wochen|woche|weeks|week)\b"#, in: text),
               let unit = match.string(1)?.lowercased() {
                text = text.replacingCharacters(in: match.range, with: " ")
                let component: Calendar.Component = unit.hasPrefix("w") ? .weekOfYear : .day
                return cal.date(byAdding: component, value: value, to: today)
            }
        }

        // "12.03." / "12.3.2026" / "March 12"
        if let match = firstMatch(#"(?:am\s+)?(\d{1,2})\.\s*(\d{1,2})\.(\d{2,4})?"#, in: text),
           let day = match.int(1), let month = match.int(2),
           (1...31).contains(day), (1...12).contains(month) {
            text = text.replacingCharacters(in: match.range, with: " ")
            var comps = DateComponents()
            comps.day = day
            comps.month = month
            comps.year = match.int(3) ?? cal.component(.year, from: reference)
            if let year = comps.year, year < 100 { comps.year = 2000 + year }
            if let date = cal.date(from: comps) {
                // Ohne Jahresangabe: ein bereits vergangenes Datum meint nächstes Jahr.
                if match.int(3) == nil, date < today {
                    return cal.date(byAdding: .year, value: 1, to: date)
                }
                return date
            }
        }

        // Wochentage: "am Freitag", "nächsten Dienstag"
        for (word, weekday) in weekdayWords {
            guard let match = firstMatch(#"(?:(?:am|nächsten|naechsten|next|on)\s+)?\#(word)s?\b"#, in: text) else { continue }
            let phrase = match.string(0)?.lowercased() ?? ""
            let wantsNextWeek = phrase.contains("nächst") || phrase.contains("naechst") || phrase.contains("next")
            text = text.replacingCharacters(in: match.range, with: " ")

            var comps = DateComponents()
            comps.weekday = weekday
            guard var next = cal.nextDate(after: reference, matching: comps, matchingPolicy: .nextTime) else { return nil }
            // "nächsten Montag" meint nur bei sehr nahen Tagen die Folgewoche –
            // ist der Wochentag noch einige Tage entfernt, ist er schon gemeint.
            if wantsNextWeek, cal.dateComponents([.day], from: today, to: next).day ?? 0 < 3 {
                next = cal.date(byAdding: .weekOfYear, value: 1, to: next) ?? next
            }
            return cal.startOfDay(for: next)
        }

        return nil
    }

    // MARK: - Titel aufräumen

    /// Füllwörter, die nach dem Entfernen der Zeitangabe übrig bleiben.
    private static let fillerPrefixes = [
        "erinnere mich daran", "erinnere mich", "erstelle eine aufgabe",
        "erstelle todo", "erstelle ein todo", "neue aufgabe", "aufgabe",
        "merk dir", "merke dir", "notiere", "ich möchte", "ich will",
        "remind me to", "remind me", "create a task", "new task", "add task",
        "i want to", "i need to"
    ]

    private static func cleanTitle(_ text: String, fallback: String, trimEdges: Bool) -> String {
        var result = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Vorangestellte Füllwörter abschneiden.
        var changed = true
        while changed {
            changed = false
            for prefix in fillerPrefixes where result.lowercased().hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                changed = true
                break
            }
        }

        // Verbliebene Bindewörter an den Rändern entfernen.
        // Bewusst knapp gehalten: "an den TÜV" darf nicht zu "den TÜV" werden.
        let edgeWords = ["um", "am", "at", "on", ",", "-", "–"]
        var trimming = trimEdges
        while trimming {
            trimming = false
            for word in edgeWords {
                if result.lowercased().hasPrefix(word + " ") {
                    result = String(result.dropFirst(word.count + 1))
                    trimming = true
                }
                if result.lowercased().hasSuffix(" " + word) {
                    result = String(result.dropLast(word.count + 1))
                    trimming = true
                }
            }
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !result.isEmpty else {
            return fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    // MARK: - Regex-Helfer

    private struct Match {
        let range: Range<String.Index>
        private let result: NSTextCheckingResult
        private let source: String

        init(result: NSTextCheckingResult, source: String) {
            self.result = result
            self.source = source
            self.range = Range(result.range, in: source)!
        }

        func string(_ index: Int) -> String? {
            guard index < result.numberOfRanges,
                  let range = Range(result.range(at: index), in: source) else { return nil }
            return String(source[range])
        }

        func int(_ index: Int) -> Int? { string(index).flatMap { Int($0) } }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Match? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return Match(result: result, source: text)
    }

    /// Entfernt eine Wortgruppe (ganzes Wort) und meldet, ob sie vorkam.
    private static func remove(_ phrase: String, from text: inout String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(result.range, in: text)
        else { return false }
        text = text.replacingCharacters(in: range, with: " ")
        return true
    }
}
