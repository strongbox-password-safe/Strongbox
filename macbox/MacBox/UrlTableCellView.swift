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
    @IBOutlet var copyButton: NSButton!

    @IBOutlet var stackViewAssociated: NSStackView!
    @IBOutlet var labelAssociated: NSTextField!

    override func awakeFromNib() {
        textFieldValue.onClicked = { [weak self] in
            self?.onLaunch?()
        }
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var onCopyButton: ((DetailsViewField?) -> Void)?

    var field: DetailsViewField?
    var associatedWebsites: String = ""

    func setContent(_ field: DetailsViewField,
                    _ associatedWebsites: String,
                    popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil,
                    onCopyButton: ((DetailsViewField?) -> Void)? = nil)
    {
        self.field = field
        self.popupMenuUpdater = popupMenuUpdater
        popupButton.menu?.delegate = self

        self.onCopyButton = onCopyButton
        copyButton.isHidden = onCopyButton == nil

        labelName.stringValue = field.name

        textFieldValue.href = field.value
        let str = field.value as NSString
        launchButton.isHidden = str.urlExtendedParse == nil

        self.associatedWebsites = associatedWebsites
        bindAssociated()
    }

    func bindAssociated() {
        stackViewAssociated.isHidden = associatedWebsites.count == 0
        labelAssociated.stringValue = associatedWebsites
    }

    var onLaunch: (() -> Void)?
    var onLaunchAndCopy: (() -> Void)?

    @IBAction func onLaunchButton(_: Any?) {
        onLaunchAndCopy?()
    }

    func showPopupButtonMenu() {


        popupButton.performClick(nil)
    }

    @IBAction func onCopy(_: Any) {
        onCopyButton?(field)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
}
