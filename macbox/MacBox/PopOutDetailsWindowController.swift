//
//  PopOutDetailsWindowController.swift
//  MacBox
//
//  Created by Strongbox on 02/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class PopOutDetailsWindowController: NSWindowController {
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("PopOutDetails"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        
        setupToolbar()
        
        bindScreenCaptureBlock()
    }
    
    func bindScreenCaptureBlock() {
        if let window = window {
            window.sharingType = Settings.sharedInstance().screenCaptureBlocked ? .none : .readOnly
        }
    }
    
    var viewController: DetailViewController {
        return contentViewController as! DetailViewController
    }

    var database: ViewModel!
    var uuid: UUID!

    func load(model: ViewModel, uuid: UUID) {
        database = model
        self.uuid = uuid

        viewController.load(explicitDocument: model.document, explicitItemUuid: uuid)

        guard let node = model.getItemBy(uuid) else {
            NSLog("🔴 PopOutDetailsWindowController - Could not find Item")
            return
        }

        let title = model.dereference(node.title, node: node)

        window?.title = title

        window?.toolbar?.validateVisibleItems()
    }

    @objc func onEditEntry2(_ sender : Any?) {
        if database.locked || database.isEffectivelyReadOnly {
            NSLog("🔴 Cannot edit locked or read-only database")
            return
        }

        let vc = CreateEditViewController.instantiateFromStoryboard()

        guard let selectedItem = database.nextGenSelectedItems.first, database.nextGenSelectedItems.count == 1 else {
            NSLog("🔴 Selected Item not set for Editing!")
            return
        }

        vc.initialNodeId = selectedItem
        vc.database = database

        viewController.presentAsSheet(vc)
    }

    var floatOnTop : Bool = false
    
    @objc func onToggleFloatOnTop(_ sender : Any?) {
        floatOnTop = !floatOnTop
        
        window?.level = floatOnTop ? .floating : .normal
        
        if #available(macOS 11.0, *) {
            guard let floatOnTopItem = window?.toolbar?.items.first(where: { item in
                item.itemIdentifier == ToolbarItemIdentifiers.floatOnTop
            }) else {
                NSLog("🔴 Couldn't find the floatOnTop toolbar item")
                return
            }
                    
            floatOnTopItem.image = NSImage(systemSymbolName: floatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)
        }
    }
    
    @objc
    var isEditsInProgress: Bool {
        if let presentedViewControllers = viewController.presentedViewControllers {
            for presentedViewController in presentedViewControllers {
                if let editVc = presentedViewController as? CreateEditViewController {
                    if editVc.isEditsInProgress {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    @objc func copy ( _ sender : Any? ) -> Any? {
        viewController.handleCopy()
    }
}

extension PopOutDetailsWindowController : NSToolbarDelegate {
    enum ToolbarItemIdentifiers {
        static let editEntry = NSToolbarItem.Identifier("editEntryToolbarItem")
        static let floatOnTop = NSToolbarItem.Identifier("floatOnTopToolbarItem")
    }

    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "nextgen-popout-identifier-version-2.0")

        toolbar.autosavesConfiguration = true
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly

        guard let window = window else {
            NSLog("🔴 Window not ready")
            return
        }

        window.toolbar = toolbar
        window.titlebarAppearsTransparent = false
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.editEntry,
                    ToolbarItemIdentifiers.floatOnTop]
        } else {
            return [] 
        }
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.editEntry,
                    ToolbarItemIdentifiers.floatOnTop]
        } else {
            return [] 
        }
    }
    
    func getEditEntryToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.editEntry)

        toolbarItem.label = NSLocalizedString("browse_vc_action_edit", comment: "Edit")

        let loc2 = NSLocalizedString("edit_entry", comment: "Edit Entry")
        toolbarItem.paletteLabel = loc2
        toolbarItem.toolTip = loc2
        toolbarItem.isEnabled = true
        
        toolbarItem.target = self
        toolbarItem.action = #selector(onEditEntry2(_:))
        
        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }

        return toolbarItem
    }

    func getFloatOnTopToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.floatOnTop)

        let loc2 =  NSLocalizedString("window_toggle_float_on_top", comment: "Float on Top")

        toolbarItem.label = loc2
        toolbarItem.paletteLabel = loc2
        toolbarItem.toolTip = loc2
        toolbarItem.isEnabled = true
        
        toolbarItem.target = self
        toolbarItem.action = #selector(onToggleFloatOnTop(_:))
        
        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: floatOnTop ? "pin.slash" : "pin", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }

        return toolbarItem
    }
    
    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        if itemIdentifier == ToolbarItemIdentifiers.editEntry {
            return getEditEntryToolbarItem()
        }
        else if itemIdentifier == ToolbarItemIdentifiers.floatOnTop {
            return getFloatOnTopToolbarItem()
        }
        
        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}

extension PopOutDetailsWindowController : NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let action = item.action, let database = database else { return false }

        if action == #selector(onEditEntry2(_:)) {
            return !database.locked && !database.isEffectivelyReadOnly
        }
        else if action == #selector(onToggleFloatOnTop(_:)) {
            return true
        }

        NSLog("🔴 validateAction - not handled: [%@]", String(describing: action))

        return false
    }
}
