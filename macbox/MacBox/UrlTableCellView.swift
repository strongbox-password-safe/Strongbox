//
//  UrlTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 23/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class UrlTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    @IBOutlet var textFieldValue: HyperlinkTextField!
    @IBOutlet var launchButton: NSButton!
    @IBOutlet var popupButton: NSPopUpButton!
    @IBOutlet var labelName: NSTextField!

    override func awakeFromNib() {
        textFieldValue.onClicked = { [weak self] in
            self?.onLaunchButton(nil)
        }
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField, popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil) {
        self.field = field
        self.popupMenuUpdater = popupMenuUpdater
        popupButton.menu?.delegate = self

        labelName.stringValue = field.name

        textFieldValue.href = field.value
        let str = field.value as NSString
        launchButton.isHidden = str.urlExtendedParse == nil
    }

    var onLaunch: (() -> Void)?
    @IBAction func onLaunchButton(_: Any?) {
        onLaunch?()
    }

    func showPopupButtonMenu() {
        NSLog("✅ showPopupButton")

        popupButton.performClick(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field = field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
}
