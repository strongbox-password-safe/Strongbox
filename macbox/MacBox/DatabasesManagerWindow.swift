//
//  DatabasesManagerWindow.swift
//  MacBox
//
//  Created by Strongbox on 23/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class DatabasesManagerWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override func cancelOperation(_: Any?) { 
        close()
    }
}
