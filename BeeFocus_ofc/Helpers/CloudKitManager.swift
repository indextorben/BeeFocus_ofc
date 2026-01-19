import Foundation
import CloudKit
import Combine

final class CloudKitManager: ObservableObject {
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
                // 2) Record befüllen (Update oder Neu)
                let record: CKRecord = existingRecord ?? CKRecord(recordType: "Todo")
                record["id"] = todo.id.uuidString as CKRecordValue
                record["title"] = todo.title as CKRecordValue
                record["description"] = todo.description as CKRecordValue
                record["isCompleted"] = todo.isCompleted as CKRecordValue
                if let due = todo.dueDate { record["dueDate"] = due as CKRecordValue } else { record["dueDate"] = nil }
                if let offset = todo.reminderOffsetMinutes { record["reminderOffsetMinutes"] = NSNumber(value: offset) } else { record["reminderOffsetMinutes"] = nil }
                record["priority"] = todo.priority.rawValue as CKRecordValue
                record["createdAt"] = todo.createdAt as CKRecordValue
                record["updatedAt"] = todo.updatedAt as CKRecordValue
                if let comp = todo.completedAt { record["completedAt"] = comp as CKRecordValue } else { record["completedAt"] = nil }
                record["calendarEnabled"] = todo.calendarEnabled as CKRecordValue
                record["isFavorite"] = todo.isFavorite as CKRecordValue

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

                self.database.save(record) { savedRecord, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ Fehler beim Speichern: \(error.localizedDescription)")
                        } else {
                            print("✅ Todo gespeichert: \(savedRecord?.recordID.recordName ?? "(no id)")")
                        }
                    }
                }
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

                        var category: BeeFocus_ofc.Category? = nil
                        if let data = record["category"] as? Data, data.count > 0,
                           let decoded = try? JSONDecoder().decode(BeeFocus_ofc.Category.self, from: data) {
                            category = decoded
                        }

                        var categoryID: UUID? = nil
                        if let catIDString = record["categoryID"] as? String {
                            categoryID = UUID(uuidString: catIDString)
                        }

                        let updatedAt = (record["updatedAt"] as? Date) ?? createdAt

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
                            calendarEnabled: calendarEnabled,
                            isFavorite: isFavorite
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
                    print("❌ Fehler beim Abrufen: \(message)")
                    if let ckError = error as? CKError, [.networkUnavailable, .serviceUnavailable, .requestRateLimited].contains(ckError.code) {
                        let delay = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval ?? 1.5
                        print("⏳ Temporärer Fehler (\(ckError.code.rawValue)). Erneuter Versuch in \(delay)s…")
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
    
    // MARK: - Todo löschen in CloudKit
    func deleteTodo(_ todo: TodoItem) {
        let predicate = NSPredicate(format: "id == %@", todo.id.uuidString)
        let query = CKQuery(recordType: "Todo", predicate: predicate)
        let operation = CKQueryOperation(query: query)
        var recordIDsToDelete: [CKRecord.ID] = []
        operation.recordMatchedBlock = { (_: CKRecord.ID, result: Result<CKRecord, Error>) in
            if case .success(let record) = result { recordIDsToDelete.append(record.recordID) }
        }
        operation.queryResultBlock = { (result: Result<CKQueryOperation.Cursor?, Error>) in
            switch result {
            case .success:
                if recordIDsToDelete.isEmpty {
                    // Fallback: Versuche Löschung über den Titel (nicht eindeutig, aber besser als gar nicht)
                    let titlePredicate = NSPredicate(format: "title == %@", todo.title)
                    let titleQuery = CKQuery(recordType: "Todo", predicate: titlePredicate)
                    let titleOp = CKQueryOperation(query: titleQuery)
                    var titleIDs: [CKRecord.ID] = []
                    titleOp.recordMatchedBlock = { (_: CKRecord.ID, res: Result<CKRecord, Error>) in
                        if case .success(let rec) = res { titleIDs.append(rec.recordID) }
                    }
                    titleOp.queryResultBlock = { (_: Result<CKQueryOperation.Cursor?, Error>) in
                        if titleIDs.isEmpty {
                            DispatchQueue.main.async { print("ℹ️ Kein Record zum Löschen gefunden (Fallback Titel) für title=\(todo.title)") }
                            return
                        }
                        let fallbackModify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: titleIDs)
                        fallbackModify.modifyRecordsResultBlock = { (modRes: Result<Void, Error>) in
                            DispatchQueue.main.async {
                                switch modRes {
                                case .success:
                                    print("🗑️ CloudKit: Todo per Titel gelöscht (\(titleIDs.count) Records)")
                                case .failure(let err):
                                    print("❌ CloudKit Fallback-Löschen fehlgeschlagen: \(err.localizedDescription)")
                                }
                            }
                        }
                        self.database.add(fallbackModify)
                    }
                    self.database.add(titleOp)
                    return
                }
                let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)
                modify.modifyRecordsResultBlock = { (modResult: Result<Void, Error>) in
                    DispatchQueue.main.async {
                        switch modResult {
                        case .success:
                            print("🗑️ CloudKit: Todo gelöscht (\(recordIDsToDelete.count) Records)")
                        case .failure(let error):
                            print("❌ CloudKit Löschen fehlgeschlagen: \(error.localizedDescription)")
                        }
                    }
                }
                self.database.add(modify)
            case .failure(let error):
                DispatchQueue.main.async { print("❌ Query für Löschen fehlgeschlagen: \(error.localizedDescription)") }
            }
        }
        database.add(operation)
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
    func fetchCategories(completion: @escaping ([BeeFocus_ofc.Category]) -> Void) {
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
                let cats: [BeeFocus_ofc.Category] = records.compactMap { rec in
                    let idString = (rec["id"] as? String) ?? rec.recordID.recordName
                    guard
                        let name = rec["name"] as? String,
                        let colorHex = rec["colorHex"] as? String,
                        let id = UUID(uuidString: idString)
                    else { return nil }
                    return BeeFocus_ofc.Category(id: id, name: name, colorHex: colorHex)
                }
                completion(cats)
            }
        }
        database.add(op)
    }

    func saveCategory(_ category: BeeFocus_ofc.Category) {
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

    func deleteCategory(_ category: BeeFocus_ofc.Category) {
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
    func saveDailyStat(date: Date, count: Int) {
        let key = dateKey(for: date)
        // Use a deterministic record ID to avoid duplicates and to not require a query index
        let recordID = CKRecord.ID(recordName: "DailyStat-" + key)
        let record = CKRecord(recordType: "DailyStat", recordID: recordID)
        record["dateKey"] = key as CKRecordValue
        record["count"] = NSNumber(value: count)
        record["updatedAt"] = Date() as CKRecordValue
        database.save(record) { _, error in
            if let error = error {
                print("❌ Fehler beim Speichern DailyStat: \(error.localizedDescription)")
            } else {
                print("✅ DailyStat upsert: key=\(key) count=\(count)")
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

