//
//  NextGenSplitViewController.swift
//  Strongbox
//
//  Created by Strongbox on 26/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class NextGenSplitViewController: NSSplitViewController, NSSearchFieldDelegate {
    deinit {
        NSLog("😎 DEINIT [NextGenSplitViewController]")
    }

    private var loadedDocument: Bool = false
    private var database: ViewModel!
    var searchField: NSSearchField?

    var windowController: WindowController {
        return view.window!.windowController as! WindowController
    }

    var masterListView: BrowseViewController {
        return children[1] as! BrowseViewController
    }

    var navigationContext: NavigationContext {
        return getNavContextFromModel(database)
    }

    @objc func onDocumentLoaded() {
        loadDocument()
    }

    func loadDocument() {
        NSLog("🚀 NextGenSplitViewController::loadDocument")

        if loadedDocument {
            return
        }

        guard let doc = view.window?.windowController?.document as? Document else {
            NSLog("🔴 NextGenSplitViewController::load Document not set!")
            return
        }

        database = doc.viewModel
        loadedDocument = true

        splitView.autosaveName = String(format: "autosave-splitview-for-%@", database.databaseMetadata.uuid)

        setupToolbar()

        

        
        if case NavigationContext.none = navigationContext {
            setModelNavigationContextWithViewNode(database, .regularHierarchy(database.rootGroup.uuid))
        }

        loadChildSplitViews()

        if database.nextGenSearchText.count > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                self.onFind(nil)
                self.searchField?.stringValue = self.database.nextGenSearchText
            }
        }
    }

    fileprivate func loadChildSplitViews() {
        for child in children {
            if let vc = child as? DocumentViewController {
                vc.onDocumentLoaded()
            }
        }
    }

    @objc func onCreateGroup(_: Any?) {
        if database.locked || database.isEffectivelyReadOnly {
            NSLog("🔴 Cannot edit locked or read-only database")
            return
        }

        let loc = NSLocalizedString("browse_vc_enter_group_name_message", comment: "Please Enter the New Group Name:")
        if let name = MacAlerts().input(loc, defaultValue: NSLocalizedString("browse_vc_group_name", comment: "Group Name"), allowEmpty: false) {
            let parentGroup: UUID
            switch navigationContext {
            case let .regularHierarchy(group):
                parentGroup = group
            default:
                parentGroup = database.rootGroup.uuid
            }

            guard let node = database.getItemBy(parentGroup) else {
                NSLog("🔴 Selected Group not set for Editing!")
                return
            }

            if name.count != 0 {
                var newGroup: Node?
                if !database.addNewGroup(node, title: name, group: &newGroup) {
                    MacAlerts.info(NSLocalizedString("browse_vc_cannot_create_group", comment: "Cannot create group"),
                                   informativeText: NSLocalizedString("browse_vc_cannot_create_group_message", comment: "Could not create a group with this name here, possibly because one with this name already exists."),
                                   window: view.window,
                                   completion: nil)
                } else {
                    if let newGroup = newGroup {
                        setModelNavigationContextWithViewNode(database, .regularHierarchy(newGroup.uuid))
                    }
                }
            }
        }
    }

    @objc func onCreateRecord(_: Any?) {
        createOrEdit()
    }

    @objc func onEditEntry(_: Any?) {
        createOrEdit(false)
    }

    func createOrEdit(_ createNew: Bool = true) {
        if database.locked || database.isEffectivelyReadOnly {
            NSLog("🔴 Cannot edit locked or read-only database")
            return
        }

        let vc = CreateEditViewController.instantiateFromStoryboard()

        if createNew {
            if case let .regularHierarchy(selectedGroup) = navigationContext {
                vc.initialParentNodeId = selectedGroup
            } else {
                vc.initialParentNodeId = database.rootGroup.uuid
            }
        } else {
            guard let selectedItem = database.nextGenSelectedItems.first, database.nextGenSelectedItems.count == 1 else {
                NSLog("🔴 Selected Item not set for Editing!")
                return
            }

            vc.initialNodeId = selectedItem
        }

        vc.database = database

        presentAsSheet(vc)
    }

    @objc func onShowHideQuickView(_: Any?) {
        toggleDetailsView()
    }

    @objc func toggleDetailsView() {
        guard let panel = splitViewItems.last else {
            NSLog("🔴 Couldn't find last panel!")
            return
        }

        panel.animator().isCollapsed = !panel.isCollapsed
    }

    @objc func toggleLeadingSidebar() {
        toggleSidebar(nil)
    }

    @IBAction func onFind(_: Any?) {


        guard let searchFieldItem = view.window?.toolbar?.visibleItems?.first(where: { item in
            item.itemIdentifier == ToolbarItemIdentifiers.searchField
        }) else {
            NSLog("🔴 Couldn't find Search Toolbar Item")
            return
        }

        if #available(macOS 11.0, *) {
            let searchToolbar: NSSearchToolbarItem = searchFieldItem as! NSSearchToolbarItem


            searchToolbar.beginSearchInteraction()
            searchToolbar.searchField.selectText(nil)
        } else {
            
            
        }
    }

    @objc
    func onSearchAction(param: Any?) {


        guard let searchField = param as? NSSearchField else {
            NSLog("🔴 searchField not good")
            return
        }

        if database.nextGenSearchText != searchField.stringValue {

            database.nextGenSearchText = searchField.stringValue
        }
    }

    func control(_ control: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {


        guard let event = control.window?.currentEvent else {
            NSLog("🔴 Could not get current event")
            return false
        }

        if control == searchField {
            if commandSelector == NSSelectorFromString("noop:") { 
                if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                    let aChar = event.charactersIgnoringModifiers?.first

                    

                    if aChar == "c" {

                        if selectFirstItemInMasterAndMakeFirstResponderForSearchResult() {
                            windowController.onCopyPassword(nil)
                            return true
                        }
                    } else {}
                }
            }

            if commandSelector == #selector(moveDown) || commandSelector == #selector(insertNewline) {
                
                return selectFirstItemInMasterAndMakeFirstResponderForSearchResult()
            }
        }

        return false
    }

    func selectFirstItemInMasterAndMakeFirstResponderForSearchResult() -> Bool {
        NSLog("✅ selectFirstItemInMasterAndMakeFirstResponderForSearchResult")

        let selected = masterListView.selectFirstItemIfAvailableForSearchResult()

        if selected {
            guard let window = view.window else {
                return false
            }

            window.makeFirstResponder(masterListView.outlineView) 
        }

        return selected
    }
}

