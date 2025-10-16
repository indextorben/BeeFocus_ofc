import Foundation
import CloudKit
import Combine

final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    // --- ERSETZE DIESE CONTAINER-ID mit deinem echten Container-Namen ---
    private let container = CKContainer(identifier: "iCloud.com.TorbenLehneke.BeeFocus")
    private var database: CKDatabase { container.privateCloudDatabase }
    
    private init() {}
    
    // MARK: - iCloud-Status prüfen
    func checkiCloudStatus() {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ iCloud-Fehler: \(error.localizedDescription)")
                    return
                }
                
                switch status {
                case .available:
                    print("✅ iCloud verfügbar")
                case .noAccount:
                    print("⚠️ Kein iCloud-Account")
                case .restricted:
                    print("⚠️ iCloud eingeschränkt")
                case .couldNotDetermine:
                    print("⚠️ iCloud-Status unbekannt")
                @unknown default:
                    print("⚠️ Unbekannter iCloud-Status")
                }
            }
        }
    }
    
    // MARK: - Todo speichern
    func saveTodo(_ todo: TodoItem) {
        let record = CKRecord(recordType: "Todo")
        record["id"] = todo.id.uuidString as CKRecordValue
        record["title"] = todo.title as CKRecordValue
        record["description"] = todo.description as CKRecordValue
        record["isCompleted"] = todo.isCompleted as CKRecordValue
        if let due = todo.dueDate { record["dueDate"] = due as CKRecordValue }
        record["priority"] = todo.priority.rawValue as CKRecordValue
        record["createdAt"] = todo.createdAt as CKRecordValue
        if let comp = todo.completedAt { record["completedAt"] = comp as CKRecordValue }
        record["calendarEnabled"] = todo.calendarEnabled as CKRecordValue
        record["isFavorite"] = todo.isFavorite as CKRecordValue
        
        // SubTasks als Data speichern (nur wenn nicht leer)
        if !todo.subTasks.isEmpty, let subTasksData = try? JSONEncoder().encode(todo.subTasks) {
            record["subTasks"] = subTasksData as CKRecordValue
        }
        
        // Kategorie als Data speichern (falls vorhanden)
        if let category = todo.category,
           let categoryData = try? JSONEncoder().encode(category) {
            record["category"] = categoryData as CKRecordValue
        }
        
        database.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Fehler beim Speichern: \(error.localizedDescription)")
                } else {
                    print("✅ Todo gespeichert: \(savedRecord?.recordID.recordName ?? "(no id)")")
                }
            }
        }
    }
    
    // MARK: - Todos abrufen
    func fetchTodos(completion: @escaping ([TodoItem]) -> Void) {
        let query = CKQuery(recordType: "Todo", predicate: NSPredicate(value: true))
        
        database.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Fehler beim Abrufen: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                var result: [TodoItem] = []
                
                // Verarbeitung iterativ statt compactMap - vermeidet Typ-Inferenz-Fehler
                for record in (records ?? []) {
                    // Pflichtfelder prüfen
                    guard
                        let idString = record["id"] as? String,
                        let id = UUID(uuidString: idString),
                        let title = record["title"] as? String,
                        let createdAt = record["createdAt"] as? Date
                    else {
                        // Pflichtfeld fehlt -> überspringen
                        continue
                    }
                    
                    // Optionalfelder optional-safe behandeln
                    let description = record["description"] as? String ?? ""
                    let isCompleted = record["isCompleted"] as? Bool ?? false
                    let dueDate = record["dueDate"] as? Date
                    let completedAt = record["completedAt"] as? Date
                    let calendarEnabled = record["calendarEnabled"] as? Bool ?? false
                    let isFavorite = record["isFavorite"] as? Bool ?? false
                    
                    let priorityRaw = record["priority"] as? String ?? "Mittel"
                    let priority = TodoPriority(rawValue: priorityRaw) ?? .medium
                    
                    // SubTasks decodieren (Data safe cast)
                    var subTasks: [SubTask] = []
                    if let data = record["subTasks"] as? Data, data.count > 0,
                       let decoded = try? JSONDecoder().decode([SubTask].self, from: data) {
                        subTasks = decoded
                    }
                    
                    // Kategorie decodieren (Data safe cast)
                    var category: Category? = nil
                    if let data = record["category"] as? Data, data.count > 0,
                       let decoded = try? JSONDecoder().decode(Category.self, from: data) {
                        category = decoded
                    }
                    
                    // Erstelle TodoItem und append
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
                        completedAt: completedAt,
                        calendarEnabled: calendarEnabled,
                        isFavorite: isFavorite
                    )
                    
                    result.append(todo)
                }
                
                completion(result)
            }
        }
    }
}
