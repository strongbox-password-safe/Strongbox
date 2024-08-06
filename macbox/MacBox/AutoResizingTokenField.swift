//
//  AutoResizingTokenField.swift
//  MacBox
//
//  Created by Strongbox on 10/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoResizingTokenField: OEXTokenField {
    private var editing = false
    private var explicitResizeRequest = false

    func explicitResizeToFitContent() {
        explicitResizeRequest = true
        _ = intrinsicContentSize
        explicitResizeRequest = false

        invalidateIntrinsicContentSize()
    }

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
            swlog("🔴 None-Wrapping!")
            return super.intrinsicContentSize
        }

        if lastIntrinsicSize == nil {
            lastIntrinsicSize = super.intrinsicContentSize
        }

        if editing || explicitResizeRequest { 
            let size = cell!.cellSize(forBounds: NSMakeRect(0, 0, bounds.size.width, CGFloat.greatestFiniteMagnitude))




            lastIntrinsicSize = NSMakeSize(bounds.size.width, size.height)
        }

        return lastIntrinsicSize!
    }
}
