//
//  CredentialsForUrlRequestResponse.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class CredentialsForUrlRequest: Codable {
    static let DefaultMaxResults = 12
    static let AbsoluteMaxResults = 24

    var url: String
    var skip: Int? = 0
    var take: Int? = DefaultMaxResults

    init(url: String, skip: Int? = nil, take: Int? = nil) {
        self.url = url
        self.skip = skip
        self.take = take
    }
}

class CredentialsForUrlResponse: Codable {
    var results: [AutoFillCredential]
    var unlockedDatabaseCount: Int

    init(results: [AutoFillCredential], unlockedDatabaseCount: Int) {
        self.results = results
        self.unlockedDatabaseCount = unlockedDatabaseCount
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
