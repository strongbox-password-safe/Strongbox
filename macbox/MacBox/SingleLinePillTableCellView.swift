//
//  SingleLinePillTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 07/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import Foundation

class SingleLinePillTableCellView: NSTableCellView {
    static let NibIdentifier: NSUserInterfaceItemIdentifier = .init("SingleLinePillTableCellView")

    @IBOutlet var stackView: NSStackView!

    override func awakeFromNib() {
        super.awakeFromNib()

        wantsLayer = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        clearContent()
    }

    func clearContent() {
        for subview in stackView.arrangedSubviews {
            stackView.removeView(subview)
        }
    }

    func setContent(_ items: [String], color: NSColor, backgroundColor: NSColor, icon: NSImage) {
        clearContent()

        for item in items {
            guard let view = createPill(item, color: color, backgroundColor: backgroundColor, icon: icon) else {
                swlog("🔴Couldn't load nib view")
                return
            }

            stackView.addView(view, in: .leading)
        }

        stackView.clipsToBounds = true
    }

    func createPill(_ string: String, color: NSColor, backgroundColor: NSColor, icon: NSImage) -> NSView? {
        guard let ret = PillView.createFromNib() else {
            return nil
        }

        ret.setContent(string, color, backgroundColor: backgroundColor, icon: icon)

        return ret
    }
}
