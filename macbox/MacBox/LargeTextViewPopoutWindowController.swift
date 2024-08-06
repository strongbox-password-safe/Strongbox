//
//  LargeTextViewPopoutWindowController.swift
//  MacBox
//
//  Created by Strongbox on 07/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class LargeTextViewPopoutWindow: NSWindow {
    override func cancelOperation(_: Any?) {
        close()
    }
}

class LargeTextViewPopoutWindowController: NSWindowController {
    class func instantiateFromStoryboard() -> LargeTextViewPopoutWindowController {
        let storyboard = NSStoryboard(name: "LargeTextViewPopout", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! LargeTextViewPopoutWindowController
        return wc
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        setupToolbar()

        bindFloatOnTop()
    }

    var theViewController: LargeTextViewAndQrCode {
        contentViewController as! LargeTextViewAndQrCode
    }

    func setContent(fieldName: String, string: String, largeText: Bool = true, subtext: String = "", qrCodeString: String? = nil) {
        theViewController.setContent(string: string, largeText: largeText, subtext: subtext, qrCodeString: qrCodeString)

        window?.subtitle = fieldName
    }

    @objc func onToggleFloatOnTop(_: Any?) {
        Settings.sharedInstance().largeTextViewFloatOnTop = !Settings.sharedInstance().largeTextViewFloatOnTop

        bindFloatOnTop()
    }

    func bindFloatOnTop() {
        window?.level = Settings.sharedInstance().largeTextViewFloatOnTop ? .floating : .normal

        guard let floatOnTopItem = window?.toolbar?.items.first(where: { item in
            item.itemIdentifier == LargeTextToolbarItemIdentifiers.floatOnTopLargeText
        }) else {
            swlog("🔴 Couldn't find the floatOnTop toolbar item")
            return
        }

        floatOnTopItem.image = NSImage(systemSymbolName: Settings.sharedInstance().largeTextViewFloatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)
    }
}

extension LargeTextViewPopoutWindowController: NSToolbarDelegate {
    enum LargeTextToolbarItemIdentifiers {
        static let floatOnTopLargeText = NSToolbarItem.Identifier("largeTextViewFloatOnTopToolbarItem")
    }

    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "nextgen-large-text-view-identifier-version-1.0")

        toolbar.autosavesConfiguration = true
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly

        guard let window else {
            swlog("🔴 Window not ready")
            return
        }

        window.toolbar = toolbar
        window.titlebarAppearsTransparent = false
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [LargeTextToolbarItemIdentifiers.floatOnTopLargeText]
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [LargeTextToolbarItemIdentifiers.floatOnTopLargeText]
    }

    func getFloatOnTopToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: LargeTextToolbarItemIdentifiers.floatOnTopLargeText)

        let loc2 = NSLocalizedString("window_toggle_float_on_top", comment: "Float on Top")

        toolbarItem.label = loc2
        toolbarItem.paletteLabel = loc2
        toolbarItem.toolTip = loc2
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onToggleFloatOnTop(_:))
        toolbarItem.image = NSImage(systemSymbolName: Settings.sharedInstance().largeTextViewFloatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)

        return toolbarItem
    }

    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        if itemIdentifier == LargeTextToolbarItemIdentifiers.floatOnTopLargeText {
            return getFloatOnTopToolbarItem()
        }

        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}
