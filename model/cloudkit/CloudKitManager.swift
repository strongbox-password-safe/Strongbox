//
//  CloudKitManager.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import Foundation

@objc
class CloudKitManagerInstrumentation: NSObject {
    @objc let recentErrors = ConcurrentCircularBuffer<NSError>(capacity: 16)

    @objc var lastOperationDuration = 0.0
    @objc var minOperationDuration = Float.greatestFiniteMagnitude
    @objc var maxOperationDuration = 0.0
    @objc var uploadTotal = 0
    @objc var downloadTotal = 0
    @objc var totalOperationDuration = 0.0
    @objc var operationCount = 0

    @objc
    var averageDuration: Double {
        totalOperationDuration / Double(operationCount)
    }
}

class CloudKitManager {
    enum CloudKitManagerError: Error {
        case invalidParameters
        case invalidRemoteShare
        case couldNotFindRecord
        case corruptRecord
        case saveError(detail: String)
        case generic(detail: String)
    }

    private static let ContainerIdentifier = "iCloud.com.strongbox"
    private static let DatabaseRecordType = "Database"
    public static let RecordZoneName = "Databases"

    private lazy var cloudKitContainer = CKContainer(identifier: Self.ContainerIdentifier)
    private lazy var cloudKitPrivateDatabase = cloudKitContainer.privateCloudDatabase
    private let privateRecordZone = CKRecordZone(zoneName: CloudKitManager.RecordZoneName)

    var instrumentation: CloudKitManagerInstrumentation = .init()

    static let shared = CloudKitManager()

    func initialize() async throws {
        swlog("  Initializing CloudKit...")

        try await createZoneIfNeeded()
    }

    func getCloudKitStatus() async throws -> CKAccountStatus {
        try await CKContainer.default().accountStatus()
    }

    func getDatabases() async throws -> [CloudKitHostedDatabase] {
        swlog("🟢 \(#function)...")

        do {
            let (privateDatabases, sharedDatabases) = try await fetchPrivateAndShared()

            return privateDatabases + sharedDatabases
        } catch {
            swlog("🔴 Error in \(#function) = [\(error)]")
            throw error
        }
    }

    func createDatabase(nickname: String, filename: String, modDate: Date, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        let id = CKRecord.ID(zoneID: privateRecordZone.zoneID)
        let ckRecord = CKRecord(recordType: Self.DatabaseRecordType, recordID: id)

        ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.filename] = filename

        let ret = try await saveOrUpdate(ckRecord, sharedWithMe: false, nickName: nickname, modDate: modDate, dataBlob: dataBlob)

        swlog("🐞 Create New Database = [\(ret)]")

