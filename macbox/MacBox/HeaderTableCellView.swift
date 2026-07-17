//
//  HeaderTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 20/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class HeaderTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    @IBOutlet var labelHeader: NSTextField!
    @IBOutlet var buttonDisclosure: NSButton!
    @IBOutlet var popupButton: NSPopUpButton!
    @IBOutlet var copyButton: NSButton!

    override func awakeFromNib() {
        buttonDisclosure.isHidden = true
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var onCopyClickedCallback: (() -> Void)?
    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField,
                    popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil,
                    showCopyButton: Bool = false,
                    onCopyClicked: (() -> Void)? = nil,
                    popupMenuImage: NSImage? = nil,
                    popupMenuText: String? = nil,
                    showDisclosure: Bool = false,
                    disclosureExpanded: Bool = true,
                    onDisclosureClicked: ((Bool) -> Void)? = nil)
    {
        self.field = field
        self.popupMenuUpdater = popupMenuUpdater
        copyButton.isHidden = !showCopyButton
        onCopyClickedCallback = onCopyClicked
        self.onDisclosureClicked = onDisclosureClicked

        labelHeader.stringValue = field.name

        buttonDisclosure.isHidden = !showDisclosure
        buttonDisclosure.state = disclosureExpanded ? .on : .off
        updateDisclosureAccessibility(sectionName: field.name,
                                      isExpanded: disclosureExpanded,
                                      showDisclosure: showDisclosure)

        popupButton.menu?.delegate = self
        popupButton.isHidden = popupMenuUpdater == nil

        if let popupMenuImage {
            popupButton.menu?.items.first?.image = popupMenuImage
            popupButton.symbolConfiguration = NSImage.SymbolConfiguration(scale: .medium)
        } else {
            popupButton.menu?.items.first?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil)
            popupButton.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)
        }

        if let popupMenuText {
            popupButton.title = popupMenuText
        } else {
            popupButton.title = ""
        }
    }

    var onDisclosureClicked: ((_: Bool) -> Void)?
    @IBAction func onDisclosure(_: Any) {
        onDisclosureClicked?(buttonDisclosure.state == .on)
    }

    private func updateDisclosureAccessibility(sectionName: String, isExpanded: Bool, showDisclosure: Bool) {
        guard showDisclosure else {
            buttonDisclosure.toolTip = nil
            buttonDisclosure.setAccessibilityLabel(nil)
            return
        }

        let formatKey = isExpanded ? "item_details_section_disclosure_collapse_fmt" : "item_details_section_disclosure_expand_fmt"
        let fallbackValue = isExpanded ? "Collapse %@ section" : "Expand %@ section"
        let format = NSLocalizedString(formatKey,
                                       tableName: nil,
                                       bundle: .main,
                                       value: fallbackValue,
                                       comment: "Tooltip and accessibility label for the detail section disclosure button")
        let label = String(format: format, sectionName)
        buttonDisclosure.toolTip = label
        buttonDisclosure.setAccessibilityLabel(label)
    }

    @IBAction func onCopyClicked(_: Any) {
        swlog("onCopyClicked")

        onCopyClickedCallback?()
    }

    func showPopupButtonMenu() {
        swlog("✅ showPopupButton")

        popupButton.performClick(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
}
