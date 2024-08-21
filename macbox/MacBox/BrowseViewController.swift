//
//  BrowseViewController.swift
//  MacBox
//
//  Created by Strongbox on 27/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

// class NoSortIndicatorTableHeaderCell : NSTableHeaderCell {





class BrowseViewController: NSViewController {
    deinit {
        swlog("😎 DEINIT [BrowseViewController]")
        NotificationCenter.default.removeObserver(self)
    }

    @IBOutlet var checkboxIncludeGroupsInSearch: NSButton!
    @IBOutlet var imageViewSearchSummary: NSImageView!
    @IBOutlet var labelSearchSummary: NSTextField!
    @IBOutlet var scopeAllFields: NSSegmentedControl!
    @IBOutlet var scopeTitle: NSSegmentedControl!
    @IBOutlet var scopeUsername: NSSegmentedControl!
    @IBOutlet var scopePassword: NSSegmentedControl!
    @IBOutlet var scopeUrl: NSSegmentedControl!
    @IBOutlet var scopeTags: NSSegmentedControl!
    @IBOutlet var outlineView: BrowseOutlineView!
    @IBOutlet var predicateEditor: NSPredicateEditor!
    @IBOutlet var predicateEditorHeightConstraint: NSLayoutConstraint!
    @IBOutlet var outlineViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var searchParametersViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet var otherContextMenu: NSMenu!

    private var loadedDocument: Bool = false
    private var database: ViewModel!

    private var sortedItemsCache: [Node]?
    var unsorted: [Node] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()

