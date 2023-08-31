//
//  PillView.swift
//  MacBox
//
//  Created by Strongbox on 07/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class PillView: NSView, NibLoadable {
    @IBOutlet var imagePill: NSImageView!
    @IBOutlet var labelText: NSTextField!

    override func awakeFromNib() {
        wantsLayer = true
        layer?.cornerRadius = 5
    }

    func setContent(_ string: String, _ color: NSColor, backgroundColor: NSColor, icon: NSImage) {
        labelText.stringValue = string

        labelText.textColor = color
        layer?.backgroundColor = backgroundColor.cgColor

        imagePill.image = icon
        imagePill.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)

        imagePill.contentTintColor = color
    }
}
