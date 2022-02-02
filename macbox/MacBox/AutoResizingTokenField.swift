//
//  AutoResizingTokenField.swift
//  MacBox
//
//  Created by Strongbox on 10/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoResizingTokenField: NSTokenField {
    var editing = false

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        invalidateIntrinsicContentSize()
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        editing = true
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        editing = false
    }

    var lastIntrinsicSize: NSSize?
    override var intrinsicContentSize: NSSize {
        if !cell!.wraps {
            NSLog("🔴 None-Wrapping!")
            return super.intrinsicContentSize
        }

        if lastIntrinsicSize == nil {
            lastIntrinsicSize = super.intrinsicContentSize
        }

        if editing {
            let size = cell!.cellSize(forBounds: NSMakeRect(0, 0, bounds.size.width, CGFloat.greatestFiniteMagnitude))




            lastIntrinsicSize = NSMakeSize(bounds.size.width, size.height)
        }

        return lastIntrinsicSize!
    }
}
