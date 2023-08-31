//
//  UrlCell.swift
//  MacBox
//
//  Created by Strongbox on 03/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class UrlCell: NSTableCellView {
    @IBOutlet var urlHyperLinkField: HyperlinkTextField!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("UrlCellTableViewCell")

    override func awakeFromNib() {
        super.awakeFromNib()

        urlHyperLinkField.linkColor = backgroundStyle == .emphasized ? .white : .linkColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        urlHyperLinkField.linkColor = backgroundStyle == .emphasized ? .white : .linkColor
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        willSet {
            urlHyperLinkField.linkColor = newValue == .emphasized ? .white : .linkColor
        }
    }
}
