//
//  SearchRequestAndResponse.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class SearchRequest: Codable {
    var query: String

    init(query: String) {
        self.query = query
    }
}

class SearchResponse: Codable {
    var results: [AutoFillCredential]

    init(results: [AutoFillCredential]) {
        self.results = results
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
