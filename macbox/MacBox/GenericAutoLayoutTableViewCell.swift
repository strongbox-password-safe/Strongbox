//
//  GenericAutoLayoutTableViewCell.swift
//  MacBox
//
//  Created by Strongbox on 31/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class GenericAutoLayoutTableViewCell: NSTableCellView {
    @IBOutlet var title: NSTextField!

    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("GenericAutoLayoutTableViewCell")
}
