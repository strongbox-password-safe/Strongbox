//
//  EntryViewTagTextField.swift
//  MacBox
//
//  Created by Strongbox on 22/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class EntryViewTagTextField: NSTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = NSColor.systemBlue
        textColor = NSColor.white

        drawsBackground = true
        wantsLayer = true
        layer?.cornerRadius = 5
        clipsToBounds = true
    }
}
