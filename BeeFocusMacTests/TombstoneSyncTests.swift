//
//  TombstoneSyncTests.swift
//  BeeFocusMacTests
//
//  Tests für das Soft-Delete-/Tombstone-Sync-Modell.
//  Deckt die zentrale Invariante ab: Eine bestätigte Löschung darf durch einen
//  späteren Sync mit einem veralteten Gerät niemals wieder auftauchen.
//

import Testing
import CloudKit
import Foundation
@testable import BeeFocusMac

struct TombstoneSyncTests {

    // MARK: - Konfliktregel (deletion wins over older edit)

    @Test func tombstoneNewerThanEditWins() {
        // Szenario 5 / 10: Löschung passierte NACH der (veralteten) Bearbeitung.
        let edit = Date(timeIntervalSince1970: 1_000)
        let deleted = Date(timeIntervalSince1970: 2_000)
        #expect(MacTodoStore.shouldSkipUpsert(existingIsDeleted: true,
                                              existingDeletedAt: deleted,
                                              incomingUpdatedAt: edit) == true)
    }

    @Test func editNewerThanTombstoneRestores() {
        // Bewusste, neuere Bearbeitung/Wiederherstellung gewinnt (LWW).
        let deleted = Date(timeIntervalSince1970: 1_000)
        let edit = Date(timeIntervalSince1970: 2_000)
        #expect(MacTodoStore.shouldSkipUpsert(existingIsDeleted: true,
                                              existingDeletedAt: deleted,
                                              incomingUpdatedAt: edit) == false)
    }

    @Test func liveRecordNeverSkips() {
        let edit = Date()
        #expect(MacTodoStore.shouldSkipUpsert(existingIsDeleted: false,
                                              existingDeletedAt: nil,
                                              incomingUpdatedAt: edit) == false)
    }

    @Test func missingDeletedAtTreatedAsDistantFuture() {
        // Defensive: Tombstone ohne deletedAt darf nicht versehentlich auferstehen.
        #expect(MacTodoStore.shouldSkipUpsert(existingIsDeleted: true,
                                              existingDeletedAt: nil,
                                              incomingUpdatedAt: Date()) == true)
    }

    // MARK: - CKRecord-Mapping

    @Test func recordWithTombstoneParsesAsDeleted() throws {
        let record = CKRecord(recordType: "Todo")
        record["id"] = UUID().uuidString as CKRecordValue
        record["title"] = "Egal" as CKRecordValue
        record["isDeleted"] = true as CKRecordValue
        record["deletedAt"] = Date() as CKRecordValue

        let item = try #require(MacTodoItem(record: record))
        #expect(item.isDeleted == true)
        #expect(item.deletedAt != nil)
    }

    @Test func recordWithoutTombstoneFieldIsLive() throws {
        // Abwärtskompatibilität: alte Records ohne isDeleted-Feld gelten als lebendig.
        let record = CKRecord(recordType: "Todo")
        record["id"] = UUID().uuidString as CKRecordValue
        record["title"] = "Alt" as CKRecordValue

        let item = try #require(MacTodoItem(record: record))
        #expect(item.isDeleted == false)
    }

    @Test func toRecordClearsTombstoneForLiveSave() {
        var item = MacTodoItem(title: "Wieder lebendig")
        item.isDeleted = true
        item.deletedAt = Date()

        let record = item.toRecord()
        #expect((record["isDeleted"] as? Bool) == false)
        #expect(record["deletedAt"] == nil)
    }

    @Test func idIsStableAcrossRoundTrip() throws {
        let original = MacTodoItem(title: "Stabil")
        let record = original.toRecord()
        let restored = try #require(MacTodoItem(record: record))
        #expect(restored.id == original.id)
    }
}
