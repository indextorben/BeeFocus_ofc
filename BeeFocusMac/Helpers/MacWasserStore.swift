import SwiftUI
import Combine
import CloudKit

struct MacWasserEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var ml: Int

    init?(record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let ml = record["ml"] as? Int else { return nil }
        self.id   = id
        self.ml   = ml
        self.date = record["date"] as? Date ?? Date()
    }

    init(ml: Int) {
        self.ml = ml
    }

    func toRecord(existingRecord: CKRecord? = nil) -> CKRecord {
        let record = existingRecord ?? CKRecord(recordType: "WasserEintrag")
        record["id"]   = id.uuidString as CKRecordValue
        record["ml"]   = ml as CKRecordValue
        record["date"] = date as CKRecordValue
        return record
    }
}

@MainActor
final class MacWasserStore: ObservableObject {
    static let shared = MacWasserStore()

    @Published var entries: [MacWasserEintrag] = []
    @Published var isSyncing = false
    @Published var tagesziel: Int = 2000 {
        didSet { UserDefaults.standard.set(tagesziel, forKey: "wasserTagesziel") }
    }

    private let container = CKContainer(identifier: "iCloud.com.TorbenLehneke.BeeFocus")
    private var db: CKDatabase { container.privateCloudDatabase }
    private var recordIDMap: [UUID: CKRecord.ID] = [:]
    private var syncTimer: Task<Void, Never>?

    private init() {
        tagesziel = UserDefaults.standard.object(forKey: "wasserTagesziel") as? Int ?? 2000
        Task { await fetch() }
        startPeriodicSync()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { await self?.fetch() } }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.pullTagesziel() } }
    }

    private func startPeriodicSync() {
        syncTimer = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await fetch()
            }
        }
    }

    // MARK: - Tagesziel via iCloud KV Store

    private func pullTagesziel() {
        let kv = NSUbiquitousKeyValueStore.default
        if let value = kv.object(forKey: "wasserTagesziel") as? Int, value != tagesziel {
            tagesziel = value
        }
    }

    // MARK: - Fetch

    func fetch() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let query = CKQuery(recordType: "WasserEintrag", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            let (results, _) = try await db.records(matching: query, resultsLimit: 500)

            var byID: [UUID: (MacWasserEintrag, CKRecord.ID)] = [:]
            for (recordID, result) in results {
                if case .success(let record) = result, let entry = MacWasserEintrag(record: record) {
                    byID[entry.id] = (entry, recordID)
                }
            }
            entries = byID.values.map(\.0).sorted { $0.date > $1.date }
            for (_, (entry, ckID)) in byID { recordIDMap[entry.id] = ckID }
        } catch {}
    }

    // MARK: - Mutations

    func add(ml: Int) {
        var entry = MacWasserEintrag(ml: ml)
        entry.date = Date()
        entries.insert(entry, at: 0)
        Task {
            do {
                let saved = try await db.save(entry.toRecord())
                recordIDMap[entry.id] = saved.recordID
            } catch {}
        }
    }

    func delete(_ entry: MacWasserEintrag) {
        entries.removeAll { $0.id == entry.id }
        guard let ckID = recordIDMap[entry.id] else { return }
        Task {
            _ = try? await db.deleteRecord(withID: ckID)
            recordIDMap.removeValue(forKey: entry.id)
        }
    }

    // MARK: - Computed views

    var todayEntries: [MacWasserEintrag] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    var todayTotal: Int { todayEntries.reduce(0) { $0 + $1.ml } }

    var todayProgress: Double { min(Double(todayTotal) / Double(tagesziel), 1.0) }

    func last7DaysTotals() -> [(date: Date, ml: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> (Date, Int)? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let total = entries.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.ml }
            return (cal.startOfDay(for: day), total)
        }
    }
}
