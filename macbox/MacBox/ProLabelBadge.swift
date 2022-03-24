//
//  ProLabelBadge.swift
//  MacBox
//
//  Created by Strongbox on 11/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class ProLabelBadge: NSTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        if Settings.sharedInstance().isPro {
            stringValue = ""
            isEnabled = false
            isHidden = true
        } else {
            wantsLayer = true
            layer?.cornerRadius = 3
            layer?.backgroundColor = NSColor.systemBlue.cgColor

            let proString = NSLocalizedString("pro_badge_text", comment: "Pro")
            let style = NSMutableParagraphStyle()
            style.alignment = .center

            usesSingleLineMode = true
            attributedStringValue = NSAttributedString(string: proString, attributes: [.font: FontManager.shared.headlineItalicFont, .baselineOffset: 1.0])
        }
    }
}
