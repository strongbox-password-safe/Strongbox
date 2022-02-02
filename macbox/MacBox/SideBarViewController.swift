//
//  SideBarViewController3.swift
//  MacBox
//
//  Created by Strongbox on 25/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

// TODO: Also allow rearrange of top level items, so like Tags can be dragged above Hierarchy for those who prefer tags
// TODO: Collapseable / Expandable Headers
// TODO: Also allow users to configure show/hide elements, e.g. no Hierarchy just Tags
// TODO: Custom Order & allowing user move and re-arrange folders?
// TODO: Header Icons
// TODO: Need to scale down custom images

class SideBarViewController: NSViewController, DocumentViewController {
    deinit {
        NSLog("😎 DEINIT [SideBarViewController]")
    }

    @IBOutlet var outlineView: OutlineView!
    @IBOutlet var contextMenu: NSMenu!

    private var loadedDocument: Bool = false
    private var database: ViewModel!

    private var viewNodes: [SideBarViewNode] = []
    var hierarchyHeader: SideBarViewNode?
    var hierarchyRoot: SideBarViewNode?
    var tagsHeader: SideBarViewNode?
    var specialsHeader: SideBarViewNode?

    private var rootGroupForDisplay: Node {
        return database.rootGroup
    }

    func onDocumentLoaded() {
        NSLog("🚀 SideBarViewController::onDocumentLoaded")

        loadDocument()
    }

    func loadDocument() {
        if loadedDocument {
            return
        }

        guard let doc = view.window?.windowController?.document as? Document else {
            NSLog("SideBarViewController::load Document not set!")
            return
        }

        database = doc.viewModel
        loadedDocument = true

        outlineView.registerForDraggedTypes([NSPasteboard.PasteboardType(kDragAndDropInternalUti), NSPasteboard.PasteboardType(kDragAndDropExternalUti)])

        outlineView.delegate = self
        outlineView.dataSource = self

        refresh()

        listenToModelUpdateNotifications()
    }

    func listenToModelUpdateNotifications() {
        NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }

