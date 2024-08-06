//
//  MacWiFiSyncManagementInterface.swift
//  MacBox
//
//  Created by Strongbox on 29/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class MacWiFiSyncManagementInterface: NSObject, WiFiSyncManagementInterface {
    enum MacWiFiSyncManagementError: Error {
        case error(details: String)
    }

    func isEditsAreInProgress(id: String) -> Bool {
        var ret = false

        DispatchQueue.main.sync {
            ret = DatabasesCollection.shared.databaseHasEditsOrIsBeingEdited(uuid: id)
        }

        return ret
    }

    func getDatabaseSummaries(id: String?, _ completion: @escaping (([WiFiSyncDatabaseSummary]) -> Void)) {
        if let id {
            guard let database = MacDatabasePreferences.getById(id) else {
                swlog("⚠️ Wi-Fi Sync Source: List -> Could not find database: [%@]", id)
                completion([]) 
                return
            }

            DatabasesCollection.shared.sync(uuid: id, allowInteractive: false, suppressErrorAlerts: true) { [weak self] result, _, error in
                guard let self else { return }

                

                if result != .success { 
                    swlog("⚠️ Wi-Fi Sync Source: List -> Sync was unsuccessful for database: [%@] - %@", id, String(describing: error))
                }

                guard let summary = getSummaryForDatabase(database) else {
                    completion([]) 
                    return
                }

                completion([summary])
            }
        } else {
            let ret = MacDatabasePreferences.allDatabases
                .filter { database in
                    database.storageProvider != .kWiFiSync 
                }
                .compactMap { getSummaryForDatabase($0) }
            completion(ret)
        }
    }

    func getSummaryForDatabase(_ database: MacDatabasePreferences) -> WiFiSyncDatabaseSummary? {
        var nsmod: NSDate?
        var fsize: UInt64 = 0

        guard WorkingCopyManager.sharedInstance().getLocalWorkingCache(database.uuid, modified: &nsmod, fileSize: &fsize) != nil,
              let mod = nsmod as? Date
        else {
            swlog("⚠️ Could not get working cache or mod date for database: [%@] - Skipping...", database.nickName)
            return nil
        }

        let filename = database.fileUrl.lastPathComponent

        return WiFiSyncDatabaseSummary(uuid: database.uuid,
                                       filename: filename,
                                       nickName: database.nickName,
                                       modDate: mod,
                                       fileSize: fsize)
    }

    func pullDatabase(id: String, _ completion: @escaping (((Date, Data)?) -> Void)) {
        swlog("Wi-Fi Sync Source: Pull Database...")

        

        DatabasesCollection.shared.sync(uuid: id, allowInteractive: false, suppressErrorAlerts: true) { result, _, error in
            

            var nsmod: NSDate?

            guard result == .success,
                  let url = WorkingCopyManager.sharedInstance().getLocalWorkingCache(id, modified: &nsmod, fileSize: nil),
                  let workingCopy = try? Data(contentsOf: url),
                  let mod = nsmod as? Date
            else {
                swlog("🔴 Wi-Fi Sync Source: Pull Database - Pre Sync Failed: [%@]", String(describing: error))
                completion(nil)
                return
            }

            completion((mod, workingCopy))
        }
    }

    func pushDatabase(id: String, _ data: Data, _ completion: @escaping ((Bool, Date?, String?) -> Void)) throws {
        swlog("Wi-Fi Sync Source: Push Database...")

        guard let database = MacDatabasePreferences.getById(id) else {
            swlog("🔴 handlePushDatabaseRequest - Could not find database to push to!")
            throw MacWiFiSyncManagementError.error(details: "🔴 handlePushDatabaseRequest - Could not find database to push to!")
        }

        

        try MacSyncManager.sharedInstance().updateLocalCopyMark(asRequiringSync: database, data: data) 

        

        DatabasesCollection.shared.reloadFromWorkingCopy(id, dispatchSyncAfterwards: false) { 
            DatabasesCollection.shared.sync(uuid: id, allowInteractive: false, suppressErrorAlerts: true) { result, localWasChanged, error in
                

                if result == .success, !localWasChanged { 
                    guard let mod = WorkingCopyManager.sharedInstance().getModDate(id) else {
                        swlog("🔴 handlePushDatabaseRequest - Could not read current mod date of working cache")
                        completion(false, nil, "Could not read current mod date of working cache")
                        return
                    }

                    completion(true, mod, nil)
                } else {
                    swlog("🔴 Wi-Fi Sync Source: Push Database - Sync Failed: [%@] - Sync localWasChanged = %hhd", String(describing: error), localWasChanged)

                    completion(false, nil, error?.localizedDescription ?? "< No Error / Local Changed >")
                }
            }
        }
    }
}
