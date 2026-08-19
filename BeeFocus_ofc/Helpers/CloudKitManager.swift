import Foundation
import CloudKit
import Combine
import os

/// Strukturiertes, datenschutzfreundliches Sync-Logging (keine Nutzerinhalte wie Titel).
enum SyncLog {
    private static let logger = Logger(subsystem: "com.TorbenLehneke.BeeFocus", category: "sync")

    static func event(_ message: String) {
        logger.log("[SYNC] \(message, privacy: .public)")
    }

    static func error(operation: String, todoID: UUID? = nil, error: Error) {
        let idPart = todoID?.uuidString ?? "-"
        var retryPart = "-"
        if let ck = error as? CKError, let retry = ck.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
            retryPart = "\(retry)s"
        }
        let code = (error as? CKError)?.code.rawValue ?? -1
        logger.error("[SYNC ERROR] op=\(operation, privacy: .public) todoID=\(idPart, privacy: .public) ckCode=\(code) retryAfter=\(retryPart, privacy: .public) desc=\(error.localizedDescription, privacy: .public)")
    }
}

final class CloudKitManager: ObservableObject {
    /// Feldname für Tombstone-Flag im CloudKit-"Todo"-Record.
    static let isDeletedKey = "isDeleted"
    static let deletedAtKey = "deletedAt"
    #if DEBUG
    static let diagnosticsEnabled = true
    #else
    static let diagnosticsEnabled = false
    #endif

    @Published var lastStatus: CKAccountStatus = .couldNotDetermine
    @Published var lastError: Error?

    static let shared = CloudKitManager()
    
