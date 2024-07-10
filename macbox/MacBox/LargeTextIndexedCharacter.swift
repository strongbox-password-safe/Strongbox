//
//  LargeTextIndexedCharacter.swift
//  MacBox
//
//  Created by Strongbox on 24/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class LargeTextIndexedCharacter: NSCollectionViewItem {
    @IBOutlet var labelCharacter: NSTextField!
    @IBOutlet var labelIndex: NSTextField!

    static let DarkModeColor1 = NSColor(hex: "#535353")
    static let DarkModeColor2 = NSColor(hex: "#424242")
    static let LightModeColor1 = NSColor(hex: "#DED4D4")
    static let LightModeColor2 = NSColor(hex: "#EFE5E5")

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("LargeTextIndexedCharacterReuseIdentifier")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
    }

    func setContent(index: Int, attributedString: NSAttributedString) {
        labelCharacter.attributedStringValue = attributedString
        labelIndex.stringValue = String(index)

        if DarkMode.isOn {
            view.layer?.backgroundColor = index % 2 == 0 ? LargeTextIndexedCharacter.DarkModeColor1.cgColor : LargeTextIndexedCharacter.DarkModeColor2.cgColor
        } else {
            view.layer?.backgroundColor = index % 2 == 0 ? LargeTextIndexedCharacter.LightModeColor1.cgColor : LargeTextIndexedCharacter.LightModeColor2.cgColor
        }
    }
}
