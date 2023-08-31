//
//  ProAutoShowBadge.swift
//  MacBox
//
//  Created by Strongbox on 11/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class RoundedBadgeTextField: NSTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
        layer?.cornerRadius = 3
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let font = FontManager.shared.headlineItalicFont

        usesSingleLineMode = true
        attributedStringValue = NSAttributedString(string: stringValue, attributes: [.font: font, .paragraphStyle: paragraphStyle, .baselineOffset: 0.0])
    }
}

class RoundedPurpleBadgeTextField: RoundedBadgeTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = NSColor.systemPurple
        textColor = NSColor.white
    }
}

class RoundedBlueBadgeTextField: RoundedBadgeTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = NSColor.systemBlue
        textColor = NSColor.white
    }
}

class ProAutoShowBadge: RoundedBlueBadgeTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        bindUi()

        NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: nil) { [weak self] _ in
            self?.bindUi()
        }
    }

    func bindUi() {
        if Settings.sharedInstance().isPro {
            stringValue = ""
            isEnabled = false
            isHidden = true
        } else {
            layer?.backgroundColor = NSColor.systemBlue.cgColor

            let proString = NSLocalizedString("pro_badge_text", comment: "Pro")
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            usesSingleLineMode = true
            attributedStringValue = NSAttributedString(string: proString, attributes: [.font: FontManager.shared.headlineItalicFont, .baselineOffset: 0.0, .paragraphStyle: paragraphStyle])
        }
    }
}
