//
//  WiFiSyncDatabaseSummary.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

@objc
class WiFiSyncDatabaseSummary: NSObject, Codable {
    @objc var uuid: String
    @objc var filename: String
    @objc var nickName: String
    @objc var modDate: Date
    @objc var fileSize: UInt64

    init(uuid: String, filename: String, nickName: String, modDate: Date, fileSize: UInt64) {
        self.uuid = uuid
        self.filename = filename
        self.nickName = nickName
        self.modDate = modDate
        self.fileSize = fileSize
    }
}