        NotificationCenter.default.addObserver(self, selector: #selector(onRulesRowsDidChange), name: NSRuleEditor.rowsDidChangeNotification, object: nil)

        setInitialHeightConstraints()

        predicateEditor.enclosingScrollView?.hasVerticalScroller = false


        adjustHeightConstraintsWithAnimation()

        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            self.refresh()
        }
    }

    func setupUI() {
        outlineView.registerForDraggedTypes([NSPasteboard.PasteboardType(kDragAndDropInternalUti), NSPasteboard.PasteboardType(kDragAndDropExternalUti)])

        outlineView.register(NSNib(nibNamed: NSNib.Name(TitleAndIconCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)
        outlineView.register(NSNib(nibNamed: NSNib.Name("CustomFieldTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("CustomFieldValueCellIdentifier"))
        outlineView.register(NSNib(nibNamed: NSNib.Name(SingleLinePillTableCellView.NibIdentifier.rawValue), bundle: nil), forIdentifier: SingleLinePillTableCellView.NibIdentifier)

        outlineView.register(NSNib(nibNamed: NSNib.Name("UrlCell"), bundle: nil), forIdentifier: UrlCell.NibIdentifier)
    }

    @objc func onRulesRowsDidChange(_: NSMenuItem) {
        swlog("onRulesRowsDidChange: %f", predicateEditor.intrinsicContentSize.height)

        adjustHeightConstraintsWithAnimation()
    }

    func setInitialHeightConstraints() {
        

        if predicateEditor.intrinsicContentSize.height == 0.0 {
            outlineViewTopConstraint.constant = -2
        } else {
            outlineViewTopConstraint.constant = -1
        }

        predicateEditorHeightConstraint.constant = 0
        searchParametersViewHeightConstraint.constant = 0
    }

    @IBOutlet var searchBarCustomView: NSView!
    func adjustHeightConstraintsWithAnimation() {
        if isSearching {
            searchBarCustomView.isHidden = false
            searchParametersViewHeightConstraint.constant = 90
        } else {
            searchBarCustomView.isHidden = true
            searchParametersViewHeightConstraint.constant = 0
        }

        if predicateEditor.intrinsicContentSize.height == 0.0 {
            outlineViewTopConstraint.animator().constant = -2
        } else {
            outlineViewTopConstraint.animator().constant = -1
        }

        predicateEditorHeightConstraint.animator().constant = predicateEditor.intrinsicContentSize.height
    }

    @objc func onToggleColumn(_ sender: NSMenuItem) {
        guard let id = sender.identifier else {
            return
        }

        guard let tableColumn = outlineView.tableColumn(withIdentifier: id) else {
            return
        }

        if !tableColumn.isHidden { 
            let visible = outlineView.tableColumns.filter { column in
                !column.isHidden
            }

            if visible.count > 1 {
                tableColumn.isHidden = !tableColumn.isHidden
            }
        } else {
            tableColumn.isHidden = !tableColumn.isHidden
        }
    }

    fileprivate func setupColumns() {
        let columnsMenu = NSMenu(title: "")

        for column in BrowseViewColumn.allCases {
            let tableColumn = NSTableColumn()

            tableColumn.headerCell.title = column.title
            tableColumn.identifier = column.identifier
            tableColumn.minWidth = 30
            tableColumn.resizingMask = [.autoresizingMask, .userResizingMask]
            tableColumn.width = column.initialSize
            tableColumn.isHidden = !column.visibleByDefault
            tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: true)

            outlineView.addTableColumn(tableColumn)

            if column == BrowseViewColumn.title {
                outlineView.outlineTableColumn = tableColumn
            }

            let menuItem = NSMenuItem()

            menuItem.title = column.title
            menuItem.identifier = column.identifier
            menuItem.action = #selector(onToggleColumn(_:))

            columnsMenu.addItem(menuItem)
        }

        

        let dummyColumn = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("DummyTitleColumn"))!

        outlineView.removeTableColumn(dummyColumn)

        let databaseId = database.databaseUuid
        outlineView.autosaveName = String(format: "master-outlineview-columns-autosave-for-%@", databaseId)
        outlineView.autosaveTableColumns = true
        outlineView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        outlineView.headerView?.menu = columnsMenu
        outlineView.menu?.delegate = windowController
    }

    func bindSearchParameters() {
        scopeAllFields.selectedSegment = -1
        scopeTitle.selectedSegment = -1
        scopeUsername.selectedSegment = -1
        scopePassword.selectedSegment = -1
        scopeUrl.selectedSegment = -1
        scopeTags.selectedSegment = -1

        switch database.nextGenSearchScope {
        case .all:
            scopeAllFields.selectedSegment = 0
        case .title:
            scopeTitle.selectedSegment = 0
        case .username:
            scopeUsername.selectedSegment = 0
        case .password:
            scopePassword.selectedSegment = 0
        case .url:
            scopeUrl.selectedSegment = 0
        case .tags:
            scopeTags.selectedSegment = 0
        @unknown default:
            swlog("🔴 Unknown Scope!")
        }

        checkboxIncludeGroupsInSearch.state = database.nextGenSearchIncludeGroups ? .on : .off
    }

    @IBAction func onSearchIncludeGroupsChanged(_: Any) {
        database.nextGenSearchIncludeGroups = checkboxIncludeGroupsInSearch.state == .on

        bindSearchParameters()
    }

    @IBAction func onSearchScopeChanged(_ sender: Any) {
        guard let segmentControl = sender as? NSSegmentedControl else {
            return
        }

        if segmentControl == scopeAllFields {
            database.nextGenSearchScope = .all
        } else if segmentControl == scopeTitle {
            database.nextGenSearchScope = .title
        } else if segmentControl == scopeUsername {
            database.nextGenSearchScope = .username
        } else if segmentControl == scopePassword {
            database.nextGenSearchScope = .password
        } else if segmentControl == scopeUrl {
            database.nextGenSearchScope = .url
        } else if segmentControl == scopeTags {
            database.nextGenSearchScope = .tags
        }

        bindSearchParameters()
    }

    func listenToModelUpdateNotifications() {






        NotificationCenter.default.addObserver(forName: NSNotification.Name(kModelUpdateNotificationFullReload),
                                               object: nil, queue: nil)
        { [weak self] notification in
            self?.onDocumentUpdateNotificationReceived(notification)
        }

        NotificationCenter.default.addObserver(forName: .genericRefreshAllDatabaseViews, object: nil, queue: nil) { [weak self] notification in
            self?.onGenericRefreshNotificationReceived(notification)
        }

        
        let note = NSNotification.Name.auditCompleted
        let auditNotificationsOfInterest: [String] = [
            
            kAuditNewSwitchedOffNotificationKey,
            note.rawValue,
        ]

        for ofInterest in auditNotificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self else { return }
                self.onAuditUpdateNotification(notification)
            }
        }

        

        let notificationsOfInterest: [String] = [kModelUpdateNotificationItemsAdded,
                                                 kModelUpdateNotificationItemEdited,
                                                 kModelUpdateNotificationItemsDeleted,
                                                 kModelUpdateNotificationItemsUnDeleted,
                                                 kModelUpdateNotificationNextGenNavigationChanged,
                                                 kModelUpdateNotificationNextGenSearchContextChanged,
                                                 kModelUpdateNotificationIconChanged,
                                                 kModelUpdateNotificationDatabasePreferenceChanged,
                                                 kModelUpdateNotificationItemsMoved,
                                                 kModelUpdateNotificationItemReOrdered,
                                                 kModelUpdateNotificationTitleChanged,
                                                 kModelUpdateNotificationTagsChanged,
                                                 kModelUpdateNotificationNextGenSelectedItemsChanged,
                                                 kModelUpdateNotificationHistoryItemRestored,
                                                 kModelUpdateNotificationHistoryItemDeleted]

        for ofInterest in notificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self else {
                    return
                }

                self.onModelNotificationReceived(notification)
            }
        }

        NotificationCenter.default.addObserver(forName: .totpUpdate, object: nil, queue: nil) { [weak self] _ in
            self?.refreshOtpCodes()
        }
    }

    func onGenericRefreshNotificationReceived(_ notification: Notification) {
        if notification.object as? String != database.databaseUuid {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func onDocumentUpdateNotificationReceived(_ notification: Notification) {
        if notification.object as? NSDocument != database.document {
            return
        }


        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }

    func onAuditUpdateNotification(_ notification: Notification) {
        
        guard let dict = notification.object as? [String: Any], let model = dict["model"] as? Model else {
            swlog("🔴 Couldn't real model from notification")
            return
        }

        if model != database.commonModel {
            return
        }

        if notification.name.rawValue == kAuditNewSwitchedOffNotificationKey {
            swlog("✅ Browse::onAuditUpdateNotification [%@] - Audit Cleared Just switch off", String(describing: notification.name))
            refresh()
            return
        }

        if case .auditIssues = navigationContext {
            swlog("✅ Browse::onAuditUpdateNotification [%@]", String(describing: notification.name))

            refresh()
            return
        }

        guard let column = outlineView.tableColumn(withIdentifier: BrowseViewColumn.auditIssues.identifier) else {
            return
        }

        if column.isHidden {
            swlog("✅ Ignoring Audit Update Notificatoin Browse::onAuditUpdateNotification [%@]", String(describing: notification.name))
            return
        }

        if let _ = items.first(where: { node in
            database.isFlagged(byAudit: node.uuid)
        }) {
            swlog("✅ Browse::onAuditUpdateNotification [%@]", String(describing: notification.name))

            refresh()
        } else {
            swlog("✅ Ignoring Audit Update Notificatoin Browse::onAuditUpdateNotification [%@]", String(describing: notification.name))
        }
    }

    func onModelNotificationReceived(_ notification: Notification) {
        guard let notifyModel = notification.object as? ViewModel, notifyModel == database else {
            return
        }

        if notification.name == NSNotification.Name(kModelUpdateNotificationNextGenSelectedItemsChanged) {

            bindSelectionToModel(selectFirstItemIfSelectionNotFound: false)
        } else if notification.name == NSNotification.Name(kModelUpdateNotificationNextGenNavigationChanged) ||
            notification.name == NSNotification.Name(kModelUpdateNotificationNextGenSearchContextChanged) ||
            notification.name == NSNotification.Name(kModelUpdateNotificationItemsDeleted)
        {

            refresh(maintainSelectionIfPossible: true, selectFirstItemIfSelectionNotFound: true)
        } else {

            refresh()
        }
    }

    func getRowIndicesForItemIds(itemIds: [UUID]) -> IndexSet {
        let indices = items.enumerated().filter { elem in
            itemIds.contains(elem.element.uuid)
        }.map { element in
            element.offset
        }

        return IndexSet(indices)
    }

    func refresh(maintainSelectionIfPossible: Bool = true, selectFirstItemIfSelectionNotFound: Bool = false) {
        


        outlineView.beginUpdates()

        adjustHeightConstraintsWithAnimation() 

        outlineView.usesAlternatingRowBackgroundColors = database.showAlternatingRows

        if database.showVerticalGrid, database.showHorizontalGrid {
            outlineView.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        } else if database.showVerticalGrid {
            outlineView.gridStyleMask = [.solidVerticalGridLineMask]
        } else if database.showHorizontalGrid {
            outlineView.gridStyleMask = [.solidHorizontalGridLineMask]
        } else {
            outlineView.gridStyleMask = []
        }

        loadAndSortItems()
        outlineView.reloadData()

        outlineView.endUpdates()

        refreshSearchResultsSummaryText()

        if maintainSelectionIfPossible {
            bindSelectionToModel(selectFirstItemIfSelectionNotFound: selectFirstItemIfSelectionNotFound)
        }





    }

    func refreshSearchResultsSummaryText() {
        if let image = NSImage(systemSymbolName: "magnifyingglass.circle.fill", accessibilityDescription: nil) {
            let largeConfig = NSImage.SymbolConfiguration(scale: .large)
            let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: items.count == 0 ? .secondaryLabelColor : .systemGreen)

            let config = largeConfig.applying(colorConfig)

            let imageLarge = image.withSymbolConfiguration(config)

            imageViewSearchSummary.image = imageLarge
        }

        if items.count == 1 {
            labelSearchSummary.stringValue = NSLocalizedString("search_results_summary_1_match_found", comment: "1 Match Found")
            imageViewSearchSummary.contentTintColor = .systemGreen
        } else if items.count > 1 {
            labelSearchSummary.stringValue = String(format: NSLocalizedString("search_results_summary_n_match_found_fmt", comment: "%@ Matches Found"), String(items.count))
            imageViewSearchSummary.contentTintColor = .systemGreen
        } else {
            labelSearchSummary.stringValue = NSLocalizedString("search_results_summary_no_matches_found", comment: "No Matches Found")
            imageViewSearchSummary.contentTintColor = .secondaryLabelColor
        }
    }

    func bindSelectionToModel(selectFirstItemIfSelectionNotFound: Bool = false) {
        let selected = database.nextGenSelectedItems
        let selectedIndices = getRowIndicesForItemIds(itemIds: selected)



        if selectedIndices.isEmpty {
            if items.count == 0 {

                database.nextGenSelectedItems = [] 
            } else if selectFirstItemIfSelectionNotFound {

                outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) 
            }
        } else {

            outlineView.selectRowIndexes(selectedIndices, byExtendingSelection: false)

            if let foo = selectedIndices.first {
                outlineView.scrollRowToVisible(foo) 
            }
        }
    }

    func convertSpecial(_ spec: OGNavigationSpecial) -> NavigationContext.SpecialNavigationItem {
        switch spec {
        case OGNavigationSpecialAllItems:
            return .allEntries
        default:
            swlog("🔴 Unhandled case of special")
            return .allEntries
        }
    }

    func sortNodes(_ unsorted: [Node]) -> [Node] {
        let objcItems = unsorted as NSArray



        let sorted = objcItems.sortedArray(options: .stable) { obj1, obj2 in
            guard let node1 = obj1 as? Node, let node2 = obj2 as? Node else {
                swlog("🔴 Node conversion issue")
                return .orderedSame
            }

            return compareNodes(node1, node2)
        }




        return sorted as? [Node] ?? []
    }

    func compareNodes(_ node1: Node, _ node2: Node) -> ComparisonResult {
        if outlineView.sortDescriptors.isEmpty {
            return compareNodes(node1, node2, .title, true)
        }

        for sortDescriptor in outlineView.sortDescriptors {
            let col = BrowseViewColumn(rawValue: sortDescriptor.key!) ?? .title
            let ascending = sortDescriptor.ascending

            let result = compareNodes(node1, node2, col, ascending)

            if result != .orderedSame {
                return result
            } else {
                
            }
        }

        return .orderedSame
    }

    private func compareNodes(_ node1: Node, _ node2: Node, _ column: BrowseViewColumn, _ ascending: Bool) -> ComparisonResult {
        switch column {
        case .title:
            return database.compareNodes(forSort: node1, node2: node2, field: .title, descending: !ascending, foldersSeparately: false)
        case .username:
            return database.compareNodes(forSort: node1, node2: node2, field: .username, descending: !ascending, foldersSeparately: false)
        case .password:
            return database.compareNodes(forSort: node1, node2: node2, field: .password, descending: !ascending, foldersSeparately: false)
        case .url:
            return database.compareNodes(forSort: node1, node2: node2, field: .url, descending: !ascending, foldersSeparately: false)
        case .email:
            return database.compareNodes(forSort: node1, node2: node2, field: .email, descending: !ascending, foldersSeparately: false)
        case .notes:
            return database.compareNodes(forSort: node1, node2: node2, field: .notes, descending: !ascending, foldersSeparately: false)
        case .created:
            return database.compareNodes(forSort: node1, node2: node2, field: .created, descending: !ascending, foldersSeparately: false)
        case .modified:
            return database.compareNodes(forSort: node1, node2: node2, field: .modified, descending: !ascending, foldersSeparately: false)
        case .expires:
            return compareDates(node1.fields.expires, node2.fields.expires, ascending: ascending)
        case .totp:
            let p1 = node1.fields.otpToken?.password ?? ""
            let p2 = node2.fields.otpToken?.password ?? ""
            return compareStrings(p1, p2, ascending: ascending)
        case .attachmentCount:
            return compareInts(node1.fields.attachments.count, node2.fields.attachments.count, ascending: ascending)
        case .customFieldCount:
            return compareInts(Int(node1.fields.customFields.count), Int(node2.fields.customFields.count), ascending: ascending)
        case .tags:
            let tagArray1: [String] = node1.fields.tags.allObjects as! [String]
            let t1 = tagArray1.joined(separator: ", ")
            let tagArray2: [String] = node2.fields.tags.allObjects as! [String]
            let t2 = tagArray2.joined(separator: ", ")
            return compareStrings(t1, t2, ascending: ascending)
        case .path:
            let path1 = database.getParentGroupPathDisplayString(node1)
            let path2 = database.getParentGroupPathDisplayString(node2)
            return compareStrings(path1, path2, ascending: ascending)
        case .historicalItemCount:
            let count1 = database.format == .passwordSafe ? node1.fields.passwordHistory.entries.count : node1.fields.keePassHistory.count
            let count2 = database.format == .passwordSafe ? node2.fields.passwordHistory.entries.count : node2.fields.keePassHistory.count
            return compareInts(count1, count2, ascending: ascending)
        case .customIcon:
            let str1 = localizedYesOrNoFromBool(node1.icon?.isCustom ?? false)
            let str2 = localizedYesOrNoFromBool(node2.icon?.isCustom ?? false)
            return compareStrings(str1, str2, ascending: ascending)
        case .uuid:
            return keePassStringIdFromUuid(ascending ? node1.uuid : node2.uuid).compare(keePassStringIdFromUuid(ascending ? node2.uuid : node1.uuid))
        case .auditIssues:
            let auditIssues1 = database.getQuickAuditAllIssuesVeryBriefSummary(forNode: node1.uuid)
            let auditIssues2 = database.getQuickAuditAllIssuesVeryBriefSummary(forNode: node2.uuid)

            return compareInts(auditIssues1.count, auditIssues2.count, ascending: ascending)
        case .customIconSize:
            let s1 = node1.icon?.estimatedStorageBytes ?? 0
            let s2 = node2.icon?.estimatedStorageBytes ?? 0

            return compareInts(Int(s1), Int(s2), ascending: ascending)
        case .size:
            let s1 = node1.estimatedSize
            let s2 = node2.estimatedSize

            return compareInts(Int(s1), Int(s2), ascending: ascending)
        }
    }

    func compareInts(_ int1: Int, _ int2: Int, ascending: Bool = true) -> ComparisonResult {
        let v1 = ascending ? int1 : int2
        let v2 = ascending ? int2 : int1

        return v1 > v2 ? .orderedDescending : (v1 == v2 ? .orderedSame : .orderedAscending)
    }

    func compareStrings(_ string1: String, _ string2: String, ascending: Bool = true) -> ComparisonResult {
        let v1 = ascending ? string1 : string2
        let v2 = ascending ? string2 : string1

        return finderStringCompare(v1, v2)
    }

    func compareDates(_ date1: Date?, _ date2: Date?, ascending: Bool = true) -> ComparisonResult {
        let v1 = ascending ? date2 : date1
        let v2 = ascending ? date1 : date2

        if v1 == nil, v2 == nil {
            return .orderedSame
        } else if v1 == nil {
            return .orderedAscending
        } else if v2 == nil {
            return .orderedDescending
        }

        return v1!.compare(v2!)
    }

    let ExpiredCellAlpha: CGFloat = 0.35
    func getTitleCell(node: Node) -> NSTableCellView {
        let cell = outlineView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! TitleAndIconCell

        let title = dereference(text: node.title, node: node)
        let icon = getIconForNode(node)
        let favourite = database.isFavourite(node.uuid)

        let possiblyDereferencedText = database.isDereferenceableText(node.title)
        let editable = !possiblyDereferencedText && !database.isEffectivelyReadOnly && !database.outlineViewTitleIsReadonly

        cell.setContent(title,
                        font: FontManager.shared.entryTitleFont,
                        editable: editable,
                        iconImage: icon,
                        showTrailingFavStar: favourite,
                        iconTintColor: .linkColor)
        { [weak self] text in
            self?.onTitleEdited(text, node: node)
        }

        return cell
    }

    func onTitleEdited(_ text: String, node: Node) {
        let trimmed = trim(text)
        if trimmed != node.title {
            database.setItemTitle(node, title: trimmed)
        }
    }

    func getDereferencedGenericCell(_ text: String, node: Node, concealable: Bool = false) -> NSTableCellView {
        getGenericCell(text, node: node, concealable: concealable, dereference: true)
    }

    func getUrlCell(_ text: String, node: Node) -> NSTableCellView {
        let cell = outlineView.makeView(withIdentifier: UrlCell.NibIdentifier, owner: nil) as! UrlCell

        let deref = dereference(text: text, node: node)

        cell.urlHyperLinkField.href = deref
        cell.urlHyperLinkField.onClicked = { [weak self] in
            self?.database.launchUrlString(deref)
        }

        return cell
    }

    func getGenericCell(_ text: String, node: Node? = nil, concealable: Bool = false, dereference: Bool = false, plainTextColor: NSColor? = nil) -> NSTableCellView {
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CustomFieldValueCellIdentifier"), owner: nil) as! CustomFieldTableCellView

        var deref = text

        if dereference {
            if let node {
                deref = self.dereference(text: text, node: node)
            } else {
                swlog("🔴 Dereferencing Requested but no Node provided.")
            }
        }

        let effectiveConcealable = concealable && !(deref.count == 0 && !database.concealEmptyProtectedFields)
        let concealed = effectiveConcealable && !(deref.count == 0 && !database.concealEmptyProtectedFields)

        cell.setContent(deref, concealable: effectiveConcealable, concealed: concealed, singleLine: true, plainTextColor: plainTextColor)

        return cell
    }

    func getPillsCell(_ items: [String], color: NSColor, backgroundColor: NSColor, icon: NSImage) -> NSTableCellView {
        let cell = outlineView.makeView(withIdentifier: SingleLinePillTableCellView.NibIdentifier, owner: nil) as! SingleLinePillTableCellView

        cell.setContent(items, color: color, backgroundColor: backgroundColor, icon: icon)

        return cell
    }

    func dereference(text: String, node: Node) -> String {
        database.dereference(text, node: node)
    }

    func getIconForNode(_ node: Node) -> IMAGE_TYPE_PTR {
        NodeIconHelper.getIconFor(node, predefinedIconSet: database!.keePassIconSet, format: database!.format, large: false)
    }

    func selectFirstItemIfAvailableForSearchResult() -> Bool {
        
        
        

        if items.count > 0 {
            outlineView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            return true
        }

        return false
    }

    func editSelectedOrJumpToGroup() {
        guard let uuid = database.nextGenSelectedItems.first, let node = database.getItemBy(uuid) else {
            swlog("⚠️ Could get selected item to edit")
            return
        }

        if node.isGroup {
            setModelNavigationContextWithViewNode(database, .regularHierarchy(node.uuid))
        } else {
            NSApplication.shared.sendAction(#selector(NextGenSplitViewController.onEditSelectedEntry(_:)), to: nil, from: self)
        }
    }

    @objc
    func onDeleteOrRecycleSelectedBrowseViewItems(_: Any?) {
        let selected = database.getItemsById(database.nextGenSelectedItems)

        var nextIdx: Int? = nil
        if let topIdx = outlineView.selectedRowIndexes.first {
            nextIdx = topIdx
        }

        windowController.onDeleteItems(selected) { [weak self] deletedOrRecycled in
            if deletedOrRecycled, let nextIdx, let self {
                if items.count == 0 {}
                else if nextIdx >= items.count {
                    outlineView.selectRowIndexes(IndexSet(integer: items.count - 1), byExtendingSelection: false)
                } else {
                    outlineView.selectRowIndexes(IndexSet(integer: nextIdx), byExtendingSelection: false)
                }
            }
        }
    }
}

