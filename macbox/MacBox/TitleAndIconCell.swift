//
//  TitleAndIconCell.swift
//  MacBox
//
//  Created by Strongbox on 31/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class TitleAndIconCell: NSTableCellView {
    @IBOutlet var icon: NSImageView!
    @IBOutlet var title: NSTextField!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("TitleAndIconCell")

    override func prepareForReuse() {
        super.prepareForReuse()

        title.action = nil
        title.isEditable = false
    }
}
