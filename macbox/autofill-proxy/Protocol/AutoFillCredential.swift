//
//  AutoFillCredential.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

struct AutoFillCredentialCustomField: Codable {
    var key: String
    var value: String
    var concealable: Bool
}

public class AutoFillCredential: Codable {
    var uuid: UUID
    var databaseId: String
    var title: String
    var icon: String
    var username: String
    var password: String
    var url: String
    var totp: String
    var customFields: [AutoFillCredentialCustomField] = []
    var attachmentFileNames: [String] = []
    var databaseName: String
    var tags: [String]
    var favourite: Bool
    var notes: String
    var modified: String

    init(uuid: UUID,
         databaseId: String,
         title: String,
         username: String,
         password: String,
         url: String,
         totp: String,
         icon: String,
         customFields: [AutoFillCredentialCustomField] = [],
         attachmentFileNames: [String] = [],
         databaseName: String,
         tags: [String],
         favourite: Bool,
         notes: String,
         modified: String)
    {
        self.uuid = uuid
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.totp = totp
        self.icon = icon
        self.customFields = customFields
        self.attachmentFileNames = attachmentFileNames
        self.databaseId = databaseId
        self.databaseName = databaseName
        self.tags = tags
        self.favourite = favourite
        self.modified = modified
        self.notes = notes
    }
}
