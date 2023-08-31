//
//  TableViewWithKeyDownEvents.swift
//  MacBox
//
//  Created by Strongbox on 06/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class TableViewWithKeyDownEvents: NSTableView {
    var onDeleteKey: (() -> Void)?
    var onSpaceBar: (() -> Void)?
    var onEnterKey: (() -> Void)?
    var onAltEnter: (() -> Void)?
    var onEscKey: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.first else {
            return
        }

        if key == Character(UnicodeScalar(NSDeleteCharacter)!) ||
            key == Character(UnicodeScalar(NSBackspaceCharacter)!) ||
            key == Character(UnicodeScalar(63272)!), onDeleteKey != nil
        {
            onDeleteKey?()
        } else if key == Character(UnicodeScalar(NSEnterCharacter)!) || event.keyCode == 36, onEnterKey != nil {
            if event.modifierFlags.contains(.option) {
                onAltEnter?()
            } else {
                onEnterKey?()
            }
        } else if key == Character(" "), onSpaceBar != nil {
            onSpaceBar?()
        } else if event.keyCode == 53, onEscKey != nil {
            onEscKey?()
        } else {

            super.keyDown(with: event)
        }
    }

    
    

    var overrideValidateProposedFirstResponderForRow: ((_: Int) -> Bool?)?

    

    override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
        guard let overrideValidateProposedFirstResponderForRow, let event else {
            return super.validateProposedFirstResponder(responder, for: event)
        }

        let localLocation = convert(event.locationInWindow, from: nil)
        let row = row(at: localLocation)

        

        let foo = overrideValidateProposedFirstResponderForRow(row)

        if foo == nil {
            return super.validateProposedFirstResponder(responder, for: event)
        } else {
            return foo!
        }
    }

    
    

    private var _clickedRow: Int = -1
    override var clickedRow: Int {
        get { _clickedRow }
        set { _clickedRow = newValue }
    }

    override func mouseDown(with event: NSEvent) {
        let row = row(at: convert(event.locationInWindow, from: nil))
        clickedRow = row

        return super.mouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        clickedRow = row

        if row >= 0 {
            if isRowSelected(row) {
                return menu
            } else if let delegate {
                if delegate.tableView?(self, shouldSelectRow: row) ?? false {
                    selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                    return menu
                }
            }
        }

        
        
        

        return nil
    }

    var emptyMessageProvider: (() -> NSAttributedString?)?

    override func drawBackground(inClipRect clipRect: NSRect) {
        super.drawBackground(inClipRect: clipRect)

        NSColor.controlBackgroundColor.set()
        clipRect.fill()

        guard let emptyMessageProvider, numberOfRows == 0 else { return }

        guard let foo = emptyMessageProvider() else { return }

        let rect = foo.boundingRect(with: bounds.size,
                                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                                    context: nil)

        let size: CGSize = rect.size

        let x_pos = (clipRect.size.width - size.width) / 2.0
        let y_pos = (clipRect.size.height - size.height) / 2.0

        let rect2 = NSMakeRect(clipRect.origin.x + x_pos, clipRect.origin.y + y_pos, size.width, size.height)

        foo.draw(in: rect2)
    }
}
