//
//  WatchAppModel.swift
//  Strongbox
//
//  Created by Strongbox on 07/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import OrderedCollections
import SwiftUI

enum WatchAppError: Error {
    case couldNotReadSettings
}

enum HomeTab {
    case entries
    case twoFactorCodes
}

class WatchAppModel: ObservableObject {
    static let SecretStoreEntriesKey = "WatchAppSecretStoreEntriesKey"
    static let SecretStoreDatabasesKey = "WatchAppSecretStoreDatabasesKey"
    static let SecretStoreSettingsKey = "WatchAppSecretStoreSettingsKey"

    private(set) var databases: [WatchDatabaseModel] = .init() {
        didSet {
            saveDatabases()
        }
    }

    private(set) var settings: WatchSettingsModel = .init() {
        didSet {
            saveSettings()
        }
    }

    private(set) var entriesByDatabase: [String: [WatchEntry]] = .init() {
        didSet {
            saveEntries()
        }
    }
    
    @Published @MainActor
    var selectedTab = HomeTab.entries

    @Published @MainActor
    private(set) var entryList: OrderedDictionary<WatchDatabaseModel, [WatchEntry]> = .init()

    @Published @MainActor
    private(set) var lastSynced: Date?

    private var otpRefreshTimer: Timer?

    init() {
        
        refreshSettings()
        startOtpRefresh()
    }

    deinit {
        otpRefreshTimer?.invalidate()
    }

    func refreshSettings() {
        loadAllSettings()
    }

    func selectTab(tab: HomeTab) {
        Task { @MainActor in
            selectedTab = tab
        }
    }
    
    private func getOrderedEntryList() -> OrderedDictionary<WatchDatabaseModel, [WatchEntry]> {
        var ret: OrderedDictionary<WatchDatabaseModel, [WatchEntry]> = .init()

        for database in databases {
            if let entriesForDb = entriesByDatabase[database.uuid], !entriesForDb.isEmpty {
                ret[database] = entriesForDb
            }
        }

        return ret
    }
    
    private func loadAllSettings() {
        do {
            entriesByDatabase = try loadEntries()
            settings = try loadSettings()
            databases = try loadDatabases()
            
            Task { @MainActor in
                entryList = getOrderedEntryList()
            }
        } catch {
            swlog("Could not load all settings... \(error)")
        }
    }

    private func startOtpRefresh() {
        let notificationName = NSNotification.Name.centralUpdateOtpUi
        NotificationCenter.default.post(name: notificationName, object: nil)

        otpRefreshTimer?.invalidate()
        otpRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            NotificationCenter.default.post(name: notificationName, object: nil)
        }

        if let otpRefreshTimer {
            RunLoop.main.add(otpRefreshTimer, forMode: .common)
        }
    }

    private func resetAllSettings() {
        swlog("⚠️ 🔴 resetAllSettings() called")
        SecretStore.sharedInstance().deleteSecureItem(WatchAppModel.SecretStoreEntriesKey)
        SecretStore.sharedInstance().deleteSecureItem(WatchAppModel.SecretStoreDatabasesKey)
        SecretStore.sharedInstance().deleteSecureItem(WatchAppModel.SecretStoreSettingsKey)
    }

    private func loadDatabases() throws -> [WatchDatabaseModel] {
        swlog("🟢 Secure Enclave loading databases... \(SecretStore.sharedInstance().secureEnclaveAvailable)")

        let jsonData = SecretStore.sharedInstance().getSecureObject(WatchAppModel.SecretStoreDatabasesKey)

        guard let jsonData, let json = jsonData as? Data else {
            swlog("🐞 No databases found in Secret Store, return default")
            throw WatchAppError.couldNotReadSettings
        }

        do {
            return try JSONDecoder().decode([WatchDatabaseModel].self, from: json)
        } catch {
            swlog("🔴 Couldn't decode databases from JSON")
            resetAllSettings() 
            return .init()
        }
    }

    private func saveDatabases() {
        do {
            let jsonData = try JSONEncoder().encode(databases)
            SecretStore.sharedInstance().setSecureObject(jsonData, forIdentifier: WatchAppModel.SecretStoreDatabasesKey)
        } catch {
            swlog("🔴 Couldn't encode databases to JSON")
            return
        }
    }

    private func loadSettings() throws -> WatchSettingsModel {
        swlog("🟢 Secure Enclave loading settings... \(SecretStore.sharedInstance().secureEnclaveAvailable)")

        let jsonData = SecretStore.sharedInstance().getSecureObject(WatchAppModel.SecretStoreSettingsKey)

        guard let jsonData, let json = jsonData as? Data else {
            swlog("🐞 No settings found in Secret Store, return default")
            throw WatchAppError.couldNotReadSettings
        }
        
        do {
            return try JSONDecoder().decode(WatchSettingsModel.self, from: json)
        } catch {
            swlog("🔴 Couldn't decode settings from JSON")
            resetAllSettings() 
            return .init()
        }
    }

    private func saveSettings() {
        do {
            let jsonData = try JSONEncoder().encode(settings)
            SecretStore.sharedInstance().setSecureObject(jsonData, forIdentifier: WatchAppModel.SecretStoreSettingsKey)
        } catch {
            swlog("🔴 Couldn't encode settings to JSON")
            return
        }
    }

    private func loadEntries() throws -> [String: [WatchEntry]] {
        swlog("🟢 Secure Enclave loading entries... \(SecretStore.sharedInstance().secureEnclaveAvailable)")

        let jsonData = SecretStore.sharedInstance().getSecureObject(WatchAppModel.SecretStoreEntriesKey)

        guard let jsonData, let json = jsonData as? Data else {
            swlog("🔴 No watch entries found in Secret Store, return empty")
            throw WatchAppError.couldNotReadSettings
        }

        do {
            return try JSONDecoder().decode([String: [WatchEntry]].self, from: json)
        } catch {
            swlog("🐞 Couldn't decode entries from JSON")
            resetAllSettings() 
            return [:]
        }
    }

    private func saveEntries() {
        do {
            let jsonData = try JSONEncoder().encode(entriesByDatabase)
            SecretStore.sharedInstance().setSecureObject(jsonData, forIdentifier: WatchAppModel.SecretStoreEntriesKey)
        } catch {
            swlog("🔴 Couldn't encode entries to JSON")
            return
        }
    }

    func updateModel(settings: WatchSettingsModel, databases: [WatchDatabaseModel], databaseUuid: String, entries: [WatchEntry]) {
        self.settings = settings
        self.databases = databases
        entriesByDatabase[databaseUuid] = entries

        

        let dbids = self.databases.map(\.uuid)
        var allDbs = Set(entriesByDatabase.keys)
        allDbs.subtract(dbids)

        for removedDb in allDbs {
            swlog("🐞 Removing no longer existing database \(removedDb) from entry set")

            entriesByDatabase.removeValue(forKey: removedDb)
        }

        refreshAndPublish()
    }

    func resetEntries(databaseUuid: String, publish: Bool) {
        entriesByDatabase[databaseUuid] = nil

        if publish {
            refreshAndPublish()
        }
    }

    private func refreshAndPublish() {
        Task { @MainActor in
            entryList = getOrderedEntryList() 
            lastSynced = Date.now
        }
    }
}
