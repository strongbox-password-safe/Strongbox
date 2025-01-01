//
//  WatchDatabaseModel.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WatchDatabaseModel: Codable, Hashable, Identifiable {
    var id: String {
        uuid
    }

    var nickName: String
    var uuid: String
    var iconSet: Int
}
