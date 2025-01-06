//
//  WatchSettingsModel.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WatchSettingsModel: Codable {
    var pro: Bool = false
    var markdownNotes: Bool = true
    var twoFactorEasyReadSeparator: Bool = true
    var colorBlind: Bool = false

    private var twoFactorHideCountdownDigitsBacking: Bool? = nil
    var twoFactorHideCountdownDigits: Bool {
        get {
            twoFactorHideCountdownDigitsBacking ?? false
        }
        set {
            twoFactorHideCountdownDigitsBacking = newValue
        }
    }

    enum CodingKeys: String, CodingKey {
        case pro
        case markdownNotes
        case twoFactorEasyReadSeparator
        case colorBlind
        case twoFactorHideCountdownDigitsBacking = "twoFactorHideCountdownDigits"
    }
}
