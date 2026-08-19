import Foundation
import CloudKit
import Combine
import AppKit
import UserNotifications
import os

/// Strukturiertes Sync-Logging (Mac). Keine Nutzerinhalte.
enum MacSyncLog {
    private static let logger = Logger(subsystem: "com.TorbenLehneke.BeeFocus", category: "sync-mac")
    static func event(_ message: String) { logger.log("[SYNC] \(message, privacy: .public)") }
    static func error(_ op: String, _ error: Error) {
        logger.error("[SYNC ERROR] op=\(op, privacy: .public) desc=\(error.localizedDescription, privacy: .public)")
    }
}

@MainActor
final class MacTodoStore: ObservableObject {
    /// Feldnamen für Tombstone (identisch zu iOS).
    static let isDeletedKey = "isDeleted"
    static let deletedAtKey = "deletedAt"
    @Published var todos: [MacTodoItem] = []
    @Published var categories: [MacCategory] = []
    @Published var isSyncing = false
    @Published var lastSyncError: String? = nil

    private let container  = CKContainer(identifier: "iCloud.com.TorbenLehneke.BeeFocus")
    private var db: CKDatabase { container.privateCloudDatabase }

    // Map from todo.id → CKRecord.ID for updates/deletes
    private var recordIDMap: [UUID: CKRecord.ID] = [:]
    // UUIDs currently being saved by addTodo() — prevents saveToCloudKit creating duplicates
    private var pendingAdds: Set<UUID> = []

    private var syncTimer: Task<Void, Never>?

