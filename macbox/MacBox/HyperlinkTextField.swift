//
//  HyperlinkTextField.swift
//  MacBox
//
//  Created by Strongbox on 23/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class HyperlinkTextField: NSTextField {
    override func awakeFromNib() {
        super.awakeFromNib()

        attributedStringValue = NSAttributedString(string: "<Not Set>")
    }

    private var parsedUrl: URL? {
        let str = href as NSString
        return str.urlExtendedParse
    }

    var linkColor: NSColor = .linkColor {
        didSet {
            refresh()
        }
    }

    var href: String = "" {
        didSet {
            refresh()
        }
    }

    func refresh() {
        if let _ = parsedUrl {
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key.foregroundColor: linkColor,
                NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue as AnyObject,
            ]
            attributedStringValue = NSAttributedString(string: href, attributes: attributes)
        } else {
            attributedStringValue = NSAttributedString(string: href)
        }
    }

    override func resetCursorRects() {
        discardCursorRects()

        if let _ = parsedUrl {
            addCursorRect(bounds, cursor: NSCursor.pointingHand)
        }
    }

    var onClicked: (() -> Void)?
    override func mouseDown(with _: NSEvent) {
        if parsedUrl != nil {
            onClicked?()
        }
    }



















}
