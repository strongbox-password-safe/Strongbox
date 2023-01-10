//
//  SideBarViewController3.swift
//  MacBox
//
//  Created by Strongbox on 25/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class SideBarViewController: NSViewController, DocumentViewController {
    deinit {
        NSLog("😎 DEINIT [SideBarViewController]")
    }

    private var headerNodeStates: [HeaderNodeState] = []
    private var viewNodes: [SideBarViewNode] = []

    @IBOutlet var outlineView: OutlineView!
    @IBOutlet var contextMenu: NSMenu!

    private var loadedDocument: Bool = false
    private var database: ViewModel!

    private var rootGroupForDisplay: Node {
        return database.rootGroup
    }

    func onDocumentLoaded() {


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

        outlineView.register(NSNib(nibNamed: NSNib.Name(TitleAndIconCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)
        outlineView.registerForDraggedTypes([NSPasteboard.PasteboardType(kDragAndDropInternalUti),
                                             NSPasteboard.PasteboardType(kDragAndDropExternalUti),
                                             NSPasteboard.PasteboardType(kDragAndDropSideBarHeaderMoveInternalUti)])


        
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

        

        let auditNotificationsOfInterest: [String] = [
            
            kAuditCompletedNotificationKey,
        ]

        for ofInterest in auditNotificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else { return }
                self.onAuditUpdateNotification(notification)
            }
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

        let navNotifications: [String] = [kModelUpdateNotificationNextGenSearchContextChanged,
                                          kModelUpdateNotificationNextGenNavigationChanged]

        for ofInterest in navNotifications {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] _ in
                guard let self = self else { return }

                self.onModelNavigationContextChanged()
            }
        }

        let notificationsOfInterest: [String] = [kModelUpdateNotificationItemsAdded,
                                                 kModelUpdateNotificationItemEdited,
                                                 kModelUpdateNotificationItemsDeleted,
                                                 kModelUpdateNotificationItemsUnDeleted,
                                                 kModelUpdateNotificationIconChanged,
                                                 kModelUpdateNotificationTitleChanged,
                                                 kModelUpdateNotificationItemsMoved,
                                                 kModelUpdateNotificationItemReOrdered,
                                                 kModelUpdateNotificationTagsChanged,
                                                 kModelUpdateNotificationDatabasePreferenceChanged,
                                                 kModelUpdateNotificationHistoryItemRestored]

        for ofInterest in notificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else {
                    return
                }

                self.onNotificationReceived(notification)
            }
        }
    }

    func onAuditUpdateNotification(_ notification: Notification) {
        
        guard let dict = notification.object as? [String: Any], let model = dict["model"] as? Model else {
            NSLog("🔴 Couldn't real model from notification")
            return
        }

        if model != database.commonModel {
            return
        }

        NSLog("✅ SideBarViewController::onAuditUpdateNotification [%@]", String(describing: notification.name))

        refresh()
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

    func loadHeaderNode(_ node: HeaderNode) -> SideBarViewNode? {
        switch node {
        case kHeaderNodeFavourites:
            return loadFavouritesSideBarNodes()
        case kHeaderNodeRegularHierarchy:
            return loadHierarchyHeader()
        case kHeaderNodeTags:
            return loadTagsSideBarNodes()
        case kHeaderNodeAuditIssues:
            return loadAuditSideBarNodes()
        case kHeaderNodeSpecial:
            return loadQuickViewSideBarNodes()
        default:
            NSLog("🔴 Unknown HEader")
            return nil
        }
    }

    func loadHierarchyHeader() -> SideBarViewNode {
        let hierarchyHeader = SideBarViewNode(context: .none, title: NSLocalizedString("side_bar_hierarchy_folder_structure", comment: "Hierarchy"), image: Icon.houseFill.image(), parent: nil, children: [], headerNode: kHeaderNodeRegularHierarchy)

        let hierarchyRoot = getHierarchicalViewNodesFor(rootGroupForDisplay, hierarchyHeader)
        hierarchyHeader.children = [hierarchyRoot]

        return hierarchyHeader
    }

    func loadFavouritesSideBarNodes() -> SideBarViewNode? {
        let favourites = database.favourites.sorted { node1, node2 in
            finderStyleNodeComparator(node1, node2) == .orderedAscending
        }

        if !favourites.isEmpty {
            let favouritesHeader = SideBarViewNode(context: .none,
                                                   title: NSLocalizedString("browse_vc_section_title_pinned", comment: "Favourites"),
                                                   image: Icon.favourite.image(),
                                                   parent: nil,
                                                   children: [],
                                                   headerNode: kHeaderNodeFavourites)

            for favourite in favourites {
                let image = NodeIconHelper.getIconFor(favourite, predefinedIconSet: database.iconSet, format: database.format)
                let ret = SideBarViewNode(context: .favourites(favourite.uuid), title: favourite.title, image: image, parent: favouritesHeader, children: [])
                favouritesHeader.children.append(ret)
            }

            return favouritesHeader
        }

        return nil
    }

    func loadTagsSideBarNodes() -> SideBarViewNode? {
        let sortedTags = database.tagSet.sorted { a, b in
            finderStringCompare(a, b) == .orderedAscending
        }

        if sortedTags.isEmpty {
            return nil
        }

        let tagsHeader = SideBarViewNode(context: .none, title: NSLocalizedString("item_details_username_field_tags", comment: "Tags"), image: Icon.tagFill.image(), parent: nil, children: [], headerNode: kHeaderNodeTags)

        let tagNodes = sortedTags.map { tag in
            SideBarViewNode(context: .tags(tag), title: tag, image: Icon.tag.image(), parent: tagsHeader)
        }

        tagsHeader.children = tagNodes

        return tagsHeader
    }

    func loadQuickViewSideBarNodes() -> SideBarViewNode {
        let specialsHeader = SideBarViewNode(context: .none,
                                             title: NSLocalizedString("quick_view_section_title_quick_views", comment: "Quick Views"),
                                             image: Icon.viewFinderCircleFill.image(), headerNode: kHeaderNodeSpecial)

        

        let allEntriesNode = SideBarViewNode(context: .special(.allEntries), title: NSLocalizedString("quick_view_title_all_entries_title", comment: "All Entries"),
                                             image: Icon.listStar.image(), parent: specialsHeader)

        var specialNodes: [SideBarViewNode] = [allEntriesNode]

        

        var expired = false
        var nearlyExpired = false
        var totp = false
        var attachment = false

        for obj in database.allSearchableEntries {
            if !expired {
                expired = obj.fields.expired
            }
            if !nearlyExpired {
                nearlyExpired = obj.fields.nearlyExpired
            }
            if !totp {
                totp = obj.fields.otpToken != nil
            }
            if !attachment {
                attachment = obj.fields.attachments.count > 0
            }

            if expired, nearlyExpired, totp, attachment {
                break
            }
        }

        

        if expired {
            let entry = SideBarViewNode(context: .special(.expiredEntries), title: NSLocalizedString("browse_vc_section_title_expired", comment: "Expired"),
                                        image: Icon.expired.image(), parent: specialsHeader)

            specialNodes.append(entry)
        }

        

        if nearlyExpired {
            let entry = SideBarViewNode(context: .special(.nearlyExpiredEntries), title: NSLocalizedString("browse_vc_section_title_nearly_expired", comment: "Nearly Expired"),
                                        image: Icon.nearlyExpired.image(), parent: specialsHeader)

            specialNodes.append(entry)
        }

        

        if totp {
            let entry = SideBarViewNode(context: .special(.totpItems), title: NSLocalizedString("generic_fieldname_totp", comment: "TOTP"),
                                        image: Icon.totp.image(), parent: specialsHeader)

            specialNodes.append(entry)
        }

        

        if attachment {
            let entry = SideBarViewNode(context: .special(.itemsWithAttachments), title: NSLocalizedString("generic_fieldname_attachments", comment: "Attachments"),
                                        image: Icon.attachment.image(), parent: specialsHeader)

            specialNodes.append(entry)
        }

        

        specialsHeader.children = specialNodes

        return specialsHeader
    }

    func loadAuditSideBarNodes() -> SideBarViewNode? {
        guard let report = database.auditReport else {
            NSLog("🔴 No Audit Report available - cannot load audit issues")
            return nil
        }

        let auditHeader = SideBarViewNode(context: .none,
                                          title: NSLocalizedString("quick_view_title_audit_issues_title", comment: "Audit Issues"),
                                          image: Icon.auditShieldFill.image(),
                                          parent: nil,
                                          children: [],
                                          headerNode: kHeaderNodeAuditIssues)

        var auditNodes: [SideBarViewNode] = []

        if !report.entriesWithNoPasswords.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.noPasswords),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_no_password_set", comment: "No Passwords"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesWithDuplicatePasswords.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.duplicated),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_duplicated_password", comment: "Duplicated"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesWithCommonPasswords.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.common),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_very_common_password", comment: "Common"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesWithSimilarPasswords.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.similar),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_password_is_similar_to_another", comment: "Similar"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesTooShort.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.tooShort),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_password_is_too_short", comment: "Short"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesPwned.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.pwned),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_password_is_pwned", comment: "Pwned"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesWithLowEntropyPasswords.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.lowEntropy),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_low_entropy", comment: "Weak/Entropy"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.entriesWithTwoFactorAvailable.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.twoFactorAvailable),
                                                   title: NSLocalizedString("audit_quick_summary_very_brief_two_factor_available", comment: "2FA Available"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        if !report.allEntries.isEmpty {
            let auditEntriesNode = SideBarViewNode(context: .auditIssues(.allEntries),
                                                   title: NSLocalizedString("audit_side_bar_nav_all_issues", comment: "All Issues"),
                                                   image: Icon.auditShield.image(),
                                                   parent: auditHeader,
                                                   color: .systemOrange)

            auditNodes.append(auditEntriesNode)
        }

        auditHeader.children = auditNodes

        return auditNodes.isEmpty ? nil : auditHeader
    }

    var databaseHeaderNodes: [HeaderNodeState] {
        get {
            return database.headerNodes
        }
        set {
            database.headerNodes = newValue
        }
    }

    private func refresh() {
        let newHeaders = databaseHeaderNodes
        var newData: [SideBarViewNode] = []

        for header in newHeaders {
            if let node = loadHeaderNode(header.header) {
                newData += [node]
            }
        }

        headerNodeStates = newHeaders
        viewNodes = newData

        let scrollOffset = outlineView.enclosingScrollView?.contentView.bounds.origin
        
        outlineView.reloadData()

        expandStructure() 

        bindSelectionToModelNavigationContext()
        
        if let scrollOffset = scrollOffset {
            outlineView.enclosingScrollView?.contentView.scroll(scrollOffset)
        }
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

    private func expandStructure() {
        isPerformingProgrammaticExpandCollapse = true

        for header in headerNodeStates {
            if header.expanded, let node = viewNodes.first(where: { $0.headerNode == header.header }) {
                outlineView.expandItem(node)

                if header.header == kHeaderNodeRegularHierarchy {
                    if let hierarchyRoot = node.children.first {
                        expandRegularHierarchyIfFieldIsExpanded(hierarchyRoot)
                    }
                }
            }
        }

        isPerformingProgrammaticExpandCollapse = false
    }

    private func getHierarchicalViewNodesFor(_ group: Node, _ parentNode: SideBarViewNode) -> SideBarViewNode {
        let image: NSImage
        if rootGroupForDisplay.uuid == group.uuid, group.isUsingKeePassDefaultIcon {
            image = Icon.house.image()
        } else {
            image = NodeIconHelper.getIconFor(group, predefinedIconSet: database.iconSet, format: database.format)
        }

        let ret = SideBarViewNode(context: .regularHierarchy(group.uuid), title: group.title, image: image, parent: parentNode, children: [], databaseNodeChildCount: group.childRecords.count)

        if database.isKeePass2Format, !database.sortKeePassNodes {
            ret.children = group.childGroups.map { child in
                getHierarchicalViewNodesFor(child, ret)
            }
        }
        else {
            var sorted = group.childGroups.sorted(by: Node.sortTitleLikeFinder)

            

            if database.recycleBinEnabled, let recycleBinNode = database.recycleBinNode, let idx = sorted.firstIndex(of: recycleBinNode) {
                sorted.remove(at: idx)

                if database.showRecycleBinInBrowse {
                    sorted.append(recycleBinNode)
                }
            }

            ret.children = sorted.map { child in
                getHierarchicalViewNodesFor(child, ret)
            }
        }
        
        return ret
    }

    func onModelNavigationContextChanged() {
        NSLog("✅ SideBarViewController::onModelNavigationContextChanged...")

        bindSelectionToModelNavigationContext()
    }

    

    func expandParentsOfItem(item: SideBarViewNode, expandCollapsedHeaderItem: Bool = true ) {
        var stack: [SideBarViewNode] = []

        var tmp = item
        while tmp.parent != nil {
            tmp = tmp.parent!
            stack.append(tmp)
        }

        if let headerItem = stack.last, let headerNode = headerItem.headerNode, let header = headerNodeStates.first(where: { hns in
            return hns.header == headerNode
        })  {
            if !header.expanded {
                return
            }
        }
        
        
        while let group = stack.last {


            outlineView.expandItem(group)

            stack.removeLast()
        }
    }

    func bindSelectionToModelNavigationContext() {
        if isSearching {
            outlineView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            return
        }

        let navContext = navigationContext



        if let viewNode = findViewNode(for: navigationContext) {
            expandParentsOfItem(item: viewNode, expandCollapsedHeaderItem: false)

            let row = outlineView.row(forItem: viewNode)

            if row != -1 {
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                return
            }
        } else if navContext == .none {
            return
        }

        NSLog("🔴 SideBarViewController::bindSelectionToModelNavigationContext: Could not find this Nav Context!")

        outlineView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
    }

    func findViewNode(for navContext: NavigationContext) -> SideBarViewNode? {
        switch navContext {
        case .none:
            return nil
        case .favourites:
            let header = viewNodes.first { $0.headerNode == kHeaderNodeFavourites }
            return header?.children.first { $0.context == navContext }
        case .regularHierarchy:
            let header = viewNodes.first { $0.headerNode == kHeaderNodeRegularHierarchy }
            let descendents = header?.allDescendents
            let match = descendents?.first { $0.context == navContext }
            return match
        case .tags:
            let header = viewNodes.first { $0.headerNode == kHeaderNodeTags }
            return header?.children.first { $0.context == navContext }
        case .auditIssues:
            let header = viewNodes.first { $0.headerNode == kHeaderNodeAuditIssues }
            return header?.children.first { $0.context == navContext }
        case .special:
            let header = viewNodes.first { $0.headerNode == kHeaderNodeSpecial }
            return header?.children.first { $0.context == navContext }
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

    var navigationContext: NavigationContext {
        return getNavContextFromModel(database)
    }

    var isSearching: Bool {
        guard let database = database else { return false }

        let text = database.nextGenSearchText

        return !text.isEmpty
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
    func outlineView(_: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        guard let node = item as? SideBarViewNode else { return true }

        switch node.context {
        case .favourites(_), .tags(_), .auditIssues(_), .special:
            return false
        case .none, .regularHierarchy:
            return true
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SideBarViewNode else { return nil }

        let cell: NSTableCellView

        if node.headerNode == nil {
            let cell = outlineView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! TitleAndIconCell

            let attr: NSAttributedString
            if database.isKeePass2Format, database.sortKeePassNodes, database.recycleBinEnabled, database.recycleBinNode != nil, node.context == .regularHierarchy(database.recycleBinNode!.uuid) {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                attr = NSAttributedString(string: node.title, attributes: [.font: FontManager.shared.italicBodyFont, .paragraphStyle: style])

                cell.setContent(attr, iconImage: node.image, topSpacing: 16.0)
            } else {
                let style = NSMutableParagraphStyle()
                style.lineBreakMode = .byTruncatingTail
                attr = NSAttributedString(string: node.title, attributes: [.font: FontManager.shared.bodyFont, .paragraphStyle: style])

                var fav = false
                if case .favourites = node.context {
                    fav = true
                }

                cell.setContent(attr, iconImage: node.image, showLeadingFavStar: fav, count: database.showChildCountOnFolderInSidebar ? node.databaseNodeChildCount : nil)
            }

            return cell
        } else {
            cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! NSTableCellView
            cell.imageView?.image = nil 
            cell.imageView?.isHidden = true
            cell.textField?.stringValue = node.title
        }

        return cell
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        guard let item = item as? SideBarViewNode else {
            return false
        }

        return item.headerNode != nil
    }

    func outlineView(_: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        guard let item = item as? SideBarViewNode else { return nil }

        if database.isKeePass2Format, database.sortKeePassNodes, database.recycleBinEnabled, database.recycleBinNode != nil, item.context == .regularHierarchy(database.recycleBinNode!.uuid) {
            return PaddedRowView()
        }

        return nil
    }

    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        guard let item = item as? SideBarViewNode else { return false }

        if item.context == .none {
            return false
        }

        return true
    }

    @available(macOS 11.0, *)
    func outlineView(_: NSOutlineView, tintConfigurationForItem item: Any) -> NSTintConfiguration? {
        return ((item as! SideBarViewNode).color != nil) ? NSTintConfiguration(fixedColor: (item as! SideBarViewNode).color!) : NSTintConfiguration.monochrome 
    }

    func outlineViewSelectionDidChange(_: Notification) {


        guard let selected = outlineView.item(atRow: outlineView.selectedRow) as? SideBarViewNode else {
            NSLog("🔴 outlineViewSelectionDidChange::Could not get selected.")
            return
        }

        if selected.context != .none {
            setModelNavigationContextWithViewNode(database, selected.context)
        }
    }

    func outlineView(_: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        guard let singleItem = items.first as? SideBarViewNode else { return false }

        if let headerNode = singleItem.headerNode {
            pasteboard.setString(String(headerNode.rawValue), forType: NSPasteboard.PasteboardType(kDragAndDropSideBarHeaderMoveInternalUti))
            return true
        }
        else if case let .regularHierarchy(groupUuid) = singleItem.context {
            if groupUuid == database.recycleBinNode?.uuid { 
                return false
            }

            if let group = database.getItemBy(groupUuid) {
                return windowController.placeItems(on: pasteboard, items: [group])
            }
        }

        return false
    }

    func isValidNonHeaderDragDestination(_ context: NavigationContext) -> Bool {
        switch context {
        case .regularHierarchy(_), .tags:
            return true
        default:
            return false 
        }
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard let destinationItem = item as? SideBarViewNode,
              let source = info.draggingSource as? NSOutlineView else { return [] }

        if let _ = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType(kDragAndDropSideBarHeaderMoveInternalUti)) {
            guard source == outlineView, destinationItem.headerNode != nil, index == NSOutlineViewDropOnItemIndex else { return [] }



            return [.move]
        }

        guard isValidNonHeaderDragDestination(destinationItem.context) else {
            return []
        }

        let sourceIsBrowseView = source == browseView.outlineView
        let sourceIsThisDatabase = source == outlineView || sourceIsBrowseView

        if sourceIsThisDatabase {
            if case let .regularHierarchy(destinationGroupId) = destinationItem.context {
                guard let destinationGroup = database.getItemBy(destinationGroupId),
                      let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(kDragAndDropInternalUti)) as? [String]
                else {
                    return []
                }



                let sourceItems = serializationIds.compactMap { database.getItemFromSerializationId($0) }
                let valid = database.validateMove(sourceItems, destination: destinationGroup)

                if sourceIsBrowseView {
                    if index == NSOutlineViewDropOnItemIndex {
                        if valid {
                            return [.move]
                        }
                    }
                }
                else {
                    if index == NSOutlineViewDropOnItemIndex {


                        if valid {
                            return [.move]
                        }
                    }
                    
                    else {
                        if database.isKeePass2Format, !database.sortKeePassNodes {
                            NSLog("✅ SideBarViewController::validateDrop: Internal Source - REORDER - %d", index)
                            return [.move]
                        }
                    }
                }
            } else if case .tags = destinationItem.context, index == NSOutlineViewDropOnItemIndex, sourceIsBrowseView {

                return [.copy]
            }
        } else {
            guard case .regularHierarchy = destinationItem.context,
                  let _ = info.draggingPasteboard.data(forType: NSPasteboard.PasteboardType(kDragAndDropExternalUti)),
                  index == NSOutlineViewDropOnItemIndex else { return [] }

            NSLog("SideBar validateDrop: External Source - %d", index)
            return [.copy]
        }

        return []
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let destinationItem = item as? SideBarViewNode,
              let source = info.draggingSource as? NSOutlineView else { return false }

        if let headerString = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType(kDragAndDropSideBarHeaderMoveInternalUti)),
           let headerInt = Int(headerString)
        {
            guard source == outlineView,
                  destinationItem.headerNode != nil,
                  let headerSrcIdx = headerNodeStates.firstIndex(where: { $0.header == HeaderNode(rawValue: headerInt) }),
                  index == NSOutlineViewDropOnItemIndex else { return false }



            var headersCopy = headerNodeStates

            let theHeader = headersCopy[headerSrcIdx]
            headersCopy.remove(at: headerSrcIdx)

            if let headerDestIdx = headerNodeStates.firstIndex(where: { $0.header == destinationItem.headerNode }) {
                headersCopy.insert(theHeader, at: headerDestIdx)
            }

            databaseHeaderNodes = headersCopy

            refresh()

            return true
        }

        guard isValidNonHeaderDragDestination(destinationItem.context) else {
            return false
        }

        let sourceIsBrowseView = source == browseView.outlineView
        let sourceIsThisDatabase = source == outlineView || sourceIsBrowseView

        if case let .regularHierarchy(destinationGroupId) = destinationItem.context {
            guard let destination = database.getItemBy(destinationGroupId) else {
                return false
            }

            if index == NSOutlineViewDropOnItemIndex {


                return windowController.pasteItems(from: info.draggingPasteboard, destinationItem: destination, internal: sourceIsThisDatabase, clear: true) != 0
            }
            else {
                guard let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType( kDragAndDropInternalUti) ) as? [String] else {
                    return false
                }
                
                let sourceItems = serializationIds.compactMap { database.getItemFromSerializationId( $0 ) }
                
                guard sourceItems.count == 1, let sourceItem = sourceItems.first else { return false }
                
                if destination.uuid != sourceItem.parent?.uuid {


                    if !database.move([sourceItem], destination: destination) {
                        return false
                    }
                }

                guard let sourceIdx = sourceItem.parent?.children.firstIndex(of: sourceItem) else { return false }
                
                let adjustedIdx = sourceIdx < index ? (index - 1) : index
                
                NSLog("SideBar acceptDrop: REORDER of item - Source [%@] => Dest [%@] index = [%d]", sourceItem.title, destination.title, adjustedIdx)
                
                if database.reorderItem(sourceItem.uuid, idx: adjustedIdx) != -1 {
                    info.draggingPasteboard.clearContents()
                    return true
                }
                
                return false
            }
        } else if case let .tags(tag) = destinationItem.context, index == NSOutlineViewDropOnItemIndex, sourceIsBrowseView {
            guard let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(kDragAndDropInternalUti)) as? [String] else { return false }
            let sourceItems = serializationIds.compactMap { database.getItemFromSerializationId($0) }



            database.addTag(toItems: sourceItems, tag: tag)
            return true
        }

        return false
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isPerformingProgrammaticExpandCollapse, let item = notification.userInfo?.values.first as? SideBarViewNode else { return }

        if let header = item.headerNode {
            NSLog("outlineViewItemDidExpand = [%@]", String(describing: item.title))

            if let idx = headerNodeStates.firstIndex(where: { $0.header == header }) {
                headerNodeStates[idx].expanded = true
                databaseHeaderNodes = headerNodeStates
            }
        }
        else if !database.isEffectivelyReadOnly,
                case let .regularHierarchy(uuid) = item.context,
                let node = database.getItemBy(uuid)
        {
            database.setGroupExpandedState(node, expanded: true)
        }
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isPerformingProgrammaticExpandCollapse, let item = notification.userInfo?.values.first as? SideBarViewNode else { return }

        if let header = item.headerNode {
            NSLog("outlineViewItemDidCollapse = [%@]", String(describing: item.title))

            if let idx = headerNodeStates.firstIndex(where: { $0.header == header }) {
                headerNodeStates[idx].expanded = false
                databaseHeaderNodes = headerNodeStates
            }
        }
        else if !database.isEffectivelyReadOnly,
                case let .regularHierarchy(uuid) = item.context,
                let node = database.getItemBy(uuid)
        {
            database.setGroupExpandedState(node, expanded: false)
        }
    }
}
