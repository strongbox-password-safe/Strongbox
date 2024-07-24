//
//  ActionTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

class ActionTableCellView: NSTableCellView {
    static let NibName = "ActionTableCellView"
    static let Identifier = NSUserInterfaceItemIdentifier("ActionTableCellView")

    @IBOutlet var textFieldTitle: NSTextField!
    @IBOutlet var textFieldSubtitle: NSTextField!
    @IBOutlet var textFieldShortcut: NSTextField!

    func setContent(title: String, subTitle: String, keyboardShortcut: String) {
        let t = cleanedUp(title)
        textFieldTitle.stringValue = t.isEmpty ? NSLocalizedString("generic_unknown", comment: "Unknown") : t

        let sub = cleanedUp(subTitle)
        textFieldSubtitle.stringValue = sub
        textFieldSubtitle.isHidden = sub.isEmpty

        textFieldShortcut.stringValue = keyboardShortcut
        textFieldShortcut.isHidden = keyboardShortcut.isEmpty
    }

    func cleanedUp(_ string: String) -> String {
        if let firstLine = string.lines.first {
            return trim(firstLine)
        } else {
            return ""
        }
    }
}
