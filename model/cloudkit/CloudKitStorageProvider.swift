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
        case deleteMeDummyErrorTODO
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

    func create(_ nickName: String, extension _: String, data: Data, parentFolder _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?) async throws -> METADATA_PTR {
        if #available(iOS 15.0, macOS 12.0, *) {
            #if os(iOS)
                let nick = DatabasePreferences.getUniqueName(fromSuggestedName: nickName) 
            #else
                let nick = MacDatabasePreferences.getUniqueName(fromSuggestedName: nickName) 
            #endif

            let filename = "Database.kdbx" 

            let newDatabase = try await CloudKitManager.shared.createDatabase(nickname: nick, filename: filename, modDate: Date.now, dataBlob: data)

            return try CloudKitStorageProvider.generateNewDatabaseMetadata(database: newDatabase)
        } else {
            throw CloudKitStorageProviderError.deleteMeDummyErrorTODO

        }
    }

    func pullDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        NSLog("🟢 CloudKitStorageProvider::pullDatabase...")

        if #available(iOS 15.0, macOS 12.0, *) { 
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
                        NSLog("🟢 CloudKitStorageProvider::pullDatabase - Modified is the same as local - not pulling entire DB")
                        completion(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                    } else {
                        readDatabase(databaseId: cloudKitId, completion: completion)
                    }
                }
            } else {
                readDatabase(databaseId: cloudKitId, completion: completion)
            }
        } else {
            
        }
    }

    func pushDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        NSLog("🟢 CloudKitStorageProvider::pushDatabase...")

        if #available(iOS 15.0, macOS 12.0, *) {
            guard let cloudKitId = cloudKitIdentifierFromStrongboxDatabase(database) else {
                NSLog("🔴 Error getting cloudKitIdentifier from database!")
                completion(.updateResultError, nil, Utils.createNSError("Error getting cloudKitIdentifier from database!", errorCode: -1))
                return
            }

            Task { 
                do {
                    let foo = try await CloudKitManager.shared.updateDatabase(cloudKitId, dataBlob: data)

                    NSLog("🟢 CloudKitStorageProvider::Push Success - \(foo) with modDate = \(foo.modDate)")

                    completion(.updateResultSuccess, foo.modDate, nil)
                } catch {
                    NSLog("🔴 CloudKit::Push - Error => [\(String(describing: error))]")
                    completion(.updateResultError, nil, error)
                }
            }
        } else {
            
        }
    }

    func delete(_: METADATA_PTR, completion _: @escaping ((any Error)?) -> Void) {
        NSLog("🐞 CloudKitStorageProvider::delete called TODO")
    }

    func list(_: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion _: @escaping (Bool, [StorageBrowserItem], (any Error)?) -> Void) {}

    func read(withProviderData _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, options _: StorageProviderReadOptions, completion _: @escaping StorageProviderReadCompletionBlock) {
        NSLog("🐞 CloudKitStorageProvider::read called TODO")
    }

    func loadIcon(_: NSObject, viewController _: VIEW_CONTROLLER_PTR, completion _: @escaping (IMAGE_TYPE_PTR) -> Void) {}

    func getDatabasePreferences(_: String, providerData _: NSObject) -> METADATA_PTR? {
        

        NSLog("🔴 WARNWARN: CloudKitStorageProviderError::getDatabasePreferences called - this is not implemented, something is very wrong")

        return nil
    }

    func getModDate(_ database: METADATA_PTR, completion: @escaping StorageProviderGetModDateCompletionBlock) {
        NSLog("🟢 CloudKitStorageProvider::getModDate for \(database.uuid)")

        if #available(iOS 15.0, macOS 12.0, *) {
            guard let cloudKitId = cloudKitIdentifierFromStrongboxDatabase(database) else {
                NSLog("🔴 CloudKitStorageProvider::getModDate Error getting cloudKitIdentifier from database!")
                completion(true, nil, Utils.createNSError("Error getting cloudKitIdentifier from database!", errorCode: -1))
                return
            }

            Task { 
                do {
                    let foo = try await CloudKitManager.shared.getDatabase(id: cloudKitId, includeDataBlob: false)

                    NSLog("🟢 CloudKitStorageProvider::getModDate Success - Got modDate = \(foo.modDate)")

                    completion(true, foo.modDate, nil)
                } catch {
                    NSLog("🔴 CloudKitStorageProvider::getModDate - Error => [\(String(describing: error))]")
                    completion(true, nil, error)
                }
            }
        } else {
            
        }
    }

    

    @available(iOS 15.0, macOS 12.0, *)
    func readDatabase(databaseId: CloudKitDatabaseIdentifier, completion: @escaping StorageProviderReadCompletionBlock) {
        NSLog("🟢 CloudKitStorageProvider::readDatabase to \(databaseId)")

        Task { 
            do {
                let foo = try await CloudKitManager.shared.getDatabase(id: databaseId, includeDataBlob: true)

                guard let dataBlob = foo.dataBlob else {
                    NSLog("🔴 CloudKit::Read - nil data returned")
                    completion(.readResultError, nil, nil, Utils.createNSError("🔴 CloudKit::Read - nil data returned!", errorCode: -1))
                    return
                }

                NSLog("🟢 CloudKitStorageProvider:: Read Success - \(foo) with modDate = \(foo.modDate) and data length = \(dataBlob.count)")

                completion(.readResultSuccess, dataBlob, foo.modDate, nil)
            } catch {
                NSLog("🔴 CloudKit::Read - Error => [\(String(describing: error))]")
                completion(.readResultError, nil, nil, error)
            }
        }
    }

    

    @available(iOS 15.0, macOS 12.0, *)
    class func generateNewDatabaseMetadata(database: CloudKitHostedDatabase) throws -> METADATA_PTR {
        #if os(iOS)
            let nick = DatabasePreferences.getUniqueName(fromSuggestedName: database.nickname) 
            let newDatabasePrefs = DatabasePreferences.templateDummy(withNickName: nick,
                                                                     storageProvider: .kCloudKit,
                                                                     fileName: database.filename,
                                                                     fileIdentifier: database.id.json)
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

        return newDatabasePrefs
    }

    @available(iOS 15.0, macOS 12.0, *)
    func cloudKitIdentifierFromStrongboxDatabase(_ db: METADATA_PTR) -> CloudKitDatabaseIdentifier? {
        #if os(iOS)
            return CloudKitDatabaseIdentifier.fromJson(db.fileIdentifier)
        #else
            return CloudKitDatabaseIdentifier.fromJson(db.storageInfo)
        #endif
    }
}
