import SwiftUI
import CloudKit
import UIKit

enum BrainDumpTag: String, CaseIterable, Codable {
    case idee = "idee"
    case aufgabe = "aufgabe"
    case frage = "frage"
    case sorge = "sorge"
    case danke = "danke"

    var label: String {
        switch self {
        case .idee:    return "Idee"
        case .aufgabe: return "Aufgabe"
        case .frage:   return "Frage"
        case .sorge:   return "Sorge"
        case .danke:   return "Dankbarkeit"
        }
    }

    var icon: String {
        switch self {
        case .idee:    return "lightbulb.fill"
        case .aufgabe: return "checkmark.circle.fill"
        case .frage:   return "questionmark.circle.fill"
        case .sorge:   return "exclamationmark.triangle.fill"
        case .danke:   return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .idee:    return Color(red: 1.0, green: 0.85, blue: 0.2)
        case .aufgabe: return Color(red: 0.3, green: 0.82, blue: 0.5)
        case .frage:   return Color(red: 0.3, green: 0.6,  blue: 1.0)
        case .sorge:   return Color(red: 1.0, green: 0.5,  blue: 0.2)
        case .danke:   return Color(red: 1.0, green: 0.4,  blue: 0.6)
        }
    }
}

struct BrainDumpEintrag: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var tag: BrainDumpTag = .idee
    var date: Date = Date()
    var isConverted: Bool = false

    init(text: String, tag: BrainDumpTag = .idee) {
        self.text = text
        self.tag  = tag
    }

    init?(record: CKRecord) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let text = record["text"] as? String else { return nil }
        self.id          = id
        self.text        = text
        self.tag         = BrainDumpTag(rawValue: record["tag"] as? String ?? "idee") ?? .idee
        self.date        = record["date"] as? Date ?? Date()
        self.isConverted = record["isConverted"] as? Bool ?? false
    }

    func toRecord(existingRecord: CKRecord? = nil) -> CKRecord {
        let record = existingRecord ?? CKRecord(recordType: "BrainDumpEntry")
        record["id"]          = id.uuidString as CKRecordValue
        record["text"]        = text as CKRecordValue
        record["tag"]         = tag.rawValue as CKRecordValue
        record["date"]        = date as CKRecordValue
        record["isConverted"] = isConverted as CKRecordValue
        return record
    }
}

@MainActor
final class BrainDumpStore: ObservableObject {
    static let shared = BrainDumpStore()

    @Published var eintraege: [BrainDumpEintrag] = []

    private let container = CKContainer(identifier: "iCloud.com.TorbenLehneke.BeeFocus")
    private var db: CKDatabase { container.privateCloudDatabase }
    private var recordIDMap: [UUID: CKRecord.ID] = [:]
    private var pendingAdds: Set<UUID> = []
    private let localKey = "brain_dump_v1"

    private init() {
        loadLocal()
        Task { await fetch() }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in Task { await self?.fetch() } }
    }

    // MARK: - Local cache

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([BrainDumpEintrag].self, from: data) else { return }
        eintraege = decoded
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(eintraege) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    // MARK: - CloudKit fetch

    func fetch() async {
        do {
            let query = CKQuery(recordType: "BrainDumpEntry", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            let (results, _) = try await db.records(matching: query, resultsLimit: 500)

            var byID: [UUID: (BrainDumpEintrag, CKRecord.ID)] = [:]
            for (recordID, result) in results {
                if case .success(let record) = result, let entry = BrainDumpEintrag(record: record) {
                    if let existing = byID[entry.id] {
                        if entry.date > existing.0.date { byID[entry.id] = (entry, recordID) }
                    } else {
                        byID[entry.id] = (entry, recordID)
                    }
                }
            }
            eintraege = byID.values.map(\.0).sorted { $0.date > $1.date }
            for (_, (entry, ckID)) in byID { recordIDMap[entry.id] = ckID }
            saveLocal()
        } catch {}
    }

    // MARK: - Mutations

    func add(text: String, tag: BrainDumpTag) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var entry = BrainDumpEintrag(text: trimmed, tag: tag)
        entry.date = Date()
        eintraege.insert(entry, at: 0)
        saveLocal()
        pendingAdds.insert(entry.id)
        Task {
            do {
                let saved = try await db.save(entry.toRecord())
                recordIDMap[entry.id] = saved.recordID
            } catch {}
            pendingAdds.remove(entry.id)
        }
    }

    func delete(_ eintrag: BrainDumpEintrag) {
        eintraege.removeAll { $0.id == eintrag.id }
        saveLocal()
        guard let ckID = recordIDMap[eintrag.id] else { return }
        Task {
            _ = try? await db.deleteRecord(withID: ckID)
            recordIDMap.removeValue(forKey: eintrag.id)
        }
    }

    func markConverted(_ eintrag: BrainDumpEintrag) {
        update(eintrag) { $0.isConverted = true }
    }

    func updateTag(_ eintrag: BrainDumpEintrag, newTag: BrainDumpTag) {
        update(eintrag) { $0.tag = newTag }
    }

    func updateText(_ eintrag: BrainDumpEintrag, newText: String) {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(eintrag) { $0.text = trimmed }
    }

    func clearAll() {
        let all = eintraege
        eintraege.removeAll()
        saveLocal()
        for entry in all {
            guard let ckID = recordIDMap[entry.id] else { continue }
            recordIDMap.removeValue(forKey: entry.id)
            Task { _ = try? await db.deleteRecord(withID: ckID) }
        }
    }

    // MARK: - Private helpers

    private func update(_ eintrag: BrainDumpEintrag, mutate: (inout BrainDumpEintrag) -> Void) {
        guard let idx = eintraege.firstIndex(where: { $0.id == eintrag.id }) else { return }
        mutate(&eintraege[idx])
        let updated = eintraege[idx]
        saveLocal()
        Task { await save(updated) }
    }

    private func save(_ entry: BrainDumpEintrag) async {
        guard !pendingAdds.contains(entry.id) else { return }
        do {
            if let ckID = recordIDMap[entry.id] {
                let record = try await db.record(for: ckID)
                let _ = entry.toRecord(existingRecord: record)
                try await db.save(record)
            } else {
                let saved = try await db.save(entry.toRecord())
                recordIDMap[entry.id] = saved.recordID
            }
        } catch {}
    }
}