            self.refresh()
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(kModelUpdateNotificationFullReload),
                                               object: nil, queue: nil)
        { [weak self] notification in
            guard let self = self else { return }

            if notification.object as? NSDocument != self.database.document {
                return
            }


            DispatchQueue.main.async { [weak self] in
                self?.refresh()
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(kModelUpdateNotificationNextGenNavigationChanged), object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }

            self.onModelNavigationContextChanged()
        }

        let notificationsOfInterest: [String] = [kModelUpdateNotificationItemsAdded,
                                                 kModelUpdateNotificationItemEdited,
                                                 kModelUpdateNotificationItemsDeleted,
                                                 kModelUpdateNotificationItemsUnDeleted,
                                                 kModelUpdateNotificationIconChanged,
                                                 kModelUpdateNotificationTitleChanged,
                                                 kModelUpdateNotificationItemsMoved]

        for ofInterest in notificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else {
                    return
                }

                self.onNotificationReceived(notification)
            }
        }
    }

    func onNotificationReceived(_ notification: Notification) {
        guard let notifyModel = notification.object as? ViewModel else {
            return
        }

        if notifyModel != database {
            return
        }

        if notification.name == NSNotification.Name(kModelUpdateNotificationItemsAdded) {
            NSLog("Master-Notify: Items Added")
        } else if notification.name == NSNotification.Name(kModelUpdateNotificationItemEdited) {
            NSLog("Master-Notify: Items Edited")
        } else if notification.name == NSNotification.Name(kModelUpdateNotificationItemsDeleted) {
            NSLog("Master-Notify: Items Deleted")
        } else if notification.name == NSNotification.Name(kModelUpdateNotificationItemsUnDeleted) {
            NSLog("Master-Notify: Items Un-Deleted")
        } else if notification.name == NSNotification.Name(kModelUpdateNotificationIconChanged) {
            NSLog("Master-Notify: Icon Changed")
        }

        refresh()
    }

    private func loadSideBarStructure() -> (structure: [SideBarViewNode], hierarchyRoot: SideBarViewNode, hierarchyHeader: SideBarViewNode, tagsHeader: SideBarViewNode?, specialsHeader: SideBarViewNode) {
        var newData: [SideBarViewNode] = []

        

        

        let hierarchyHeader = SideBarViewNode(context: .none, title: NSLocalizedString("side_bar_hierarchy_folder_structure", comment: "Hierarchy"), image: Icon.house.image(), parent: nil, children: [], isHeaderNode: true)
        let hierarchyRoot = getHierarchicalViewNodesFor(rootGroupForDisplay, hierarchyHeader)
        hierarchyHeader.children = [hierarchyRoot]
        newData += [hierarchyHeader]

        

        let sortedTags = database.tagSet.sorted { a, b in
            finderStringCompare(a, b) == .orderedAscending
        }

        let tagsHeader = SideBarViewNode(context: .none, title: NSLocalizedString("item_details_username_field_tags", comment: "Tags"), image: Icon.tag.image(), parent: nil, children: [], isHeaderNode: true)

        let tagNodes = sortedTags.map { tag in
            SideBarViewNode(context: .tags(tag), title: tag, image: Icon.tag.image(), parent: tagsHeader)
        }

        if !tagNodes.isEmpty {
            tagsHeader.children = tagNodes
            newData += [tagsHeader]
        }

        

        

        let specialsHeader = SideBarViewNode(context: .none,
                                             title: NSLocalizedString("quick_view_section_title_quick_views", comment: "Quick Views"),
                                             image: Icon.house.image(),
                                             parent: nil, children: [], isHeaderNode: true)
        let specialNodes: [SideBarViewNode] = [SideBarViewNode(context: .special(.allEntries), title: NSLocalizedString("quick_view_title_all_entries_title", comment: "All Entries"),
                                                               image: Icon.listStar.image(), parent: specialsHeader)]
        specialsHeader.children = specialNodes

        newData += [specialsHeader]

        return (newData, hierarchyRoot, hierarchyHeader, tagsHeader, specialsHeader)
    }

    private func refresh() {
        let newData = loadSideBarStructure()

        viewNodes = newData.structure
        hierarchyHeader = newData.hierarchyHeader
        hierarchyRoot = newData.hierarchyRoot
        tagsHeader = newData.tagsHeader
        specialsHeader = newData.specialsHeader

        outlineView.reloadData()

        expandBasicRequiredStructure()

        bindSelectionToModelNavigationContext()
    }

    private func expandRegularHierarchyIfFieldIsExpanded(_ node: SideBarViewNode) {
        if case let .regularHierarchy(uuid) = node.context {
            guard let childNode = database.getItemBy(uuid) else { return }



            if childNode.fields.isExpanded {
                outlineView.expandItem(node, expandChildren: true)
            } else {
                outlineView.collapseItem(node, collapseChildren: true)
            }

            for child in node.children {
                expandRegularHierarchyIfFieldIsExpanded(child)
            }
        }
    }

    var isPerformingProgrammaticExpandCollapse: Bool = false
    private func expandBasicRequiredStructure() {
        isPerformingProgrammaticExpandCollapse = true

        outlineView.expandItem(hierarchyHeader)
        outlineView.expandItem(hierarchyRoot)

        if let hierarchyRoot = hierarchyRoot {
            expandRegularHierarchyIfFieldIsExpanded(hierarchyRoot)
        }

        if tagsHeader != nil {
            outlineView.expandItem(tagsHeader)
        }
        outlineView.expandItem(specialsHeader)

        isPerformingProgrammaticExpandCollapse = false
    }

    private func getHierarchicalViewNodesFor(_ group: Node, _ parentNode: SideBarViewNode) -> SideBarViewNode {
        let image: NSImage
        if rootGroupForDisplay.uuid == group.uuid, group.isUsingKeePassDefaultIcon {
            image = Icon.house.image()
        } else {
            image = NodeIconHelper.getIconFor(group, predefinedIconSet: database.iconSet, format: database.format)
        }

        let ret = SideBarViewNode(context: .regularHierarchy(group.uuid), title: group.title, image: image, parent: parentNode, children: [])

        let sorted = group.childGroups.sorted(by: Node.sortTitleLikeFinder)

        ret.children = sorted.map { child in
            getHierarchicalViewNodesFor(child, ret)
        }

        return ret
    }

    func onModelNavigationContextChanged() {
        NSLog("✅ SideBar::onModelNavigationContextChanged...")

        bindSelectionToModelNavigationContext()
    }

    

    func expandParentsOfItem(item: SideBarViewNode) {
        var stack: [SideBarViewNode] = []

        var tmp = item
        while tmp.parent != nil {
            tmp = tmp.parent!
            stack.append(tmp)
        }

        while let group = stack.last {


            outlineView.expandItem(group)

            stack.removeLast()
        }
    }

    func bindSelectionToModelNavigationContext() {
        let navContext = getNavContextFromModel(database)



        if let viewNode = findViewNode(for: navContext) {
            expandParentsOfItem(item: viewNode)

            let row = outlineView.row(forItem: viewNode)

            if row != -1 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                return
            }
        } else if navContext != .none {
            return
        }

        NSLog("🔴 bindSelectionToModelNavigationContext: Could not find this Nav Context!")

        outlineView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }

    func findViewNode(for navContext: NavigationContext) -> SideBarViewNode? {
        switch navContext {
        case .none:
            return nil
        case .favourites:
            return nil 
        case .regularHierarchy:
            guard let hierarchyHeader = hierarchyHeader else {
                NSLog("🔴 Hierarchy header not set")
                return nil
            }

            let descendents = hierarchyHeader.allDescendents
            let match = descendents.first { node in
                node.context == navContext
            }

            return match
        case .tags:
            return tagsHeader?.children.first(where: { tag in
                tag.context == navContext
            })
        case .totps:
            return nil 
        case .special:
            return specialsHeader?.children.first(where: { special in
                special.context == navContext
            })
        }
    }

    

    var windowController: WindowController {
        return view.window!.windowController as! WindowController
    }

    var splitViewController: NextGenSplitViewController {
        return windowController.contentViewController as! NextGenSplitViewController
    }

    var browseView: BrowseViewController {
        return splitViewController.masterListView
    }






}









