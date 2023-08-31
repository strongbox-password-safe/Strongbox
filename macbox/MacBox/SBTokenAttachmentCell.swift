//
//  SBTokenAttachmentCell.swift
//  MacBox
//
//  Created by Strongbox on 11/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class SBTokenAttachmentCell: OEXTokenAttachmentCell {
    override func titleMargin() -> CGFloat {
        6.0
    }

    override func tokenMargin() -> CGFloat {
        4.0
    }

    let heightPadding: CGFloat = 10.0
    let heightMargin: CGFloat = 4.0

    override func titleRect(forBounds bounds: NSRect) -> NSRect {
        let titleMargin = titleMargin()

        var foo = bounds
        foo.size.width = max(bounds.size.width, titleMargin * 2 + bounds.size.height)

        return NSInsetRect(foo, titleMargin + foo.size.height / 2, heightPadding / 2)
    }

    override func cellSize(forTitleSize titleSize: NSSize) -> NSSize {
        var size = titleSize

        size.height += heightPadding
        size.width += size.height + (titleMargin() * 2)

        let rect = NSMakeRect(0, 0, size.width, size.height)

        return NSIntegralRect(rect).size
    }

    override func tokenFillColor(for drawingMode: OEXTokenDrawingMode) -> NSColor! {
        switch drawingMode {
        case .default:
            return .linkColor
        case .highlighted:
            return .linkColor
        case .selected:
            return NSColorFromRGB(0x00008B)
        @unknown default:
            return .linkColor
        }
    }

    override func tokenStrokeColor(for drawingMode: OEXTokenDrawingMode) -> NSColor! {
        switch drawingMode {
        case .default:
            return .linkColor
        case .highlighted:
            return super.tokenStrokeColor(for: drawingMode)
        case .selected:
            return super.tokenStrokeColor(for: drawingMode)
        @unknown default:
            return .linkColor
        }
    }

    override func tokenTitleColor(for _: OEXTokenDrawingMode) -> NSColor! {
        .white
    }

    override func tokenPath(forBounds bounds: NSRect, joinStyle _: OEXTokenJoinStyle) -> NSBezierPath! {
        let newRect = NSInsetRect(bounds, tokenMargin(), heightMargin)

        let path = NSBezierPath(roundedRect: newRect, xRadius: 5, yRadius: 5)

        return path
    }
}
