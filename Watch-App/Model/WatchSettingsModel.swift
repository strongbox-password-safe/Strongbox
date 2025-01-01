//
//  WatchSettingsModel.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WatchSettingsModel: Codable {
    var pro: Bool
    var markdownNotes: Bool = true
    var twoFactorEasyReadSeparator: Bool = true
    var colorBlind: Bool = false
}
