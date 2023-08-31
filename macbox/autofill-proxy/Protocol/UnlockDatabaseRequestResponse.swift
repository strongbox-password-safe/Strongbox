//
//  UnlockDatabaseRequestResponse.swift
//  MacBox
//
//  Created by Strongbox on 06/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class UnlockDatabaseRequest: NSObject, Codable {
    var databaseId: String

    init(databaseId: String) {
        self.databaseId = databaseId
    }
}

class UnlockDatabaseResponse: NSObject, Codable {
    var success: Bool

    init(success: Bool) {
        self.success = success
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}

class LockDatabaseRequest: NSObject, Codable {
    var databaseId: String

    init(databaseId: String) {
        self.databaseId = databaseId
    }
}

class LockDatabaseResponse: NSObject, Codable {
    var success: Bool

    init(success: Bool) {
        self.success = success
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