extension BrowseViewController: NSMenuItemValidation, NSMenuDelegate {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {


        if menuItem.action == #selector(onDeleteOrRecycleSelectedBrowseViewItems) {
            
            
            
            
            
            
            
            
            
            







            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            

            
            
            
            
            
            
            
            

            
            

            return true
        } else if menuItem.action == #selector(onToggleColumn(_:)) {
            guard let id = menuItem.identifier else {
                return false
            }

            guard let tableColumn = outlineView.tableColumn(withIdentifier: id) else {
                return false
            }

            menuItem.state = tableColumn.isHidden ? .off : .on

            return true
        } else {
            swlog("🔴 BrowseViewController::validateMenuItem Unknown Item - [%@] - %@", menuItem, String(describing: menuItem.action))
            return false
        }
    }
}

extension BrowseViewController: DocumentViewController {
    func onDocumentLoaded() {


        loadDocument()
    }

    fileprivate func setupInitialSortingConfiguration() {
        if outlineView.sortDescriptors.isEmpty { 
            swlog("🐞 BrowseViewController::setupInitialSortingConfiguration - Configuring initial sort mode as none currently set")
            outlineView.sortDescriptors.append(NSSortDescriptor(key: BrowseViewColumn.modified.rawValue, ascending: false))
        }
    }

