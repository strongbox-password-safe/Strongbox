//
//  PaddedTextFieldCell.swift
//  Mac-Freemium
//
//  Created by Strongbox on 27/06/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class PaddedTextFieldCell: NSTextFieldCell {
    @IBInspectable var leftPadding: CGFloat = 10.0

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rectInset = NSMakeRect(rect.origin.x + leftPadding, rect.origin.y, rect.size.width - leftPadding, rect.size.height)
        return super.drawingRect(forBounds: rectInset)
    }
}

class CustomTextFieldCell: NSTextFieldCell {
    private static let padding = CGSize(width: 14.0, height: 14.0)

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += (CustomTextFieldCell.padding.height * 2)
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        rect.insetBy(dx: CustomTextFieldCell.padding.width, dy: CustomTextFieldCell.padding.height)
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: CustomTextFieldCell.padding.width, dy: CustomTextFieldCell.padding.height)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: CustomTextFieldCell.padding.width, dy: CustomTextFieldCell.padding.height)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.insetBy(dx: CustomTextFieldCell.padding.width, dy: CustomTextFieldCell.padding.height)
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
}