extension SideBarViewController: NSOutlineViewDataSource {
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? viewNodes.count : (item as! SideBarViewNode).children.count
    }

    
    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? viewNodes[index] : (item as! SideBarViewNode).children[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        let node = item as! SideBarViewNode
        return !node.children.isEmpty 
    }
}

extension SideBarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SideBarViewNode,
              let cell = outlineView.makeView(withIdentifier: node.cellIdentifier, owner: self) as? NSTableCellView
        else {
            return nil
        }

        if !node.isHeaderNode {
            cell.imageView?.image = node.image
        }

        let attr: NSAttributedString
        if database.recycleBinEnabled, database.recycleBinNode != nil, node.context == .regularHierarchy(database.recycleBinNode!.uuid) {
            attr = NSAttributedString(string: node.title, attributes: [.font: FontManager.shared.italicBodyFont])
        } else {
            attr = NSAttributedString(string: node.title, attributes: [.font: FontManager.shared.bodyFont])
        }

        cell.textField?.attributedStringValue = attr

        return cell
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as! SideBarViewNode).isHeaderNode
    }

    func outlineView(_: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        let node = item as! SideBarViewNode
        return node.context != .none
    }

    
    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        !(item as! SideBarViewNode).isHeaderNode
    }

    @available(macOS 11.0, *)
    func outlineView(_: NSOutlineView, tintConfigurationForItem item: Any) -> NSTintConfiguration? {
        return ((item as! SideBarViewNode).color != nil) ? NSTintConfiguration(fixedColor: (item as! SideBarViewNode).color!) : NSTintConfiguration.monochrome 
    }

    func outlineViewSelectionDidChange(_: Notification) {


        guard let selected = outlineView.item(atRow: outlineView.selectedRow) as? SideBarViewNode else {
            NSLog("🔴 Could not get selected.")
            return
        }

        setModelNavigationContextWithViewNode(database, selected.context)
    }

    func outlineView(_: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        guard let singleItem = items.first as? SideBarViewNode else { return false }

        if case let .regularHierarchy(groupUuid) = singleItem.context {
            if groupUuid == database.recycleBinNode?.uuid { 
                return false
            }

            if let group = database.getItemBy(groupUuid) {
                return windowController.placeItems(on: pasteboard, items: [group])
            }
        }

        return false
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let destinationItem = item as? SideBarViewNode else { return [] }

        let destinationItemId: NodeIdentifier

        switch destinationItem.context {
        case let .regularHierarchy(group):
            destinationItemId = group
        default:
            return [] 
        }

        guard let destination = database.getItemBy(destinationItemId) else {
            return []
        }

        if let source = info.draggingSource as? NSOutlineView {
            if source == outlineView || source == browseView.outlineView { 
                if source == outlineView {
                    NSLog("SideBar validateDrop: Internal move of Side Bar Items! - %d", index)



                } else {
                    NSLog("SideBar validateDrop: Drop from Browse View! - %@ - %d", String(describing: item), index)
                }

                guard let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(kDragAndDropInternalUti)) as? [String] else {
                    return []
                }

                let sourceItems = serializationIds.compactMap { obj in
                    database.getItemFromSerializationId(obj)
                }

                let valid = database.validateMove(sourceItems, destination: destination)

                NSLog("SideBar::validateDrop: Internal Source (Browse View) - destination [%@] - valid = [%d]", String(describing: destination), valid)

                if !valid {
                    return []
                }

                if index == NSOutlineViewDropOnItemIndex { 
                    return [.move]
                } else {
                    return []
                }
            }
        }

        guard let _ = info.draggingPasteboard.data(forType: NSPasteboard.PasteboardType(kDragAndDropExternalUti)) else { return [] }

        if index == NSOutlineViewDropOnItemIndex { 


            return [.copy]
        } else {
            return []
        }
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let destinationItem = item as? SideBarViewNode else { return false }

        let destinationItemId: NodeIdentifier

        switch destinationItem.context {
        case let .regularHierarchy(group):
            destinationItemId = group
        default:
            return false 
        }

        guard let destination = database.getItemBy(destinationItemId) else {
            return false
        }

        if let source = info.draggingSource as? NSOutlineView {
            if source == outlineView {
                NSLog("SideBar acceptDrop: Internal move of Side Bar Items! - %d", index)

                return windowController.pasteItems(from: info.draggingPasteboard, destinationItem: destination, internal: true, clear: true) != 0
            } else if source == browseView.outlineView {
                NSLog("SideBar acceptDrop: Internal move of items from Browse! - %d", index)

                return windowController.pasteItems(from: info.draggingPasteboard, destinationItem: destination, internal: true, clear: true) != 0
            }
        }

        NSLog("SideBar acceptDrop: External Drop Source! - %d", index)
        return windowController.pasteItems(from: info.draggingPasteboard, destinationItem: destination, internal: false, clear: true) != 0
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?.values.first as? SideBarViewNode else { return }

        if isPerformingProgrammaticExpandCollapse {

            return
        }



        if !database.isEffectivelyReadOnly {
            if case let .regularHierarchy(uuid) = item.context {
                if let node = database.getItemBy(uuid) {
                    database.setGroupExpandedState(node, expanded: true)
                }
            }
        } else {
            
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?.values.first as? SideBarViewNode else { return }

        if isPerformingProgrammaticExpandCollapse {

            return
        }



        if !database.isEffectivelyReadOnly {
            if case let .regularHierarchy(uuid) = item.context {
                if let node = database.getItemBy(uuid) {
                    database.setGroupExpandedState(node, expanded: false)
                }
            }
        } else {
            
        }
    }
}































