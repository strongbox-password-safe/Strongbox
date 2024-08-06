//
//  AutoLayoutResizingTokenField.swift
//  MacBox
//
//  Created by Strongbox on 22/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoLayoutResizingTokenField: NSTokenField {
    override var intrinsicContentSize: NSSize {
        if !cell!.wraps {
            swlog("🔴 None-Wrapping!")
            return super.intrinsicContentSize
        }

        let originalIntrinsic = super.intrinsicContentSize

        let size = cell!.cellSize(forBounds: NSMakeRect(0, 0, bounds.size.width, CGFloat.greatestFiniteMagnitude))




        return NSMakeSize(originalIntrinsic.width, size.height)
    }
}
