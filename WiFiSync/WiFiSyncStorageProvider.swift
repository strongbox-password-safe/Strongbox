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

    

    

    func create(_: String, fileName _: String, data _: Data, parentFolder _: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion _: @escaping (METADATA_PTR?, Error?) -> Void) {
        
    }

    func pullDatabase(_ database: METADATA_PTR, interactiveVC: VIEW_CONTROLLER_PTR?, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        swlog("🟢 WiFiSyncStorageProvider::pullDatabase...")

        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.readResultError, nil, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        guard let config = getServerConfigFromDatabase(database) else {
            swlog("🔴 WiFiSyncStorageProvider::pullDatabase - Could not read config for WiFi Sync Server")
            completion(.readResultError, nil, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        if config.passcode == nil {
            if let interactiveVC {
                requestPasscode(interactiveVC, config) { [weak self] _ in
                    self?.continuePull(database, config: config, options: options, completion: completion)
                }
            } else {
                completion(.readResultBackgroundReadButUserInteractionRequired, nil, nil, nil)
                return
            }
        } else {
            continuePull(database, config: config, options: options, completion: completion)
        }
    }

    func continuePull(_ database: METADATA_PTR, config: WiFiSyncServerConnectionConfig, options: StorageProviderReadOptions, completion: @escaping StorageProviderReadCompletionBlock) {
        guard let passcode = config.passcode else {
            completion(.readResultError, nil, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            return
        }

        guard let endpoint = getEndpointForServer(config) else {
            swlog("⚠️ WiFiSyncStorageProvider::pullDatabase - Could not get endpoint for WiFi Sync Server. Unavailable Result")
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
                    swlog("🔴 Error while getting mod date! [%@] - will continue to try pull anyway", String(describing: error))
                    completion(.readResultError, nil, nil, error ?? Utils.createNSError("Could not read (getModDate failed)", errorCode: -1))
                    return
                }

                if let modDate, modDate.isEqualToDateWithinEpsilon(currentMod) {
                    swlog("🟢 WiFiSyncStorageProvider::pullDatabase - Modified is the same as local - not pulling entire DB")
                    completion(.readResultModifiedIsSameAsLocal, nil, nil, nil)
                } else {
                    readDatabase(databaseId: config.databaseId,
                                 serverConfig: config,
                                 endpoint: endpoint,
                                 passcode: passcode,
                                 completion: completion)
                }
            }
        } else {
            readDatabase(databaseId: config.databaseId,
                         serverConfig: config,
                         endpoint: endpoint,
                         passcode: passcode,
                         completion: completion)
        }
    }

    func pushDatabase(_ database: METADATA_PTR, interactiveVC: VIEW_CONTROLLER_PTR?, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        swlog("🟢 WiFiSyncStorageProvider::pushDatabase...")

        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.updateResultError, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        guard let config = getServerConfigFromDatabase(database) else {
            swlog("🔴 Could not read config for WiFi Sync Server")
            completion(.updateResultError, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        if config.passcode == nil {
            if let interactiveVC {
                requestPasscode(interactiveVC, config) { [weak self] _ in
                    self?.continuePush(database, config: config, data: data, completion: completion)
                }
            } else {
                completion(.updateResultUserInteractionRequired, nil, nil)
                return
            }
        } else {
            continuePush(database, config: config, data: data, completion: completion)
        }
    }

    func continuePush(_: METADATA_PTR, config: WiFiSyncServerConnectionConfig, data: Data, completion: @escaping StorageProviderUpdateCompletionBlock) {
        guard let passcode = config.passcode else {
            completion(.updateResultError, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            return
        }

        if let endpoint = getEndpointForServer(config) {
            let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: passcode)

            

            let databaseId = config.databaseId

            connection.pushDatabase(databaseId, data) { mod, incorrectPasscode, error in
                if incorrectPasscode {
                    config.passcode = nil
                    completion(.updateResultError, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
                } else if let mod {
                    swlog("🟢 Pushed Database [\(databaseId)] successfully. New Mod = \(mod.iso8601withFractionalSeconds)")
                    completion(.updateResultSuccess, mod, nil)
                } else {
                    swlog("🔴 Got Database => [\(String(describing: error))]")
                    completion(.updateResultError, nil, error)
                }
            }
        } else {
            swlog("⚠️ Could not get endpoint for WiFi Sync Server - Unavailable Result")
            completion(.updateResultUnavailable, nil, Utils.createNSError("Endpoint Unavailable.", errorCode: -123))
        }
    }

    func list(_: NSObject?, viewController _: VIEW_CONTROLLER_PTR?, completion: @escaping (Bool, [StorageBrowserItem], Error?) -> Void) {
        guard let connectionConfig = explicitConnectionConfig else {
            swlog("🔴 Explicit server not set but LIST called without a parameterized!")
            completion(false, [], Utils.createNSError("Explicit server not set but LIST called without a parameterized!", errorCode: -1))
            return
        }

        guard let passcode = connectionConfig.passcode else {
            swlog("🔴 Passcode not set but LIST called?!")
            completion(false, [], Utils.createNSError("Passcode not set but LIST called!", errorCode: -1))
            return
        }

        swlog("🟢 Connecting to \(connectionConfig.name)")

        listWithEndpoint(connectionConfig.endpoint, passcode) { _, databases, error in
            if let databases {
                

                let mapped = databases.compactMap { [weak self] database in
                    self?.mapDatabaseToSbi(connectionConfig.name, database)
                }

                completion(false, mapped, nil)
            } else if let error {
                swlog("🔴 WiFiSync::List Error = \(error)")
                completion(false, [], error)
            } else {
                swlog("🔴 Unknown Error in WiFiSync List")
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

        connection.listDatabases(nil) { databases, incorrectPasscode, error in
            if incorrectPasscode {
                completion(false, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            } else {
                completion(databases != nil, databases, error)
            }
        }
    }

    func read(withProviderData providerData: NSObject?,
              viewController _: VIEW_CONTROLLER_PTR?,
              options _: StorageProviderReadOptions,
              completion: @escaping StorageProviderReadCompletionBlock)
    {
        swlog("🟢 WiFiSyncStorageProvider::read...")

        guard let dict = providerData as? [String: String],
              let databaseId = dict["databaseId"],
              let connectionConfig = explicitConnectionConfig,
              let passcode = connectionConfig.passcode
        else {
            swlog("🔴 Could not get UUID to Read Database or Explicit server and Passcode not set but READ called?!")
            return
        }

        readDatabase(databaseId: databaseId,
                     serverConfig: nil,
                     endpoint: connectionConfig.endpoint,
                     passcode: passcode, completion: completion)
    }

    @objc class var wiFiSyncIsPossible: Bool {
        let prefs = CrossPlatformDependencies.defaults().applicationPreferences

        return StrongboxProductBundle.supportsWiFiSync && !prefs.disableWiFiSyncClientMode && prefs.isPro
    }

    func readDatabase(databaseId: String, serverConfig: WiFiSyncServerConnectionConfig?, endpoint: NWEndpoint, passcode: String, completion: @escaping StorageProviderReadCompletionBlock) {
        guard WiFiSyncStorageProvider.wiFiSyncIsPossible else {
            completion(.readResultError, nil, nil, Utils.createNSError("WiFi Sync is not available. Pro Only, not available on Zero.", errorCode: -1234))
            return
        }

        let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: passcode)

        

        connection.getDatabase(databaseId) { mod, data, incorrectPasscode, error in
            if incorrectPasscode {
                if let serverConfig {
                    serverConfig.passcode = nil
                }

                completion(.readResultError, nil, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            } else if let mod, let data {
                swlog("🟢 Got Database [\(databaseId)] with Mod = \(mod)")
                completion(.readResultSuccess, data, mod, nil)
            } else {
                swlog("🔴 Got Database => [\(String(describing: error))]")
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
            swlog("🔴 WiFiSyncStorageProvider::pullDatabase - Could not read config for WiFi Sync Server")
            completion(true, nil, Utils.createNSError("Could not read config for WiFi Sync Server", errorCode: -123))
            return
        }

        guard let passcode = config.passcode else {
            completion(true, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
            return
        }

        if let endpoint = getEndpointForServer(config) {
            let connection = WiFiSyncClientConnection(endpoint: endpoint, passcode: passcode)

            connection.listDatabases(config.databaseId) { items, incorrectPasscode, error in
                if incorrectPasscode {
                    config.passcode = nil
                    completion(true, nil, Utils.createNSError(NSLocalizedString("wifi_sync_incorrect_passcode", comment: "Incorrect Passcode"), errorCode: -1))
                } else if items != nil {
                    guard let items, let database = items.first(where: { database in database.uuid == config.databaseId }) else {
                        swlog("🔴 WiFiSyncStorageProvider::getModDate - Could not get databases or match database for server!")
                        completion(true, nil, Utils.createNSError("Could not get databases or match database for server!", errorCode: -1))
                        return
                    }

                    swlog("🟢 Got Mod Date: [%@]", database.modDate.iso8601withFractionalSeconds)

                    completion(true, database.modDate, nil)
                } else {
                    swlog("🔴 Failed with [%@]", String(describing: error))
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

            let config = UIImage.SymbolConfiguration(paletteColors: [.systemGreen, .systemBlue])
            completion(baseImage.applyingSymbolConfiguration(config)!)
        #else
            let baseImage = NSImage(systemSymbolName: "externaldrive.fill.badge.wifi", accessibilityDescription: nil)!

            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen, .systemBlue])
            completion(baseImage.withSymbolConfiguration(config)!)
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
                swlog("🔴 Could not read storage info Wi-Fi Sync in database.")
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
            swlog("🔴 Could not get UUID to Read Database or Explicit server and Passcode not set but READ called?!")
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
                swlog("🔴 Could not generate URL - WiFi Sync")
                return nil
            }

            let ret = MacDatabasePreferences.templateDummy(withNickName: nickName, storageProvider: storageId, fileUrl: url, storageInfo: json)

            let queryItem = URLQueryItem(name: "uuid", value: ret.uuid)
            components.queryItems = [queryItem] 

            guard let url2 = components.url else {
                swlog("🔴 Could not generate URL - WiFi Sync")
                return nil
            }

            ret.fileUrl = url2
        #endif

        return ret
    }

    func requestPasscode(_ viewController: VIEW_CONTROLLER_PTR, _ config: WiFiSyncServerConnectionConfig, completion: @escaping (_ success: Bool) -> Void) {
        DispatchQueue.main.async {
            let co = WiFiSyncServerConfig(name: config.serverName)
            #if os(iOS)
                let vc = SwiftUIViewFactory.makeWiFiSyncPasscodeViewController(co) { _, pinCode in
                    if let pinCode {
                        config.passcode = pinCode
                        completion(true)
                    } else {
                        completion(false)
                    }
                }

                viewController.present(vc, animated: true)
            #else
                let vc = SwiftUIViewFactory.makeWiFiSyncPassCodeEntryViewController(co) { _, pinCode in
                    if let pinCode {
                        config.passcode = pinCode
                        completion(true)
                    } else {
                        completion(false)
                    }

                    if let sheet = viewController.presentedViewControllers?.first {
                        Utils.dismissViewControllerCorrectly(sheet)
                    }
                }

                viewController.presentAsSheet(vc)
            #endif
        }
    }
}
