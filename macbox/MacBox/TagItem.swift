//
//  TagItem.swift
//  MacBox
//
//  Created by Strongbox on 21/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class TagItem: NSCollectionViewItem {
    @IBOutlet var label: NSTextField!

    static let reuseIdentifier = NSUserInterfaceItemIdentifier("TagItemReuseIdentifier")

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.linkColor.cgColor
        view.layer?.cornerRadius = 8.0

        if #available(macOS 10.13, *) {

        }
    }
}