    func loadDocument() {
        if loadedDocument {
            return
        }

        guard let doc = view.window?.windowController?.document as? Document else {
            swlog("MasterViewController::load Document not set!")
            return
        }

        database = doc.viewModel
        loadedDocument = true

        setupColumns()

        setupInitialSortingConfiguration()

        bindSearchParameters()

        outlineView.doubleAction = #selector(onOutlineViewDoubleClicked)
        outlineView.onEnterKey = { [weak self] in
            guard let self else { return }
            self.editSelectedOrJumpToGroup()
        }
        outlineView.onDeleteKey = { [weak self] in
            guard let self else { return }
            self.onDeleteOrRecycleSelectedBrowseViewItems(nil)
        }

        

        refresh() 

        outlineView.delegate = self
        outlineView.dataSource = self

        bindSelectionToModel(selectFirstItemIfSelectionNotFound: true) 

        

        listenToModelUpdateNotifications()
    }
}

extension BrowseViewController: NSOutlineViewDelegate {
    func outlineViewSelectionDidChange(_: Notification) {
        let selectedUuids = items.enumerated().filter { index, _ in
            outlineView.selectedRowIndexes.contains(index)
        }.map { _, item in
            item.uuid
        }



        database.nextGenSelectedItems = selectedUuids
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? Node else {
            let cell = outlineView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! NSTableCellView
            cell.textField?.stringValue = "🔴 nil item"
            return cell
        }

        guard let tableColumn else {
            let cell = outlineView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! NSTableCellView
            cell.textField?.stringValue = "🔴 nil table column"
            return cell
        }

        let col = BrowseViewColumn(rawValue: tableColumn.identifier.rawValue)!

        let cell: NSTableCellView
        switch col {
        case .title:
            cell = getTitleCell(node: item)
        case .username:
            cell = getDereferencedGenericCell(item.fields.username, node: item)
        case .password:
            cell = getDereferencedGenericCell(item.fields.password, node: item, concealable: true)
        case .url:

            cell = getUrlCell(item.fields.url, node: item)
        case .email:
            cell = getDereferencedGenericCell(item.fields.email, node: item)
        case .notes:
            cell = getDereferencedGenericCell(item.fields.notes, node: item)
        case .created:
            cell = getGenericCell((item.fields.created! as NSDate).friendlyDateTimeString)
        case .modified:
            cell = getGenericCell((item.fields.modified! as NSDate).friendlyDateTimeString)
        case .expires:
            cell = getGenericCell((item.fields.expires as NSDate?)?.friendlyDateTimeString ?? "")
        case .totp:
            cell = getTotpCell(item)
        case .attachmentCount:
            cell = getGenericCell(String(item.fields.attachments.count))
        case .customFieldCount:
            cell = getGenericCell(String(item.fields.customFields.count))
        case .tags:
            var tags = Set(item.fields.tags.allObjects as! [String])

            tags.remove(kCanonicalFavouriteTag) 

            let sorted = tags.sorted { a, b in
                compareStrings(a, b) == .orderedAscending
            }

            cell = getPillsCell(sorted, color: .white, backgroundColor: .linkColor, icon: Icon.tag.image())
        case .path:
            let path = database.getParentGroupPathDisplayString(item)
            cell = getGenericCell(path)
        case .historicalItemCount:
            let count = database.format == .passwordSafe ? item.fields.passwordHistory.entries.count : item.fields.keePassHistory.count
            let str = String(count)
            cell = getGenericCell(str)
        case .customIcon:
            let str = localizedYesOrNoFromBool(item.icon?.isCustom ?? false)
            cell = getGenericCell(str, node: item)
        case .uuid:
            let str = keePassStringIdFromUuid(item.uuid)
            cell = getGenericCell(str, node: item)
        case .auditIssues:
            let issues = database.getQuickAuditAllIssuesVeryBriefSummary(forNode: item.uuid)
            let sorted = issues.sorted { a, b in
                compareStrings(a, b) == .orderedAscending
            }
            cell = getPillsCell(sorted, color: .white, backgroundColor: .orange, icon: Icon.auditShield.image())
        case .customIconSize:
            let str = item.icon == nil ? "" : friendlyMemorySizeString(Int64(item.icon!.estimatedStorageBytes))
            cell = getGenericCell(str, node: item)
        case .size:
            let str = friendlyMemorySizeString(Int64(item.estimatedSize))
            cell = getGenericCell(str, node: item)
        }

        cell.alphaValue = item.expired ? ExpiredCellAlpha : 1.0

        return cell
    }

