//
//  WhatIsMarkdownViewController.swift
//  MacBox
//
//  Created by Strongbox on 12/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class WhatIsMarkdownViewController: NSViewController {
    @IBOutlet var moreInfoLink: HyperlinkTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        moreInfoLink.href = "https://www.markdownguide.org/getting-started"
        moreInfoLink.onClicked = {
            NSWorkspace.shared.open(URL(string: "https://www.markdownguide.org/getting-started")!)
        }
    }
}
