//
//  GetIconRequestResponse.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class GetIconRequest: NSObject, Codable {
    var databaseId: String
    var nodeId: UUID

    init(databaseId: String, nodeId: UUID) {
        self.databaseId = databaseId
        self.nodeId = nodeId
    }
}

class GetIconResponse: NSObject, Codable {
    var icon: String

    init(icon: String) {
        self.icon = icon
    }

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
