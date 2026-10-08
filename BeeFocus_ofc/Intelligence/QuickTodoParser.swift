//
//  QuickTodoParser.swift
//  BeeFocus_ofc
//
//  Wandelt einen gesprochenen oder getippten Satz in eine fertige Aufgabe um –
//  ohne Apple Intelligence, also auch auf iOS 18. Beispiele:
//  "schlafen gehen um 23 Uhr" → Titel "Schlafen gehen", fällig heute 23:00.
//  "ich brauche Milch, Brot und Eier" → eine Aufgabe "Einkaufen" mit drei
//  Unteraufgaben – statt drei einzelner Aufgaben.
//

import Foundation

/// Ergebnis der Satzanalyse. Gemeinsames Entwurfsmodell für den regelbasierten
/// Parser und für Apple Intelligence (siehe `AITodoIntelligence.compose`),
/// damit die UI nur ein Modell kennt.
struct QuickTodoDraft: Equatable {
    var title: String
    /// Alles, was nicht in den Titel gehört, aber zur Aufgabe: Ort, Grund, Hinweise.
    var details: String = ""
    /// Die Einzelteile der Aufgabe – werden zu Unteraufgaben.
    var subtasks: [String] = []
    var dueDate: Date?
    /// Wurde eine konkrete Uhrzeit genannt (und nicht nur ein Tag)?
    var hasTime: Bool = false
    var priority: TodoPriority = .medium
    /// Name einer Kategorie, die Apple Intelligence vorgeschlagen hat.
    var categoryName: String = ""
    /// Geschätzte Dauer in Minuten, falls bekannt.
    var estimatedMinutes: Int?
    /// Hat Apple Intelligence den Entwurf verfeinert?
    var isAIRefined: Bool = false
    /// Der Text, aus dem dieser Entwurf entstanden ist – Grundlage für eine
    /// spätere Verfeinerung durch das Sprachmodell.
    var source: String = ""

    var subTaskItems: [SubTask] {
        subtasks.map { SubTask(title: $0) }
    }

    /// Baut daraus die echte Aufgabe. Bei genannter Uhrzeit wird die
    /// Erinnerung punktgenau zur Fälligkeit gesetzt.
    @MainActor
    func makeTodo(category: Category? = nil) -> TodoItem {
        let resolved = category ?? Self.matchedCategory(named: categoryName)
        return TodoItem(
            title: title,
            description: details,
            dueDate: dueDate,
            reminderOffsetMinutes: dueDate != nil ? 0 : nil,
            category: resolved,
            categoryID: resolved?.id,
            priority: priority,
            subTasks: subTaskItems,
            focusTimeInMinutes: estimatedMinutes.map(Double.init)
        )
    }

    @MainActor
    private static func matchedCategory(named name: String) -> Category? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        return TodoStore.shared.categories.first {
            $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame
        }
    }
}

// MARK: - Aufräumen von Modell- und Parserausgaben

extension QuickTodoDraft {

