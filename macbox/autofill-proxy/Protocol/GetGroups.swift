//
//  GetGroups.swift
//  MacBox
//
//  Created by Strongbox on 23/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class GetGroupsRequest: Codable {
    var databaseId: String
}

class GroupSummary: Codable {
    var title: String
    var uuid: String

    init(title: String, uuid: String) {
        self.title = title
        self.uuid = uuid
    }
}

class GetGroupsResponse: Codable {
    var groups: [GroupSummary]?
    var error: String?
}
