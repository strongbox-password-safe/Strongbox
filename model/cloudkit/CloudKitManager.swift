//
//  CloudKitManager.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit
import Foundation

@available(iOS 15.0, macOS 12.0, *)
@objc final class CloudKitManager: NSObject { 
    enum CloudKitManagerError: Error {
        case invalidParameters
        case invalidRemoteShare
        case couldNotFindRecord
        case corruptRecord
        case saveError(detail: String)
        case generic(detail: String)
    }

    enum State {
        case loading
        case loaded(private: [CloudKitHostedDatabase], shared: [CloudKitHostedDatabase]) 
        case error(Error)
    }

    private(set) var state: State = .loading

    private static let ContainerIdentifier = "iCloud.com.strongbox"
    private static let DatabaseRecordType = "Database"
    static let RecordZoneName = "Databases"

    private lazy var cloudKitContainer = CKContainer(identifier: Self.ContainerIdentifier)
    private lazy var cloudKitPrivateDatabase = cloudKitContainer.privateCloudDatabase
    private let privateRecordZone = CKRecordZone(zoneName: CloudKitManager.RecordZoneName)

    @objc static let shared = CloudKitManager()

    override private init() {}

    func refreshDatabases() async throws {
        NSLog("🟢 \(#function)...")

        state = .loading

        do {
            NSLog("Initializing CloudKit - Creating Zone if Needed...")

            try await createZoneIfNeeded()

            NSLog("Initializing CloudKit - Zone Creation Done")

            let (privateDatabases, sharedDatabases) = try await fetchPrivateAndShared()

            state = .loaded(private: privateDatabases, shared: sharedDatabases)







        } catch {
            NSLog("🔴 Error in \(#function) = [\(error)]")
            state = .error(error)
            throw error
        }
    }

    

    func createDatabase(nickname: String, filename: String, modDate: Date, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        let id = CKRecord.ID(zoneID: privateRecordZone.zoneID)
        let ckRecord = CKRecord(recordType: Self.DatabaseRecordType, recordID: id)

        ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.filename] = filename

