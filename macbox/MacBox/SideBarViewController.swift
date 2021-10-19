//
//  SideBarViewController3.swift
//  MacBox
//
//  Created by Strongbox on 25/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class SideBarViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, DocumentViewController {
    private class ViewNode {
        let id: Int
        let title: String
        let symbolName: String?
        let children: [ViewNode]
        let isGroup: Bool
        let color: NSColor?
        
        init(id: Int, title: String, symbolName: String? = nil, children: [ViewNode] = [], isGroup: Bool = false, color: NSColor? = nil ) {
            self.id = id
            self.title = title
            self.symbolName = symbolName
            self.children = children
            self.isGroup = isGroup
            self.color = color
        }
        
        convenience init(groupId: Int, title: String, children: [ViewNode]) {
            self.init(id: groupId, title: title, children: children, isGroup: true)
        }

        var cellIdentifier: NSUserInterfaceItemIdentifier {
            NSUserInterfaceItemIdentifier(rawValue: isGroup ? "HeaderCell" : "DataCell")
        }
    }
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    private var document : Document?
    private var loadedDocument : Bool = false
    private var model : ViewModel {
        return document!.viewModel
    }
    
    private var dataSource : [ViewNode] = []
    
    private let staticData : [ViewNode] = [ 
        ViewNode(groupId: 1, title: "Home", children: [
            ViewNode(id: 11, title: "Mark's Database", symbolName: "house" ),
            ViewNode(id: 12, title: "Nearly Expired", symbolName: "clock.arrow.circlepath" ),
            ViewNode(id: 13, title: "Expired", symbolName: "timer" ),
            ViewNode(id: 14, title: "Audit Issues", symbolName: "exclamationmark.triangle", color: NSColor.systemOrange ),
            ViewNode(id: 15, title: "Recycle Bin", symbolName: "trash"),
            ViewNode(id: 16, title: "Preferences", symbolName: "gear" )
        ]),
        ViewNode(groupId: 2, title: "Favorites", children: [
            ViewNode(id: 21, title: "HSBC", symbolName: "star", color: NSColor.systemYellow ),
            ViewNode(id: 22, title: "Google", symbolName: "star", color: NSColor.systemYellow ),
            ViewNode(id: 23, title: "Strava", symbolName: "star", color: NSColor.systemYellow )
        ])
    ]
    




    

         
         









    
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
        
        let tagNodes = model.tagSet.map { tag in
            return ViewNode(id: tag.hash, title: tag, symbolName: "tag")
        }
        
        var newData = staticData;
        
        if ( !tagNodes.isEmpty ) {
            newData += [
                ViewNode(groupId: 5, title: "Tags", children: tagNodes)
            ]
        }
                
        Logging.log("SideBarViewController::load done, expanding all items")
        
        dataSource = newData
        
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? dataSource.count : (item as! ViewNode).children.count
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? dataSource[index] : (item as! ViewNode).children[index]
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? ViewNode,
              let cell = outlineView.makeView(withIdentifier: node.cellIdentifier, owner: self) as? NSTableCellView else {
            return nil
        }
        
        cell.textField?.stringValue = node.title
        
        if !node.isGroup {
            if #available(macOS 11.0, *) {
                cell.imageView?.image = NSImage(systemSymbolName: node.symbolName ?? "folder", accessibilityDescription: nil)
            }
            else {
                cell.imageView?.image = NSImage(named: node.symbolName ?? "folder")
            }
        }
        
        return cell
    }

    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as! ViewNode).isGroup
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !(item as! ViewNode).children.isEmpty
    }
    
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item as! ViewNode).isGroup
    }
    
    @available(macOS 11.0, *)
    func outlineView(_ outlineView: NSOutlineView, tintConfigurationForItem item: Any) -> NSTintConfiguration? {
        return ((item as! ViewNode).color != nil) ? NSTintConfiguration.init(fixedColor: (item as! ViewNode).color!) : NSTintConfiguration.default
    }
}
