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
    @IBOutlet var favStarIcon: NSImageView!

    @IBOutlet var trailingFavStar: NSImageView!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("TitleAndIconCell")

    override func prepareForReuse() {
        super.prepareForReuse()
        
        favStarIcon.isHidden = true
        trailingFavStar.isHidden = true
    }

    func setContent(_ attributedTitle: NSAttributedString,
                    editable : Bool = false,
                    iconImage: NSImage? = nil,
                    topSpacing: CGFloat = 4.0,
                    bottomSpacing: CGFloat = 4.0,
                    leadingSpace: CGFloat = 0.0,
                    showLeadingFavStar: Bool = false,
                    showTrailingFavStar: Bool = false,
                    contentTintColor: NSColor? = nil,
                    count: String? = nil,
                    onTitleEdited : (( _ text : String ) -> Void )? = nil)
    {
        favStarIcon.isHidden = !showLeadingFavStar
        trailingFavStar.isHidden = !showTrailingFavStar

        title.attributedStringValue = attributedTitle
        title.isEditable = editable
        self.onTitleEdited = onTitleEdited

        icon.image = iconImage
        icon.contentTintColor = contentTintColor

        if let count = count {
            childCount.isHidden = false
            childCount.stringValue = count
        } else {
            childCount.isHidden = true
        }

        topSpaceConstraint.constant = topSpacing
        bottomSpaceConstraint.constant = bottomSpacing
        leadingSpaceConstraint.constant = leadingSpace
    }
    
    var onTitleEdited : (( _ text : String ) -> Void )? = nil
    
    @IBAction func onEdited(_ sender: Any) {
        onTitleEdited?( title.stringValue )
    }
}
