//
//  MasterViewController.swift
//  MacBox
//
//  Created by Strongbox on 27/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class MasterViewController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource, DocumentViewController {
    
    private enum ColumnIdentifiers {
        static let Title: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("TitleColumn")
        static let Username: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("UsernameColumn")
    }
    
    private enum CellIdentifiers {
        static let Title: NSUserInterfaceItemIdentifier = NSUserInterfaceItemIdentifier("TitleCellIdentifier")

    }
    
    



























    @IBOutlet weak var outlineView: NSOutlineView!
    
    private var document : Document?
    private var loadedDocument : Bool = false
    private var model : ViewModel? {
        return document?.viewModel
    }


     
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
        

        
        outlineView.reloadData()
        

    }








    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        let it = item as! Node;
        
        if (it.isGroup) {
            let items = getItems(it);
            return items.count > 0;
        }

        return false;
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let group = (item == nil) ? model?.rootGroup : (item as! Node);
        let items = getItems(group);
        return items.count;
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let group = (item == nil) ? model?.rootGroup : (item as! Node);
        let items = getItems(group);
        return items[index];
    }

    







    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let it = item as! Node;
        
        if ( it.isGroup ) {
            if ( tableColumn!.identifier == ColumnIdentifiers.Title ) {
                return getTitleCell(node: it)
            }
            else {

            }
            
        }
        
        return getTitleCell(node: it)

    }
    
    func getItems(_ parentGroup : Node? ) -> [Node] {
        
        







            return loadItems(parentGroup);
        




    }

    func loadItems(_ parentGroup : Node? ) -> [Node] {
        
        
        if ( parentGroup == nil || !parentGroup!.isGroup ) {
            return [];
        }
        
        let children = parentGroup!.children
        var sorted : [Node]
        
        let sort = model!.sortKeePassNodes || model!.format == DatabaseFormat.passwordSafe
        if ( sort ) {
            sorted = (children as NSArray).sortedArray(options: .stable, usingComparator: { (lhs, rhs) -> ComparisonResult in
                return finderStyleNodeComparator(lhs, rhs)
            }) as! [Node]
        }
        else {
            sorted = children
        }
        
        
        

        let isSearching = false 


        let filtered = sorted;
        















        
         
        let matches = !isSearching ? filtered : [] 


        
        return matches;
    }

    func getTitleCell(node : Node) -> NSTableCellView {
        let cell = outlineView.makeView(withIdentifier: CellIdentifiers.Title, owner: self) as! NSTableCellView

        
        















        


        cell.textField?.stringValue = node.title;
        







        return cell;
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let node = outlineView.item(atRow: outlineView.selectedRow) as! Node?
        model?.selectedItem = node?.uuid
    }
}
