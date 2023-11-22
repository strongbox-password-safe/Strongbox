//
//  GetNewEntryDefaults.swift
//  MacBox
//
//  Created by Strongbox on 23/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class GetNewEntryDefaultsRequest: Codable {
    var databaseId: String
}

class GetNewEntryDefaultsResponse: Codable {
    var username: String?
    var mostPopularUsernames: [String]?
    var password: String?

    var error: String?

    init(error: String) {
        self.error = error
    }

    init(username: String, password: String, mostPopularUsernames: [String]) {
        self.username = username
        self.password = password
        self.mostPopularUsernames = mostPopularUsernames
    }
}

class GetNewEntryDefaultsV2Response: Codable {
    var username: String?
    var mostPopularUsernames: [String]?
    var password: PasswordAndStrength?

    var error: String?

    init(error: String) {
        self.error = error
    }

    init(username: String, password: PasswordAndStrength, mostPopularUsernames: [String]) {
        self.username = username
        self.password = password
        self.mostPopularUsernames = mostPopularUsernames
    }
}
