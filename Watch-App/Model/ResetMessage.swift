//
//  ResetMessage.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import WatchConnectivity

struct ResetMessage: Codable {
    var databaseUuid: String
    var isStartOfBatchUpdate: Bool
}
