//
//  SideBarViewController3.swift
//  MacBox
//
//  Created by Strongbox on 25/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

// TODO: Edit Group names
// TODO: Move Folders around / Drag Drop

class SideBarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, DocumentViewController {
    @IBOutlet weak var outlineView: NSOutlineView!

    private class ViewNode {
        let context: NavigationContext?
        let title: String
        let image : NSImage
        let children: [ViewNode]
        let isHeaderNode: Bool
        let color: NSColor?
        
        init(context : NavigationContext?,
             title: String,
             image: NSImage,
             children: [ViewNode] = [],
             isHeaderNode: Bool = false,
             color: NSColor? = nil ) {
            self.context = context
            self.title = title
            self.image = image
            self.children = children
            self.isHeaderNode = isHeaderNode
            self.color = color
        }
        
        var cellIdentifier: NSUserInterfaceItemIdentifier { 
            NSUserInterfaceItemIdentifier(rawValue: isHeaderNode ? "HeaderCell" : "DataCell")
        }
    }
        
    private var document : Document?
    private var loadedDocument : Bool = false
    private var model : ViewModel {
        return document!.viewModel
    }
    
    private var dataSource : [ViewNode] = []





















    

         
         









    
    override func viewDidLoad() {
        super.viewDidLoad()

        outlineView.delegate = self;
        outlineView.dataSource = self;
    }
    
    func onDocumentLoaded() {
        Logging.log("SideBarViewController::onDocumentLoaded")

        loadDocument()
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

        var newData : [ViewNode] = []

        

        

        let hierarchy = getHierarchicalViewNodesFor(model.rootGroup)
        let hierarchyNode = ViewNode(context: .regularHierarchy(nil), title: "Hierarchy", image: Icon.house.image(), children: [hierarchy], isHeaderNode: true) 
        newData += [hierarchyNode];
        
        

        let tagNodes = model.tagSet.map { tag in
            return ViewNode(context: .tags(tag), title: tag, image: Icon.tag.image())
        }
        
        var tagsNode: ViewNode? = nil
        
        if ( !tagNodes.isEmpty ) {
            tagsNode = ViewNode(context: nil, title: NSLocalizedString("item_details_username_field_tags", comment: "Tags"), image: Icon.tag.image(), children: tagNodes, isHeaderNode: true)
            newData += [ tagsNode! ]
        }

        
        
        
                        
        Logging.log("SideBarViewController::load done, expanding all items")
        
        dataSource = newData
        
        outlineView.reloadData()
        
        

        outlineView.expandItem(hierarchyNode)
        if ( tagsNode != nil ) {
            outlineView.expandItem(tagsNode)
        }
    }
        
    private func getHierarchicalViewNodesFor(_ group : Node ) -> ViewNode {
        
        
        let sorted = group.childGroups.sorted(by: Node.sortTitleLikeFinder )
        
        let children : [ViewNode] = sorted.map { child in
            return getHierarchicalViewNodesFor(child)
        }
        
        
        
        let image : NSImage
        if ( model.rootGroup.uuid == group.uuid && group.isUsingKeePassDefaultIcon ) {
            image = Icon.house.image()
        }
        else {
            image = NodeIconHelper.getIconFor( group, predefinedIconSet: KeePassIconSet.sfSymbols, format: model.format )
        }
        
        return ViewNode(context: .regularHierarchy(group.uuid), title: group.title, image: image, children: children) 
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? dataSource.count : (item as! ViewNode).children.count
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? dataSource[index] : (item as! ViewNode).children[index]
    }
    
    var italicFont : NSFont?
    var regularFont : NSFont?
    
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? ViewNode,
              let cell = outlineView.makeView(withIdentifier: node.cellIdentifier, owner: self) as? NSTableCellView else {
            return nil
        }
                
        if !node.isHeaderNode {
            cell.imageView?.image = node.image
        }
        
        
        
        if( italicFont == nil ) {
            regularFont = cell.textField?.font!;
            italicFont = NSFontManager.shared.convert(cell.textField!.font!, toHaveTrait: .italicFontMask)
        }
        
        
        if ( model.recycleBinEnabled && model.recycleBinNode != nil && node.context == .regularHierarchy(model.recycleBinNode!.uuid) ) {
            cell.textField!.font = italicFont;
        }
        else {
            cell.textField!.font = regularFont;
        }
        
        cell.textField?.stringValue = node.title 

        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as! ViewNode).isHeaderNode
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        let node = item as! ViewNode
        return node.context != .regularHierarchy(nil)
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        let node = item as! ViewNode
        return !node.children.isEmpty 
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item as! ViewNode).isHeaderNode
    }
    
    @available(macOS 11.0, *)
    func outlineView(_ outlineView: NSOutlineView, tintConfigurationForItem item: Any) -> NSTintConfiguration? {
        return ((item as! ViewNode).color != nil) ? NSTintConfiguration.init(fixedColor: (item as! ViewNode).color!) : NSTintConfiguration.default
    }
}
