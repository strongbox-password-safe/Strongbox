//
//  AppModel.swift
//  Strongbox
//
//  Created by Strongbox on 01/03/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import UIKit

@objc
class AppModel: NSObject {
    @objc
    static let shared = AppModel()

    override private init() {}

    var theUnlockedDatabase: Model?

    
    

    var editingSet: ConcurrentMutableSet<NSString> = ConcurrentMutableSet()

    @objc
    var unlockedDatabase: Model? {
        theUnlockedDatabase
    }

    @objc
    func isUnlocked(_ uuid: String) -> Bool {
        theUnlockedDatabase?.databaseUuid == uuid
    }

    @objc
    func closeDatabase() {
        theUnlockedDatabase = nil
    }

    @objc
    func unlockDatabase(_ database: Model) {
        if theUnlockedDatabase != nil {
            NSLog("🔴 Overwriting current unlocked database! Should have been marked as locked previously...")
        }

        theUnlockedDatabase = database
    }

    @objc
    func isEditing(_ id: String) -> Bool {
        editingSet.contains(id as NSString)
    }

    @objc
    func markAsEditing(id: String, editing: Bool = true) {
        NSLog("AppModel::markAsEditing: %@ => %hhd", id, editing)

        if editing {
            editingSet.add(id as NSString)
        } else {
            editingSet.remove(id as NSString)
        }
    }
}
