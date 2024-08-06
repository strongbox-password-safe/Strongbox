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

    @IBOutlet var buttonClose: NSButton!
    @IBOutlet var buttonToggleKeyboardHints: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        textFieldQuickSearch.stringValue = quickSearchShortcut
        textFieldQuickSearch.isHidden = quickSearchShortcut.isEmpty

        textFieldShowStrongbox.stringValue = showStrongboxShortcut.isEmpty ? "⌘S" : showStrongboxShortcut

        buttonToggleKeyboardHints.contentTintColor = .clear
        buttonClose.contentTintColor = .clear
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeKey()
        view.window?.makeFirstResponder(buttonClose)
    }

    @IBAction func onClose(_: Any) {
        presentingViewController?.dismiss(self)
    }
}
