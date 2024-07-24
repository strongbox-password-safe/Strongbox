//
//  KeyboardShortcutsHelpViewController.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class KeyboardShortcutsHelpViewController: NSViewController {
    var quickSearchShortcut: String = ""
    var showStrongboxShortcut: String = ""

    @IBOutlet var textFieldQuickSearch: NSTextField!
    @IBOutlet var textFieldShowStrongbox: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        textFieldQuickSearch.stringValue = quickSearchShortcut
        textFieldQuickSearch.isHidden = quickSearchShortcut.isEmpty

        textFieldShowStrongbox.stringValue = showStrongboxShortcut
        textFieldShowStrongbox.isHidden = showStrongboxShortcut.isEmpty
    }
}
