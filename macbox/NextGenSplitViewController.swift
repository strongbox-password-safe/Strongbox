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
    var detailView: DetailViewController {
        return children[2] as! DetailViewController
    }
    
    var navigationContext: NavigationContext {
        return getNavContextFromModel(database)
    }
    
    @objc func onDocumentLoaded() {
        loadDocument()
    }
    
    func loadDocument() {
        NSLog("========================================================================")
        NSLog("🚀 NextGenSplitViewController::loadDocument")
        NSLog("========================================================================")
        
        if loadedDocument {
            return
        }
        
        guard let doc = view.window?.windowController?.document as? Document else {
            NSLog("🔴 NextGenSplitViewController::load Document not set!")
            return
        }
        
        let start = DispatchTime.now() 
        
        database = doc.viewModel
        loadedDocument = true
        
        splitView.autosaveName = String(format: "autosave-splitview-for-%@", database.databaseMetadata.uuid)
        
        setupToolbar()
        
        if database.nextGenSearchText.count > 0 {
            searchField?.stringValue = database.nextGenSearchText
        }
        
        
        
        NSLog("🚀 Initial Navigation Context = [%@], browse selected items = [%@]", String(describing: navigationContext), database.nextGenSelectedItems)
        
        if case NavigationContext.none = navigationContext {
            setModelNavigationContextWithViewNode(database, .special(.allEntries))
        }
        
        loadChildSplitViews()
        
        listenToModelUpdateNotifications()
        
        let end = DispatchTime.now() 
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds 
        let timeInterval = Double(nanoTime) / 1_000_000_000 
        
        NSLog("========================================================================")
        NSLog("⏱ ✅ Initial Document UI Load Time: %0.2f seconds", timeInterval)
        NSLog("========================================================================")
    }
    
    var firstAppearance = true
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if database != nil, database.nextGenSearchText.count > 0 || database.startWithSearch, firstAppearance {
            firstAppearance = false
            onFind(nil)
        }
        
        bindSyncButtonToSyncStatus()
    }
    
    func listenToModelUpdateNotifications() {
        let notificationsOfInterest: [String] = [kModelUpdateNotificationNextGenNavigationChanged]
        
        for ofInterest in notificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else {
                    return
                }
                
                self.onModelNotificationReceived(notification)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name (kAsyncUpdateStarting), object: nil, queue: nil) { [weak self] notification in
            self?.onAsyncUpdateStarting(notification: notification)
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name (kAsyncUpdateDone), object: nil, queue: nil) { [weak self] notification in
            self?.onAsyncUpdateDone(notification: notification)
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name (kSyncManagerDatabaseSyncStatusChanged), object: nil, queue: nil) { [weak self] notification in
            self?.onSyncStatusChanged(notification: notification)
        }
    }
    
    func onAsyncUpdateStarting ( notification : Notification ) {
        guard let databaseUuid = notification.object as? String,
              databaseUuid == database.databaseUuid else {
            return
        }
        
        updateSyncButton(color: NSColor.systemBlue, animate: true)
    }
    
    func onAsyncUpdateDone ( notification : Notification ) {
        guard let asyncResult = notification.object as? AsyncUpdateResult,
                asyncResult.databaseUuid == database.databaseUuid else {
            return
        }
        
        updateSyncButton()
        
        if asyncResult.success {
            if !database.isInOfflineMode {
                
                NSLog("✅ NextGenSplitViewController::onAsyncUpdateDone Received Indication of Successful Save/Update")
            }
            else {
                NSLog("✅ Async Update Done and in offline mode so displaying a toast to indicate success");
                
                showToastNotification(message: NSLocalizedString("generic_save_was_successful", comment: "Save Successful"))
            }
        }
        else {
            
        }
    }

    func onSyncStatusChanged ( notification : Notification ) {
        guard let databaseUuid = notification.object as? String,
              databaseUuid == database.databaseUuid else {
            return
        }
        
        let status = MacSyncManager.sharedInstance().getSyncStatus(database.databaseMetadata)
        

        
        if status.state == .error {
            showToastNotification(message: NSLocalizedString("open_sequence_storage_provider_error_title", comment: "Sync Error"), error: true)
            



















        }
        else if status.state == .backgroundButUserInteractionRequired {
        }
        else if status.state == .inProgress {
        }
        else {
            showToastNotification(message: NSLocalizedString("notification_sync_successful", comment: "Sync Successful"))
        }
        
        bindSyncButtonToSyncStatus()
    }

    func bindSyncButtonToSyncStatus () {
        let status = MacSyncManager.sharedInstance().getSyncStatus(database.databaseMetadata)
        
        
        
        if status.state == .error {
            updateSyncButton(color: NSColor.systemRed, animate: false)
        }
        else if status.state == .backgroundButUserInteractionRequired {
            updateSyncButton(color: NSColor.systemYellow, animate: false)
        }
        else if status.state == .inProgress {
            updateSyncButton(color: NSColor.systemBlue, animate: true)
        }
        else {
            updateSyncButton(color: nil, animate: false)
        }
    }
    
    func showToastNotification( message : String, error : Bool = false) {
        if view.window?.isMiniaturized ?? true {
            NSLog("Not Showing Popup Change notification because window is miniaturized");
            return;
        }
        
        showToastNotification(message: message, error: error,  yOffset: 150)
    }

    func showToastNotification( message : String, error : Bool = false, yOffset : Float = 0.0 ) {



                
        DispatchQueue.main.async { [weak self] in
            let defaultColor = NSColor(deviceRed: 0.23, green: 0.5, blue: 0.82, alpha: 0.6)
            let errorColor = NSColor(deviceRed: 1, green: 0.55, blue: 0.05, alpha: 0.9)
            
            guard let hud = MBProgressHUD.showAdded(to: self?.view, animated: true) else {

                NSLog("🔴 Couldn't create Toast!")
                return
            }
            
            hud.labelText = message;
            hud.color = ( error ? errorColor : defaultColor )
            hud.mode = MBProgressHUDModeText
            hud.margin = 10
            hud.yOffset = yOffset
            hud.removeFromSuperViewOnHide = true
            hud.dismissible = true
            
            let delay = error ? 3.0 : 0.5
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay ) {
                hud.hide(true)
            }
        }
    }
    
    func updateSyncButton ( color : NSColor? = nil, animate : Bool = false ) {
        guard let syncToolbarItem = view.window?.toolbar?.visibleItems?.first(where: { item in
            item.itemIdentifier == ToolbarItemIdentifiers.syncButton
        }), let button = syncToolbarItem.view as? NSButton else {
            NSLog("🔴 Couldn't find Sync Toolbar Item")
            return
        }
        
        button.contentTintColor = color
        
        runSpinAnimationOnView(view: button, spin: animate)
    }
    
    func runSpinAnimationOnView (view : NSView, spin : Bool ) {
        guard let layer = view.layer else {
            NSLog("COuldn't get layer!")
            return
        }
        
        layer.removeAllAnimations()

        if ( spin ) {
            layer.position = NSMakePoint(NSMidX(layer.frame), NSMidY(layer.frame)); 
            layer.anchorPoint = NSMakePoint(0.5, 0.5); 

            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
            
            rotationAnimation.duration = 1.25;
            rotationAnimation.isCumulative = true;
            rotationAnimation.toValue = NSNumber(floatLiteral: .pi * -2.0)
            rotationAnimation.repeatCount = Float.infinity
            rotationAnimation.isRemovedOnCompletion = false 
            
            layer.add(rotationAnimation, forKey: "rotationAnimation")
        }
    }

    func onModelNotificationReceived(_ notification: Notification) {
        guard let notifyModel = notification.object as? ViewModel else {
            return
        }
        
        if notifyModel != database {
            return
        }
        
        if notification.name == NSNotification.Name(kModelUpdateNotificationNextGenNavigationChanged) {
            NSLog("NextGenSplitView: Nav Changed")
            
            searchField?.stringValue = ""
        }
    }
    
    fileprivate func loadChildSplitViews() {
        for child in children {
            if let vc = child as? DocumentViewController {
                vc.onDocumentLoaded()
            }
        }
    }
    
    @objc func onLockDatabase(_: Any?) {
        NSApplication.shared.sendAction(#selector(WindowController.onLock(_:)), to: nil, from: self)
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
    
    @objc func onSync(_: Any?) {






            guard let doc = view.window?.windowController?.document as? Document else {
                NSLog("🔴 NextGenSplitViewController::load Document not set!")
                return
            }
            
            if doc.hasUnautosavedChanges || doc.isDocumentEdited {
                NSLog("NextGenSplitViewController::onSync: Sync called but there are unsaved changes. Saving then syncing...")
                NSApplication.shared.sendAction(#selector(NSDocument.save(_:)), to: nil, from: self)
            }
            else {
                NSLog("NextGenSplitViewController::onSync: Sync called and NO unsaved changes. Syncing...")
                DatabasesCollection.shared.sync(uuid: database.databaseUuid, allowInteractive: true)
            }

    }
    
    func createOrEdit(_ createNew: Bool = true) {
        if database.locked || database.isEffectivelyReadOnly {
            NSLog("🔴 Cannot edit locked or read-only database")
            return
        }
        
        let vc = CreateEditViewController.instantiateFromStoryboard()
        
        if createNew {
            if case let .regularHierarchy(selectedGroup) = navigationContext, !database.is(inRecycled: selectedGroup) {
                vc.initialParentNodeId = selectedGroup
            } else {
                vc.initialParentNodeId = database.rootGroup.uuid
            }
            
            guard vc.initialParentNodeId != nil else {
                NSLog("🔴 Could not get initial parent node id!")
                return
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
    
    @objc func showDatabasePreferences() {
        NSApplication.shared.sendAction(#selector(WindowController.onGeneralDatabaseSettings(_:)), to: nil, from: self)
    }
    
    @objc func showAppPreferences() {
        AppPreferencesWindowController.sharedInstance.show(tab: .general)
    }
    
    @objc func showAutoFillPreferences() {
        NSApplication.shared.sendAction(#selector(WindowController.onDatabaseAutoFillSettings(_:)), to: nil, from: self)
    }
    
    @objc func showEncryptionPreferences() {
        NSApplication.shared.sendAction(#selector(WindowController.onDatabaseEncryptionSettings(_:)), to: nil, from: self)
    }
    
    @objc func showTouchIdPreferences() {
        NSApplication.shared.sendAction(#selector(WindowController.onConvenienceUnlockProperties(_:)), to: nil, from: self)
    }
    
    @objc func showChangeMasterCredentials() {
        NSApplication.shared.sendAction(#selector(WindowController.onChangeMasterPassword(_:)), to: nil, from: self)
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
    





















    
    
    
    var popouts : [UUID : PopOutDetailsWindowController] = [:] 
    
    @objc func onPopOutDetailsAndPin(_: Any?) {
        popOutDetails(pin: true)
    }
    
    @objc func onPopOutDetails(_: Any?) {
        popOutDetails()
    }
    
    func popOutDetails(pin : Bool = false) {
        guard database.nextGenSelectedItems.count == 1, let uuid = database.nextGenSelectedItems.first else {
            NSLog("✅ onPopOutDetails - Selection invalid")
            return
        }
        
        if let existing = popouts[uuid] {
            existing.showWindow(nil)
        }
        else {
            let popout = PopOutDetailsWindowController.fromStoryboard()
            
            popout.load(model: database, uuid: uuid)
            
            popouts[uuid] = popout
            
            popout.showWindow(nil)
        }
    }
    
    func closeAllPresentedRecursive( viewController: NSViewController ) {
        if let presentedViewControllers = viewController.presentedViewControllers {
            for presented in presentedViewControllers {
                closeAllPresentedRecursive(viewController: presented)
                dismiss(presented)
            }
        }
    }
    
    @objc func onLockDoneKillAllWindows() {
        closeAllPresentedRecursive(viewController: self)
        
        for popout in popouts.values {
            popout.close()
        }
        
        popouts.removeAll()
    }
    
    @objc var editsInProgress : Bool {
        if let presentedViewControllers = presentedViewControllers {
            for presentedViewController in presentedViewControllers {
                if let editVc = presentedViewController as? CreateEditViewController {
                    if editVc.isEditsInProgress {
                        return true
                    }
                }
            }
        }
        
        for popout in popouts.values {
            if popout.isEditsInProgress {
                return true
            }
        }
        
        return false
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
        static let databasePreferences = NSToolbarItem.Identifier("databasePreferencesToolbarItem")
        static let lockDatabase = NSToolbarItem.Identifier("lockDatabaseToolbarItem")
        static let popoutDetails = NSToolbarItem.Identifier("popoutDetailsToolbarItem")
        static let syncButton = NSToolbarItem.Identifier("syncToolbarItem")
    }
    
    func setupToolbar() {
        let toolbar = NSToolbar(identifier: "nextgen-toolbar-identifier-version-9.0")
        
        toolbar.autosavesConfiguration = true
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true 
        toolbar.displayMode = .iconOnly
        
        guard let window = view.window else {
            NSLog("🔴 Window not ready")
            return
        }
        
        window.toolbar = toolbar
        window.titlebarAppearsTransparent = false
    }
    
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.toggleSideBar,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.databasePreferences,
                    ToolbarItemIdentifiers.masterTracking,
                    ToolbarItemIdentifiers.syncButton,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.createGroup,
                    ToolbarItemIdentifiers.addEntry,
                    ToolbarItemIdentifiers.searchField,
                    
                    ToolbarItemIdentifiers.lockDatabase,
                    ToolbarItemIdentifiers.detailTracking,
                    ToolbarItemIdentifiers.editEntry,
                    ToolbarItemIdentifiers.popoutDetails,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.toggleDetails]
        } else {
            return [] 
        }
    }
    
    func toolbarAllowedItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return [ToolbarItemIdentifiers.toggleSideBar,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.databasePreferences,
                    ToolbarItemIdentifiers.masterTracking,
                    ToolbarItemIdentifiers.syncButton,
                    NSToolbarItem.Identifier.flexibleSpace,
                    ToolbarItemIdentifiers.createGroup,
                    ToolbarItemIdentifiers.addEntry,
                    ToolbarItemIdentifiers.searchField,
                    
                    ToolbarItemIdentifiers.lockDatabase,
                    ToolbarItemIdentifiers.detailTracking,
                    ToolbarItemIdentifiers.editEntry,
                    ToolbarItemIdentifiers.popoutDetails,
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
            
            return NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.searchField)
        }
    }
    
    func getPopOutDetailsToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.popoutDetails)
        
        let loc = NSLocalizedString("action_verb_popout_details_window", comment: "Pop Out Details")
        
        toolbarItem.label = loc
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onPopOutDetails)
        
        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "arrow.up.forward.square", accessibilityDescription: nil)
        } else {
            toolbarItem.image = NSImage(named: NSImage.folderName) 
        }
        
        return toolbarItem
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
    
    func getLockDatabaseToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.lockDatabase)
        
        let loc = NSLocalizedString("verb_lock_database", comment: "Lock Database")
        toolbarItem.label = loc
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true
        toolbarItem.target = self
        toolbarItem.action = #selector(onLockDatabase)
        
        if #available(macOS 11.0, *) {
            toolbarItem.image = NSImage(systemSymbolName: "lock", accessibilityDescription: nil)
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
    
    func getSyncToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.syncButton)

        let image : NSImage
        if #available(macOS 11.0, *) {
            image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)!
        } else {
            image = NSImage(named: NSImage.folderName)! 
        }

        let button = NSButton(image: image, target: self, action: #selector(onSync))
        button.isBordered = false
        toolbarItem.view = button
        
        let loc = NSLocalizedString("generic_action_sync", comment: "Sync")

        toolbarItem.label = loc
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true

        toolbarItem.action = #selector(onSync)
        
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
    
    func getDatabasePreferencesToolbarItem() -> NSToolbarItem {
        let toolbarItem = NSToolbarItem(itemIdentifier: ToolbarItemIdentifiers.databasePreferences)
        
        let menu = NSMenu(title: "")
        
        let loc1 = NSLocalizedString("nextgen_toolbar_settings_convenience_unlock_ellipsis", comment: "Touch ID & Watch Unlock Settings...");
        menu.addItem(withTitle: loc1, action: #selector(showTouchIdPreferences), keyEquivalent: "")
        
        let loc2 = NSLocalizedString("nextgen_toolbar_settings_autofill_settings_ellipsis", comment: "AutoFill Settings...");
        menu.addItem(withTitle: loc2, action: #selector(showAutoFillPreferences), keyEquivalent: "")
        
        let loc3 = NSLocalizedString("nextgen_toolbar_settings_encryption_settings_ellipsis", comment: "Encryption Settings...");
        menu.addItem(withTitle: loc3, action: #selector(showEncryptionPreferences), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        
        let loc4 = NSLocalizedString("nextgen_toolbar_settings_change_master_credentials_ellipsis", comment: "Change Master Credentials...");
        menu.addItem(withTitle: loc4, action: #selector(showChangeMasterCredentials), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        
        let loc5 = NSLocalizedString("nextgen_toolbar_settings_database_settings_ellipsis", comment: "Database Settings...");
        menu.addItem(withTitle: loc5, action: #selector(showDatabasePreferences), keyEquivalent: "")
        
        menu.addItem(NSMenuItem.separator())
        
        let loc6 = NSLocalizedString("nextgen_toolbar_settings_application_preferences_ellipsis", comment: "Application Preferences...");
        menu.addItem(withTitle: loc6, action: #selector(showAppPreferences), keyEquivalent: "")
        
        let segmentedControl = NSSegmentedControl(images: [Icon.preferences.image()], trackingMode: .momentary, target: self, action: nil);
        segmentedControl.setShowsMenuIndicator(true, forSegment: 0)
        segmentedControl.setMenu(menu, forSegment: 0)
        
        toolbarItem.view = segmentedControl
        
        let loc = NSLocalizedString("generic_settings", comment: "Settings")
        
        toolbarItem.paletteLabel = loc
        toolbarItem.toolTip = loc
        toolbarItem.isEnabled = true
        
        return toolbarItem
    }
    
    func toolbar(_: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool) -> NSToolbarItem? {
        if itemIdentifier == ToolbarItemIdentifiers.searchField {
            return getSearchToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.createGroup {
            return getCreateGroupToolbarItem()
        }
        else if itemIdentifier == ToolbarItemIdentifiers.lockDatabase {
            return getLockDatabaseToolbarItem()
        }
        else if itemIdentifier == ToolbarItemIdentifiers.editEntry {
            return getEditEntryToolbarItem()
        }
        else if itemIdentifier == ToolbarItemIdentifiers.syncButton {
            return getSyncToolbarItem()
        }
        else if itemIdentifier == ToolbarItemIdentifiers.addEntry {
            return getCreateEntryToolbarItem()
        } else if itemIdentifier == NSToolbarItem.Identifier.flexibleSpace {
            return NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.flexibleSpace)
        } else if itemIdentifier == ToolbarItemIdentifiers.toggleDetails {
            return getToggleDetailsToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.popoutDetails {
            return getPopOutDetailsToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.toggleSideBar {
            return getToggleSidebarToolbarItem()
        } else if itemIdentifier == ToolbarItemIdentifiers.databasePreferences {
            return getDatabasePreferencesToolbarItem()
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
        }
        
        else if action == #selector(showDatabasePreferences) {
            return !database.locked
        }
        else if action == #selector(showAppPreferences) {
            return true
        }
        else if action == #selector(showAutoFillPreferences) {
            return !database.locked
        }
        else if action == #selector(showEncryptionPreferences) {
            return !database.locked
        }
        else if action == #selector(showTouchIdPreferences) {
            return !database.locked
        }
        else if action == #selector(showChangeMasterCredentials) {
            return !database.locked && !database.isEffectivelyReadOnly
        }
        else if action == #selector(onCreateGroup) {
            return !database.locked && !database.isEffectivelyReadOnly
        }
        else if action == #selector(onPopOutDetails(_:)) {
            return !database.locked
        }
        else if action == #selector(onLockDatabase) {
            return !database.locked && !database.isEffectivelyReadOnly
        }
        else if action == #selector(onCreateRecord) {
            if database.format == .keePass1 { 
                if case let .regularHierarchy(selectedGroup) = navigationContext {
                    if selectedGroup == database.rootGroup.uuid {
                        return false
                    }
                }
            }
            
            return !database.locked && !database.isEffectivelyReadOnly
        } else if action == #selector(onEditEntry) {
            return !database.locked && database.nextGenSelectedItems.count == 1 && !database.isEffectivelyReadOnly
        } else if action == #selector(onSync) {
            return !database.locked && !database.isEffectivelyReadOnly && !database.isInOfflineMode
        }
        else if action == #selector(onFind) {
            return !database.locked
        } else if action == #selector(onShowHideQuickView(_:)) {
            return !database.locked
        }
        
        NSLog("🔴 validateAction - not handled: [%@]", String(describing: action))
        
        return false
    }
}
