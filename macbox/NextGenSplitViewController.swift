//
//  NextGenSplitViewController.swift
//  Strongbox
//
//  Created by Strongbox on 26/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class NextGenSplitViewController: NSSplitViewController, NSToolbarDelegate {
    private static let searchFieldToolbarIdentifier = NSToolbarItem.Identifier("SearchField")
    private static let toggleLeadingSideBar = NSToolbarItem.Identifier("toggleLeftSidebar")
    private static let masterViewToolbarTrackingIdentifier = NSToolbarItem.Identifier("masterViewToolbarTrackingIdentifier")
    private static let detailViewToolbarTrackingIdentifier = NSToolbarItem.Identifier("detailViewToolbarTrackingIdentifier")

    private static let toolbarItemIdentifiers : [NSToolbarItem.Identifier] = [toggleLeadingSideBar, searchFieldToolbarIdentifier, detailViewToolbarTrackingIdentifier]
    
    @available(macOS 11.0, *)
    private static let macOS11ToolbarItemIdentifiers : [NSToolbarItem.Identifier] = [toggleLeadingSideBar, masterViewToolbarTrackingIdentifier, searchFieldToolbarIdentifier, detailViewToolbarTrackingIdentifier]

    func getToolbarItems () -> [NSToolbarItem.Identifier] {
        if #available(macOS 11.0, *) {
            return NextGenSplitViewController.macOS11ToolbarItemIdentifiers
        } else {
            return NextGenSplitViewController.toolbarItemIdentifiers;
        };
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return getToolbarItems()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return getToolbarItems()
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if (itemIdentifier == NextGenSplitViewController.searchFieldToolbarIdentifier ) {
            if #available(macOS 11.0, *) {
                return NSSearchToolbarItem(itemIdentifier: NextGenSplitViewController.searchFieldToolbarIdentifier)
            }
            else { 
                let toolbarItem = NSToolbarItem(itemIdentifier: NextGenSplitViewController.searchFieldToolbarIdentifier)
                toolbarItem.label = String("File")
                toolbarItem.paletteLabel = String("Open File")
                toolbarItem.toolTip = String("Open file to be handled")
                toolbarItem.isEnabled = true
                toolbarItem.target = self
                toolbarItem.action = #selector(self.toggleLeadingSidebar)
                toolbarItem.image = NSImage.init(named:NSImage.folderName)
                return toolbarItem
            }
        }
        else if (itemIdentifier == NextGenSplitViewController.toggleLeadingSideBar ) {
            let toolbarItem = NSToolbarItem(itemIdentifier: NextGenSplitViewController.toggleLeadingSideBar)
            




            toolbarItem.isEnabled = true
            toolbarItem.target = self
            toolbarItem.action = #selector(self.toggleLeadingSidebar)
            
            if #available(macOS 11.0, *) {
                toolbarItem.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: nil)
            }
            else {
                
            }

            return toolbarItem
        }
        else if (itemIdentifier == NextGenSplitViewController.masterViewToolbarTrackingIdentifier ) {
            if #available(macOS 11.0, *) {
                return NSTrackingSeparatorToolbarItem( identifier: itemIdentifier, splitView: self.splitView, dividerIndex: 0)
            } else {
                
                
            }
        }
        else if (itemIdentifier == NextGenSplitViewController.detailViewToolbarTrackingIdentifier ) {
            if #available(macOS 11.0, *) {
                return NSTrackingSeparatorToolbarItem( identifier: itemIdentifier, splitView: self.splitView, dividerIndex: 1)
            } else {
                
                
            }
        }

        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }

    @objc func toggleLeadingSidebar() {
        Logging.log("Yo!")
        toggleSidebar(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logging.log("viewDidLoad")
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        Logging.log("viewWillAppear")
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        Logging.log("viewDidAppear")
    }
    
    @objc func onDocumentLoaded() {
        Logging.log("NextGenSplitViewController::onDocumentLoaded")
        
        for child in children {
            if let vc = child as? DocumentViewController {
                vc.onDocumentLoaded()
            }
        }
        
        if #available(macOS 11.0, *) {
            view.window!.subtitle = "Subtitle FOO!"
        }












  
        view.window?.toolbar?.delegate = self

        setCurrentToolBarItems(desiredItems: getToolbarItems())
        
        loadDocument()
    }

    func setCurrentToolBarItems(desiredItems:[NSToolbarItem.Identifier]){
        
        for _ in (view.window?.toolbar?.items)!{
            view.window?.toolbar?.removeItem(at: 0)
        }
        
        for item in desiredItems.reversed() {
            view.window?.toolbar?.insertItem(withItemIdentifier: item, at: 0)
        }
    }
    
    
    private var loadedDocument : Bool = false
    private var document : Document? = nil
    private var model : ViewModel? {
        return document?.viewModel
    }
    
    func loadDocument() {
        if ( loadedDocument ) {
            return
        }
        
        guard let doc = self.view.window?.windowController?.document as? Document else {
            Logging.warn("SideBarViewController::load Document not set!")
            return
        }
        document = doc
        loadedDocument = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onSelectionChanged), name: NSNotification.Name(kModelUpdateNotificationSelectedItemChanged), object: nil)
        
        bindUI()
    }

    @objc func onSelectionChanged(_ notification: Notification) {
        let vm = notification.object as! ViewModel
        
        if ( vm == model ) {
            Logging.log("onSelectionChanged \(vm) == \(model!) - Selected Item = \(String(describing: model?.selectedItem))")

            bindUI()
        }
    }
    
    func bindUI () {
        let panel = self.splitViewItems.last;

        let uuid = model?.selectedItem;
        
        if ( uuid == nil ) {
            panel?.animator().isCollapsed = true
        }
        else {
            let item = model?.database.getItemBy(uuid!)
    
            panel?.animator().isCollapsed = item == nil ? true : item!.isGroup
        }
    }
}

