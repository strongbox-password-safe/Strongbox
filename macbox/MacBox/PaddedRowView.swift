//
//  PaddedRowView.swift
//  MacBox
//
//  Created by Strongbox on 14/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

// import AppKit


class PaddedRowView: NSTableRowView {
    
    override var backgroundColor: NSColor {
        get {
            .red
        }
        set {}
    }





    var topPadding: CGFloat = 12.0






    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            if isEmphasized {
                let padded = NSRect(x: bounds.minX, y: bounds.minY + topPadding, width: bounds.width, height: bounds.height - topPadding)

                let selectionRect = padded.insetBy(dx: 10, dy: 0.0)

                

                let color = NSColorFromRGB(0x143EAB)

                color.setFill()

                let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 5, yRadius: 5)
                selectionPath.fill()
            } else {
                
            }
        } else {
            super.drawSelection(in: dirtyRect)
        }
    }

    
    






















    





}































































































