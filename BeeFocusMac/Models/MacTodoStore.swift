import Foundation
import CloudKit
import Combine
import AppKit

@MainActor
final class MacTodoStore: ObservableObject {
    @Published var todos: [MacTodoItem] = []
    @Published var isSyncing = false
    @Published var lastSyncError: String? = nil

    private let container  = CKContainer(identifier: "iCloud.com.TorbenLehneke.BeeFocus")
    private var db: CKDatabase { container.privateCloudDatabase }

    // Map from todo.id → CKRecord.ID for updates/deletes
    private var recordIDMap: [UUID: CKRecord.ID] = [:]

    private var syncTimer: Task<Void, Never>?

    init() {
        Task { await fetchTodos() }
        startPeriodicSync()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.fetchTodos() }
        }
    }

    private func startPeriodicSync() {
        syncTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
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
            var fetched: [MacTodoItem] = []
            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    if let item = MacTodoItem(record: record) {
                        fetched.append(item)
                        recordIDMap[item.id] = recordID
                    }
                case .failure:
                    break
                }
            }
            todos = fetched.sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - Add

    func addTodo(_ item: MacTodoItem) {
        todos.insert(item, at: 0)
        Task {
            do {
                let record = item.toRecord()
                let saved  = try await db.save(record)
                recordIDMap[item.id] = saved.recordID
            } catch {
                lastSyncError = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle Completion

    func toggle(_ item: MacTodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].isCompleted.toggle()
        let updated = todos[idx]
        Task { await saveToCloudKit(updated) }
    }

    // MARK: - Delete

    private(set) var lastDeleted: MacTodoItem? = nil

    func delete(_ item: MacTodoItem) {
        lastDeleted = item
        todos.removeAll { $0.id == item.id }
        guard let ckID = recordIDMap[item.id] else { return }
        Task {
            try? await db.deleteRecord(withID: ckID)
            recordIDMap.removeValue(forKey: item.id)
        }
    }

    func undo() {
        guard let item = lastDeleted else { return }
        lastDeleted = nil
        addTodo(item)
    }

    func deleteCompleted() {
        let completed = todos.filter { $0.isCompleted }
        todos.removeAll { $0.isCompleted }
        for item in completed {
            guard let ckID = recordIDMap[item.id] else { continue }
            recordIDMap.removeValue(forKey: item.id)
            Task { try? await db.deleteRecord(withID: ckID) }
        }
    }

    // MARK: - Update

    func update(_ item: MacTodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx] = item
        Task { await saveToCloudKit(item) }
    }

    func toggleFavorite(_ item: MacTodoItem) {
        var updated = item
        updated.isFavorite.toggle()
        update(updated)
    }

    private func saveToCloudKit(_ item: MacTodoItem) async {
        do {
            let existing = recordIDMap[item.id].map { CKRecord(recordType: "Todo", recordID: $0) }
            if let ckID = recordIDMap[item.id] {
                // fetch then update
                let record = try await db.record(for: ckID)
                let _ = item.toRecord(existingRecord: record)
                try await db.save(record)
            } else {
                let record = item.toRecord()
                let saved  = try await db.save(record)
                recordIDMap[item.id] = saved.recordID
            }
            _ = existing
        } catch {
            lastSyncError = error.localizedDescription
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
}