extension NextGenSplitViewController: NSToolbarDelegate {
    enum ToolbarItemIdentifiers {
        static let searchField = NSToolbarItem.Identifier("SearchField")
        static let toggleSideBar = NSToolbarItem.Identifier("toggleLeftSidebar")
        static let addEntry = NSToolbarItem.Identifier("addEntryToolbarItem")
        static let createGroup = NSToolbarItem.Identifier("createGroupToolbarItem")
        static let editEntry = NSToolbarItem.Identifier("editEntryToolbarItem")
        static let toggleDetails = NSToolbarItem.Identifier("toggleDetailsView")
        static let masterTracking = NSToolbarItem.Identifier("masterViewToolbarTrackingIdentifier")
        static let detailTracking = NSToolbarItem.Identifier("detailViewToolbarTrackingIdentifier")
    }

    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "nextgen-toolbar-identifier-version-2")

        toolbar.autosavesConfiguration = true
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true

        guard let window = view.window else {
            NSLog("🔴 Window not ready")
            return
        }

        window.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.toggleSideBar,
                    ToolbarItemIdentifiers.masterTracking,
                    ToolbarItemIdentifiers.createGroup,
                    ToolbarItemIdentifiers.addEntry,
                    ToolbarItemIdentifiers.searchField,
                    ToolbarItemIdentifiers.detailTracking,
                    ToolbarItemIdentifiers.editEntry,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.toggleDetails]
        } else {
            return [] 
        }
    }

    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.toggleSideBar,
                    ToolbarItemIdentifiers.masterTracking,

                    ToolbarItemIdentifiers.createGroup,
                    ToolbarItemIdentifiers.addEntry,
                    ToolbarItemIdentifiers.searchField,

                    ToolbarItemIdentifiers.detailTracking,
                    ToolbarItemIdentifiers.editEntry,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.toggleDetails]
        } else {
            return [] 
        }
    }

    func getSearchToolbarItem() -> NSToolbarItem {
        if #available(macOS 11.0, *) {
            let search = NSSearchToolbarItem(itemIdentifier: ToolbarItemIdentifiers.searchField)

            search.searchField.action = #selector(onSearchAction)
            search.searchField.delegate = self
            search.resignsFirstResponderWithCancel = false

            searchField = search.searchField

            return search
        } else {
            
            let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.searchField)
            toolbarItem.label = String("File")
            toolbarItem.paletteLabel = String("Open File")
            toolbarItem.toolTip = String("Open file to be handled")
            toolbarItem.isEnabled = true
            toolbarItem.target = self
            toolbarItem.action = #selector(toggleLeadingSidebar)
            toolbarItem.image = NSImage(named: NSImage.folderName)
            return toolbarItem
        }
    }

    func getCreateGroupToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.createGroup)

        let loc = NSLocalizedString("create_group", comment: "Create Group")
        toolbarItem.label = loc
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onCreateGroup)

        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }

        return toolbarItem
    }

    func getEditEntryToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.editEntry)

        toolbarItem.label = NSLocalizedString("browse_vc_action_edit", comment: "Edit")

        let loc2 = NSLocalizedString("edit_entry", comment: "Edit Entry")
        toolbarItem.paletteLabel = loc2
        toolbarItem.toolTip = loc2
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onEditEntry)

        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }

        return toolbarItem
    }

    func getCreateEntryToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.addEntry)

        let loc = NSLocalizedString("create_entry", comment: "Create Entry")

        toolbarItem.label = loc
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onCreateRecord(_:))

        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }

        return toolbarItem
    }

    func getToggleDetailsToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.toggleDetails)

        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(toggleDetailsView)

        let loc = NSLocalizedString("nextgen_toolbar_item_toggle_details_panel", comment: "Toggle Details Panel")

        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc

        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "sidebar.trailing", accessibilityDescription: nil)
        } else {
            
        }

        return toolbarItem
    }

    func getToggleSidebarToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.toggleSideBar)

        let loc = NSLocalizedString("nextgen_toolbar_item_toggle_sidebar", comment: "Toggle Sidebar")

        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc

        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(toggleLeadingSidebar)

        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: nil)
        } else {
            
        }

        return toolbarItem
    }

    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        if itemIdentifier == ToolbarItemIdentifiers.searchField {
            return getSearchToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.createGroup {
            return getCreateGroupToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.editEntry {
            return getEditEntryToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.addEntry {
            return getCreateEntryToolbarItem()
        } else if itemIdentifier == NSToolbarItem.Identifier.flexibleSpace {
            return NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.flexibleSpace)
        } else if itemIdentifier == ToolbarItemIdentifiers.toggleDetails {
            return getToggleDetailsToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.toggleSideBar {
            return getToggleSidebarToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.masterTracking {
            if #available(macOS 11.0, *) {
                return NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: self.splitView, dividerIndex: 0)
            } else {
                
                
            }
        } else if itemIdentifier == ToolbarItemIdentifiers.detailTracking {
            if #available(macOS 11.0, *) {
                return NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: self.splitView, dividerIndex: 1)
            } else {
                
                
            }
        }

        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}

