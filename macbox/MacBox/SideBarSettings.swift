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

    override func viewDidLoad() {
        super.viewDidLoad()

        bindUI()
    }

    func bindUI() {
        let headerNodes = model.headerNodes

        checkboxFavourites.state = headerNodes.contains { $0.header == kHeaderNodeFavourites } ? .on : .off
        checkboxHierarchy.state = headerNodes.contains { $0.header == kHeaderNodeRegularHierarchy } ? .on : .off
        checkboxTags.state = headerNodes.contains { $0.header == kHeaderNodeTags } ? .on : .off
        checkboxAuditIssues.state = headerNodes.contains { $0.header == kHeaderNodeAuditIssues } ? .on : .off
        checkboxQuickViews.state = headerNodes.contains { $0.header == kHeaderNodeSpecial } ? .on : .off
    }

    @IBAction func onFavouritesChanged(_ sender: Any) {
        let show = checkboxFavourites.state == .on

        showOrHideItem(show: show, item: kHeaderNodeFavourites, preferredInsertionIdx: 0)
    }

    @IBAction func onChanged(_ sender: Any) {
        let show = checkboxHierarchy.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeFavourites }
        let idx = favIdx != nil ? favIdx! + 1 : -1

        showOrHideItem(show: show, item: kHeaderNodeRegularHierarchy, preferredInsertionIdx: idx)
    }

    @IBAction func onTagsChanged(_ sender: Any) {
        let show = checkboxTags.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeRegularHierarchy }
        let idx = favIdx != nil ? favIdx! + 1 : -1

        showOrHideItem(show: show, item: kHeaderNodeTags, preferredInsertionIdx: idx)
    }

    @IBAction func onAuditIssuesChanged(_ sender: Any) {
        let show = checkboxAuditIssues.state == .on

        let headerNodes = model.headerNodes
        let favIdx = headerNodes.firstIndex { $0.header == kHeaderNodeSpecial }
        let idx = favIdx != nil ? favIdx! : -1

        showOrHideItem(show: show, item: kHeaderNodeAuditIssues, preferredInsertionIdx: idx)
    }

    @IBAction func onQuickViewsChanged(_ sender: Any) {
        let show = checkboxQuickViews.state == .on

        showOrHideItem(show: show, item: kHeaderNodeSpecial )
    }

    func showOrHideItem(show: Bool, item: HeaderNode, preferredInsertionIdx: Int = -1) {
        var headerNodes = model.headerNodes

        if show {
            guard !headerNodes.contains(where: { $0.header == item }) else {
                NSLog("🔴 Item Turned On but already on!")
                return
            }

            if preferredInsertionIdx > -1, preferredInsertionIdx <= headerNodes.count {
                headerNodes.insert(HeaderNodeState(header: item, expanded: true), at: preferredInsertionIdx)
            }
            else {
                headerNodes.append(HeaderNodeState(header: item, expanded: true))
            }
        }
        else {
            guard let nodeIdx = headerNodes.firstIndex(where: { $0.header == item }) else {
                NSLog("🔴 Item Turned Off but not found!")
                return
            }

            headerNodes.remove(at: nodeIdx)
        }

        model.headerNodes = headerNodes

        bindUI()
    }
}
