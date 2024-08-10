//
//  ResultsHeaderCell.swift
//  MacBox
//
//  Created by Strongbox on 22/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class ResultsHeaderCell: NSTableCellView {
    static let NibName = "ResultsHeaderCell"
    static let Identifier = NSUserInterfaceItemIdentifier("ResultsHeaderCell")


    @IBOutlet var textFieldHeader: NSTextField!

    func setContent(title: String, icon _: NSImage) {
        textFieldHeader.stringValue = title

    }
}
