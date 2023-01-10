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
    @IBOutlet weak var copyButton: NSButton!
    
    override func awakeFromNib() {
        buttonDisclosure.isHidden = true
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var onCopyClickedCallback : (() -> Void)?
    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField,
                    popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil,
                    showCopyButton : Bool = false,
                    onCopyClicked: (() -> Void)? = nil,
                    popupMenuImage : NSImage? = nil,
                    popupMenuText : String? = nil) {
        self.field = field
        self.popupMenuUpdater = popupMenuUpdater
        self.copyButton.isHidden = !showCopyButton
        self.onCopyClickedCallback = onCopyClicked
        
        labelHeader.stringValue = field.name

        popupButton.menu?.delegate = self
        popupButton.isHidden = popupMenuUpdater == nil
        
        if let popupMenuImage {
            popupButton.menu?.items.first?.image = popupMenuImage
            if #available(macOS 11, *) {
                popupButton.symbolConfiguration = NSImage.SymbolConfiguration(scale: .medium)
            }
        }
        else {
            if #available(macOS 11.0, *) {
                popupButton.menu?.items.first?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil )
                popupButton.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)
            }
        }
        
        if let popupMenuText {
            popupButton.title = popupMenuText
        }
        else {
            popupButton.title = ""
        }
    }

    var onDisclosureClicked: ((_: Bool) -> Void)?
    @IBAction func onDisclosure(_: Any) {
        onDisclosureClicked?(buttonDisclosure.state == .on)
    }

    @IBAction func onCopyClicked(_ sender: Any) {
        NSLog("onCopyClicked")
        
        onCopyClickedCallback?()
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
