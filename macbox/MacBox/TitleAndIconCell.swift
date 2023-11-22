//
//  TitleAndIconCell.swift
//  MacBox
//
//  Created by Strongbox on 31/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class TitleAndIconCell: NSTableCellView, NSTextFieldDelegate {
    @IBOutlet var icon: NSImageView!
    @IBOutlet var title: NSTextField!
    @IBOutlet var topSpaceConstraint: NSLayoutConstraint!
    @IBOutlet var leadingSpaceConstraint: NSLayoutConstraint!
    @IBOutlet var bottomSpaceConstraint: NSLayoutConstraint!
    @IBOutlet var childCount: NSTextField!
    @IBOutlet var trailingFavStar: NSImageView!

    @IBOutlet var titleWidthConstraint: NSLayoutConstraint!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("TitleAndIconCell")

    override func prepareForReuse() {
        super.prepareForReuse()

        title.isEditable = false
        trailingFavStar.isHidden = true
    }

    func setContent(_ text: String,
                    font: NSFont? = FontManager.shared.bodyFont,
                    textTintColor: NSColor? = nil,
                    editable: Bool = false,
                    iconImage: NSImage? = nil,
                    topSpacing: CGFloat = 4.0,
                    bottomSpacing: CGFloat = 4.0,
                    leadingSpace: CGFloat = 0.0,
                    showTrailingFavStar: Bool = false,
                    iconTintColor: NSColor? = nil,
                    count: String? = nil,
                    tooltip: String? = nil,
                    onTitleEdited: ((_ text: String) -> Void)? = nil)
    {
        trailingFavStar.isHidden = !showTrailingFavStar

        title.font = font
        title.stringValue = text
        title.textColor = textTintColor ?? .labelColor

        
        
        
        
        
        
        

        titleWidthConstraint.constant = title.intrinsicContentSize.width
        title.isEditable = editable
        self.onTitleEdited = onTitleEdited

        toolTip = tooltip

        icon.image = iconImage
        icon.contentTintColor = iconTintColor

        if let count {
            childCount.isHidden = false
            childCount.stringValue = count
        } else {
            childCount.isHidden = true
        }
        childCount.textColor = textTintColor ?? .secondaryLabelColor

        topSpaceConstraint.constant = topSpacing
        bottomSpaceConstraint.constant = bottomSpacing
        leadingSpaceConstraint.constant = leadingSpace
    }

    var onTitleEdited: ((_ text: String) -> Void)? = nil

    @IBAction func onEdited(_: Any) {
        onTitleEdited?(title.stringValue)
    }
}
