//
//  IOSWiFiSyncManagementInterface.swift
//  Strongbox
//
//  Created by Strongbox on 29/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let wiFiSyncSourceWorkingCopyDidChange = Notification.Name("wiFiSyncSourceWorkingCopyDidChange")
}

@objc public extension NSNotification {
    static let wiFiSyncSourceWorkingCopyDidChange = Notification.Name.wiFiSyncSourceWorkingCopyDidChange
}

class IOSWiFiSyncManagementInterface: NSObject, WiFiSyncManagementInterface {
    enum IOSWiFiSyncManagementError: Error {
        case error(details: String)
    }

    func isEditsAreInProgress(id: String) -> Bool {
        AppModel.shared.isEditing(id)
    }

    func getDatabaseSummaries(id: String?, _ completion: @escaping (([WiFiSyncDatabaseSummary]) -> Void)) {
        if let id {
            guard let database = DatabasePreferences.fromUuid(id) else {
                swlog("⚠️ Wi-Fi Sync Source: List -> Could not find database: [%@]", id)
                completion([]) 
                return
            }

            sync(id) { [weak self] success, localWasChanged, error in
                guard let self else { return }

                if AppModel.shared.isUnlocked(id), localWasChanged {
                    notifyWiFiSyncUpdatedWorkingCopy()
                }

                if !success { 
                    swlog("⚠️ Wi-Fi Sync Source: List -> Sync was unsuccessful for database: [%@] - %@", id, String(describing: error))
                }

                guard let summary = getSummaryForDatabase(database) else {
                    completion([]) 
                    return
                }

                completion([summary])
            }
        } else {
            let ret = DatabasePreferences.allDatabases
                .filter { database in
                    database.storageProvider != .kWiFiSync 
                }
                .compactMap { getSummaryForDatabase($0) }
            completion(ret)
        }
    }

    func getSummaryForDatabase(_ database: METADATA_PTR) -> WiFiSyncDatabaseSummary? {
        var nsmod: NSDate?
        var fsize: UInt64 = 0

        guard WorkingCopyManager.sharedInstance().getLocalWorkingCache(database.uuid, modified: &nsmod, fileSize: &fsize) != nil,
              let mod = nsmod as? Date
        else {
            swlog("⚠️ Could not get working cache or mod date for database: [%@] - Skipping...", database.nickName)
            return nil
        }

        return WiFiSyncDatabaseSummary(uuid: database.uuid,
                                       filename: database.fileName,
                                       nickName: database.nickName,
                                       modDate: mod,
                                       fileSize: fsize)
    }

    func pullDatabase(id: String, _ completion: @escaping (((Date, Data)?) -> Void)) {
        swlog("Wi-Fi Sync Source: Pull Database...")

        sync(id) { [weak self] success, localWasChanged, error in
            guard let self else { return }

            var nsmod: NSDate?

            if AppModel.shared.isUnlocked(id), localWasChanged {
                notifyWiFiSyncUpdatedWorkingCopy()
            }

            guard success,
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

        guard let database = DatabasePreferences.fromUuid(id) else {
            swlog("🔴 handlePushDatabaseRequest - Could not find database to push to!")
            throw IOSWiFiSyncManagementError.error(details: "🔴 handlePushDatabaseRequest - Could not find database to push to!")
        }

        

        try SyncManager.sharedInstance().updateLocalCopyMark(asRequiringSync: database, data: data)

        if AppModel.shared.isUnlocked(id) {
            notifyWiFiSyncUpdatedWorkingCopy()
        }

        

        sync(id) { [weak self] success, localWasChanged, error in
            guard let self else { return }

            if success, !localWasChanged { 
                guard let mod = WorkingCopyManager.sharedInstance().getModDate(id) else {
                    swlog("🔴 handlePushDatabaseRequest - Could not read current mod date of working cache")
                    completion(false, nil, "Could not read current mod date of working cache")
                    return
                }

                completion(true, mod, nil)
            } else {
                if AppModel.shared.isUnlocked(id), localWasChanged {
                    notifyWiFiSyncUpdatedWorkingCopy()
                }

                swlog("🔴 Wi-Fi Sync Source: Push Database - Sync Failed: [%@] - Sync localWasChanged = %hhd", String(describing: error), localWasChanged)

                completion(false, nil, error?.localizedDescription ?? "< No Error / Local Changed >")
            }
        }
    }

    func notifyWiFiSyncUpdatedWorkingCopy() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .wiFiSyncSourceWorkingCopyDidChange, object: nil)
        }
    }

    func sync(_ id: String, _ completion: @escaping ((Bool, Bool, Error?) -> Void)) {
        guard let database = DatabasePreferences.fromUuid(id) else {
            completion(false, false, Utils.createNSError("🔴 handlePushDatabaseRequest - Could not find database to sync!", errorCode: -1))
            return
        }

        SyncManager.sharedInstance().backgroundSyncDatabase(database, join: false, key: nil) { result, localWasChanged, error in
            swlog("🐞 Wi-Fi Sync Source: Sync Complete with %@ - %@, %hhd", String(describing: result), String(describing: error), localWasChanged)
            completion(result == .success, localWasChanged, error)
        }
    }
}
