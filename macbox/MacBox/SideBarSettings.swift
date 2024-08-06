//
//  SideBarSettings.swift
//  MacBox
//
//  Created by Strongbox on 15/03/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class SideBarSettings: NSViewController {
    @objc
    var model: ViewModel!

    @IBOutlet var checkboxFavourites: NSButton!
    @IBOutlet var checkboxHierarchy: NSButton!
    @IBOutlet var checkboxTags: NSButton!
    @IBOutlet var checkboxAuditIssues: NSButton!
    @IBOutlet var checkboxQuickViews: NSButton!

    @IBOutlet var checkboxShowChildCounts: NSButton!
    @IBOutlet var checkboxShowDatabaeSummaryCount: NSButton!
    @IBOutlet var checkboxShowZeroCounts: NSButton!
    @IBOutlet var stackViewDisplayFormat: NSStackView!
    @IBOutlet var stackViewSeparator: NSStackView!
    @IBOutlet var stackViewGroupPrefix: NSStackView!

    @IBOutlet var popupDisplayFormat: NSPopUpButton!
    @IBOutlet var textFieldSeparator: NSTextField!
    @IBOutlet var textFieldGroupPrefix: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        populateChildCountFormatPopup()

        bindUI()
        bindChildCountUI()
    }

    func bindUI() {
        let headerNodes = model.headerNodes

        checkboxFavourites.state = headerNodes.contains { $0.header == kHeaderNodeFavourites } ? .on : .off
        checkboxHierarchy.state = headerNodes.contains { $0.header == kHeaderNodeRegularHierarchy } ? .on : .off
        checkboxTags.state = headerNodes.contains { $0.header == kHeaderNodeTags } ? .on : .off
        checkboxAuditIssues.state = headerNodes.contains { $0.header == kHeaderNodeAuditIssues } ? .on : .off
        checkboxQuickViews.state = headerNodes.contains { $0.header == kHeaderNodeSpecial } ? .on : .off
    }

    @IBAction func onFavouritesChanged(_: Any) {
        let show = checkboxFavourites.state == .on

        showOrHideItem(show: show, item: kHeaderNodeFavourites, preferredInsertionIdx: 0)
    }

    @IBAction func onChanged(_: Any) {
        let show = checkboxHierarchy.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeFavourites }
        let idx = favIdx != nil ? favIdx! + 1 : -1

        showOrHideItem(show: show, item: kHeaderNodeRegularHierarchy, preferredInsertionIdx: idx)
    }

    @IBAction func onTagsChanged(_: Any) {
        let show = checkboxTags.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeRegularHierarchy }
        let idx = favIdx != nil ? favIdx! + 1 : -1

        showOrHideItem(show: show, item: kHeaderNodeTags, preferredInsertionIdx: idx)
    }

    @IBAction func onAuditIssuesChanged(_: Any) {
        let show = checkboxAuditIssues.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeSpecial }
        let idx = favIdx != nil ? favIdx! : -1

        showOrHideItem(show: show, item: kHeaderNodeAuditIssues, preferredInsertionIdx: idx)
    }

    @IBAction func onQuickViewsChanged(_: Any) {
        let show = checkboxQuickViews.state == .on

        showOrHideItem(show: show, item: kHeaderNodeSpecial)
    }

    func showOrHideItem(show: Bool, item: HeaderNode, preferredInsertionIdx: Int = -1) {
        var headerNodes = model.headerNodes

        if show {
            guard !headerNodes.contains(where: { $0.header == item }) else {
                swlog("🔴 Item Turned On but already on!")
                return
            }

            if preferredInsertionIdx > -1, preferredInsertionIdx <= headerNodes.count {
                headerNodes.insert(HeaderNodeState(header: item, expanded: true), at: preferredInsertionIdx)
            } else {
                headerNodes.append(HeaderNodeState(header: item, expanded: true))
            }
        } else {
            guard let nodeIdx = headerNodes.firstIndex(where: { $0.header == item }) else {
                swlog("🔴 Item Turned Off but not found!")
                return
            }

            headerNodes.remove(at: nodeIdx)
        }

        model.headerNodes = headerNodes

        bindUI()
    }

    @IBAction func onClose(_: Any) {
        view.window?.cancelOperation(nil)
    }

    

    func populateChildCountFormatPopup() {
        popupDisplayFormat.menu?.removeAllItems()

        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_entries", comment: "Entries"), action: nil, keyEquivalent: "")
        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_entries_rec", comment: "Entries (Recursive)"), action: nil, keyEquivalent: "")
        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_groups_and_entries", comment: "Groups and Entries"), action: nil, keyEquivalent: "")
        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_groups_and_entries_rec", comment: "Groups and Entries (Recursive)"), action: nil, keyEquivalent: "")
        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_items", comment: "Items"), action: nil, keyEquivalent: "")
        popupDisplayFormat.menu?.addItem(withTitle: NSLocalizedString("side_bar_child_count_format_items_rec", comment: "Items (Recursive)"), action: nil, keyEquivalent: "")
    }

    func bindChildCountUI() {
        checkboxShowChildCounts.state = model.showChildCountOnFolderInSidebar ? .on : .off
        checkboxShowDatabaeSummaryCount.state = model.sideBarShowTotalCountOnHierarchy ? .on : .off
        checkboxShowZeroCounts.state = model.sideBarChildCountShowZero ? .on : .off

        textFieldSeparator.stringValue = model.sideBarChildCountSeparator
        textFieldGroupPrefix.stringValue = model.sideBarChildCountGroupPrefix

        popupDisplayFormat.selectItem(at: model.sideBarChildCountFormat.rawValue)

        checkboxShowZeroCounts.isHidden = !model.showChildCountOnFolderInSidebar
        stackViewDisplayFormat.isHidden = !model.showChildCountOnFolderInSidebar

        stackViewSeparator.isHidden = !model.showChildCountOnFolderInSidebar || !(model.sideBarChildCountFormat == .groupsAndEntries || model.sideBarChildCountFormat == .groupsAndEntriesRecursive)

        stackViewGroupPrefix.isHidden = !model.showChildCountOnFolderInSidebar || !(model.sideBarChildCountFormat == .groupsAndEntries || model.sideBarChildCountFormat == .groupsAndEntriesRecursive)
    }

    @IBAction func onChangeFormatPopup(_: Any) {
        model.sideBarChildCountFormat = SideBarChildCountFormat(rawValue: popupDisplayFormat.indexOfSelectedItem) ?? .entries

        bindChildCountUI()
    }

    @IBAction func onChildCountChanged(_: Any) {
        model.showChildCountOnFolderInSidebar = checkboxShowChildCounts.state == .on

        bindChildCountUI()
    }

    @IBAction func onShowSummaryChanged(_: Any) {
        model.sideBarShowTotalCountOnHierarchy = checkboxShowDatabaeSummaryCount.state == .on

        bindChildCountUI()
    }

    @IBAction func onShowZeroCountsChanged(_: Any) {
        model.sideBarChildCountShowZero = checkboxShowZeroCounts.state == .on

        bindChildCountUI()
    }

    @IBAction func onEditSeparator(_: Any) {
        guard let ret = MacAlerts().input(NSLocalizedString("mac_password_gen_enter_new_separator", comment: "Please Enter a New Word Separator"), defaultValue: model.sideBarChildCountSeparator, allowEmpty: true) else {
            return
        }

        model.sideBarChildCountSeparator = ret

        bindChildCountUI()
    }

    @IBAction func onEditGroupPrefix(_: Any) {
        guard let ret = MacAlerts().input(NSLocalizedString("mac_password_gen_enter_new_separator", comment: "Please Enter a New Word Separator"), defaultValue: model.sideBarChildCountGroupPrefix, allowEmpty: true) else {
            return
        }

        model.sideBarChildCountGroupPrefix = ret

        bindChildCountUI()
    }
}
