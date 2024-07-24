//
//  HeaderTableRowView.swift
//  MacBox
//
//  Created by Strongbox on 20/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class HeaderTableRowView: NSTableRowView {


    override func draw(_ dirtyRect: NSRect) {




        NSColor.windowBackgroundColor.setFill()

        dirtyRect.fill()
    }

    override func drawBackground(in _: NSRect) {
        
    }
}
