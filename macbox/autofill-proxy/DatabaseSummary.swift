//
//  DatabaseSummary.swift
//  MacBox
//
//  Created by Strongbox on 24/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc
class DatabaseSummary: NSObject, Codable {
    var uuid: String
    var nickName: String
    var autoFillEnabled: Bool
    var locked: Bool
    var includeFavIconForNewEntries: Bool

    @objc
    init(uuid: String, nickName: String, autoFillEnabled: Bool, includeFavIconForNewEntries: Bool, locked: Bool) {
        self.uuid = uuid
        self.nickName = nickName
        self.autoFillEnabled = autoFillEnabled
        self.locked = locked
        self.includeFavIconForNewEntries = includeFavIconForNewEntries
    }
}