    func getTotpCell(_ item: Node) -> NSTableCellView {
        if let otpToken = item.fields.otpToken {
            let remainingSeconds = otpToken.period - (NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: otpToken.period))
            let color: NSColor? = (remainingSeconds < 5) ? .systemRed : (remainingSeconds < 9) ? .systemOrange : nil

            return getGenericCell(otpToken.password, node: item, plainTextColor: color)
        } else {
            return getGenericCell("", node: item)
        }
    }

    var windowController: WindowController {
        view.window!.windowController as! WindowController
    }

    func outlineView(_: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        windowController.placeItems(on: pasteboard, items: items as! [Node])
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem _: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if let source = info.draggingSource as? NSOutlineView, source == outlineView {
            if database.isKeePass2Format, !database.sortKeePassNodes {
                guard index != NSOutlineViewDropOnItemIndex, let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(kDragAndDropInternalUti)) as? [String] else {
                    return []
                }

                let sourceItems = serializationIds.compactMap { database.getItemFromSerializationId($0) }
                guard sourceItems.count == 1 else { return [] }



                return [.move] 
            } else {
                return []
            }
        } else {
            swlog("validateDrop: External Source -%d", index)

            guard let _ = info.draggingPasteboard.data(forType: NSPasteboard.PasteboardType(kDragAndDropExternalUti)) else { return [] }

            if index == NSOutlineViewDropOnItemIndex { 
                return []
            } else {
                switch navigationContext {
                case .regularHierarchy:
                    return [.copy]
                case let .special(theSpecial):
                    switch theSpecial {
                    case .allEntries:
                        return [.copy]
                    default:
                        break
                    }
                default:
                    break
                }

                return []
            }
        }
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item _: Any?, childIndex index: Int) -> Bool {
        if let source = info.draggingSource as? NSOutlineView, source == outlineView {
            if database.isKeePass2Format, !database.sortKeePassNodes {
                guard index != NSOutlineViewDropOnItemIndex,
                      let serializationIds = info.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(kDragAndDropInternalUti)) as? [String]
                else {
                    return false
                }

                let sourceItems = serializationIds.compactMap { database.getItemFromSerializationId($0) }

                guard sourceItems.count == 1, let sourceItem = sourceItems.first else { return false }



                guard let sourceIdx = sourceItem.parent?.children.firstIndex(of: sourceItem) else { return false }
                let adjustedIdx = sourceIdx < index ? (index - 1) : index

                swlog("Browse validateDrop: REORDER of item - Source [%@] => index = [%d]", sourceItem.title, adjustedIdx)

                if database.reorderItem(sourceItem.uuid, idx: adjustedIdx) != -1 {
                    info.draggingPasteboard.clearContents()
                    return true
                }
            }

            return false
        } else {
            let destinationItemId: NodeIdentifier

            switch navigationContext {
            case let .regularHierarchy(group):
                destinationItemId = group
            case let .special(theSpecial):
                switch theSpecial {
                case .allEntries:
                    destinationItemId = database.rootGroup.uuid
                default:
                    swlog("🔴 Invalid Drop Destination - Navigation Context")
                    return false
                }
            default:
                swlog("🔴 Invalid Drop Destination - Navigation Context")
                return false
            }

            guard let destinationItem = database.getItemBy(destinationItemId) else {
                return false
            }

            return windowController.pasteItems(from: info.draggingPasteboard, destinationItem: destinationItem, internal: false, clear: true) != 0
        }
    }

    @objc func onOutlineViewDoubleClicked(_: Any) {
        guard outlineView.selectedRowIndexes.count == 1 else { return }

        let colIdx = outlineView.clickedColumn
        let rowIdx = outlineView.clickedRow

        guard colIdx != -1, rowIdx != -1, let _ = outlineView.item(atRow: rowIdx) as? Node, let column = outlineView.tableColumns[safe: colIdx], let col = BrowseViewColumn(rawValue: column.identifier.rawValue) else {
            return
        }

        guard let uuid = database.nextGenSelectedItems.first, let node = database.getItemBy(uuid) else {
            swlog("⚠️ Could get selected item to edit")
            return
        }

        if node.isGroup {
            editSelectedOrJumpToGroup()
        } else {
            switch col {
            case .username:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyUsername(_:)), to: nil, from: self)
            case .password:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyPassword(_:)), to: nil, from: self)
            case .url:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyUrl(_:)), to: nil, from: self)
            case .email:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyEmail(_:)), to: nil, from: self)
            case .notes:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyNotes(_:)), to: nil, from: self)
            case .totp:
                NSApplication.shared.sendAction(#selector(WindowController.onCopyTotp(_:)), to: nil, from: self)
            default:
                editSelectedOrJumpToGroup()
            }
        }
    }
}