extension NextGenSplitViewController: NSMenuItemValidation, NSToolbarItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return false }

        if action == #selector(onShowHideQuickView(_:)) {
            guard let panel = splitViewItems.last else {
                NSLog("🔴 Couldn't find last panel!")
                return false
            }

            menuItem.title = panel.isCollapsed ? NSLocalizedString("main_menu_show_details_panel", comment: "Show Details Panel") : NSLocalizedString("main_menu_hide_details_panel", comment: "Hide Details Panel")
        }

        return validateAction(action)
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let action = item.action else { return false }

        return validateAction(action)
    }

    func validateAction(_ action: Selector) -> Bool {
        if action == #selector(toggleLeadingSidebar) {
            return true
        } else if action == #selector(toggleDetailsView) {
            return true
        } else if action == #selector(onCreateGroup) {
            return !database.locked && !database.isEffectivelyReadOnly
        }
        if action == #selector(onCreateRecord) {
            
            
            
            
            
            

            return !database.locked && !database.isEffectivelyReadOnly
        } else if action == #selector(onEditEntry) {
            
            return !database.locked && database.nextGenSelectedItems.count == 1 && !database.isEffectivelyReadOnly
        } else if action == #selector(onFind) {
            return !database.locked
        } else if action == #selector(onShowHideQuickView(_:)) {
            return !database.locked
        }

        NSLog("🔴 validateAction - not handled: [%@]", String(describing: action))

        return false
    }
}
