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
        fetchOp.recordMatchedBlock = { _, result in
            if case .success(let record) = result { existingRecord = record }
        }
        fetchOp.queryResultBlock = { [weak self] result in
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
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                fetchedRecords.append(record)
            case .failure(let error):
                DispatchQueue.main.async {
                    print("❌ Fehler bei recordMatched: \(error.localizedDescription)")
                }
            }
        }
        operation.queryResultBlock = { finalResult in
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

                        let updatedAt = (record["updatedAt"] as? Date) ?? createdAt

                        let todo = TodoItem(
                            id: id,
                            title: title,
                            description: description,
                            isCompleted: isCompleted,
                            dueDate: dueDate,
                            category: category,
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
        operation.recordMatchedBlock = { _, result in
            if case .success(let record) = result { recordIDsToDelete.append(record.recordID) }
        }
        operation.queryResultBlock = { result in
            switch result {
            case .success:
                if recordIDsToDelete.isEmpty {
                    // Fallback: Versuche Löschung über den Titel (nicht eindeutig, aber besser als gar nicht)
                    let titlePredicate = NSPredicate(format: "title == %@", todo.title)
                    let titleQuery = CKQuery(recordType: "Todo", predicate: titlePredicate)
                    let titleOp = CKQueryOperation(query: titleQuery)
                    var titleIDs: [CKRecord.ID] = []
                    titleOp.recordMatchedBlock = { _, res in
                        if case .success(let rec) = res { titleIDs.append(rec.recordID) }
                    }
                    titleOp.queryResultBlock = { _ in
                        if titleIDs.isEmpty {
                            DispatchQueue.main.async { print("ℹ️ Kein Record zum Löschen gefunden (Fallback Titel) für title=\(todo.title)") }
                            return
                        }
                        let fallbackModify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: titleIDs)
                        fallbackModify.modifyRecordsResultBlock = { modRes in
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
                modify.modifyRecordsResultBlock = { modResult in
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
    func syncNow(todoStore: TodoStore) {
        fetchTodos { cloudTodos in
            // 1) Merge from cloud (source of truth)
            todoStore.mergeFromCloud(cloudTodos)
            // 2) Upload any remaining local items (e.g., newly created offline)
            self.uploadTodosIfNeeded(from: todoStore)
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
        op.recordMatchedBlock = { _, result in
            if case .success(let record) = result {
                recordIDs.append(record.recordID)
            }
        }
        op.queryResultBlock = { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                if recordIDs.isEmpty {
                    DispatchQueue.main.async { completion?(0) }
                    return
                }
                let modify = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDs)
                modify.modifyRecordsResultBlock = { modResult in
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
}
