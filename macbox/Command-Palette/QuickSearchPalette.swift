//
//  QuickSearchPalette.swift
//  MacBox
//
//  Created by Strongbox on 15/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

@objc
class QuickSearchPalette: NSObject {
    @objc static let shared = QuickSearchPalette()

    let model = QuickSearchViewModel()
    let panel: QuickSearchPalettePanel

    override init() {
        panel = QuickSearchPalettePanel(model: model)

        super.init()
    }

    @objc
    func toggleShow() {
        panel.toggleShow()
    }
}
