//
//  SearchRequestAndResponse.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

public class SearchRequest: NSObject, Codable {
    static let DefaultMaxResults = 24
    static let AbsoluteMaxResults = 64

    var query: String
    var skip: Int? = 0
    var take: Int? = DefaultMaxResults

    init(query: String, skip: Int? = nil, take: Int? = nil) {
        self.query = query
        self.skip = skip
        self.take = take
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}

public class SearchResponse: NSObject, Codable {
    var results: [AutoFillCredential] = []

    init(results: [AutoFillCredential]) {
        self.results = results
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
