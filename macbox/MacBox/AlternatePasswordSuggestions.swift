//
//  AlternatePasswordSuggestions.swift
//  MacBox
//
//  Created by Strongbox on 02/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AlternatePasswordSuggestions: NSViewController {
    @IBOutlet var stackView: NSStackView!

    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("AlternatePasswordSuggestions"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let colorize = Settings.sharedInstance().colorizePasswords
        let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
        let dark = DarkMode.isOn

        let suggestions = ["Foo", "bar"]

        for suggestion in suggestions {
            let colored = ColoredStringHelper.getColorizedAttributedString(suggestion, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.easyReadFont)

            let label = NSTextField()

            label.isBordered = false
            label.isEditable = false

            if #available(macOS 11.0, *) {
                label.controlSize = .large
            }

            label.attributedStringValue = colored

            stackView.addArrangedSubview(label)
        }
    }
}
