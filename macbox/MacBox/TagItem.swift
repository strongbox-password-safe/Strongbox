//
//  TagItem.swift
//  MacBox
//
//  Created by Strongbox on 21/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class TagItem: NSCollectionViewItem {
    @IBOutlet var label: NSTextField!
    @IBOutlet var tagIcon: NSImageView!

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("TagItemReuseIdentifier")
    static let itemHeight: CGFloat = 24.0
    static let labelFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)

    private static let leadingPadding: CGFloat = 4.0
    private static let trailingPadding: CGFloat = 8.0
    private static let iconWidth: CGFloat = 20.0
    private static let iconSpacing: CGFloat = 4.0
    private static let minimumTextWidth: CGFloat = 24.0

    static func preferredSize(for title: String, maxWidth: CGFloat) -> NSSize {
        let textWidth = ceil((title as NSString).size(withAttributes: [.font: labelFont]).width)
        let desiredWidth = leadingPadding + iconWidth + iconSpacing + max(minimumTextWidth, textWidth) + trailingPadding

        return NSSize(width: min(max(1.0, maxWidth), desiredWidth), height: itemHeight)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.linkColor.cgColor
        view.layer?.cornerCurve = .continuous

        label.font = Self.labelFont
        label.textColor = .white

        tagIcon.image = NSImage(systemSymbolName: "tag.fill", accessibilityDescription: nil)
        tagIcon.contentTintColor = .white
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        view.layer?.cornerRadius = view.bounds.height / 2.0
    }
}
