//
//  WiFiSyncPushDatabaseResult.swift
//  MacBox
//
//  Created by Strongbox on 04/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

struct WiFiSyncPushDatabaseResult: Codable {
    var success: Bool
    var newModDate: Date?
    var error: String?
}
