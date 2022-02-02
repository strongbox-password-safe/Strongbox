//
//  GrowingTextField.swift
//  MacBox
//
//  Created by Strongbox on 20/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

// H/T https://stackoverflow.com/questions/14107385/getting-a-nstextfield-to-grow-with-the-text-in-auto-layout

import Cocoa

class GrowingTextField: NSTextField {
    var editing = false
    var lastIntrinsicSize = NSSize.zero
    var hasLastIntrinsicSize = false
    var enableGrowth: Bool = false

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        editing = true
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        editing = false
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        var intrinsicSize = lastIntrinsicSize

        if editing || !hasLastIntrinsicSize {
            intrinsicSize = super.intrinsicContentSize

            
            if enableGrowth, let textView = window?.fieldEditor(false, for: self) as? NSTextView, let textContainer = textView.textContainer, var usedRect = textView.textContainer?.layoutManager?.usedRect(for: textContainer) {
                usedRect.size.height += 5.0 
                intrinsicSize.height = usedRect.size.height
            }

            lastIntrinsicSize = intrinsicSize
            hasLastIntrinsicSize = true
        }

        return intrinsicSize
    }
}