    init() {
        Task { await fetchCategories() }
        Task { await fetchTodos() }
        startPeriodicSync()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task {
                await self?.fetchCategories()
                await self?.fetchTodos()
            }
        }
    }

    private func startPeriodicSync() {
        syncTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await fetchCategories()
                await fetchTodos()
            }
        }
    }

    // MARK: - Fetch

    func fetchTodos() async {
        isSyncing = true
        lastSyncError = nil
        do {
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: "Todo", predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

            let (results, _) = try await db.records(matching: query, resultsLimit: 200)

            // Deduplicate by UUID — keeps newest updatedAt, schedules CK cleanup for extras
            var byID: [UUID: (MacTodoItem, CKRecord.ID)] = [:]
            var duplicatesToDelete: [CKRecord.ID] = []

            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    if let item = MacTodoItem(record: record) {
                        // Tombstone: nicht anzeigen. Lokale Kopie entfernen, Reminder abbestellen.
                        // Da fetch die Liste vollständig ersetzt, genügt das Auslassen –
                        // der Mac lädt Nur-lokal-Items nie wieder hoch (keine Resurrection).
                        if item.isDeleted {
                            recordIDMap[item.id] = recordID
                            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reminder-\(item.id)"])
                            continue
                        }
                        if let existing = byID[item.id] {
                            if item.updatedAt > existing.0.updatedAt {
                                duplicatesToDelete.append(existing.1)
                                byID[item.id] = (item, recordID)
                            } else {
                                duplicatesToDelete.append(recordID)
                            }
                        } else {
                            byID[item.id] = (item, recordID)
                        }
                    }
                case .failure:
                    break
                }
            }

            var fetched: [MacTodoItem] = []
            for (id, (item, recordID)) in byID {
                fetched.append(item)
                recordIDMap[id] = recordID
            }

            // Kein verlustbehafteter Full-Replace: gerade erstellte, noch nicht
            // hochgeladene Aufgaben (pendingAdds) beibehalten, damit sie nicht
            // kurzzeitig verschwinden, bevor der Upload abgeschlossen ist.
            if !pendingAdds.isEmpty {
                let fetchedIDs = Set(fetched.map { $0.id })
                for local in todos where pendingAdds.contains(local.id) && !fetchedIDs.contains(local.id) {
                    fetched.append(local)
                }
            }

            todos = fetched.sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }

            // Ordner, die per Cloud (z. B. vom iPhone) an Aufgaben hängen, in die lokale
            // Mac-Ordnerliste übernehmen, damit sie auch hier auswählbar/sichtbar sind.
            let existingFolders = Set(customFolders)
            let cloudFolders = todos.compactMap { $0.customFolder }.filter { !$0.isEmpty }
            let newFolders = cloudFolders.filter { !existingFolders.contains($0) }
            if !newFolders.isEmpty {
                var merged = customFolders
                for f in newFolders where !merged.contains(f) { merged.append(f) }
                customFolders = merged
            }

            if !duplicatesToDelete.isEmpty {
                Task {
                    for ckID in duplicatesToDelete {
                        try? await db.deleteRecord(withID: ckID)
                    }
                }
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - Add

    func addTodo(_ item: MacTodoItem) {
        todos.insert(item, at: 0)
        scheduleReminder(for: item)
        pendingAdds.insert(item.id)
        Task {
            do {
                let record = item.toRecord()
                let saved  = try await db.save(record)
                recordIDMap[item.id] = saved.recordID
            } catch {
                lastSyncError = error.localizedDescription
            }
            pendingAdds.remove(item.id)
        }
    }

    // MARK: - Reminder Scheduling

    func scheduleReminder(for item: MacTodoItem) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-\(item.id)"])
        guard let due = item.dueDate,
              let offset = item.reminderOffsetMinutes,
              !item.isCompleted else { return }
        let fireDate = due.addingTimeInterval(-Double(offset) * 60)
        guard fireDate > Date() else { return }
        let content       = UNMutableNotificationContent()
        content.title     = item.title
        content.body      = offset == 0 ? "Jetzt fällig" : "Fällig in \(offset) Minute\(offset == 1 ? "" : "n")"
        content.sound     = .default
        let comps         = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger       = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request       = UNNotificationRequest(identifier: "reminder-\(item.id)", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Toggle Completion

    func toggle(_ item: MacTodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].isCompleted.toggle()
        if todos[idx].isCompleted {
            let now = Date()
            todos[idx].completedAt = now
            recordCompletion(todoID: todos[idx].id, on: now)
        } else {
            todos[idx].completedAt = nil
        }
        todos[idx].updatedAt = Date()
        let updated = todos[idx]
        Task { await saveToCloudKit(updated) }
    }

    // MARK: - Delete

    private(set) var lastDeleted: MacTodoItem? = nil

    func delete(_ item: MacTodoItem) {
        lastDeleted = item
        todos.removeAll { $0.id == item.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["reminder-\(item.id)"])
        Task { await softDeleteInCloud(item) }
    }

    func undo() {
        guard let item = lastDeleted else { return }
        lastDeleted = nil
        // addTodo schreibt über toRecord() isDeleted=false → hebt den Tombstone auf.
        addTodo(item)
    }

    func deleteCompleted() {
        let completed = todos.filter { $0.isCompleted }
        todos.removeAll { $0.isCompleted }
        for item in completed {
            Task { await softDeleteInCloud(item) }
        }
    }

    /// Schreibt einen Tombstone (Soft-Delete) statt den Record physisch zu löschen.
    /// Robust auch OHNE Eintrag in recordIDMap: sucht den Record per `id`-Feld bzw.
    /// legt einen minimalen Tombstone an. Das behebt die frühere Resurrection, bei
    /// der eine fehlende recordID dazu führte, dass in der Cloud gar nichts gelöscht
    /// wurde und die Aufgabe beim nächsten Fetch zurückkehrte.
    private func softDeleteInCloud(_ item: MacTodoItem) async {
        let now = Date()
        do {
            let record: CKRecord
            if let ckID = recordIDMap[item.id], let fetched = try? await db.record(for: ckID) {
                record = fetched
            } else if let found = try await fetchRecord(forTodoID: item.id) {
                record = found
                recordIDMap[item.id] = found.recordID
            } else {
                record = CKRecord(recordType: "Todo")
                record["id"]        = item.id.uuidString as CKRecordValue
                record["title"]     = item.title as CKRecordValue
                record["createdAt"] = item.createdAt as CKRecordValue
            }
            record[Self.isDeletedKey] = true as CKRecordValue
            record[Self.deletedAtKey] = now as CKRecordValue
            record["updatedAt"]       = now as CKRecordValue
            try await db.save(record)
            MacSyncLog.event("Todo tombstoned (todoID=\(item.id))")
        } catch {
            lastSyncError = error.localizedDescription
            MacSyncLog.error("softDelete", error)
        }
    }

    /// Reine Konfliktregel (ohne CloudKit → unit-testbar):
    /// Eine bestätigte Löschung (Tombstone) darf nicht durch eine ÄLTERE Bearbeitung
    /// wieder auferstehen. Gibt `true` zurück, wenn ein Upsert übersprungen werden soll.
    nonisolated static func shouldSkipUpsert(existingIsDeleted: Bool,
                                             existingDeletedAt: Date?,
                                             incomingUpdatedAt: Date) -> Bool {
        guard existingIsDeleted else { return false }
        let deletedAt = existingDeletedAt ?? .distantFuture
        return deletedAt > incomingUpdatedAt
    }

    /// Sucht einen Todo-Record über das benutzerdefinierte `id`-Feld.
    private func fetchRecord(forTodoID id: UUID) async throws -> CKRecord? {
        let query = CKQuery(recordType: "Todo", predicate: NSPredicate(format: "id == %@", id.uuidString))
        let (results, _) = try await db.records(matching: query, resultsLimit: 5)
        for (_, result) in results {
            if case .success(let rec) = result { return rec }
        }
        return nil
    }

    // MARK: - Update

    func update(_ item: MacTodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx] = item
        scheduleReminder(for: item)
        Task { await saveToCloudKit(item) }
    }

    func toggleFavorite(_ item: MacTodoItem) {
        var updated = item
        updated.isFavorite.toggle()
        update(updated)
    }

    // MARK: - Custom Folders

    var customFolders: [String] {
        get {
            let str = UserDefaults.standard.string(forKey: "mac_customFolders") ?? ""
            return str.isEmpty ? [] : str.components(separatedBy: ",").filter { !$0.isEmpty }
        }
        set {
            UserDefaults.standard.set(newValue.joined(separator: ","), forKey: "mac_customFolders")
            objectWillChange.send()
        }
    }

    func addCustomFolder(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty && !customFolders.contains(trimmed) else { return }
        customFolders = customFolders + [trimmed]
    }

    func removeCustomFolder(_ name: String) {
        customFolders = customFolders.filter { $0 != name }
        for todo in todos where todo.customFolder == name {
            var updated = todo; updated.customFolder = nil; update(updated)
        }
    }

    func assignTodo(_ id: UUID, toFolder folder: String?) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].customFolder = folder
        let updated = todos[idx]
        Task { await saveToCloudKit(updated) }
    }

    private func saveToCloudKit(_ item: MacTodoItem) async {
        // If addTodo() is still in flight for this id, skip — it will save the latest state
        guard !pendingAdds.contains(item.id) else { return }
        do {
            if let ckID = recordIDMap[item.id] {
                let record = try await db.record(for: ckID)
                // Konfliktregel: eine bestätigte Löschung darf nicht durch eine ÄLTERE
                // Bearbeitung wieder auferstehen (deletedAt > updatedAt ⇒ Löschung gewinnt).
                if Self.shouldSkipUpsert(existingIsDeleted: (record[Self.isDeletedKey] as? Bool) == true,
                                         existingDeletedAt: record[Self.deletedAtKey] as? Date,
                                         incomingUpdatedAt: item.updatedAt) {
                    MacSyncLog.event("Upsert skipped – tombstone newer than edit (todoID=\(item.id))")
                    return
                }
                let _ = item.toRecord(existingRecord: record) // setzt isDeleted=false (lebendig)
                try await db.save(record)
            } else {
                let record = item.toRecord()
                let saved  = try await db.save(record)
                recordIDMap[item.id] = saved.recordID
            }
        } catch {
            lastSyncError = error.localizedDescription
            MacSyncLog.error("saveToCloudKit", error)
        }
    }

    // MARK: - Filtered Views

    var todayTodos: [MacTodoItem] {
        todos.filter { $0.isDueToday && !$0.isCompleted }
    }

    var tomorrowTodos: [MacTodoItem] {
        let cal = Calendar.current
        let tom    = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        let tomEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tom) ?? tom
        return todos.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return due >= tom && due <= tomEnd
        }
    }

    var thisWeekTodos: [MacTodoItem] {
        let cal = Calendar.current
        let today   = cal.startOfDay(for: Date())
        let weekEnd = cal.date(byAdding: .day, value: 7, to: today) ?? today
        return todos.filter {
            guard let due = $0.dueDate, !$0.isCompleted else { return false }
            return due >= today && due < weekEnd
        }
    }

    var overdueTodos: [MacTodoItem] {
        todos.filter { $0.isOverdue }
    }

    var activeTodos: [MacTodoItem] {
        todos.filter { !$0.isCompleted }
    }

    // MARK: - Categories (read-only; verwaltet auf iOS)

    func fetchCategories() async {
        do {
            let query = CKQuery(recordType: "Category", predicate: NSPredicate(value: true))
            let (results, _) = try await db.records(matching: query, resultsLimit: 500)
            var byID: [UUID: MacCategory] = [:]
            for (_, result) in results {
                guard case .success(let rec) = result else { continue }
                let idString = (rec["id"] as? String) ?? rec.recordID.recordName
                guard let name = rec["name"] as? String,
                      let colorHex = rec["colorHex"] as? String,
                      let id = UUID(uuidString: idString) else { continue }
                byID[id] = MacCategory(id: id, name: name, colorHex: colorHex)
            }
            let sorted = byID.values.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            if sorted != categories { categories = sorted }
        } catch {
            // Bestehende Kategorien beibehalten; nicht als harten Sync-Fehler werten
        }
    }

    func category(for id: UUID?) -> MacCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Category Management (schreibt in denselben "Category"-Record wie iOS)
    //
    // Verwendet dieselbe Datenquelle wie das iPhone: Record-Typ "Category" mit
    // recordName == category.id.uuidString (deterministisch, idempotent – identisch
    // zu CloudKitManager.saveCategory auf iOS). Keine parallele macOS-Kategorie-DB.

    private static let categoryPalette: [String] = [
        "#FF6B6B", "#FF9F43", "#FECA57", "#1DD1A1", "#2ECC71",
        "#54A0FF", "#5F27CD", "#EE5253", "#00D2D3", "#576574"
    ]
    static var suggestedCategoryColors: [String] { categoryPalette }

    /// Nächste noch nicht verwendete Palettenfarbe (Fallback: erste Farbe).
    func nextSuggestedCategoryColor() -> String {
        let used = Set(categories.map { $0.colorHex.uppercased() })
        return Self.categoryPalette.first { !used.contains($0.uppercased()) } ?? Self.categoryPalette[0]
    }

    @discardableResult
    func addCategory(name: String, colorHex: String) -> MacCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Doppelte Namen (case-insensitiv) vermeiden – konsistent zur iOS-Logik.
        if let existing = categories.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let cat = MacCategory(name: trimmed, colorHex: colorHex)
        categories.append(cat)
        sortCategories()
        Task { await saveCategoryToCloud(cat) }
        return cat
    }

    func renameCategory(_ category: MacCategory, to newName: String, colorHex: String? = nil) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let idx = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[idx].name = trimmed
        if let colorHex { categories[idx].colorHex = colorHex }
        let updated = categories[idx]
        sortCategories()
        Task { await saveCategoryToCloud(updated) }
    }

    func deleteCategory(_ category: MacCategory) {
        categories.removeAll { $0.id == category.id }
        // Zuweisung betroffener Aufgaben entfernen (KEIN Cascade-Delete der Aufgaben).
        for todo in todos where todo.categoryID == category.id {
            var updated = todo
            updated.categoryID = nil
            updated.updatedAt = Date()
            update(updated) // pusht die entfernte Zuweisung in die Cloud
        }
        Task { await deleteCategoryFromCloud(category) }
    }

    private func sortCategories() {
        categories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func saveCategoryToCloud(_ category: MacCategory) async {
        let recordID = CKRecord.ID(recordName: category.id.uuidString)
        do {
            // Fetch-then-save: funktioniert sowohl für neue als auch bestehende Records
            // (idempotent, vermeidet "serverRecordChanged" beim Umbenennen).
            let record = (try? await db.record(for: recordID)) ?? CKRecord(recordType: "Category", recordID: recordID)
            record["id"]        = category.id.uuidString as CKRecordValue
            record["name"]      = category.name as CKRecordValue
            record["colorHex"]  = category.colorHex as CKRecordValue
            record["updatedAt"] = Date() as CKRecordValue
            try await db.save(record)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func deleteCategoryFromCloud(_ category: MacCategory) async {
        let recordID = CKRecord.ID(recordName: category.id.uuidString)
        do {
            try await db.deleteRecord(withID: recordID)
        } catch {
            // Fallback: Legacy-Records mit abweichendem recordName per id-Feld finden.
            let query = CKQuery(recordType: "Category", predicate: NSPredicate(format: "id == %@", category.id.uuidString))
            if let (results, _) = try? await db.records(matching: query, resultsLimit: 50) {
                for (recID, res) in results {
                    if case .success = res { try? await db.deleteRecord(withID: recID) }
                }
            }
        }
    }

    // MARK: - Tages-Erledigungsstatistik (geteilter CloudKit-Record "DailyStat")

    private static let countedCompletionsKey = "mac_countedCompletions"

    private var countedCompletions: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.countedCompletionsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.countedCompletionsKey) }
    }

    /// UTC-Tagesschlüssel im Format "yyyy-MM-dd" – identisch zur iOS-Implementierung,
    /// damit Mac und iPhone denselben DailyStat-Record adressieren.
    private func dailyStatKey(for date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = utc.startOfDay(for: date)
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: start)
    }

    /// Zählt eine auf dem Mac erledigte Aufgabe genau einmal pro Tag in die geteilte
    /// Tagesstatistik. Liest den aktuellen Cloud-Zählwert und erhöht ihn um 1 – reduziert
    /// den Wert nie. Ein lokaler Guard verhindert Doppelzählungen desselben Todos am selben Tag.
    private func recordCompletion(todoID: UUID, on date: Date) {
        let key = dailyStatKey(for: date)
        let guardKey = "\(todoID.uuidString)-\(key)"
        // Alte Guard-Einträge (> 14 Tage) entfernen – yyyy-MM-dd sortiert lexikografisch = chronologisch.
        let cutoffKey = dailyStatKey(for: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? date)
        var counted = countedCompletions.filter { entry in
            guard entry.count >= 10 else { return true }
            return String(entry.suffix(10)) >= cutoffKey
        }
        guard !counted.contains(guardKey) else { countedCompletions = counted; return }
        counted.insert(guardKey)
        countedCompletions = counted

        Task {
            let recordID = CKRecord.ID(recordName: "DailyStat-" + key)
            do {
                let existing = try? await db.record(for: recordID)
                let current = (existing?["count"] as? NSNumber)?.intValue ?? 0
                let record = existing ?? CKRecord(recordType: "DailyStat", recordID: recordID)
                record["dateKey"]   = key as CKRecordValue
                record["count"]     = NSNumber(value: current + 1)
                record["updatedAt"] = Date() as CKRecordValue
                try await db.save(record)
            } catch {
                // Fehlgeschlagen: Guard zurücknehmen, damit später erneut gezählt werden kann
                var c = self.countedCompletions
                c.remove(guardKey)
                self.countedCompletions = c
            }
        }
    }
}
