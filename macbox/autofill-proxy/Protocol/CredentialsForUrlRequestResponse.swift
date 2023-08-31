//
//  CredentialsForUrlRequestResponse.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class CredentialsForUrlRequest: Codable {
    var url: String

    init(url: String) {
        self.url = url
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
