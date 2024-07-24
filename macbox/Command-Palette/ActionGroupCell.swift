//
//  ActionGroupCell.swift
//  MacBox
//
//  Created by Strongbox on 20/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class ActionGroupCell: NSTableCellView {
    static let NibName = "ActionGroupCell"
    static let Identifier = NSUserInterfaceItemIdentifier("ActionGroupCell")

    @IBOutlet var labelHeader: NSTextField!

    func setContent(title: String) {
        labelHeader.stringValue = title
        labelHeader.isHidden = title.isEmpty
    }
}
