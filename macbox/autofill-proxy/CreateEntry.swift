//
//  CreateEntry.swift
//  MacBox
//
//  Created by Strongbox on 21/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class CreateEntryRequest: Codable {
    var databaseId: String
    var groupId: String?
    var icon: String?
    var title: String?
    var username: String?
    var password: String?
    var url: String?
}

class CreateEntryResponse: Codable {
    var uuid: String?
    var error: String?
    var credential: AutoFillCredential?
}