        return try await saveOrUpdate(ckRecord, sharedWithMe: false, nickName: nickname, modDate: modDate, dataBlob: dataBlob)
    }

    func getDatabase(id: CloudKitDatabaseIdentifier, includeDataBlob: Bool) async throws -> CloudKitHostedDatabase {
        NSLog("🐞 \(#function) for \(id)")

        let cloudKitDatabase = cloudKitContainer.database(with: id.sharedWithMe ? .shared : .private)
        let config = CKOperation.Configuration()
        config.qualityOfService = .userInitiated 

        return try await cloudKitDatabase.configuredWith(configuration: config) { database in
            var desiredKeys = [
                CloudKitHostedDatabase.RecordKeys.nickname,
                CloudKitHostedDatabase.RecordKeys.filename,
                CloudKitHostedDatabase.RecordKeys.modDate,
            ]

            if includeDataBlob {
                desiredKeys.append(CloudKitHostedDatabase.RecordKeys.dataBlob)
            }

            let records = try await database.records(for: [CKRecord.ID(recordName: id.recordName, zoneID: id.zoneID)], desiredKeys: desiredKeys)

            guard let match = records.first else {
                NSLog("🔴 Could not find database on CloudKit! \(id)")
                throw CloudKitManagerError.couldNotFindRecord
            }

            let record = try match.value.get()
            guard let ret = CloudKitHostedDatabase(record: record, sharedWithMe: id.sharedWithMe) else {
                NSLog("🔴 Could not read CloudKit CKRecord! \(id)")
                throw CloudKitManagerError.corruptRecord
            }

            return ret
        }
    }

    class func list(_ cloudKitDatabase: CKDatabase, _ zone: CKRecordZone) async throws -> [CloudKitHostedDatabase] {
        let query = CKQuery(recordType: Self.DatabaseRecordType, predicate: NSPredicate(value: true))

        let desiredKeys = [
            CloudKitHostedDatabase.RecordKeys.nickname,
            CloudKitHostedDatabase.RecordKeys.filename,
            CloudKitHostedDatabase.RecordKeys.modDate,
            
        ]

        let config = CKOperation.Configuration()
        config.qualityOfService = .userInitiated 

        return try await cloudKitDatabase.configuredWith(configuration: config) { database in
            var all: [CloudKitHostedDatabase] = []

            let (results, initialQueryCursor) = try await database.records(matching: query, inZoneWith: zone.zoneID, desiredKeys: desiredKeys)

            let ckDatabases = Self.mapFetchResultsToDatabases(results, sharedWithMe: cloudKitDatabase.databaseScope == .shared)
            all.append(contentsOf: ckDatabases)

            var currentQueryCursor = initialQueryCursor
            while let cursor = currentQueryCursor {
                NSLog("🐞 More results coming from server... paged...")

                let (results, newQueryCursor) = try await database.records(continuingMatchFrom: cursor, desiredKeys: desiredKeys)

                let ckDatabases = Self.mapFetchResultsToDatabases(results, sharedWithMe: cloudKitDatabase.databaseScope == .shared)
                all.append(contentsOf: ckDatabases)

                currentQueryCursor = newQueryCursor
            }

            for db in all {
                NSLog("🐞 fetched: \(db.id) - \(db.nickname) in zone \(zone)")
            }

            return all
        }
    }

    func updateDatabase(_ id: CloudKitDatabaseIdentifier, dataBlob: Data) async throws -> CloudKitHostedDatabase {
        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        return try await saveOrUpdate(existing.associatedCkRecord, sharedWithMe: id.sharedWithMe, modDate: Date.now, dataBlob: dataBlob) 
    }

    func rename(id: CloudKitDatabaseIdentifier, nickName: String) async throws -> CloudKitHostedDatabase {
        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        return try await saveOrUpdate(existing.associatedCkRecord, sharedWithMe: id.sharedWithMe, nickName: nickName)
    }

    func delete(id: CloudKitDatabaseIdentifier) async throws {
        let cloudKitDatabase = cloudKitContainer.database(with: id.sharedWithMe ? .shared : .private) 
        let config = CKOperation.Configuration()
        config.qualityOfService = .userInitiated 

        let existing = try await getDatabase(id: id, includeDataBlob: false) 

        try await cloudKitDatabase.configuredWith(configuration: config) { database in
            try await database.deleteRecord(withID: existing.associatedCkRecord.recordID)
        }
    }

    private func saveOrUpdate(_ ckRecord: CKRecord, sharedWithMe: Bool, nickName: String? = nil, modDate: Date? = nil, dataBlob: Data? = nil) async throws -> CloudKitHostedDatabase {
        if let nickName {
            ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.nickname] = nickName
        }

        if let dataBlob {
            guard let modDate else {
                NSLog("🔴 Datablob sent in for update without mod date?!")
                throw CloudKitManagerError.invalidParameters
            }

            let tmpUrl = try getTempAssetUrl(dataBlob) 
            let dataBlobAsset = CKAsset(fileURL: tmpUrl)
            ckRecord[CloudKitHostedDatabase.RecordKeys.dataBlob] = dataBlobAsset

            ckRecord.encryptedValues[CloudKitHostedDatabase.RecordKeys.modDate] = modDate
        }

        let start = CFAbsoluteTimeGetCurrent()

        let cloudKitDatabase = cloudKitContainer.database(with: sharedWithMe ? .shared : .private)
        let config = CKOperation.Configuration()
        config.qualityOfService = .userInitiated 

        return try await cloudKitDatabase.configuredWith(configuration: config) { database in
            let ret = try await database.save(ckRecord)

            let diff = CFAbsoluteTimeGetCurrent() - start
            NSLog("🟢 Database updated \(ret) in \(diff) seconds")

            guard let db = CloudKitHostedDatabase(record: ret, sharedWithMe: false) else {
                NSLog("🔴 Could not convert return CKRecord to a database object!")
                throw CloudKitManagerError.saveError(detail: "Could not convert return CKRecord to a database object!")
            }

            return db
        }
    }

    func createShare(database: CloudKitHostedDatabase) async throws -> (share: CKShare, container: CKContainer) {
        NSLog("🟢 \(#function) ENTER")
        defer {
            NSLog("🟢 \(#function) EXIT")
        }

        if let existingShare = database.associatedCkRecord.share {
            NSLog("🟢 \(#function) Found existing share, returning that...")

            let config = CKOperation.Configuration()
            config.qualityOfService = .userInitiated 

            return try await cloudKitPrivateDatabase.configuredWith(configuration: config) { ckConfiguredDb in
                guard let share = try await ckConfiguredDb.record(for: existingShare.recordID) as? CKShare else {
                    throw CloudKitManagerError.invalidRemoteShare
                }

                return (share, cloudKitContainer)
            }
        } else {
            NSLog("🟢 \(#function) No existing share found, creating...")

            let share = CKShare(rootRecord: database.associatedCkRecord)
            share[CKShare.SystemFieldKey.title] = "Strongbox Database: \(database.nickname)" 

            let config = CKOperation.Configuration()
            config.qualityOfService = .userInitiated 

            return try await cloudKitPrivateDatabase.configuredWith(configuration: config) { ckConfiguredDb in
                _ = try await ckConfiguredDb.modifyRecords(saving: [database.associatedCkRecord, share], deleting: []) 

                return (share, cloudKitContainer)
            }
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        let container = CKContainer(identifier: metadata.containerIdentifier)

        try await container.accept(metadata)
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

        try await withThrowingTaskGroup(of: [CloudKitHostedDatabase].self) { group in
            for zone in zones {
                group.addTask {
                    try await CloudKitManager.list(database, zone)
                }
            }

            for try await result in group {
                allDatabases.append(contentsOf: result)
            }
        }

        return allDatabases
    }

    private func createZoneIfNeeded() async throws {
        

        guard !CrossPlatformDependencies.defaults().applicationPreferences.cloudKitZoneCreated else {
            return
        }

        do {
            let result = try await cloudKitPrivateDatabase.modifyRecordZones(saving: [privateRecordZone], deleting: []) 

            NSLog("🐞 DEBUG: modifyRecordZones done: \(result)")
        } catch {
            print("ERROR: Failed to create custom zone: \(error.localizedDescription)")
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

    class func mapFetchResultsToDatabases(_ results: [(CKRecord.ID, Result<CKRecord, any Error>)], sharedWithMe: Bool) -> [CloudKitHostedDatabase] {
        let records = results.compactMap { recordId, result in
            do {
                return try result.get()
            } catch {
                NSLog("🔴 Error fetching CKRecord -> [\(error)] - RecordID = [\(recordId)]")
                return nil
            }
        }

        return records.compactMap { CloudKitHostedDatabase(record: $0, sharedWithMe: sharedWithMe) }
    }
}