extension BrowseViewController: NSOutlineViewDataSource {
    var items: [Node] {
        if sortedItemsCache == nil {
            swlog("🔴 BrowseViewController::Cache MISS!")
            loadAndSortItems()
        }

        return sortedItemsCache!
    }

    func reSortItems() {
        if sortedItemsCache != nil {
            sortedItemsCache = sortItems()
        } else {
            loadAndSortItems()
        }
    }

    func loadAndSortItems() {
        loadItems()
        sortedItemsCache = sortItems()
    }

    func loadItems() {


        if isSearching {
            unsorted = loadSearchItems()
        } else {
            switch navigationContext {
            case .none:
                unsorted = []
            case let .regularHierarchy(groupId):
                unsorted = loadHierarchyChildEntries(groupId)
            case let .tags(tag):
                unsorted = loadTagChildEntries(tag)
            case let .special(special):
                unsorted = loadSpecial(special)
            case let .auditIssues(category):
                unsorted = loadAuditIssues(category)
            case let .favourites(nodeId):
                unsorted = loadFavourites(nodeId)
            }
        }
    }

    func sortItems() -> [Node] {






        if case .regularHierarchy = navigationContext, database.isKeePass2Format, !database.sortKeePassNodes {
            if let sortDescriptor = outlineView.sortDescriptors.first,
               let col = BrowseViewColumn(rawValue: sortDescriptor.key!), col != .title
            {






                return sortNodes(unsorted)
            } else {
                return unsorted
            }
        } else {
            return sortNodes(unsorted)
        }
    }

