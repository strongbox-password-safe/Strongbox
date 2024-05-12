//
//  CloudKitDatabasesInteractor.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CloudKit

@available(iOS 15.0, macOS 12.0, *)
@objc
class CloudKitDatabasesInteractor: NSObject {
    enum CloudKitDatabasesInteractorError: Error {
        case cloudKitDatabaseNotFound
        case couldNotGenerateMacOSURL
        case couldNotParseCloudKitId
        case invalidParameter
    }

    @objc static let shared = CloudKitDatabasesInteractor()

    var refreshInProgress = false 

    override private init() {}

    @objc
    func refreshAndMerge() {
        

        Task {
            do {
                try await refreshAndMergeInternal() 
            } catch {
                NSLog("🔴 Error caught in \(#function) - [\(error)]")
            }
        }
    }

    func refreshAndMergeInternal() async throws { 
        

        dispatchPrecondition(condition: .notOnQueue(.main)) 

        NSLog("🏴‍☠️  \(#function) ENTER")

        guard !refreshInProgress else {
            NSLog("🏴‍☠️ Refresh Already in progress! Not doing another!")
            NSLog("🏴‍☠️ \(#function) EXIT")
            return
        }

        refreshInProgress = true

        defer {
            NSLog("🏴‍☠️  \(#function) EXIT")
            refreshInProgress = false
        }

        try await CloudKitManager.shared.refreshDatabases()

        guard case let .loaded(private: privateDbs, shared: sharedDbs) = CloudKitManager.shared.state else {
            NSLog("🔴 CloudKitManager not in expected state after refresh! Databases not loaded. State = \(CloudKitManager.shared.state)") 
            return
        }

        try await mergeOrUpdateDatabases(privateDbs, sharedDbs) 
    }

    var existingCloudKitDatabases: [METADATA_PTR] {
        #if os(iOS)
            return DatabasePreferences.forAllDatabases(of: .kCloudKit)
        #else
            return MacDatabasePreferences.forAllDatabases(of: .kCloudKit)
        #endif
    }

    func cloudKitIdentifierFromStrongboxDatabase(_ db: METADATA_PTR) -> CloudKitDatabaseIdentifier? {
        #if os(iOS)
            return CloudKitDatabaseIdentifier.fromJson(db.fileIdentifier)
        #else
            return CloudKitDatabaseIdentifier.fromJson(db.storageInfo)
        #endif
    }

    fileprivate func removeNoneExistentDatabases(_ privateDbs: [CloudKitHostedDatabase], _ sharedDbs: [CloudKitHostedDatabase]) {
        

        let allIds = Set(privateDbs.map(\.id) + sharedDbs.map(\.id))

        let toRemove = existingCloudKitDatabases.filter { db in
            guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(db) else {
                NSLog("🔴 ERROR: Could not read fileId! \(#function)!!")
                return false
            }

            return !allIds.contains(cloudKitDatabaseId)
        }

        for removeMe in toRemove {
            NSLog("⚠️ Removing no longer present on CloudKit database: \(removeMe.nickName) from databases list")

            DatabaseNuker.nuke(removeMe)
        }
    }

    func mergeOrUpdateDatabases(_ privateDbs: [CloudKitHostedDatabase], _ sharedDbs: [CloudKitHostedDatabase]) async throws {
        NSLog("Got privateDbs = [\(privateDbs.map(\.nickname))] and shared = [\(sharedDbs.map(\.nickname))]")

        removeNoneExistentDatabases(privateDbs, sharedDbs)

        

        for db in privateDbs {
            try await mergeCloudKitDatabaseIn(db, false)
        }

        for db in sharedDbs {
            try await mergeCloudKitDatabaseIn(db, true)
        }
    }

    func mergeCloudKitDatabaseIn(_ database: CloudKitHostedDatabase, _ sharedWithMe: Bool) async throws {
        

        if let existing = findStrongboxDatabaseForCloudKitDatabase(cloudKitDatabase: database, sharedWithMe: sharedWithMe) {
            if existing.nickName != database.nickname {
                NSLog("🟢 Updating CloudKit Database. Database nickname has changed.")
                #if os(iOS)
                    let nick = DatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
                #else
                    let nick = MacDatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
                #endif
                existing.nickName = nick
            }

            let shared = sharedWithMe || database.associatedCkRecord.share != nil
            if existing.isSharedInCloudKit != shared {
                NSLog("🟢 Updating CloudKit Database. Shared has changed.")
                existing.isSharedInCloudKit = shared
            }
        } else {
            NSLog("Database [\(database.nickname)] is new! Adding...")

            try await addNewlyAddedDatabase(database, sharedWithMe) 
        }
    }

