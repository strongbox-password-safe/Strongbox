//
//  WiFiSyncStorageProvider.swift
//  Strongbox
//
//  Created by Strongbox on 26/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Network

@objc
class WiFiSyncStorageProvider: NSObject, SafeStorageProvider {
    @objc
    static let sharedInstance = WiFiSyncStorageProvider()

    var spinnerUI: SpinnerUI {
        CrossPlatformDependencies.defaults().spinnerUi
    }

    @objc var explicitConnectionConfig: WiFiSyncServerConfig? = nil

    var storageId: StorageProvider {
        .kWiFiSync
    }

    var providesIcons: Bool {
        true
    }

    var browsableNew: Bool {
        false
    }

    var browsableExisting: Bool {
        true
    }

    var rootFolderOnly: Bool {
        true
    }

    var supportsConcurrentRequests: Bool {
        false
    }

    var defaultForImmediatelyOfferOfflineCache: Bool {
        false
    }

    var privacyOptInRequired: Bool {
        false
    }

    

    

    func create(_: String, extension _: String, data _: Data, parentFolder _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion _: @escaping (METADATA_PTR?, Error?) -> Void) {
        
    }

    func pullDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        NSLog("🟢 WiFiSyncStorageProvider::pullDatabase...")

        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.readResultError, nil, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        guard let config = getServerConfigFromDatabase(database) else {
            NSLog("🔴 WiFiSyncStorageProvider::pullDatabase - Could not read config for WiFi Sync Server")
            completion(.readResultError, nil, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        guard let endpoint = getEndpointForServer(config) else {
            NSLog("⚠️ WiFiSyncStorageProvider::pullDatabase - Could not get endpoint for WiFi Sync Server. Unavailable Result")
            completion(.readResultUnavailable, nil, nil, Utils.createNSError("Endpoint not available.", errorCode: -123))
            return
        }

        if let currentMod = options.onlyIfModifiedDifferentFrom {
            getModDate(database) { [weak self] available, modDate, error in
                guard let self else { return }

                guard available else {
                    completion(.readResultUnavailable, nil, nil, Utils.createNSError("Endpoint not available.", errorCode: -123))
                    return
                }

                guard error == nil else {
                    NSLog("🔴 Error while getting mod date! [%@] - will continue to try pull anyway", String(describing: error))
                    completion(.readResultError, nil, nil, error ?? Utils.createNSError("Could not read (getModDate failed)", errorCode: -1))
                    return
                }

                if let modDate, modDate.isEqualToDateWithinEpsilon(currentMod) {
                    NSLog("🟢 WiFiSyncStorageProvider::pullDatabase - Modified is the same as local - not pulling entire DB")
                    completion(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                } else {
                    readDatabase(databaseId: config.databaseId,
                                 endpoint: endpoint,
                                 passcode: config.passcode,
                                 completion: completion)
                }
            }
        } else {
            readDatabase(databaseId: config.databaseId,
                         endpoint: endpoint,
                         passcode: config.passcode,
                         completion: completion)
        }
    }

    func pushDatabase(_ database: METADATA_PTR, interactiveVC _: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        NSLog("🟢 WiFiSyncStorageProvider::pushDatabase...")

        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.updateResultError, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        guard let config = getServerConfigFromDatabase(database) else {
            NSLog("🔴 Could not read config for WiFi Sync Server")
            completion(.updateResultError, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        if let endpoint = getEndpointForServer(config) {
            let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: config.passcode)

            

            let databaseId = config.databaseId

            connection.pushDatabase(databaseId, data) { mod, error in
                if let mod {
                    NSLog("🟢 Pushed Database [\(databaseId)] successfully. New Mod = \(mod.iso8601withFractionalSeconds)")
                    completion(.updateResultSuccess, mod, nil)
                } else {
                    NSLog("🔴 Got Database => [\(String(describing: error))]")
                    completion(.updateResultError, nil, error)
                }
            }
        } else {
            NSLog("⚠️ Could not get endpoint for WiFi Sync Server - Unavailable Result")
            completion(.updateResultUnavailable, nil, Utils.createNSError("Endpoint Unavailable.", errorCode: -123))
        }
    }

    func list(_: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        guard let connectionConfig = explicitConnectionConfig else {
            NSLog("🔴 Explicit server not set but LIST called without a parameterized!")
            completion(false, [], Utils.createNSError("Explicit server not set but LIST called without a parameterized!", errorCode: -1))
            return
        }

        guard let passcode = connectionConfig.passcode else {
            NSLog("🔴 Passcode not set but LIST called?!")
            completion(false, [], Utils.createNSError("Passcode not set but LIST called!", errorCode: -1))
            return
        }

        NSLog("🟢 Connecting to \(connectionConfig.name)")

        listWithEndpoint(connectionConfig.endpoint, passcode) { _, databases, error in
            if let databases {
                

                let mapped = databases.compactMap { [weak self] database in
                    self?.mapDatabaseToSbi(connectionConfig.name, database)
                }

                completion(false, mapped, nil)
            } else if let error {
                NSLog("🔴 WiFiSync::List Error = \(error)")
                completion(false, [], error)
            } else {
                NSLog("🔴 Unknown Error in WiFiSync List")
                completion(false, [], Utils.createNSError("Unknown Error in WiFiSync List!", errorCode: 123))
            }
        }
    }

    func mapDatabaseToSbi(_ serverName: String, _ database: WiFiSyncDatabaseSummary) -> StorageBrowserItem {
        let sbi = StorageBrowserItem(name: database.nickName,
                                     identifier: database.uuid,
                                     folder: false,
                                     providerData: [
                                         "databaseId": database.uuid,
                                         "filename": database.filename,
                                     ])

        sbi.disabled = databaseAlreadyExists(serverName, database)

        return sbi
    }

    func databaseAlreadyExists(_ server: String, _ database: WiFiSyncDatabaseSummary) -> Bool {
        #if os(iOS)
            let allDatabases = DatabasePreferences.allDatabases
        #else
            let allDatabases = MacDatabasePreferences.allDatabases
        #endif

        let match = allDatabases.first { existing in
            if existing.storageProvider == .kWiFiSync,
               let config = getServerConfigFromDatabase(existing)
            {
                return database.uuid == config.databaseId && server == config.serverName
            }

            return false
        }

        return match != nil
    }

    func listWithEndpoint(_ endpoint: NWEndpoint, _ passcode: String, _ completion: @escaping (Bool, [WiFiSyncDatabaseSummary]?, Error?) -> Void) {
        let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: passcode)

        connection.listDatabases(nil) { databases, error in
            completion(databases != nil, databases, error)
        }
    }

    func read(withProviderData providerData: NSObject?,
              viewController _: VIEW_CONTROLLER_PTR?,
              options _: StorageProviderReadOptions,
              completion: @escaping StorageProviderReadCompletionBlock)
    {
        NSLog("🟢 WiFiSyncStorageProvider::read...")

        guard let dict = providerData as? [String: String],
              let databaseId = dict["databaseId"],
              let connectionConfig = explicitConnectionConfig,
              let passcode = connectionConfig.passcode
        else {
            NSLog("🔴 Could not get UUID to Read Database or Explicit server and Passcode not set but READ called?!")
            return
        }

        readDatabase(databaseId: databaseId, endpoint: connectionConfig.endpoint, passcode: passcode, completion: completion)
    }

    @objc class var wiFiSyncIsPossible: Bool {
        let prefs = CrossPlatformDependencies.defaults().applicationPreferences

        return StrongboxProductBundle.supportsWiFiSync && !prefs.disableWiFiSyncClientMode && prefs.isPro
    }

    func readDatabase(databaseId: String, endpoint: NWEndpoint, passcode: String, completion: @escaping StorageProviderReadCompletionBlock) {
        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.readResultError, nil, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: passcode)

        

        connection.getDatabase(databaseId) { mod, data, error in
            if let mod, let data {
                NSLog("🟢 Got Database [\(databaseId)] with Mod = \(mod)")
                completion(.readResultSuccess, data, mod, nil)
            } else {
                NSLog("🔴 Got Database => [\(String(describing: error))]")
                completion(.readResultError, nil, nil, error)
            }
        }
    }

    func getEndpointForServer(_ config: WiFiSyncServerConnectionConfig) -> NWEndpoint? {
        WiFiSyncBrowser.shared.getEndpoint(config.serverName)
    }

    func getModDate(_ database: METADATA_PTR, completion: @escaping StorageProviderGetModDateCompletionBlock) {
        

        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(true, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        guard let config = getServerConfigFromDatabase(database) else {
            NSLog("🔴 WiFiSyncStorageProvider::pullDatabase - Could not read config for WiFi Sync Server")
            completion(true, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        if let endpoint = getEndpointForServer(config) {
            let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: config.passcode)

            connection.listDatabases(config.databaseId) { items, error in
                if items != nil {
                    guard let items, let database = items.first(where: { database in database.uuid == config.databaseId }) else {
                        NSLog("🔴 WiFiSyncStorageProvider::getModDate - Could not get databases or match database for server!")
                        completion(true, nil, Utils.createNSError("Could not get databases or match database for server!", errorCode: -1))
                        return
                    }

                    NSLog("🟢 Got Mod Date: [%@]", database.modDate.iso8601withFractionalSeconds)

                    completion(true, database.modDate, nil)
                } else {
                    NSLog("🔴 Failed with [%@]", String(describing: error))
                    completion(true, nil, error)
                }
            }
        } else {
            
            completion(false, nil, nil)
        }
    }

    func delete(_: METADATA_PTR, completion _: @escaping (Error?) -> Void) {
        
    }

    func loadIcon(_: NSObject, viewController _: VIEW_CONTROLLER_PTR, completion: @escaping (IMAGE_TYPE_PTR) -> Void) {
        #if os(iOS)
            let baseImage = UIImage(systemName: "externaldrive.fill.badge.wifi")!

            if #available(iOS 15.0, *) {
                let config = UIImage.SymbolConfiguration(paletteColors: [.systemGreen, .systemBlue])
                completion(baseImage.applyingSymbolConfiguration(config)!)
            } else {
                completion(baseImage)
            }
        #else
            let baseImage = NSImage(systemSymbolName: "externaldrive.fill.badge.wifi", accessibilityDescription: nil)!

            if #available(macOS 12.0, *) {
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen, .systemBlue])
                completion(baseImage.withSymbolConfiguration(config)!)
            } else {
                completion(baseImage)
            }
        #endif
    }

    @objc
    func getWifiSyncServerNameFromDatabaseMetadata(_ database: METADATA_PTR) -> String? {
        guard let config = getServerConfigFromDatabase(database) else {
            return nil
        }

        return config.serverName
    }

    func getServerConfigFromDatabase(_ metaData: METADATA_PTR) -> WiFiSyncServerConnectionConfig? {
        #if os(iOS)
            return WiFiSyncServerConnectionConfig.fromJson(metaData.fileIdentifier)
        #else
            guard let storageInfo = metaData.storageInfo else {
                NSLog("🔴 Could not read storage info Wi-Fi Sync in database.")
                return nil
            }

            return WiFiSyncServerConnectionConfig.fromJson(storageInfo)
        #endif
    }

    func getDatabasePreferences(_ nickName: String, providerData: NSObject) -> METADATA_PTR? {
        guard let dict = providerData as? [String: String],
              let databaseId = dict["databaseId"],
              let filename = dict["filename"],
              let connectionConfig = explicitConnectionConfig,
              let passcode = connectionConfig.passcode
        else {
            NSLog("🔴 Could not get UUID to Read Database or Explicit server and Passcode not set but READ called?!")
            return nil
        }

        let config = WiFiSyncServerConnectionConfig.newConfig(databaseId: databaseId, serverName: connectionConfig.name, passcode: passcode)
        let json = config.json

        #if os(iOS)
            let ret = DatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileName: filename, fileIdentifier: json)
        #else
            var components = URLComponents()

            components.scheme = kStrongboxWiFiSyncUrlScheme
            components.path = filename.hasPrefix("/") ? filename : String(format: "/%@", filename)

            guard let url = components.url else {
                NSLog("🔴 Could not generate URL - WiFi Sync")
                return nil
            }

            let ret = MacDatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileUrl: url, storageInfo: json)

            let queryItem = URLQueryItem(name: "uuid", value: ret.uuid)
            components.queryItems = [queryItem] 

            guard let url2 = components.url else {
                NSLog("🔴 Could not generate URL - WiFi Sync")
                return nil
            }

            ret.fileUrl = url2
        #endif

        return ret
    }
}