    func loadFavourites(_ nodeId: NodeIdentifier) -> [Node] {
        guard let node = database.getItemBy(nodeId) else {
            swlog("🔴 could not find favourite: [%@]", String(describing: nodeId))
            return []
        }

        if node.isGroup {
            return node.childRecords
        } else {
            return [node]
        }
    }

    func loadSpecial(_ special: NavigationContext.SpecialNavigationItem) -> [Node] {
        switch special {
        case .allEntries:
            return loadAllEntries()
        case .expiredEntries:
            return loadExpired()
        case .nearlyExpiredEntries:
            return loadNearlyExpired()
        case .totpItems:
            return loadTotps()
        case .itemsWithAttachments:
            return loadAttachmentEntries()
        case .keeAgentSshKeyEntries:
            return loadKeeAgentSshKeyEntries()
        case .passkeys:
            return loadPasskeys()
        case .allFavourites:
            return loadAllFavourites()
        }
    }

    func loadAllEntries() -> [Node] {
        let mut = NSMutableArray(array: database.rootGroup.allChildRecords)

        return database.filterAndSort(forBrowse: mut,
                                      includeKeePass1Backup: false,
                                      includeRecycleBin: false,
                                      includeExpired: true,
                                      includeGroups: false,
                                      browseSortField: .none,
                                      descending: false,
                                      foldersSeparately: false)
    }

