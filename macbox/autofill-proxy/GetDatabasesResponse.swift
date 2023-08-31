//
//  GetDatabasesResponse.swift
//  MacBox
//
//  Created by Strongbox on 16/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
class DatabaseSummary: NSObject, Codable {
    var nickName: String
    var autoFillEnabled: Bool
    var locked: Bool

    @objc
    init(nickName: String, autoFillEnabled: Bool = false, locked: Bool = true) {
        self.nickName = nickName
        self.autoFillEnabled = autoFillEnabled
        self.locked = locked
    }
}

@objc
class GetDatabasesResponse: NSObject, Codable {
    @objc
    var databases: [DatabaseSummary] = []

    @objc
    func toJson() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let encodedData = try? encoder.encode(self) else {
            NSLog("🔴 Could not encode") 
            return nil
        }

        let jsonString = String(data: encodedData, encoding: .utf8)

        return jsonString
    }
}