    // --- ERSETZE DIESE CONTAINER-ID mit deinem echten Container-Namen ---
    // Verwende App Group/Bundle Identifier aus Info.plist falls gesetzt, fallback auf harte ID
    private static let defaultContainerID = "iCloud.com.TorbenLehneke.BeeFocus"
    private let container: CKContainer = {
        // Versuche, eine Container-ID aus Info.plist zu lesen: Schlüssel `CloudKitContainerIdentifier`
        if let plistID = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerIdentifier") as? String, !plistID.isEmpty {
            print("ℹ️ Verwende CloudKit-Container aus Info.plist: \(plistID)")
            return CKContainer(identifier: plistID)
        } else {
            print("ℹ️ Verwende Default CloudKit-Container: \(defaultContainerID)")
            return CKContainer(identifier: defaultContainerID)
        }
    }()
    private var database: CKDatabase { container.privateCloudDatabase }
    
    // MARK: - Date Key Helpers for Stats
    private lazy var dateKeyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private func dateKey(for date: Date) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let startUTC = utc.startOfDay(for: date)
        return dateKeyFormatter.string(from: startUTC)
    }

    private func date(fromKey key: String) -> Date? {
        return dateKeyFormatter.date(from: key)
    }
    
    private init() {}
    
    // MARK: - Helper
    private func isTestTitle(_ title: String) -> Bool {
        let lower = title.lowercased()
        // Block any title that contains "cloudkit" in any form
        return lower.contains("cloudkit")
    }
    
    // MARK: - iCloud-Status prüfen
    func checkiCloudStatus() {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                self.lastError = error
                if let error = error {
                    print("❌ iCloud-Fehler: \(error.localizedDescription)")
                }
                self.lastStatus = status
                switch status {
                case .available:
                    print("✅ iCloud verfügbar – Benutzer ist angemeldet und Berechtigungen ok.")
                case .noAccount:
                    print("⚠️ Kein iCloud-Account – In den iOS-Einstellungen mit iCloud anmelden.")
                case .restricted:
                    print("⚠️ iCloud eingeschränkt – Mögliche Kindersicherung/MDM.")
                case .couldNotDetermine:
                    print("⚠️ iCloud-Status unbekannt – später erneut versuchen.")
                @unknown default:
                    print("⚠️ Unbekannter iCloud-Status")
                }
            }
        }
    }

    /// Prüft, ob der Record-Typ "Todo" im CloudKit-Schema existiert (nur Entwicklungsumgebung)
    func validateSchema(completion: ((Bool) -> Void)? = nil) {
        let query = CKQuery(recordType: "Todo", predicate: NSPredicate(value: true))
        database.perform(query, inZoneWith: nil) { _, error in
            DispatchQueue.main.async {
                if let ckError = error as? CKError {
                    switch ckError.code {
                    case .unknownItem, .permissionFailure, .invalidArguments, .partialFailure:
                        print("⚠️ Schema/Permission Hinweis: \(ckError.localizedDescription)")
                    case .notAuthenticated:
                        print("⚠️ Nicht authentifiziert – iCloud am Gerät aktivieren.")
                    default:
                        break
                    }
                }
                if let error = error {
                    print("ℹ️ validateSchema Ergebnisfehler: \(error.localizedDescription)")
                    completion?(false)
                } else {
                    print("✅ Record-Typ 'Todo' ist im Schema erreichbar.")
                    completion?(true)
                }
            }
        }
    }
    
    // MARK: - Todo speichern
    func saveTodo(_ todo: TodoItem) {
        // Prevent saving known test todos to CloudKit
        if isTestTitle(todo.title) {
            DispatchQueue.main.async {
                print("⛔️ Save skipped for test todo title: \(todo.title)")
            }
            return
        }

        if lastStatus != .available {
            print("⚠️ Speichern abgebrochen – iCloud nicht verfügbar (Status: \(lastStatus.rawValue)). Rufe checkiCloudStatus() auf.")
            checkiCloudStatus()
        }

        // 1) Versuche vorhandenen Record über eigene ID zu finden
        let predicate = NSPredicate(format: "id == %@", todo.id.uuidString)
        let query = CKQuery(recordType: "Todo", predicate: predicate)
        let fetchOp = CKQueryOperation(query: query)

        var existingRecord: CKRecord?
        fetchOp.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result { existingRecord = record }
        }
        fetchOp.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            switch result {
            case .success:
                // 2) Konfliktregel: Eine bestätigte Löschung darf nicht durch eine
                // ÄLTERE Bearbeitung wieder auferstehen. Wenn der Cloud-Record bereits
                // ein Tombstone ist und später gelöscht wurde als diese Bearbeitung
                // (deletedAt > updatedAt), überspringen wir das Schreiben.
                if let existing = existingRecord,
                   (existing[Self.isDeletedKey] as? Bool) == true {
                    let deletedAt = (existing[Self.deletedAtKey] as? Date) ?? .distantFuture
                    if deletedAt > todo.updatedAt {
                        SyncLog.event("Upsert skipped – tombstone newer than edit (todoID=\(todo.id) deletedAt=\(deletedAt) > updatedAt=\(todo.updatedAt))")
                        return
                    }
                }
                // 2) Record befüllen (Update oder Neu)
                let record: CKRecord = existingRecord ?? CKRecord(recordType: "Todo")
                record["id"] = todo.id.uuidString as CKRecordValue
                // Lebendiger Datensatz: evtl. vorhandenen Tombstone aufheben.
                record[Self.isDeletedKey] = false as CKRecordValue
                record[Self.deletedAtKey] = nil
                record["title"] = todo.title as CKRecordValue
                record["description"] = todo.description as CKRecordValue
                record["isCompleted"] = todo.isCompleted as CKRecordValue
                if let due = todo.dueDate { record["dueDate"] = due as CKRecordValue } else { record["dueDate"] = nil }
                if let end = todo.endDate { record["endDate"] = end as CKRecordValue } else { record["endDate"] = nil }
                if let offset = todo.reminderOffsetMinutes { record["reminderOffsetMinutes"] = NSNumber(value: offset) } else { record["reminderOffsetMinutes"] = nil }
                record["priority"] = todo.priority.rawValue as CKRecordValue
                record["createdAt"] = todo.createdAt as CKRecordValue
                record["updatedAt"] = todo.updatedAt as CKRecordValue
                if let comp = todo.completedAt { record["completedAt"] = comp as CKRecordValue } else { record["completedAt"] = nil }
                record["calendarEnabled"] = todo.calendarEnabled as CKRecordValue
                record["isFavorite"] = todo.isFavorite as CKRecordValue
                if let calID = todo.calendarEventIdentifier {
                    record["calendarEventIdentifier"] = calID as CKRecordValue
                } else {
                    record["calendarEventIdentifier"] = nil
                }

                if !todo.subTasks.isEmpty, let subTasksData = try? JSONEncoder().encode(todo.subTasks) {
                    record["subTasks"] = subTasksData as CKRecordValue
                } else {
                    record["subTasks"] = nil
                }

                if let category = todo.category, let categoryData = try? JSONEncoder().encode(category) {
                    record["category"] = categoryData as CKRecordValue
                } else {
                    record["category"] = nil
                }

                if let catID = todo.categoryID {
                    record["categoryID"] = catID.uuidString as CKRecordValue
                } else {
                    record["categoryID"] = nil
                }

                // Ordner-Zuweisung (String-Feld) plattformübergreifend synchronisieren.
                // Gleiches Feld wie die macOS-App ("customFolder"), damit Ordner-Zuweisungen
                // zwischen iPhone und Mac übereinstimmen. Kein separates Folder-Record-Schema.
                if let folder = todo.customFolder, !folder.isEmpty {
                    record["customFolder"] = folder as CKRecordValue
                } else {
                    record["customFolder"] = nil
                }

                let saveOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                saveOp.savePolicy = .allKeys  // Verhindert "client oplock error": lokale Version gewinnt immer (record-level LWW)
                saveOp.modifyRecordsResultBlock = { [weak self] (result: Result<Void, Error>) in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            SyncLog.event("Todo uploaded (todoID=\(todo.id))")
                        case .failure(let error):
                            SyncLog.error(operation: "saveTodo", todoID: todo.id, error: error)
                            if let ckError = error as? CKError,
                               [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy].contains(ckError.code) {
                                let delay = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval ?? 2.0
                                SyncLog.event("Retry saveTodo in \(delay)s (todoID=\(todo.id))")
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    self?.saveTodo(todo)
                                }
                            }
                        }
                    }
                }
                self.database.add(saveOp)
            case .failure(let error):
                DispatchQueue.main.async { print("❌ Fehler beim Upsert-Query: \(error.localizedDescription)") }
            }
        }
        database.add(fetchOp)
    }
    
    // Hinweis: Wir vermeiden Predicate/Sort auf `recordName`, da dieses Feld standardmäßig nicht queryable ist.
    // Wenn Sortierung/Filter benötigt werden (z. B. nach `createdAt`), muss im CloudKit Dashboard ein Query-Index für dieses Feld aktiviert werden.
    func fetchTodos(completion: @escaping ([TodoItem]) -> Void) {
        if lastStatus != .available {
            print("ℹ️ Abruf läuft, aber iCloud-Status ist \(lastStatus.rawValue). Prüfe Anmeldung/Berechtigungen.")
        }

        let predicate = NSPredicate(value: true) // keine Filter auf recordName
        let query = CKQuery(recordType: "Todo", predicate: predicate)

        var fetchedRecords: [CKRecord] = []
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 200 // Paging-freundlich; bei Bedarf erhöhen oder Folgeseiten laden
        operation.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Fehler bei recordMatched: \(error.localizedDescription)")
                }
            }
        }
        operation.queryResultBlock = { (finalResult: Result<CKQueryOperation.Cursor?, Error>) in
            DispatchQueue.main.async {
                switch finalResult {
                case .success:
                    // Records in TodoItem umwandeln
                    var result: [TodoItem] = []
                    for record in fetchedRecords {
                        guard
                            let idString = record["id"] as? String,
                            let id = UUID(uuidString: idString),
                            let title = record["title"] as? String,
                            let createdAt = record["createdAt"] as? Date
                        else {
                            continue
                        }

                        let description = record["description"] as? String ?? ""
                        let isCompleted = record["isCompleted"] as? Bool ?? false
                        let dueDate = record["dueDate"] as? Date
                        let endDate = record["endDate"] as? Date
                        let reminderOffset = (record["reminderOffsetMinutes"] as? NSNumber)?.intValue
                        let completedAt = record["completedAt"] as? Date
                        let calendarEnabled = record["calendarEnabled"] as? Bool ?? false
                        let isFavorite = record["isFavorite"] as? Bool ?? false

                        let priorityRaw = record["priority"] as? String ?? "Mittel"
                        let priority = TodoPriority(rawValue: priorityRaw) ?? .medium

                        var subTasks: [SubTask] = []
                        if let data = record["subTasks"] as? Data, data.count > 0,
                           let decoded = try? JSONDecoder().decode([SubTask].self, from: data) {
                            subTasks = decoded
                        }

                        var category: Category? = nil
                        if let data = record["category"] as? Data, data.count > 0,
                           let decoded = try? JSONDecoder().decode(Category.self, from: data) {
                            category = decoded
                        }

                        var categoryID: UUID? = nil
                        if let catIDString = record["categoryID"] as? String {
                            categoryID = UUID(uuidString: catIDString)
                        }

                        // Ordner-Zuweisung aus CloudKit lesen (von Mac oder iPhone gesetzt)
                        let customFolder = record["customFolder"] as? String

                        let updatedAt = (record["updatedAt"] as? Date) ?? createdAt
                        let calendarEventIdentifier = record["calendarEventIdentifier"] as? String

                        let isDeleted = (record[Self.isDeletedKey] as? Bool) ?? ((record[Self.isDeletedKey] as? NSNumber)?.boolValue ?? false)
                        let deletedAt = record[Self.deletedAtKey] as? Date

                        let todo = TodoItem(
                            id: id,
                            title: title,
                            description: description,
                            isCompleted: isCompleted,
                            dueDate: dueDate,
                            reminderOffsetMinutes: reminderOffset,
                            category: category,
                            categoryID: categoryID,
                            priority: priority,
                            subTasks: subTasks,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            completedAt: completedAt,
                            calendarEventIdentifier: calendarEventIdentifier,
                            calendarEnabled: calendarEnabled,
                            isFavorite: isFavorite,
                            customFolder: customFolder,
                            endDate: endDate,
                            isDeleted: isDeleted,
                            deletedAt: deletedAt
                        )
                        result.append(todo)
                    }
                    // Lokal primär nach updatedAt, sekundär nach createdAt absteigend sortieren (neueste zuerst)
                    result.sort { ($0.updatedAt, $0.createdAt) > ($1.updatedAt, $1.createdAt) }
                    completion(result)
                case .failure(let error):
                    // Spezifischer Hinweis für "Field 'recordName' is not marked queryable"
                    let message = error.localizedDescription
                    if message.contains("recordName") && message.contains("not marked queryable") {
                        print("⚠️ CloudKit-Hinweis: Deine Abfrage/SORTIERUNG nutzt implizit 'recordName'. Stelle sicher, dass du im CloudKit Dashboard für deine gewünschten Filter/SORTIERFelder (z. B. 'createdAt') einen Query-Index aktivierst oder verzichte auf Sortierung/Filter auf nicht indexierten Feldern.")
                    }
                    SyncLog.error(operation: "fetchTodos", error: error)
                    if let ckError = error as? CKError, [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy].contains(ckError.code) {
                        let delay = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval ?? 1.5
                        SyncLog.event("Retry fetchTodos in \(delay)s")
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.fetchTodos(completion: completion)
                        }
                        return
                    }
                    completion([])
                }
            }
        }
 
        database.add(operation)
    }

    func runDiagnosticsOnLaunch() {
        guard Self.diagnosticsEnabled else { return }
        print("🧪 CloudKit-Diagnose gestartet…")
        checkiCloudStatus()
        validateSchema()
    }
    
    // MARK: - Todo löschen in CloudKit (Soft-Delete / Tombstone)
    //
    // WICHTIG: Wir löschen den Record NICHT physisch. Ein Hard-Delete kommuniziert
    // die Löschung anderen Geräten nur durch die *Abwesenheit* des Records – ein
    // Gerät, das die Aufgabe noch lokal hält, lädt sie beim nächsten Merge wieder
    // hoch ("Resurrection"). Stattdessen markieren wir den Record als Tombstone
    // (isDeleted=true, deletedAt=now). Alle Geräte lesen den Tombstone, entfernen
    // die Aufgabe lokal und legen sie nie wieder neu an.
    func deleteTodo(_ todo: TodoItem) {
        writeTombstone(for: todo)
    }

    /// Schreibt/aktualisiert einen Tombstone für die gegebene Todo-ID.
    /// Fetch-then-modify über das `id`-Feld; existiert kein Record, wird ein
    /// minimaler Tombstone angelegt (idempotent).
    private func writeTombstone(for todo: TodoItem, retryCount: Int = 0) {
        let now = Date()
        let predicate = NSPredicate(format: "id == %@", todo.id.uuidString)
        let query = CKQuery(recordType: "Todo", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var existing: CKRecord?
        operation.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result { existing = record }
        }
        operation.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            switch result {
            case .success:
                let record = existing ?? CKRecord(recordType: "Todo")
                record["id"] = todo.id.uuidString as CKRecordValue
                // Minimaldaten sicherstellen, damit der Record gültig ist, wenn er neu angelegt wird.
                if record["title"] == nil { record["title"] = todo.title as CKRecordValue }
                if record["createdAt"] == nil { record["createdAt"] = todo.createdAt as CKRecordValue }
                record[Self.isDeletedKey] = true as CKRecordValue
                record[Self.deletedAtKey] = now as CKRecordValue
                record["updatedAt"] = now as CKRecordValue
                let modify = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
                modify.savePolicy = .allKeys
                modify.modifyRecordsResultBlock = { [weak self] (modResult: Result<Void, Error>) in
                    DispatchQueue.main.async {
                        switch modResult {
                        case .success:
                            SyncLog.event("Todo tombstoned (todoID=\(todo.id))")
                        case .failure(let error):
                            SyncLog.error(operation: "deleteTodo", todoID: todo.id, error: error)
                            if let ckError = error as? CKError,
                               [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy].contains(ckError.code),
                               retryCount < 5 {
                                let delay = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval ?? 2.0
                                SyncLog.event("Retry tombstone in \(delay)s (todoID=\(todo.id))")
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    self?.writeTombstone(for: todo, retryCount: retryCount + 1)
                                }
                            }
                        }
                    }
                }
                self.database.add(modify)
            case .failure(let error):
                SyncLog.error(operation: "deleteTodo.query", todoID: todo.id, error: error)
                if let ckError = error as? CKError,
                   [.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy].contains(ckError.code),
                   retryCount < 5 {
                    let delay = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval ?? 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.writeTombstone(for: todo, retryCount: retryCount + 1)
                    }
                }
            }
        }
        database.add(operation)
    }

    /// Explizite Wiederherstellung (Undo/Papierkorb): hebt einen Tombstone
    /// eindeutig auf – gewinnt bewusst gegen einen älteren Löschzustand.
    func restoreTodo(_ todo: TodoItem) {
        var restored = todo
        restored.isDeleted = false
        restored.deletedAt = nil
        restored.updatedAt = Date() // frischer Zeitstempel ⇒ gewinnt gegen deletedAt
        SyncLog.event("Todo restore requested (todoID=\(todo.id))")
        saveTodo(restored)
    }

    /// Physisches Löschen (Purge) – nur für endgültige Bereinigung alter Tombstones.
    private func purgeRecordIDs(_ ids: [CKRecord.ID], label: String) {
        guard !ids.isEmpty else { return }
        let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
        modify.modifyRecordsResultBlock = { (res: Result<Void, Error>) in
            switch res {
            case .success: SyncLog.event("Purged \(ids.count) records (\(label))")
            case .failure(let error): SyncLog.error(operation: "purge.\(label)", error: error)
            }
        }
        database.add(modify)
    }

    private static let lastTombstonePurgeKey = "lastTombstonePurgeDate"

    /// Startet die Tombstone-Bereinigung höchstens **einmal pro Kalendertag**
    /// (gedrosselt via UserDefaults). Gedacht für den Aufruf beim App-Start.
    func purgeOldTombstonesIfDue(olderThanDays days: Int = 60) {
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: Self.lastTombstonePurgeKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: now) {
            return // heute bereits ausgeführt
        }
        UserDefaults.standard.set(now, forKey: Self.lastTombstonePurgeKey)
        SyncLog.event("Tombstone purge due – running (olderThanDays=\(days))")
        purgeOldTombstones(olderThanDays: days)
    }

    /// Bereinigt alte Tombstones (deletedAt älter als `olderThanDays`, Default 60).
    /// Sicher, solange kein Gerät länger als dieser Zeitraum offline war.
    func purgeOldTombstones(olderThanDays days: Int = 60) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = NSPredicate(format: "%K == 1 AND %K < %@", Self.isDeletedKey, Self.deletedAtKey, cutoff as NSDate)
        let query = CKQuery(recordType: "Todo", predicate: predicate)
        var ids: [CKRecord.ID] = []
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 400
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let rec) = result { ids.append(rec.recordID) }
        }
        op.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            switch result {
            case .success:
                DispatchQueue.main.async { self?.purgeRecordIDs(ids, label: "old-tombstones") }
            case .failure(let error):
                // Fehlender Query-Index ist kein kritischer Fehler – nur Aufräumen entfällt.
                SyncLog.error(operation: "purgeOldTombstones.query", error: error)
            }
        }
        database.add(op)
    }

    /// Uploads local todos to CloudKit if there is local data to push.
    /// This is a convenience used on launch when cloud is empty.
    /// - Parameter todoStore: The source of local todos.
    func uploadTodosIfNeeded(from todoStore: TodoStore) {
        print("⛔️ uploadTodosIfNeeded disabled: Seeding is turned off.")
        return
    }

    /// Performs a one-shot sync: fetch from Cloud, merge into local, then upload any local items not present in Cloud.
    /// Use for a manual "Jetzt synchronisieren" action.
    /// - Parameters:
    ///   - todoStore: The local store to merge into
    ///   - completion: Called on main queue with counts of changed items (todosChanged, dailyStatsChanged, focusStatsChanged)
    func syncNow(todoStore: BeeFocus_ofc.TodoStore, completion: ((Int, Int, Int) -> Void)? = nil) {
        let group = DispatchGroup()
        var todosChanged = 0
        var dailyChanged = 0
        var focusChanged = 0

        group.enter()
        fetchTodos { cloudTodos in
            // Compute changes against current local state
            let oldByID = Dictionary(uniqueKeysWithValues: todoStore.todos.map { ($0.id, $0) })
            // Merge from cloud (source of truth)
            todoStore.mergeFromCloud(cloudTodos)
            // Count changed/new items by comparing updatedAt (since TodoItem == compares only id)
            var count = 0
            for t in cloudTodos {
                if let old = oldByID[t.id] {
                    if old.updatedAt != t.updatedAt { count += 1 }
                } else {
                    count += 1
                }
            }
            todosChanged = count
            // Upload any remaining local items (e.g., newly created offline)
            self.uploadTodosIfNeeded(from: todoStore)
            group.leave()
        }

        group.enter()
        fetchDailyStats { cloudDaily in
            let before = todoStore.dailyStats
            // Cloud als Quelle: lokal anwenden und persistieren
            todoStore.applyDailyStatsFromCloud(cloudDaily)
            // Delta berechnen
            var delta = 0
            for (k, v) in cloudDaily {
                if before[k] != v { delta += 1 }
            }
            dailyChanged = delta
            group.leave()
        }

        group.enter()
        fetchFocusStats { cloudFocus in
            let before = todoStore.dailyFocusMinutes
            // Cloud als Quelle: lokal anwenden und persistieren
            todoStore.applyFocusStatsFromCloud(cloudFocus)
            // Delta berechnen
            var delta = 0
            for (k, v) in cloudFocus {
                if before[k] != v { delta += 1 }
            }
            focusChanged = delta
            group.leave()
        }

        group.enter()
        self.fetchCategories { cloudCategories in
            todoStore.applyCategoriesFromCloud(cloudCategories)
            group.leave()
        }

        group.notify(queue: .main) {
            self.uploadStatsIfNeeded(from: todoStore)
            completion?(todosChanged, dailyChanged, focusChanged)
        }
    }
    
    // MARK: - Bulk delete test records
    /// Deletes all Todo records in CloudKit whose title contains the given substring (case-insensitive).
    /// - Parameters:
    ///   - titleContains: Substring to match in the title (case-insensitive), e.g. "cloudkittest".
    ///   - completion: Called on main queue with the number of deleted records.
    func deleteTestTodos(titleContains: String = "cloudkittest", completion: ((Int) -> Void)? = nil) {
        // Case-insensitive CONTAINS
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", titleContains)
        let query = CKQuery(recordType: "Todo", predicate: predicate)

        var recordIDs: [CKRecord.ID] = []
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 500
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result {
                recordIDs.append(record.recordID)
            }
        }
        op.queryResultBlock = { [weak self] (result: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            switch result {
            case .success:
                if recordIDs.isEmpty {
                    DispatchQueue.main.async { completion?(0) }
                    return
                }
                let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                modify.modifyRecordsResultBlock = { (modResult: Result<Void, Error>) in
                    DispatchQueue.main.async {
                        switch modResult {
                        case .success:
                            print("🗑️ CloudKit: Test-Todos gelöscht: \(recordIDs.count)")
                            completion?(recordIDs.count)
                        case .failure(let error):
                            print("❌ CloudKit Bulk-Löschen fehlgeschlagen: \(error.localizedDescription)")
                            completion?(0)
                        }
                    }
                }
                self.database.add(modify)
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Query für Bulk-Löschen fehlgeschlagen: \(error.localizedDescription)")
                    completion?(0)
                }
            }
        }
        database.add(op)
    }

    /// Deletes all known CloudKit test todos (both legacy and current patterns)
    func deleteAllTestTodos(completion: ((Int) -> Void)? = nil) {
        // First delete entries containing "cloudkittest"
        self.deleteTestTodos(titleContains: "cloudkittest") { firstCount in
            // Then delete entries containing "CloudKit Test"
            self.deleteTestTodos(titleContains: "CloudKit Test") { secondCount in
                let total = firstCount + secondCount
                print("🧹 CloudKit: Gesamte Test-Todos gelöscht: \(total)")
                completion?(total)
            }
        }
    }
    
    // MARK: - Categories
    func fetchCategories(completion: @escaping ([Category]) -> Void) {
        let query = CKQuery(recordType: "Category", predicate: NSPredicate(value: true))
        var records: [CKRecord] = []
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 500
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result {
                records.append(record)
            }
        }
        op.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
            DispatchQueue.main.async {
                let cats: [Category] = records.compactMap { rec in
                    let idString = (rec["id"] as? String) ?? rec.recordID.recordName
                    guard
                        let name = rec["name"] as? String,
                        let colorHex = rec["colorHex"] as? String,
                        let id = UUID(uuidString: idString)
                    else { return nil }
                    return Category(id: id, name: name, colorHex: colorHex)
                }
                completion(cats)
            }
        }
        database.add(op)
    }

    func saveCategory(_ category: Category) {
        let recordID = CKRecord.ID(recordName: category.id.uuidString)
        let record = CKRecord(recordType: "Category", recordID: recordID)
        record["id"] = category.id.uuidString as CKRecordValue
        record["name"] = category.name as CKRecordValue
        record["colorHex"] = category.colorHex as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        database.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Fehler beim Speichern der Kategorie: \(error.localizedDescription)")
                } else {
                    print("✅ Kategorie gespeichert: \(category.name)")
                }
            }
        }
    }

    func deleteCategory(_ category: Category) {
        // Prefer deleting by custom 'id' field to handle legacy records with different recordName
        let idPredicate = NSPredicate(format: "id == %@", category.id.uuidString)
        let idQuery = CKQuery(recordType: "Category", predicate: idPredicate)

        var recordIDsToDelete: [CKRecord.ID] = []
        let idOp = CKQueryOperation(query: idQuery)
        idOp.resultsLimit = 500
        idOp.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result { recordIDsToDelete.append(record.recordID) }
        }
        idOp.queryResultBlock = { [weak self] (_: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            if recordIDsToDelete.isEmpty {
                // Fallback: try delete by name (not unique, but better than nothing)
                let namePredicate = NSPredicate(format: "name == %@", category.name)
                let nameQuery = CKQuery(recordType: "Category", predicate: namePredicate)
                let nameOp = CKQueryOperation(query: nameQuery)
                var nameIDs: [CKRecord.ID] = []
                nameOp.resultsLimit = 500
                nameOp.recordMatchedBlock = { (_: CKRecord.ID, res: Result<CKRecord, Error>) in
                    if case .success(let rec) = res { nameIDs.append(rec.recordID) }
                }
                nameOp.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
                    let ids = nameIDs
                    if ids.isEmpty {
                        DispatchQueue.main.async {
                            print("ℹ️ CloudKit: Keine Kategorie-Records zum Löschen gefunden (id/name) für \(category.name)")
                        }
                        return
                    }
                    let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
                    modify.modifyRecordsResultBlock = { (res: Result<Void, Error>) in
                        DispatchQueue.main.async {
                            switch res {
                            case .success:
                                print("🗑️ Kategorie gelöscht (Fallback Name): \(category.name) – Records: \(ids.count)")
                            case .failure(let error):
                                print("❌ Fehler beim Löschen der Kategorie (Fallback Name): \(error.localizedDescription)")
                            }
                        }
                    }
                    self.database.add(modify)
                }
                self.database.add(nameOp)
                return
            }
            // Primary path: delete by matching id
            let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
            modify.modifyRecordsResultBlock = { (result: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        print("🗑️ Kategorie gelöscht: \(category.name) – Records: \(recordIDsToDelete.count)")
                    case .failure(let error):
                        print("❌ Fehler beim Löschen der Kategorie: \(error.localizedDescription)")
                    }
                }
            }
            self.database.add(modify)
        }
        database.add(idOp)
    }

    // MARK: - Statistics (DailyStat & FocusStat)
    /// Fetches all daily completion stats from CloudKit.
    /// Record Type: DailyStat, Fields: dateKey(String), count(Int64), updatedAt(Date)
    func fetchDailyStats(completion: @escaping ([Date: Int]) -> Void) {
        let query = CKQuery(recordType: "DailyStat", predicate: NSPredicate(value: true))
        var map: [Date: Int] = [:]
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1000
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result {
                if let key = record["dateKey"] as? String,
                   let countNumber = record["count"] as? NSNumber,
                   let date = self.date(fromKey: key) {
                    map[date] = countNumber.intValue
                }
            }
        }
        op.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
            DispatchQueue.main.async { completion(map) }
        }
        database.add(op)
    }

    /// Upserts a daily completion stat for a given date.
    ///
    /// **Monotoner Upsert (max):** Der geteilte `DailyStat`-Record wird von BEIDEN
    /// Plattformen beschrieben – iOS zählt lokal erledigte Aufgaben, der Mac erhöht
    /// denselben Record (`MacTodoStore.recordCompletion`). Früher überschrieb iOS den
    /// Record mit seinem lokalen Wert und konnte damit die Beiträge des Macs (oder
    /// umgekehrt) auslöschen. Jetzt lesen wir den aktuellen Cloud-Wert und schreiben
    /// nur, wenn er dadurch STEIGT (`max(existing, count)`). Zusammen mit dem bereits
    /// vorhandenen max-Merge in `applyDailyStatsFromCloud` ist der Zähler damit
    /// geräteübergreifend monoton und verlustfrei. Rücknahmen einer Erledigung senken
    /// den geteilten Zähler bewusst nicht mehr (kein Datenverlust > exakte Rücknahme).
    func saveDailyStat(date: Date, count: Int) {
        let key = dateKey(for: date)
        // Deterministische Record-ID: kein Query-Index nötig, keine Duplikate.
        let recordID = CKRecord.ID(recordName: "DailyStat-" + key)
        database.fetch(withRecordID: recordID) { [weak self] fetched, error in
            guard let self = self else { return }
            // Transienter Lesefehler (Netzwerk o. ä.): NICHT blind neu anlegen/überschreiben,
            // sonst droht genau der Clobber, den wir verhindern wollen. `unknownItem` = Record
            // existiert noch nicht → regulär anlegen.
            if let ckErr = error as? CKError, ckErr.code != .unknownItem {
                print("ℹ️ DailyStat: Lesen fehlgeschlagen (\(ckErr.code.rawValue)) – Write übersprungen für key=\(key)")
                return
            }
            let record = fetched ?? CKRecord(recordType: "DailyStat", recordID: recordID)
            let existing = (record["count"] as? NSNumber)?.intValue ?? 0
            let newValue = max(existing, count)
            // Keinen unnötigen Write auslösen, wenn sich der Cloud-Wert nicht erhöht.
            if fetched != nil && newValue == existing { return }
            record["dateKey"]   = key as CKRecordValue
            record["count"]     = NSNumber(value: newValue)
            record["updatedAt"] = Date() as CKRecordValue
            self.database.save(record) { _, saveError in
                if let saveError = saveError {
                    print("❌ Fehler beim Speichern DailyStat: \(saveError.localizedDescription)")
                } else {
                    print("✅ DailyStat upsert (max): key=\(key) count=\(newValue)")
                }
            }
        }
    }

    /// Fetches all daily focus minutes from CloudKit.
    /// Record Type: FocusStat, Fields: dateKey(String), minutes(Int64), updatedAt(Date)
    func fetchFocusStats(completion: @escaping ([Date: Int]) -> Void) {
        let query = CKQuery(recordType: "FocusStat", predicate: NSPredicate(value: true))
        var map: [Date: Int] = [:]
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1000
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result {
                if let key = record["dateKey"] as? String,
                   let minutesNumber = record["minutes"] as? NSNumber,
                   let date = self.date(fromKey: key) {
                    map[date] = minutesNumber.intValue
                }
            }
        }
        op.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
            DispatchQueue.main.async { completion(map) }
        }
        database.add(op)
    }

    /// Upserts a daily focus minutes stat for a given date.
    func saveFocusStat(date: Date, minutes: Int) {
        let key = dateKey(for: date)
        // Use a deterministic record ID to avoid duplicates and to not require a query index
        let recordID = CKRecord.ID(recordName: "FocusStat-" + key)
        let record = CKRecord(recordType: "FocusStat", recordID: recordID)
        record["dateKey"] = key as CKRecordValue
        record["minutes"] = NSNumber(value: minutes)
        record["updatedAt"] = Date() as CKRecordValue
        database.save(record) { _, error in
            if let error = error {
                print("❌ Fehler beim Speichern FocusStat: \(error.localizedDescription)")
            } else {
                print("✅ FocusStat upsert: key=\(key) minutes=\(minutes)")
            }
        }
    }
    
    /// Deduplicates Category records in CloudKit by name (case-insensitive),
    /// reassigns Todos that reference duplicate category IDs to the kept ID,
    /// then deletes the duplicate Category records.
    /// - Parameter completion: Called with (deletedCategories, updatedTodos)
    func deduplicateCategories(completion: ((Int, Int) -> Void)? = nil) {
        // 1) Fetch all Category records
        let catQuery = CKQuery(recordType: "Category", predicate: NSPredicate(value: true))
        let catOp = CKQueryOperation(query: catQuery)
        var catRecords: [CKRecord] = []
        catOp.resultsLimit = 1000
        catOp.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let rec) = result { catRecords.append(rec) }
        }
        catOp.queryResultBlock = { [weak self] (_: Result<CKQueryOperation.Cursor?, Error>) in
            guard let self = self else { return }
            // Group by normalized name
            var groups: [String: [CKRecord]] = [:]
            for rec in catRecords {
                let name = (rec["name"] as? String) ?? ""
                let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                groups[key, default: []].append(rec)
            }
            var loserIDs: [CKRecord.ID] = []
            var mapping: [String: String] = [:] // loser idString -> winner idString
            var winnerByKey: [String: CKRecord] = [:]

            for (key, records) in groups {
                guard records.count > 1 else { continue }
                // Pick winner by updatedAt (field) or creationDate
                let sorted = records.sorted { a, b in
                    let au = (a["updatedAt"] as? Date) ?? a.modificationDate ?? a.creationDate ?? Date.distantPast
                    let bu = (b["updatedAt"] as? Date) ?? b.modificationDate ?? b.creationDate ?? Date.distantPast
                    return au > bu
                }
                guard let winner = sorted.first else { continue }
                winnerByKey[key] = winner
                let winnerIDString = (winner["id"] as? String) ?? winner.recordID.recordName
                // All others are losers
                for rec in sorted.dropFirst() {
                    loserIDs.append(rec.recordID)
                    let loserIDString = (rec["id"] as? String) ?? rec.recordID.recordName
                    mapping[loserIDString] = winnerIDString
                }
            }

            if loserIDs.isEmpty {
                DispatchQueue.main.async { completion?(0, 0) }
                return
            }

            // 2) Fetch all Todo records to reassign categoryID
            let todoQuery = CKQuery(recordType: "Todo", predicate: NSPredicate(value: true))
            let todoOp = CKQueryOperation(query: todoQuery)
            var todoRecords: [CKRecord] = []
            todoOp.resultsLimit = 2000
            todoOp.recordMatchedBlock = { (_: CKRecord.ID, res: Result<CKRecord, Error>) in
                if case .success(let rec) = res { todoRecords.append(rec) }
            }
            todoOp.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
                // Prepare modifications for todos
                var toSave: [CKRecord] = []
                var updatedTodos = 0
                for rec in todoRecords {
                    if let oldCatID = rec["categoryID"] as? String, let newCatID = mapping[oldCatID] {
                        rec["categoryID"] = newCatID as CKRecordValue
                        // Update embedded category data to winner if available
                        // Determine winner by name group
                        // We don't have direct access by ID here; acceptable to clear embedded category to let app resolve by ID
                        rec["category"] = nil
                        updatedTodos += 1
                        toSave.append(rec)
                    }
                }
                // 3) Save modified todos, then delete loser categories
                let modifyTodos = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: nil)
                modifyTodos.modifyRecordsResultBlock = { [weak self] (todoSaveResult: Result<Void, Error>) in
                    guard let self = self else { return }
                    switch todoSaveResult {
                    case .success:
                        let deleteCats = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: loserIDs)
                        deleteCats.modifyRecordsResultBlock = { (delRes: Result<Void, Error>) in
                            DispatchQueue.main.async {
                                switch delRes {
                                case .success:
                                    print("🧹 CloudKit: Kategorie-Duplikate gelöscht: \(loserIDs.count)")
                                    completion?(loserIDs.count, updatedTodos)
                                case .failure(let err):
                                    print("❌ Fehler beim Löschen von Duplikat-Kategorien: \(err.localizedDescription)")
                                    completion?(0, updatedTodos)
                                }
                            }
                        }
                        self.database.add(deleteCats)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            print("❌ Fehler beim Speichern der Todo-Neuzuordnungen: \(error.localizedDescription)")
                            completion?(0, 0)
                        }
                    }
                }
                self.database.add(modifyTodos)
            }
            self.database.add(todoOp)
        }
        database.add(catOp)
    }
    
    /// Uploads local statistics (daily completion counts and focus minutes) to CloudKit.
    /// This is idempotent because `saveDailyStat`/`saveFocusStat` upsert by dateKey.
    func uploadStatsIfNeeded(from todoStore: BeeFocus_ofc.TodoStore) {
        let dailyCount = todoStore.dailyStats.count
        let focusCount = todoStore.dailyFocusMinutes.count
        print("⬆️ UploadStats: pushing \(dailyCount) daily stats, \(focusCount) focus stats")
        // Push daily completion stats
        for (date, count) in todoStore.dailyStats {
            self.saveDailyStat(date: date, count: count)
        }
        // Push focus minutes
        for (date, minutes) in todoStore.dailyFocusMinutes {
            self.saveFocusStat(date: date, minutes: minutes)
        }
    }
    
    // MARK: - Delete all stats
    /// Deletes all DailyStat records from CloudKit.
    func deleteAllDailyStats(completion: ((Int) -> Void)? = nil) {
        let query = CKQuery(recordType: "DailyStat", predicate: NSPredicate(value: true))
        var ids: [CKRecord.ID] = []
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1000
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let rec) = result { ids.append(rec.recordID) }
        }
        op.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
            if ids.isEmpty { DispatchQueue.main.async { completion?(0) }; return }
            let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
            modify.modifyRecordsResultBlock = { (res: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        print("🗑️ CloudKit: DailyStat gelöscht: \(ids.count)")
                        completion?(ids.count)
                    case .failure(let error):
                        print("❌ Fehler beim Löschen DailyStat: \(error.localizedDescription)")
                        completion?(0)
                    }
                }
            }
            self.database.add(modify)
        }
        database.add(op)
    }

    /// Deletes all FocusStat records from CloudKit.
    func deleteAllFocusStats(completion: ((Int) -> Void)? = nil) {
        let query = CKQuery(recordType: "FocusStat", predicate: NSPredicate(value: true))
        var ids: [CKRecord.ID] = []
        let op = CKQueryOperation(query: query)
        op.resultsLimit = 1000
        op.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let rec) = result { ids.append(rec.recordID) }
        }
        op.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
            if ids.isEmpty { DispatchQueue.main.async { completion?(0) }; return }
            let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: ids)
            modify.modifyRecordsResultBlock = { (res: Result<Void, Error>) in
                DispatchQueue.main.async {
                    switch res {
                    case .success:
                        print("🗑️ CloudKit: FocusStat gelöscht: \(ids.count)")
                        completion?(ids.count)
                    case .failure(let error):
                        print("❌ Fehler beim Löschen FocusStat: \(error.localizedDescription)")
                        completion?(0)
                    }
                }
            }
            self.database.add(modify)
        }
        database.add(op)
    }

    /// Convenience to delete all stats of both types.
    func deleteAllStats(completion: ((Int, Int) -> Void)? = nil) {
        let group = DispatchGroup()
        var daily = 0
        var focus = 0
        group.enter()
        deleteAllDailyStats { count in daily = count; group.leave() }
        group.enter()
        deleteAllFocusStats { count in focus = count; group.leave() }
        group.notify(queue: .main) { completion?(daily, focus) }
    }
}