    func addNewlyAddedDatabase(_ database: CloudKitHostedDatabase, _: Bool) async throws {


        NSLog("Got Full New Database including Data Blob: [\(database)]")

        let newDatabasePrefs = try CloudKitStorageProvider.generateNewDatabaseMetadata(database: database)

        #if os(iOS)
            newDatabasePrefs.add(withDuplicateCheck: nil, initialCacheModDate: nil) 

            

            Task {
                try await SyncManager.sharedInstance().backgroundSyncDatabase(newDatabasePrefs, join: true, key: nil) 
            }
        #else
            newDatabasePrefs.add()
        #endif
    }

    

    @objc
    func rename(database: METADATA_PTR, nickName: String) async throws {
        guard database.storageProvider == .kCloudKit else {
            NSLog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            throw CloudKitDatabasesInteractorError.invalidParameter
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 ERROR: Could not read fileId! \(#function)!!")
            throw CloudKitDatabasesInteractorError.couldNotParseCloudKitId
        }

        _ = try await CloudKitManager.shared.rename(id: cloudKitDatabaseId, nickName: nickName)
    }

    @objc
    func delete(database: METADATA_PTR) async throws {
        guard database.storageProvider == .kCloudKit else {
            NSLog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            throw CloudKitDatabasesInteractorError.invalidParameter
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 ERROR: Could not read fileId! \(#function)!!")
            throw CloudKitDatabasesInteractorError.couldNotParseCloudKitId
        }

        try await CloudKitManager.shared.delete(id: cloudKitDatabaseId)
    }

    func beginSharing(for database: METADATA_PTR) async throws -> (share: CKShare, container: CKContainer) {
        

        guard let ckDb = findCloudKitDatabaseForStrongboxDatabase(database: database) else {
            NSLog("🔴 \(#function) Could not find associated cloudKit Database for database \(database.uuid)")
            throw CloudKitDatabasesInteractorError.cloudKitDatabaseNotFound
        }

        return try await CloudKitManager.shared.createShare(database: ckDb)
    }

    @objc
    func acceptShare(metadata: CKShare.Metadata) async throws {
        CrossPlatformDependencies.defaults().spinnerUi.show("Accepting...", viewController: nil) 

        defer {
            CrossPlatformDependencies.defaults().spinnerUi.dismiss()
        }

        try await CloudKitManager.shared.acceptShare(metadata: metadata)

        try await refreshAndMergeInternal() 
    }

    

    func findStrongboxDatabaseForCloudKitDatabase(cloudKitDatabase: CloudKitHostedDatabase, sharedWithMe _: Bool) -> METADATA_PTR? {
        findStrongboxDatabaseForCloudKitDatabase(cloudKitIdentifier: cloudKitDatabase.id)
    }

    func findStrongboxDatabaseForCloudKitDatabase(cloudKitIdentifier: CloudKitDatabaseIdentifier) -> METADATA_PTR? {
        existingCloudKitDatabases.first(where: { existingDb in
            guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(existingDb) else {
                NSLog("🔴 Could not read file identifier for cloudkit database")
                return false
            }

            return cloudKitDatabaseId == cloudKitIdentifier
        })
    }

    func findCloudKitDatabaseForStrongboxDatabase(database: METADATA_PTR) -> CloudKitHostedDatabase? {
        

        guard database.storageProvider == .kCloudKit else {
            NSLog("🔴 ERROR: Non CloudKit database sent to \(#function)!!")
            return nil
        }

        guard case let .loaded(private: privateDbs, shared: sharedDbs) = CloudKitManager.shared.state else {
            
            NSLog("🔴 Could not find database as manager not in loaded state \(#function)")
            return nil
        }

        guard let cloudKitDatabaseId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 ERROR: Could not read fileId! \(#function)!!")
            return nil
        }

        let dbs = cloudKitDatabaseId.sharedWithMe ? sharedDbs : privateDbs

        return dbs.first { $0.id == cloudKitDatabaseId }
    }
}