    /// Macht aus einer Modellantwort einen brauchbaren Titel: eine Zeile,
    /// keine Anführungszeichen, kein Satzpunkt, nicht länger als 60 Zeichen.
    static func tidyTitle(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'„“”«»-–—•*: "))
        while text.hasSuffix(".") || text.hasSuffix(",") || text.hasSuffix(";") {
            text = String(text.dropLast())
        }
        guard !text.isEmpty else { return "" }

        // Lange Titel am letzten Wort vor der Grenze abschneiden, nicht mitten im Wort.
        if text.count > 60 {
            let cut = String(text.prefix(60))
            if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > 20 {
                text = String(cut[cut.startIndex..<space])
            } else {
                text = cut
            }
            text = text.trimmingCharacters(in: CharacterSet(charactersIn: " ,;-"))
        }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Räumt eine Liste von Unteraufgaben auf: ohne Aufzählungszeichen,
    /// ohne Leereinträge, ohne Doppelte und ohne Wiederholung des Titels.
    static func tidyItems(_ raw: [String], title: String = "", limit: Int = 20) -> [String] {
        let titleKey = normalizedKey(title)
        var seen = Set<String>()
        var result: [String] = []

        for entry in raw {
            var item = entry
                .replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Führende Aufzählungszeichen und Nummerierungen entfernen.
            item = item.replacingOccurrences(
                of: #"^(?:[-–—•*·]+|\d{1,2}[.)])\s*"#,
                with: "",
                options: .regularExpression
            )
            item = item.trimmingCharacters(in: CharacterSet(charactersIn: " \t.;,-–—\"'„“”"))
            guard !item.isEmpty, item.count <= 60 else { continue }

            let key = normalizedKey(item)
            guard !key.isEmpty, key != titleKey, seen.insert(key).inserted else { continue }
            result.append(item.prefix(1).uppercased() + item.dropFirst())
            if result.count >= limit { break }
        }

        // Ein einzelner Eintrag, der nur den Titel umschreibt, ist keine Liste.
        if result.count == 1 {
            let key = normalizedKey(result[0])
            if !titleKey.isEmpty, key.contains(titleKey) || titleKey.contains(key) {
                return []
            }
        }
        return result
    }

    /// Lässt in der Beschreibung nur stehen, was nicht schon im Titel oder in
    /// den Unteraufgaben steht.
    static func tidyDetails(_ raw: String, title: String = "", items: [String] = [], limit: Int = 600) -> String {
        let itemKeys = Set(items.map(normalizedKey))
        let titleKey = normalizedKey(title)

        let lines = raw
            .components(separatedBy: .newlines)
            .map { line -> String in
                line.replacingOccurrences(
                    of: #"^(?:[-–—•*·]+|\d{1,2}[.)])\s*"#,
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { line in
                guard !line.isEmpty else { return false }
                let key = normalizedKey(line)
                return !key.isEmpty && key != titleKey && !itemKeys.contains(key)
            }

        var text = lines.joined(separator: "\n")
            .replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Eine Beschreibung, die nur den Titel wiederholt, bringt nichts.
        let key = normalizedKey(text)
        if !titleKey.isEmpty, key == titleKey || key.count <= titleKey.count && titleKey.contains(key) {
            return ""
        }
        if text.count > limit {
            text = String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return text
    }

    /// Vergleichsform: klein geschrieben, ohne Satzzeichen und Mehrfach-Leerzeichen.
    static func normalizedKey(_ text: String) -> String {
        text.localizedLowercase
            .replacingOccurrences(of: #"[^\p{L}\p{N} ]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

/// Regelbasierte Erkennung von Zeitangaben, Priorität und Aufzählungen in
/// normaler Sprache. Deckt Deutsch und Englisch ab und braucht kein Sprachmodell.
enum QuickTodoParser {

    // MARK: - Öffentliche API

    /// Zerlegt einen Satz in Titel, Beschreibung, Unteraufgaben, Fälligkeit
    /// und Priorität.
    /// - Parameter reference: Bezugszeitpunkt (für Tests überschreibbar).
    static func parse(_ input: String, reference: Date = Date()) -> QuickTodoDraft {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var working = " " + trimmed + " "

        // Erst Priorität und Zeitangabe herauslösen – danach steht im Rest nur
        // noch, worum es inhaltlich geht. Sonst landet "morgen" am Ende einer
        // Aufzählung im letzten Eintrag ("Eier morgen").
        let priority = extractPriority(from: &working)
        let time = extractTime(from: &working)
        let day = extractDay(from: &working, reference: reference)
        let trimEdges = day != nil || time != nil

        var title = ""
        var details = ""
        var items: [String] = []

        // Steckt eine Aufzählung im Satz, wird daraus eine Aufgabe mit
        // Unteraufgaben – nicht eine Aufgabe pro genanntem Ding.
        if let list = extractList(in: working) {
            items = list.items
            let rest = cleanTitle(list.rest, fallback: "", trimEdges: trimEdges)
            let restIsUsable = rest.count >= 3 && !isFillerOnly(rest)

            if list.headIsTitle, restIsUsable {
                title = rest
            } else {
                // Der Titel benennt das Vorhaben ("Einkaufen"), alles weitere
                // Gesagte gehört in die Beschreibung.
                title = list.label
                if restIsUsable { details = rest }
            }
        } else {
            title = cleanTitle(working, fallback: trimmed, trimEdges: trimEdges)
        }

        return QuickTodoDraft(
            title: QuickTodoDraft.tidyTitle(title),
            details: details,
            subtasks: QuickTodoDraft.tidyItems(items, title: title),
            dueDate: dueDate(day: day, time: time, reference: reference),
            hasTime: time != nil,
            priority: priority,
            source: trimmed
        )
    }

    /// Zerlegt einen mehrzeiligen Text in mehrere Entwürfe. Eine Zeile mit
    /// Doppelpunkt und die Aufzählungspunkte darunter gehören zusammen:
    ///
    ///     Einkaufen:
    ///     - Milch
    ///     - Brot
    ///
    /// wird eine Aufgabe mit zwei Unteraufgaben.
    static func drafts(from text: String, reference: Date = Date()) -> [QuickTodoDraft] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result: [QuickTodoDraft] = []
        var index = 0

        while index < lines.count {
            let header = lines[index]
            let opensList = header.hasSuffix(":")
            var items: [String] = []
            var sawBullet = false
            var next = index + 1

            // Folgezeilen einsammeln, solange sie wie Listeneinträge aussehen.
            // Sobald Aufzählungszeichen im Spiel sind, zählen nur noch diese –
            // eine Zeile ohne Zeichen ist dann wieder eine eigene Aufgabe.
            while next < lines.count {
                let line = lines[next]
                let isBullet = isBulletLine(line)
                let fitsUnderHeader = opensList && !line.hasSuffix(":")
                    && line.count <= 40 && looksLikeThing(line)

                if isBullet {
                    sawBullet = true
                } else if sawBullet || !fitsUnderHeader {
                    break
                }
                items.append(line)
                next += 1
            }

            if items.isEmpty {
                result.append(parse(header, reference: reference))
            } else {
                var draft = parse(opensList ? String(header.dropLast()) : header, reference: reference)
                draft.subtasks = QuickTodoDraft.tidyItems(draft.subtasks + items, title: draft.title)
                draft.source = ([header] + items).joined(separator: "\n")
                result.append(draft)
            }
            index = next
        }

        return result
    }

    private static func isBulletLine(_ line: String) -> Bool {
        line.range(of: #"^(?:[-–—•*·]+|\d{1,2}[.)])\s+\S"#, options: .regularExpression) != nil
    }

    /// Setzt Tag und Uhrzeit zu einer Fälligkeit zusammen.
    private static func dueDate(day: Date?, time: TimeOfDay?, reference: Date) -> Date? {
        let cal = Calendar.current
        switch (day, time) {
        case let (day?, time?):
            return cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
        case let (day?, nil):
            // Nur ein Tag genannt: als Tagesziel auf 9:00 legen.
            return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)
        case let (nil, time?):
            // Nur eine Uhrzeit: heute, und wenn schon vorbei, dann morgen.
            guard let today = cal.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: reference)
            else { return nil }
            return today <= reference ? cal.date(byAdding: .day, value: 1, to: today) : today
        case (nil, nil):
            return nil
        }
    }

    // MARK: - Aufzählungen

    /// Wofür eine erkannte Aufzählung steht – bestimmt den Titel der Aufgabe.
    private enum ListKind {
        case shopping
        case packing
        case todo

        var title: String {
            switch self {
            case .shopping: return AIL("quick_list_title_shopping")
            case .packing:  return AIL("quick_list_title_packing")
            case .todo:     return AIL("quick_list_title_todo")
            }
        }
    }

    /// Wörter, die eine Aufzählung von Dingen ankündigen.
    private static let listTriggers: [(words: [String], kind: ListKind)] = [
        (["einkaufen", "einkaufsliste", "lebensmittel", "shopping list", "grocery list", "groceries", "go shopping"], .shopping),
        (["brauche", "braucht", "benötige", "besorgen", "kaufen", "holen", "mitbringen",
           "need to buy", "need", "buy", "pick up"], .shopping),
        (["einpacken", "packen", "packliste", "mitnehmen", "pack", "packing list", "bring"], .packing),
        (["erledigen", "abarbeiten", "to do", "aufgaben", "tasks"], .todo)
    ]

    /// Füllwörter, die am Anfang einer Aufzählung stehen können.
    private static let listFillers = [
        "ich muss noch", "ich muss", "ich sollte", "ich will noch", "ich will", "ich möchte",
        "wir müssen noch", "wir müssen", "wir brauchen", "noch", "auch noch", "auch", "bitte",
        "unbedingt", "dringend", "heute noch", "ich", "wir", "für", "fuer",
        "i have to", "i need to", "i must", "i should", "we need to", "we need", "please", "also",
        "i", "we", "for"
    ]

    /// Findet eine Aufzählung im Satz.
    /// - Returns: die Einzelteile, der übrige Satzteil und ob dieser als Titel
    ///   taugt (beim Doppelpunkt ja, bei einem Auslösewort nicht).
    private static func extractList(
        in text: String
    ) -> (items: [String], rest: String, headIsTitle: Bool, label: String)? {
        guard !text.isEmpty else { return nil }

        // 1. Doppelpunkt: "Einkaufen: Milch, Brot, Eier"
        if let colon = text.firstIndex(of: ":") {
            let head = String(text[text.startIndex..<colon])
            let tail = String(text[text.index(after: colon)...])
            let items = splitItems(tail)
            if items.count >= 2 {
                return (items, head, true, kind(for: head)?.title ?? ListKind.todo.title)
            }
        }

        // 2. Auslösewort plus Aufzählung: "ich brauche Milch, Brot und Eier",
        //    "Milch, Brot und Eier kaufen".
        for trigger in listTriggers {
            for word in trigger.words {
                guard let match = firstMatch(wordPattern(word), in: text) else { continue }

                let before = String(text[text.startIndex..<match.range.lowerBound])
                let after = String(text[match.range.upperBound...])
                // Nach einem Auslösewort zählen nur Dinge. "Rezept holen,
                // Paket abgeben und tanken" sind drei Aufgaben, keine Liste.
                let itemsBefore = splitItems(before).filter(looksLikeThing)
                let itemsAfter = splitItems(after).filter(looksLikeThing)

                // Die Seite mit der längeren Aufzählung trägt die Dinge,
                // die andere Seite bleibt für den übrigen Satz.
                if itemsAfter.count >= 2, itemsAfter.count >= itemsBefore.count {
                    return (itemsAfter, before, false, trigger.kind.title)
                }
                if itemsBefore.count >= 2 {
                    return (itemsBefore, after, false, trigger.kind.title)
                }
            }
        }

        return nil
    }

    /// Ordnet einem Listenkopf ("Einkauf:") eine Art zu.
    private static func kind(for header: String) -> ListKind? {
        let lower = header.localizedLowercase
        for trigger in listTriggers where trigger.words.contains(where: { lower.contains($0) }) {
            return trigger.kind
        }
        return nil
    }

    /// Tätigkeiten. Steht eine davon in einem Aufzählungseintrag, ist der
    /// Eintrag kein Ding, sondern eine eigene Aufgabe – dann wird aus dem Satz
    /// keine Dingeliste. Lieber eine Aufgabe zu wenig erkennen als die
    /// Aufgaben des Nutzers zu Einkaufsposten machen.
    private static let actionWords: Set<String> = [
        "abgeben", "abholen", "abwaschen", "anrufen", "antworten", "aufhängen", "aufräumen",
        "ausfüllen", "backen", "bauen", "bezahlen", "bringen", "buchen", "drucken", "düngen",
        "einladen", "erledigen", "fahren", "gehen", "gießen", "kochen", "kündigen", "lernen",
        "lesen", "machen", "mähen", "melden", "packen", "planen", "prüfen", "putzen",
        "rausbringen", "reinigen", "reparieren", "schicken", "schreiben", "senden", "sortieren",
        "tanken", "tauschen", "trainieren", "vereinbaren", "vorbereiten", "waschen", "wechseln",
        "wischen", "zahlen", "üben",
        "answer", "book", "buy", "call", "clean", "cook", "fix", "pay", "plan", "prepare",
        "send", "wash", "write"
    ]

    /// Enthält der Text eine Tätigkeit?
    private static func containsActionWord(_ text: String) -> Bool {
        text.localizedLowercase
            .split(whereSeparator: { !$0.isLetter })
            .contains { actionWords.contains(String($0)) }
    }

    /// Sieht der Eintrag nach einem Ding aus (und nicht nach einer Tätigkeit)?
    private static func looksLikeThing(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        return words.count <= 4 && !containsActionWord(text)
    }

    /// Zerlegt "Milch, Brot und Eier" in die einzelnen Dinge.
    private static func splitItems(_ text: String) -> [String] {
        var normalized = stripListFillers(text)
        for joiner in [#"\s+und\s+"#, #"\s+sowie\s+"#, #"\s+and\s+"#, #"\s+plus\s+"#] {
            normalized = normalized.replacingOccurrences(
                of: joiner,
                with: ",",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let parts = normalized
            .components(separatedBy: CharacterSet(charactersIn: ",;\n•·*"))
            .map { part in
                part.replacingOccurrences(of: #"^\s*(?:[-–—]+|\d{1,2}[.)])\s*"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t.-–—"))
            }
            .map(stripListFillers)
            .filter { !$0.isEmpty }

        // Aufzählungen bestehen aus kurzen Nennungen. Ein langer Nebensatz ist
        // keine Liste, sondern Prosa – dann lieber gar keine Liste erkennen.
        guard parts.count >= 2, parts.allSatisfy({ $0.count <= 40 }) else { return [] }
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    }

    private static func stripListFillers(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var changed = true
        while changed {
            changed = false
            for filler in listFillers {
                let lower = result.localizedLowercase
                if lower == filler {
                    return ""
                }
                if lower.hasPrefix(filler + " ") {
                    result = String(result.dropFirst(filler.count + 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    changed = true
                    break
                }
            }
        }
        return result
    }

    /// Füllwörter, die als Titel nichts aussagen.
    private static let emptyTitles = [
        "ich", "wir", "du", "man", "noch", "auch", "dafür", "dazu", "für", "fuer",
        "i", "we", "you", "also", "for", "to"
    ]

    /// Ist vom Satz nach dem Aufräumen nur noch ein Füllwort übrig?
    private static func isFillerOnly(_ text: String) -> Bool {
        let lower = text.localizedLowercase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return true }
        if emptyTitles.contains(lower) || listFillers.contains(lower) { return true }
        if listTriggers.contains(where: { $0.words.contains(lower) }) { return true }
        // "ich noch", "für die" – mehrere Füllwörter hintereinander.
        let words = lower.split(separator: " ").map(String.init)
        return words.count <= 2 && words.allSatisfy {
            emptyTitles.contains($0) || listFillers.contains($0) || ["die", "der", "das", "den", "dem", "the"].contains($0)
        }
    }

    private static func wordPattern(_ word: String) -> String {
        "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
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
        let saysEvening = lower.contains("abend") || lower.contains("nachmittag")
            || firstMatch(#"\d\s*pm\b"#, in: lower) != nil
        // "am" steht im Deutschen für einen Tag ("am Freitag"), nicht für den
        // Vormittag – darum nur die englische Uhrzeitform "8 am" auswerten.
        let saysMorning = lower.contains("morgens") || lower.contains("früh")
            || firstMatch(#"\d\s*am\b"#, in: lower) != nil

        // 0. Tageszeit am Tag: "morgen abend", "Freitag nachmittag".
        //    Nur die Tageszeit wird ersetzt – der Tag muss stehen bleiben,
        //    damit "morgen abend" nicht zu "heute 19 Uhr" wird.
        if let match = firstMatch(
            #"\b(heute|morgen|übermorgen|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)s?\s+(abend|nachmittag|vormittag|nacht|mittag)\b"#,
            in: text
        ), let part = match.string(2)?.localizedLowercase, let range = match.range(of: 2) {
            let hour: Int
            switch part {
            case "abend":      hour = 19
            case "nachmittag": hour = 15
            case "vormittag":  hour = 10
            case "mittag":     hour = 12
            default:           hour = 23   // nacht
            }
            text = text.replacingCharacters(in: range, with: " ")
            return TimeOfDay(hour: hour, minute: 0)
        }

        // 1. "23:30", "8:05"
        if let match = firstMatch(#"(?:um\s+)?(\d{1,2}):(\d{2})"#, in: text),
           let hour = match.int(1), let minute = match.int(2),
           hour <= 23, minute <= 59 {
            text = text.replacingCharacters(in: match.range, with: " ")
            return TimeOfDay(hour: adjust(hour, evening: saysEvening, morning: saysMorning), minute: minute)
        }

        // 1b. "23.30 Uhr", "um 8.15" – mit Punkt nur, wenn "um" oder "Uhr"
        //     dabeisteht. Sonst wäre "12.03." eine Uhrzeit statt eines Datums.
        if let match = firstMatch(#"(?:(?:um|gegen|ab)\s+(\d{1,2})\.(\d{2})(?:\s*uhr)?|(\d{1,2})\.(\d{2})\s*uhr)(?!\s*\.)"#, in: text) {
            let hour = match.int(1) ?? match.int(3)
            let minute = match.int(2) ?? match.int(4)
            if let hour, let minute, hour <= 23, minute <= 59 {
                text = text.replacingCharacters(in: match.range, with: " ")
                return TimeOfDay(hour: adjust(hour, evening: saysEvening, morning: saysMorning), minute: minute)
            }
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
        "ich muss noch", "ich muss", "ich sollte", "ich brauche", "brauche noch", "brauche",
        "remind me to", "remind me", "create a task", "new task", "add task",
        "i want to", "i need to", "i have to"
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
                let rest = String(result.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Nur abschneiden, wenn danach noch eine Aufgabe übrig bleibt.
                guard !rest.isEmpty else { continue }
                result = rest
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

        /// Bereich einer einzelnen Gruppe – um nur einen Teil zu ersetzen.
        func range(of index: Int) -> Range<String.Index>? {
            guard index < result.numberOfRanges else { return nil }
            return Range(result.range(at: index), in: source)
        }
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
