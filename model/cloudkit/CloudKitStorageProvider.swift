//
//  CloudKitStorageProvider.swift
//  Strongbox
//
//  Created by Strongbox on 04/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class CloudKitStorageProvider: NSObject, SafeStorageProvider {
    enum CloudKitStorageProviderError: Error {
        case generic(detail: String)
        case couldNotGenerateMacOSURL
    }

    @objc
    static let sharedInstance = CloudKitStorageProvider()

    var spinnerUI: SpinnerUI { CrossPlatformDependencies.defaults().spinnerUi }

    var storageId: StorageProvider { .kCloudKit }
    var providesIcons: Bool { false }
    var browsableNew: Bool { false }
    var browsableExisting: Bool { false }
    var rootFolderOnly: Bool { true }
    var supportsConcurrentRequests: Bool { false }
    var defaultForImmediatelyOfferOfflineCache: Bool { true }
    var privacyOptInRequired: Bool { false }

    func create(_ nickName: String, fileName _: String, data: Data, parentFolder _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?) async throws -> METADATA_PTR {
        #if os(iOS)
            let nick = DatabasePreferences.getUniqueName(fromSuggestedName: nickName) 
        #else
            let nick = MacDatabasePreferences.getUniqueName(fromSuggestedName: nickName) 
        #endif

        let filename = "Database.kdbx"

        let newDatabase = try await CloudKitDatabasesInteractor.shared.createDatabase(nickname: nick, filename: filename, modDate: Date.now, dataBlob: data)

        return try CloudKitStorageProvider.generateNewDatabaseMetadata(database: newDatabase)
    }

    func pullDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {


        guard let cloudKitId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 Error getting cloudKitIdentifier from database!")
            completion(.readResultError, nil, nil, Utils.createNSError("Error getting cloudKitIdentifier from database!", errorCode: -1))
            return
        }

        if let currentMod = options.onlyIfModifiedDifferentFrom {
            getModDate(database) { [weak self] _, modDate, error in
                guard let self else { return }

                guard error == nil else {
                    NSLog("🔴 Error while getting mod date! [%@] - will continue to try pull anyway", String(describing: error))
                    completion(.readResultError, nil, nil, error ?? Utils.createNSError("Could not read (getModDate failed)", errorCode: -1))
                    return
                }

                if let modDate, modDate.isEqualToDateWithinEpsilon(currentMod) {

                    completion(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                } else {
                    readDatabase(databaseId: cloudKitId, completion: completion)
                }
            }
        } else {
            readDatabase(databaseId: cloudKitId, completion: completion)
        }
    }

    func pushDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        NSLog("🟢 CloudKitStorageProvider::pushDatabase...")

        guard let cloudKitId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 Error getting cloudKitIdentifier from database!")
            completion(.updateResultError, nil, Utils.createNSError("Error getting cloudKitIdentifier from database!", errorCode: -1))
            return
        }

        Task {
            do {
                let foo = try await CloudKitDatabasesInteractor.shared.updateDatabase(cloudKitId, dataBlob: data)

                NSLog("🟢 CloudKitStorageProvider::Push Success - \(foo) with modDate = \(foo.modDate)")

                completion(.updateResultSuccess, foo.modDate, nil)
            } catch {
                NSLog("🔴 CloudKit::Push - Error => [\(String(describing: error))]")
                completion(.updateResultError, nil, error)
            }
        }
    }

    func delete(_: METADATA_PTR, completion _: @escaping ((any Error)?) -> Void) {
        NSLog("🐞 CloudKitStorageProvider::delete called - NOTIMPL")
    }

    func list(_: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion _: @escaping (Bool, [StorageBrowserItem], (any Error)?) -> Void) {}

    func read(withProviderData _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, options _: StorageProviderReadOptions, completion _: @escaping StorageProviderReadCompletionBlock) {
        NSLog("🐞 CloudKitStorageProvider::read called NOTIMPL")
    }

    func loadIcon(_: NSObject, viewController _: VIEW_CONTROLLER_PTR, completion _: @escaping (IMAGE_TYPE_PTR) -> Void) {}

    func getDatabasePreferences(_: String, providerData _: NSObject) -> METADATA_PTR? {
        NSLog("🔴 WARNWARN: CloudKitStorageProviderError::getDatabasePreferences called - this is not implemented, something is very wrong")

        return nil
    }

    func getModDate(_ database: METADATA_PTR, completion: @escaping StorageProviderGetModDateCompletionBlock) {


        guard let cloudKitId = cloudKitIdentifierFromStrongboxDatabase(database) else {
            NSLog("🔴 CloudKitStorageProvider::getModDate Error getting cloudKitIdentifier from database!")
            completion(true, nil, Utils.createNSError("Error getting cloudKitIdentifier from database!", errorCode: -1))
            return
        }

        Task {
            do {
                let foo = try await CloudKitDatabasesInteractor.shared.getDatabase(id: cloudKitId, includeDataBlob: false)

                NSLog("🟢 CloudKitStorageProvider::getModDate Success - Got modDate = \(foo.modDate)")

                completion(true, foo.modDate, nil)
            } catch {
                NSLog("🔴 CloudKitStorageProvider::getModDate - Error => [\(String(describing: error))]")
                completion(true, nil, error)
            }
        }
    }

    func readDatabase(databaseId: CloudKitDatabaseIdentifier, completion: @escaping StorageProviderReadCompletionBlock) {


        Task {
            do {
                let foo = try await CloudKitDatabasesInteractor.shared.getDatabase(id: databaseId, includeDataBlob: true)

                guard let dataBlob = foo.dataBlob else {
                    NSLog("🔴 CloudKit::Read - nil data returned")
                    completion(.readResultError, nil, nil, Utils.createNSError("🔴 CloudKit::Read - nil data returned!", errorCode: -1))
                    return
                }



                completion(.readResultSuccess, dataBlob, foo.modDate, nil)
            } catch {
                NSLog("🔴 CloudKit::Read - Error => [\(String(describing: error))]")
                completion(.readResultError, nil, nil, error)
            }
        }
    }

    

    class func generateNewDatabaseMetadata(database: CloudKitHostedDatabase) throws -> METADATA_PTR {
        #if os(iOS)
            let nick = DatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
            let newDatabasePrefs = DatabasePreferences.templateDummy(withNickName: nick,
                                                                     storageProvider: .kCloudKit,
                                                                     fileName: database.filename,
                                                                     fileIdentifier: database.id.json)

            newDatabasePrefs.lazySyncMode = true 
        #else
            var components = URLComponents()
            components.scheme = kStrongboxCloudUrlScheme
            components.path = String(format: "/%@", database.filename)

            guard let url = components.url else {
                NSLog("🔴 Could not generate URL - CloudKit Sync")
                throw CloudKitStorageProviderError.couldNotGenerateMacOSURL
            }

            let nick = MacDatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
            let newDatabasePrefs = MacDatabasePreferences.templateDummy(withNickName: nick, storageProvider: .kCloudKit, fileUrl: url, storageInfo: database.id.json)

            let queryItem = URLQueryItem(name: "uuid", value: newDatabasePrefs.uuid)
            components.queryItems = [queryItem] 

            guard let url2 = components.url else {
                NSLog("🔴 Could not generate URL - CloudKit Sync")
                throw CloudKitStorageProviderError.couldNotGenerateMacOSURL
            }

            newDatabasePrefs.fileUrl = url2
        #endif

        let shared = database.sharedWithMe || database.associatedCkRecord.share != nil 
        let ownedByMe = !database.sharedWithMe

        if newDatabasePrefs.isSharedInCloudKit != shared {
            newDatabasePrefs.isSharedInCloudKit = shared
        }

        if newDatabasePrefs.isOwnedByMeCloudKit != ownedByMe {
            newDatabasePrefs.isOwnedByMeCloudKit = ownedByMe
        }

        return newDatabasePrefs
    }

    func cloudKitIdentifierFromStrongboxDatabase(_ db: METADATA_PTR) -> CloudKitDatabaseIdentifier? {
        #if os(iOS)
            return CloudKitDatabaseIdentifier.fromJson(db.fileIdentifier)
        #else
            return CloudKitDatabaseIdentifier.fromJson(db.storageInfo)
        #endif
    }
}
