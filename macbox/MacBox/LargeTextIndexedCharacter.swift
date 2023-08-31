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

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("LargeTextIndexedCharacterReuseIdentifier")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
