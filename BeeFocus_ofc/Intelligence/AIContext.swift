//
//  AIContext.swift
//  BeeFocus_ofc
//
//  Baut kompakte Text-Snapshots der App-Daten, die als Kontext in Prompts
//  wandern. Bewusst knapp gehalten – das Kontextfenster des On-Device-Modells
//  ist begrenzt.
//

import Foundation

@MainActor
enum AIContext {

    // MARK: - Basis

    /// Heutiges Datum inkl. Wochentag, damit das Modell "morgen" auflösen kann.
    static var dateContext: String {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.currentLocale
        f.dateFormat = "EEEE, dd.MM.yyyy"
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"
        return """
        Heute ist \(f.string(from: Date())) (ISO: \(AIDateFormat.string(from: Date()))). \
        Aktuelle Uhrzeit: \(time.string(from: Date())).
        """
    }

    /// Verfügbare Kategorien als Auswahlliste.
    static var categoryContext: String {
        let names = TodoStore.shared.categories.map(\.name)
        guard !names.isEmpty else { return "Es sind keine Kategorien angelegt." }
        return "Verfügbare Kategorien: " + names.joined(separator: ", ") + "."
    }

    // MARK: - Aufgaben

    /// Offene Aufgaben, kompakt und nummeriert.
    static func openTodos(limit: Int = 40) -> String {
        let open = TodoStore.shared.todos
            .filter { !$0.isCompleted && !$0.isDeleted }
            .sorted { lhs, rhs in
                switch (lhs.dueDate, rhs.dueDate) {
                case let (l?, r?): return l < r
                case (nil, _?):    return false
                case (_?, nil):    return true
                default:           return lhs.createdAt < rhs.createdAt
                }
            }
            .prefix(limit)

        guard !open.isEmpty else { return "Es sind aktuell keine Aufgaben offen." }

        let lines = open.enumerated().map { index, todo -> String in
            var parts = ["\(index + 1). \(todo.title)"]
            if let due = todo.dueDate {
                parts.append("fällig \(AIDateFormat.string(from: due))")
            }
            parts.append("Priorität \(todo.priority.rawValue)")
            if let cat = todo.category?.name ?? TodoStore.shared.categories.first(where: { $0.id == todo.categoryID })?.name {
                parts.append("Kategorie \(cat)")
            }
            if !todo.subTasks.isEmpty {
                let done = todo.subTasks.filter(\.isCompleted).count
                parts.append("\(done)/\(todo.subTasks.count) Schritte erledigt")
            }
            return parts.joined(separator: " – ")
        }
        return "Offene Aufgaben:\n" + lines.joined(separator: "\n")
    }

    /// Aufgaben, die heute fällig oder überfällig sind.
    static func todaysTodos() -> [TodoItem] {
        let cal = Calendar.current
        return TodoStore.shared.todos.filter { todo in
            guard !todo.isCompleted, !todo.isDeleted else { return false }
            guard let due = todo.dueDate else { return false }
            return cal.isDateInToday(due) || due < Date()
        }
    }

    // MARK: - Tracker-Daten

    /// Zusammenfassung der letzten 7 Tage über alle Tracker.
    static var weeklyStatsContext: String {
        var lines: [String] = []

        let focus = TodoStore.shared.weeklyFocusData
        if !focus.isEmpty {
            let total = focus.reduce(0) { $0 + $1.minutes }
            lines.append("Fokuszeit letzte 7 Tage: \(total) Minuten (Durchschnitt \(TodoStore.shared.weeklyFocusAverage) min/Tag).")
        }

        let completed = TodoStore.shared.todos.filter {
            guard let done = $0.completedAt else { return false }
            return done > Date().addingTimeInterval(-7 * 86_400)
        }.count
        lines.append("In den letzten 7 Tagen erledigte Aufgaben: \(completed).")

        let sleep = SchlafStore.shared.last7Days().compactMap(\.stunden)
        if !sleep.isEmpty {
            let avg = sleep.reduce(0, +) / Double(sleep.count)
            lines.append(String(format: "Durchschnittlicher Schlaf: %.1f Stunden.", avg))
        }

        let mood = StimmungsStore.shared.last7Days().compactMap(\.stufe)
        if !mood.isEmpty {
            let avg = Double(mood.reduce(0, +)) / Double(mood.count)
            lines.append(String(format: "Durchschnittliche Stimmung: %.1f von 5.", avg))
        }

        let habits = HabitStore.shared.todayProgress()
        if habits.total > 0 {
            lines.append("Gewohnheiten heute: \(habits.done) von \(habits.total) erledigt.")
        }

        let water = WasserStore.shared.last7DaysTotals()
        if let today = water.last {
            lines.append("Wasser heute: \(today.ml) ml von \(WasserStore.shared.tagesziel) ml.")
        }

        return lines.joined(separator: "\n")
    }

    /// Zu welcher Tageszeit der Nutzer erfahrungsgemäß am produktivsten ist.
    static var productivityRhythmContext: String {
        let completions = TodoStore.shared.todos.compactMap(\.completedAt)
        guard completions.count >= 5 else {
            return "Es gibt noch zu wenig Verlaufsdaten, um einen Produktivitätsrhythmus zu erkennen."
        }
        let cal = Calendar.current
        var buckets: [Int: Int] = [:] // 0 = morgens, 1 = mittags, 2 = nachmittags, 3 = abends
        for date in completions {
            let hour = cal.component(.hour, from: date)
            let bucket: Int
            switch hour {
            case 5..<11:  bucket = 0
            case 11..<14: bucket = 1
            case 14..<18: bucket = 2
            default:      bucket = 3
            }
            buckets[bucket, default: 0] += 1
        }
        let names = ["morgens (5–11 Uhr)", "mittags (11–14 Uhr)", "nachmittags (14–18 Uhr)", "abends (18–24 Uhr)"]
        guard let best = buckets.max(by: { $0.value < $1.value }) else { return "" }
        return "Der Nutzer erledigt Aufgaben am häufigsten \(names[best.key]). Lege wichtige Fokusblöcke bevorzugt dorthin."
    }

    // MARK: - Zusammengesetzte Kontexte

    /// Kontext für den Sprach-Assistenten.
    static var assistantContext: String {
        [dateContext, categoryContext, openTodos(limit: 25)].joined(separator: "\n\n")
    }

    /// Kontext für den Tagesplaner.
    static var plannerContext: String {
        [dateContext, categoryContext, productivityRhythmContext].joined(separator: "\n\n")
    }
}
