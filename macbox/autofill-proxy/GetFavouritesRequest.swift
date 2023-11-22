//
//  GetFavouritesRequest.swift
//  MacBox
//
//  Created by Strongbox on 14/11/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class GetFavouritesRequest: Codable {
    static let DefaultMaxResults = 48
    static let AbsoluteMaxResults = 48

    var skip: Int? = 0
    var take: Int? = DefaultMaxResults

    init(skip: Int? = nil, take: Int? = nil) {
        self.skip = skip
        self.take = take
    }
}

class GetFavouritesResponse: Codable {
    var results: [AutoFillCredential]

    init(results: [AutoFillCredential]) {
        self.results = results
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
