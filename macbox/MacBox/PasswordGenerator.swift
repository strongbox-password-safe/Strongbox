//
//  PasswordGenerator.swift
//  MacBox
//
//  Created by Strongbox on 24/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa

class PasswordGeneratorWindow: NSWindow {
    override func cancelOperation(_: Any?) {
        close()
    }

    var theViewController: PasswordGenerationPreferences {
        contentViewController as! PasswordGenerationPreferences
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), let key = event.charactersIgnoringModifiers?.first, key == "c" {
            theViewController.onSamplePasswordClicked()
        } else if event.keyCode == 36 || event.keyCode == 49 || event.keyCode == 76 { 
            theViewController.refreshSample()
        } else {
            return super.keyDown(with: event)
        }
    }
}

class PasswordGenerator: NSWindowController {
    @objc
    static let sharedInstance: PasswordGenerator = .instantiateFromStoryboard()

    private class func instantiateFromStoryboard() -> PasswordGenerator {
        let storyboard = NSStoryboard(name: "PasswordGenerator", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! PasswordGenerator
        return wc
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        setupToolbar()

        guard let window else {
            swlog("🔴 Couldn't get window in WindowDidLoad?!")
            return
        }

        window.title = NSLocalizedString("popout_password_generator", comment: "Password Generator")

        bindFloatOnTop()
    }

    @objc
    public func show() {
        showWindow(nil)
    }

    @objc func onToggleFloatOnTop(_: Any?) {
        Settings.sharedInstance().passwordGeneratorFloatOnTop = !Settings.sharedInstance().passwordGeneratorFloatOnTop

        bindFloatOnTop()
    }

    func bindFloatOnTop() {
        window?.level = Settings.sharedInstance().passwordGeneratorFloatOnTop ? .floating : .normal

        guard let floatOnTopItem = window?.toolbar?.items.first(where: { item in
            item.itemIdentifier == ToolbarItemIdentifiers.floatOnTop
        }) else {
            swlog("🔴 Couldn't find the floatOnTop toolbar item")
            return
        }

        floatOnTopItem.image = NSImage(systemSymbolName: Settings.sharedInstance().passwordGeneratorFloatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)
    }























}

extension PasswordGenerator: NSToolbarDelegate {
    enum ToolbarItemIdentifiers {
        static let floatOnTop = NSToolbarItem.Identifier("generatorFloatOnTopToolbarItem")
    }

    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "nextgen-password-generator-identifier-version-1.0")

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
        [ToolbarItemIdentifiers.floatOnTop]
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [ToolbarItemIdentifiers.floatOnTop]
    }

    func getFloatOnTopToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.floatOnTop)

        let loc2 = NSLocalizedString("window_toggle_float_on_top", comment: "Float on Top")

        toolbarItem.label = loc2
        toolbarItem.paletteLabel = loc2
        toolbarItem.toolTip = loc2
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onToggleFloatOnTop(_:))
        toolbarItem.image = NSImage(systemSymbolName: Settings.sharedInstance().passwordGeneratorFloatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)

        return toolbarItem
    }

    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        if itemIdentifier == ToolbarItemIdentifiers.floatOnTop {
            return getFloatOnTopToolbarItem()
        }

        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}