    func getItemsByUuid(_ ids: Set<NodeIdentifier>) -> [Node] {
        ids.compactMap { database.getItemBy($0) }
    }

    func loadAuditIssues(_ category: NavigationContext.AuditNavigationCategory) -> [Node] {
        guard let report = database.auditReport else {
            swlog("🔴 No Audit Report available - cannot load audit issues")
            return []
        }

        switch category {
        case .noPasswords:
            return getItemsByUuid(report.entriesWithNoPasswords)
        case .duplicated:
            return getItemsByUuid(report.entriesWithDuplicatePasswords)
        case .common:
            return getItemsByUuid(report.entriesWithCommonPasswords)
        case .similar:
            return getItemsByUuid(report.entriesWithSimilarPasswords)
        case .tooShort:
            return getItemsByUuid(report.entriesTooShort)
        case .pwned:
            return getItemsByUuid(report.entriesPwned)
        case .lowEntropy:
            return getItemsByUuid(report.entriesWithLowEntropyPasswords)
        case .twoFactorAvailable:
            return getItemsByUuid(report.entriesWithTwoFactorAvailable)
        case .allEntries:
            return getItemsByUuid(report.allEntries)
        case .excludedItems:
            return database.excludedFromAuditEntries
        }
    }

    func loadExpired() -> [Node] {
        database.expiredEntries
    }

    func loadNearlyExpired() -> [Node] {
        database.nearlyExpiredEntries
    }

    func loadTotps() -> [Node] {
        database.totpEntries
    }

    func loadAttachmentEntries() -> [Node] {
        database.attachmentEntries
    }

    func loadKeeAgentSshKeyEntries() -> [Node] {
        database.keeAgentSshKeyEntries
    }

    func loadPasskeys() -> [Node] {
        database.passkeyEntries
    }

    func loadAllFavourites() -> [Node] {
        database.favourites
    }

    func loadTagChildEntries(_ tag: String) -> [Node] {
        database.entries(withTag: tag)
    }

    func loadHierarchyChildEntries(_ parentGroup: UUID) -> [Node] {
        guard let group = database.getItemBy(parentGroup) else {
            swlog("🔴 Could not get regular hierarchy group in model [%@]", parentGroup.description)
            return []
        }

        if !group.isGroup {
            swlog("🔴 Regular hierarchy group is not a group!! [%@]", group)
            return []
        }

        let mut = NSMutableArray(array: group.childRecords)

        return database.filterAndSort(forBrowse: mut,
                                      includeKeePass1Backup: true,
                                      includeRecycleBin: true, 
                                      includeExpired: true,
                                      includeGroups: false,
                                      browseSortField: .none,
                                      descending: false,
                                      foldersSeparately: false)
    }

    func loadSearchItems() -> [Node] {


        let text = database.nextGenSearchText
        let scope = database.nextGenSearchScope

        let unsorted = database.search(text,
                                       scope: scope,
                                       dereference: true,
                                       includeKeePass1Backup: database.showRecycleBinInSearchResults,
                                       includeRecycleBin: database.showRecycleBinInSearchResults,
                                       includeExpired: true,
                                       includeGroups: database.nextGenSearchIncludeGroups,
                                       browseSortField: .none,
                                       descending: false,
                                       foldersSeparately: false)

        return unsorted
    }

    func outlineView(_: NSOutlineView, isItemExpandable _: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {




        if let firstDes = outlineView.sortDescriptors.first,
           let col = BrowseViewColumn(rawValue: firstDes.key!),
           col == .title,
           case .regularHierarchy = navigationContext, database.isKeePass2Format, !database.sortKeePassNodes
        {
            if let prevFirstDes = oldDescriptors.first,
               firstDes.key == prevFirstDes.key
            {
                swlog("✅ Title column sort clicked again")

                MacAlerts.info(NSLocalizedString("browse_cannot_sort_by_title_title", comment: "Cannot Sort"),
                               informativeText: NSLocalizedString("browse_cannot_sort_by_title_message", comment: "You cannot sort by Title here because you have disabled sorting in Database Settings."),
                               window: view.window,
                               completion: nil)

                return
            }
        }

        reSortItems()
        outlineView.reloadData()



    }

    func outlineView(_: NSOutlineView, numberOfChildrenOfItem _: Any?) -> Int {


        items.count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem _: Any?) -> Any {


        items[index]
    }

    func refreshOtpCodes() {
        guard let tableColumn = outlineView.tableColumn(withIdentifier: BrowseViewColumn.totp.identifier) else {
            return
        }

        if !tableColumn.isHidden {
            guard let scrollView = outlineView.enclosingScrollView else { return }

            let visibleRect = scrollView.contentView.visibleRect
            let rowRange = outlineView.rows(in: visibleRect)
            let totpColumnIndex = outlineView.column(withIdentifier: BrowseViewColumn.totp.identifier)

            if rowRange.length > 0 {
                outlineView.beginUpdates()

                for i in 0 ... rowRange.length {
                    guard let item = outlineView.item(atRow: rowRange.location + i) as? Node else { continue }

                    if item.fields.otpToken != nil {
                        outlineView.reloadData(forRowIndexes: IndexSet(integer: rowRange.location + i), columnIndexes: IndexSet(integer: totpColumnIndex))
                    }
                }

                outlineView.endUpdates()
            }
        }
    }
}

extension BrowseViewController {
    var isSearching: Bool {
        guard let database else { return false }

        let text = database.nextGenSearchText

        return !text.isEmpty
    }

    var navigationContext: NavigationContext {
        getNavContextFromModel(database)
    }
}