        return ret
    }

    func getDatabase(id: CloudKitDatabaseIdentifier, includeDataBlob: Bool) async throws -> CloudKitHostedDatabase {
        let baseKeys = [
            CloudKitHostedDatabase.RecordKeys.nickname,
            CloudKitHostedDatabase.RecordKeys.filename,
            CloudKitHostedDatabase.RecordKeys.modDate,
            CKRecord.SystemFieldKey.share,
        ]

        let desiredKeys = includeDataBlob ? (baseKeys + [CloudKitHostedDatabase.RecordKeys.dataBlob]) : baseKeys

        let cloudKitDatabase = cloudKitContainer.database(with: id.sharedWithMe ? .shared : .private)

        return try await executeCloudKitOperation(theDatabase: cloudKitDatabase) { database in
            let records = try await database.records(for: [CKRecord.ID(recordName: id.recordName, zoneID: id.zoneID)], desiredKeys: desiredKeys)

            guard let match = records.first else {
                swlog("🔴 Could not find database on CloudKit! \(id)")
                throw CloudKitManagerError.couldNotFindRecord
            }

            let record = try match.value.get()
            guard let ret = CloudKitHostedDatabase(record: record, sharedWithMe: id.sharedWithMe) else {
                swlog("🔴 Could not read CloudKit CKRecord! \(id)")
                throw CloudKitManagerError.corruptRecord
            }

            if includeDataBlob, let dataBlob = ret.dataBlob {
                instrumentation.downloadTotal += dataBlob.count
            }

            return ret
        }
    }

    func list(_ cloudKitDatabase: CKDatabase, _ zone: CKRecordZone) async throws -> [CloudKitHostedDatabase] {
        let query = CKQuery(recordType: Self.DatabaseRecordType, predicate: NSPredicate(value: true))

        let desiredKeys: [CKRecord.FieldKey] = [
            CloudKitHostedDatabase.RecordKeys.nickname,
            CloudKitHostedDatabase.RecordKeys.filename,
            CloudKitHostedDatabase.RecordKeys.modDate,
            CKRecord.SystemFieldKey.share,
            
        ]

        return try await executeCloudKitOperation(theDatabase: cloudKitDatabase) { database in
            var all: [CloudKitHostedDatabase] = []

            let (results, initialQueryCursor) = try await database.records(matching: query, inZoneWith: zone.zoneID, desiredKeys: desiredKeys)

            let ckDatabases = Self.mapFetchResultsToDatabases(results, sharedWithMe: cloudKitDatabase.databaseScope == .shared)
            all.append(contentsOf: ckDatabases)

            var currentQueryCursor = initialQueryCursor
            while let cursor = currentQueryCursor {
                swlog("🐞 More results coming from server... paged...")

                let (results, newQueryCursor) = try await database.records(continuingMatchFrom: cursor, desiredKeys: desiredKeys)

                let ckDatabases = Self.mapFetchResultsToDatabases(results, sharedWithMe: cloudKitDatabase.databaseScope == .shared)
                all.append(contentsOf: ckDatabases)

                currentQueryCursor = newQueryCursor
            }





            return all
        }
    }

    func updateDatabase(_ id: CloudKitDatabaseIdentifier, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        

        return try await saveOrUpdate(existing.associatedCkRecord, sharedWithMe: id.sharedWithMe, modDate: Date.now, dataBlob: dataBlob)
    }

    func rename(id: CloudKitDatabaseIdentifier, nickName: String, fileName: String?) async throws -> CloudKitHostedDatabase {
        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        return try await saveOrUpdate(existing.associatedCkRecord, sharedWithMe: id.sharedWithMe, nickName: nickName, fileName: fileName)
    }

    func delete(id: CloudKitDatabaseIdentifier) async throws {
        guard !id.sharedWithMe else {
            swlog("🔴 Cannot delete a database we don't own")
            throw CloudKitManagerError.invalidParameters
        }

        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        try await executeCloudKitOperation(theDatabase: cloudKitPrivateDatabase) { database in
            try await database.deleteRecord(withID: existing.associatedCkRecord.recordID)
        }
    }

    private func saveOrUpdate(_ ckRecord: CKRecord, sharedWithMe: Bool, nickName: String? = nil, fileName: String? = nil, modDate: Date? = nil, dataBlob: Data? = nil) async throws -> CloudKitHostedDatabase {
        if let nickName {
            ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.nickname] = nickName
        }
        if let fileName {
            ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.filename] = fileName
        }

        var tmpAssetUrlToDelete: URL? = nil

        defer {
            if let tmpAssetUrlToDelete {
                do {
                    try FileManager.default.removeItem(at: tmpAssetUrlToDelete)
                } catch {
                    swlog("🔴 CloudKitManager - Could not delete tmp file after update.")
                }
            }
        }

        if let dataBlob {
            guard let modDate else {
                swlog("🔴 Datablob sent in for update without mod date?!")
                throw CloudKitManagerError.invalidParameters
            }

            let url = try getTempAssetUrl(dataBlob)
            tmpAssetUrlToDelete = url

            let dataBlobAsset = CKAsset(fileURL: url)
            ckRecord[CloudKitHostedDatabase.RecordKeys.dataBlob] = dataBlobAsset
            ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.modDate] = modDate
        }

        let cloudKitDatabase = cloudKitContainer.database(with: sharedWithMe ? .shared : .private)

        return try await executeCloudKitOperation(theDatabase: cloudKitDatabase) { database in
            let ret = try await database.save(ckRecord)

            guard let db = CloudKitHostedDatabase(record: ret, sharedWithMe: false) else {
                swlog("🔴 Could not convert return CKRecord to a database object!")
                throw CloudKitManagerError.saveError(detail: "Could not convert return CKRecord to a database object!")
            }

            if let dataBlob {
                instrumentation.uploadTotal += dataBlob.count
            }

            return db
        }
    }

    func getShareRecord(database: CloudKitHostedDatabase) async throws -> (share: CKShare?, container: CKContainer) {
        swlog("🟢 \(#function) ENTER")
        defer {
            swlog("🟢 \(#function) EXIT")
        }

        guard let existingShare = database.associatedCkRecord.share else {
            return (nil, cloudKitContainer)
        }

        let cloudKitDatabase = cloudKitContainer.database(with: database.id.sharedWithMe ? .shared : .private)

        return try await executeCloudKitOperation(theDatabase: cloudKitDatabase) { ckConfiguredDb in
            guard let share = try await ckConfiguredDb.record(for: existingShare.recordID) as? CKShare else {
                throw CloudKitManagerError.invalidRemoteShare
            }

            return (share, cloudKitContainer)
        }
    }

    func createShare(database: CloudKitHostedDatabase) async throws -> (share: CKShare, container: CKContainer) {
        swlog("🟢 \(#function) ENTER")
        defer {
            swlog("🟢 \(#function) EXIT")
        }

        guard !database.id.sharedWithMe else {
            swlog("🔴 Cannot create share for a database we don't own!")
            throw CloudKitManagerError.invalidParameters
        }

        if let existingShare = database.associatedCkRecord.share {
            swlog("🟢 \(#function) Found existing share, returning that...")

            return try await executeCloudKitOperation(theDatabase: cloudKitPrivateDatabase) { ckConfiguredDb in
                guard let share = try await ckConfiguredDb.record(for: existingShare.recordID) as? CKShare else {
                    throw CloudKitManagerError.invalidRemoteShare
                }

                return (share, cloudKitContainer)
            }
        } else {
            swlog("🟢 \(#function) No existing share found, creating...")

            let share = CKShare(rootRecord: database.associatedCkRecord)
            share[CKShare.SystemFieldKey.title] = "Strongbox Database: \(database.nickname)"

            return try await executeCloudKitOperation(theDatabase: cloudKitPrivateDatabase) { ckConfiguredDb in
                _ = try await ckConfiguredDb.modifyRecords(saving: [database.associatedCkRecord, share], deleting: [])

                return (share, cloudKitContainer)
            }
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        let container = CKContainer(identifier: metadata.containerIdentifier)

        try await container.accept(metadata)
    }

    

    func subscribeToChangeNotifications() async throws {
        guard !CrossPlatformDependencies.defaults().applicationPreferences.changeNotificationsSubscriptionCreated, CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated else {
            return
        }

        swlog("🟢 \(#function) ENTER")
        defer {
            swlog("🟢 \(#function) EXIT")
        }

        let privateDb = cloudKitContainer.database(with: .private)

        try await subscribeToChangeNotifications(theDatabase: privateDb)

        let shared = cloudKitContainer.database(with: .shared)

        try await subscribeToChangeNotifications(theDatabase: shared)

        CrossPlatformDependencies.defaults().applicationPreferences.changeNotificationsSubscriptionCreated = true
    }

    func subscribeToChangeNotifications(theDatabase: CKDatabase) async throws {
        await clearAllSubscriptions(theDatabase)

        let subId = UUID().uuidString

        

        let subscription = CKDatabaseSubscription(subscriptionID: subId)
        subscription.recordType = CloudKitManager.DatabaseRecordType

        let ni = CKSubscription.NotificationInfo()
        ni.shouldSendContentAvailable = true
        ni.shouldBadge = false

        subscription.notificationInfo = ni

        try await executeCloudKitOperation(theDatabase: theDatabase) { database in


            try await database.save(subscription)


        }
    }

    func clearAllSubscriptions(_ database: CKDatabase) async {
        do {
            let subs = try await database.allSubscriptions()

            for sub in subs {
                do {
                    try await executeCloudKitOperation(theDatabase: database) { database in
                        try await database.deleteSubscription(withID: sub.subscriptionID)
                    }

                    swlog("Successfully delete subscription: [\(sub)]")
                } catch {
                    swlog("⚠️ Error deleting subscription: [\(sub)]: [\(error)]")
                }
            }
        } catch {
            swlog("⚠️ Error in clearAllSubscriptions: \(error)")
        }
    }

    

    func fetchPrivateAndShared() async throws -> (private: [CloudKitHostedDatabase], shared: [CloudKitHostedDatabase]) {
        

        async let privateDatabases = fetchPrivate()

        async let sharedDatabases = fetchShared()

        return try await (private: privateDatabases, shared: sharedDatabases)
    }

    private func fetchPrivate() async throws -> [CloudKitHostedDatabase] {
        try await fetchAllFromZones(scope: .private, in: [privateRecordZone])
    }

    private func fetchShared() async throws -> [CloudKitHostedDatabase] {
        let sharedZones = try await cloudKitContainer.sharedCloudDatabase.allRecordZones()
        guard !sharedZones.isEmpty else {
            return []
        }

        return try await fetchAllFromZones(scope: .shared, in: sharedZones)
    }

    private func fetchAllFromZones(scope: CKDatabase.Scope, in zones: [CKRecordZone]) async throws -> [CloudKitHostedDatabase] {
        let database = cloudKitContainer.database(with: scope)

        var allDatabases: [CloudKitHostedDatabase] = []

        try await withThrowingTaskGroup(of: [CloudKitHostedDatabase]?.self) { group in
            for zone in zones {
                group.addTask { [weak self] in
                    try await self?.list(database, zone)
                }
            }

            for try await result in group {
                if let result {
                    allDatabases.append(contentsOf: result)
                }
            }
        }

        return allDatabases
    }

    func createZoneIfNeeded() async throws {
        guard !CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated else {
            return
        }

        do {
            let result = try await executeCloudKitOperation(theDatabase: cloudKitPrivateDatabase) { db in
                try await db.modifyRecordZones(saving: [privateRecordZone], deleting: [])
            }

            swlog("🐞 DEBUG: modifyRecordZones done: \(result)")
        } catch {
            swlog("🔴 ERROR: Failed to create custom zone: \(error)")
            throw error
        }

        CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated = true
    }

    func getTempAssetUrl(_ data: Data) throws -> URL {
        let path = StrongboxFilesManager.sharedInstance().tmpAttachmentPreviewPath as NSString

        let tmp = path.appendingPathComponent(UUID().uuidString)
        let url = URL(fileURLWithPath: tmp)

        try data.write(to: url)

        return url
    }

    static func mapFetchResultsToDatabases(_ results: [(CKRecord.ID, Result<CKRecord, any Error>)], sharedWithMe: Bool) -> [CloudKitHostedDatabase] {
        let records = results.compactMap { recordId, result in
            do {
                return try result.get()
            } catch {
                swlog("🔴 Error fetching CKRecord -> [\(error)] - RecordID = [\(recordId)]")
                return nil
            }
        }

        return records.compactMap { CloudKitHostedDatabase(record: $0, sharedWithMe: sharedWithMe) }
    }

    

    func logError(_ error: Error) {
        swlog("🔴 CloudKitManager - Error = [\(error)]")
        instrumentation.recentErrors.add(error as NSError)
    }

    @discardableResult
    func executeCloudKitOperation<R>(theDatabase: CKDatabase, action: (CKDatabase) async throws -> R) async rethrows -> R {
        let start = CFAbsoluteTimeGetCurrent()

        defer {
            let diff = CFAbsoluteTimeGetCurrent() - start

            instrumentation.lastOperationDuration = diff
            instrumentation.totalOperationDuration += diff
            instrumentation.operationCount += 1

            if instrumentation.minOperationDuration > Float(diff) {
                instrumentation.minOperationDuration = Float(diff)
            }

            if instrumentation.maxOperationDuration < diff {
                instrumentation.maxOperationDuration = diff
            }

            #if DEBUG

            #endif
        }

        let config = CKOperation.Configuration()
        config.qualityOfService = .userInitiated 

        return try await theDatabase.configuredWith(configuration: config) { database in
            do {
                return try await action(database)
            } catch {
                if let ckErr = error as? CKError, ckErr.code == .zoneNotFound {
                    swlog("Zone not found error, will attempt to recreate the zone on next restart.")
                    CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated = false
                }

                logError(error)
                throw error
            }
        }
    }
}
