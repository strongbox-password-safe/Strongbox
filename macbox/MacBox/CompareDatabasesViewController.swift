//
//  CompareDatabasesViewController.swift
//  MacBox
//
//  Created by Strongbox on 05/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
class CompareDatabasesViewController: NSViewController {
    @objc class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "CompareDatabases", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    @IBOutlet var tableView: NSTableView!

    @objc var isCompareForMerge: Bool = false
    @objc var isSyncInitiated: Bool = false

    @objc var firstModel: Model! 
    @objc var secondModel: DatabaseModel!
    @objc var secondModelTitle: String!
    @objc var onDone: ((_ mergeRequested: Bool, _ synchronize: Bool) -> Void)?

    @IBOutlet var buttonMergeSynchronize: NSButton!

    private var rows: [Row] = []

    @IBOutlet var labelFirstTitle: NSTextField!
    @IBOutlet var labelSecondTitle: NSTextField!
    @IBOutlet var stackViewDatabaseNames: NSStackView!
    @IBOutlet var buttonMerge: NSButton!
    @IBOutlet var labelTitle: NSTextField!
    @IBOutlet var buttonUpgrade: NSButton!

    var willBeAddedOrOnlyInSecond: [Node] = []
    var willBeChangedOrEdited: [MMcGPair<Node, Node>] = []
    var willChangeHistoryOrHasDifferentHistory: [Node] = []
    var willBeMovedOrDifferentLocation: [MMcGPair<Node, Node>] = []
    var willBeDeletedOrOnlyInFirst: [Node] = []

    var diffSummary: DiffSummary?

    private struct Row {
        enum RowType {
            case header
            case nonFunctional
            case summary
            case databaseProperties
            case onlyInSecond
            case edit
            case historyChange
            case moved
            case onlyInFirst
        }

        var type: RowType
        var text: String
        var icon: NSImage?
        var iconTintColor: NSColor?
        var dataIndex: Int = 0
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonUpgrade.isHidden = Settings.sharedInstance().isPro
        buttonMergeSynchronize.isHidden = true
        buttonMerge.isHidden = true

        if isCompareForMerge {
            labelTitle.stringValue = NSLocalizedString("diff_nav_title_comparison_title", comment: "Comparison Results")
            stackViewDatabaseNames.isHidden = true
        } else {
            labelFirstTitle.stringValue = firstModel.metadata.nickName
            labelSecondTitle.stringValue = secondModelTitle
        }

        tableView.register(NSNib(nibNamed: NSNib.Name(TitleAndIconCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.action = #selector(onTableViewClicked)

        macOSSpinnerUI.sharedInstance().show(NSLocalizedString("diff_progress_comparing", comment: "Comparing..."), viewController: self)

        DispatchQueue.global().async { [weak self] in
            macOSSpinnerUI.sharedInstance().dismiss()

            self?.diffSummary = self?.diff()

            self?.loadRows()

            DispatchQueue.main.async {
                self?.refresh()
            }
        }
    }

    func refresh() {
        tableView.reloadData()

        if isCompareForMerge {
            buttonMerge.isHidden = false 
            buttonMerge.title = (diffSummary?.diffExists ?? false) ? NSLocalizedString("generic_action_merge", comment: "Merge") : NSLocalizedString("generic_done", comment: "Done")
        } else {
            buttonMergeSynchronize.isHidden = false
            buttonMergeSynchronize.isEnabled = Settings.sharedInstance().isPro
        }
    }

    @objc func onTableViewClicked() {
        guard tableView.clickedRow != -1,
              let row = rows[safe: tableView.clickedRow],
              let view = tableView.view(atColumn: 0, row: tableView.clickedRow, makeIfNecessary: false)
        else {
            return
        }

        switch row.type {
        case .databaseProperties:
            if diffSummary!.databasePropertiesDifferent {
                showDrillDownForDiffPair(pair: nil, popoverView: view)
            }
        case .edit:
            guard let diffPair = willBeChangedOrEdited[safe: row.dataIndex] else { return }
            showDrillDownForDiffPair(pair: diffPair, popoverView: view)
        case .moved:
            guard let diffPair = willBeMovedOrDifferentLocation[safe: row.dataIndex] else { return }
            showDrillDownForDiffPair(pair: diffPair, popoverView: view)
        default: break
        }
    }

    func diff() -> DiffSummary {
        let summary = DatabaseDiffer.diff(firstModel.database, second: secondModel)

        

        let created = summary.onlyInSecond.compactMap { secondModel.getItemBy($0) }
        willBeAddedOrOnlyInSecond = firstModel.sortItems(forBrowse: created, browseSortField: .title, descending: false, foldersSeparately: true)

        

        let deleted = summary.onlyInFirst.compactMap { firstModel.getItemBy($0) }
        willBeDeletedOrOnlyInFirst = firstModel.sortItems(forBrowse: deleted, browseSortField: .title, descending: false, foldersSeparately: true)

        

        let history = summary.historicalChanges.compactMap { firstModel.getItemBy($0) }
        willChangeHistoryOrHasDifferentHistory = firstModel.sortItems(forBrowse: history, browseSortField: .title, descending: false, foldersSeparately: true)

        

        willBeChangedOrEdited = summary.edited.compactMap { obj in
            if let first = firstModel.getItemBy(obj), let second = secondModel.getItemBy(obj) {
                return MMcGPair(ofA: first, andB: second)
            }

            return nil
        }.sorted(by: { first, second in
            finderStringCompare(first.a.title, second.a.title) == .orderedAscending
        })

        

        willBeMovedOrDifferentLocation = summary.moved.compactMap { obj in
            if let first = firstModel.getItemBy(obj), let second = secondModel.getItemBy(obj) {
                return MMcGPair(ofA: first, andB: second)
            }

            return nil
        }.sorted(by: { first, second in
            finderStringCompare(first.a.title, second.a.title) == .orderedAscending
        })

        return summary
    }

    func loadRows() {
        guard let diffSummary else {
            return
        }

        rows.append(Row(type: .header, text: NSLocalizedString("diff_view_section_header_summary", comment: "Summary")))

        if !Settings.sharedInstance().isPro {
            rows.append(Row(type: .nonFunctional,
                            text: NSLocalizedString("generic_pro_feature_only_please_upgrade", comment: "Pro feature only. Please Upgrade."),
                            icon: NSImage(named: "star"),
                            iconTintColor: .systemYellow))
            return
        }

        let text: String
        if isCompareForMerge {
            if diffSummary.diffExists {
                text = String(format: NSLocalizedString("merge_result_will_lead_to_percentage_difference_fmt", comment: "Merge will lead to a %0.1f%% difference."), diffSummary.differenceMeasure * 100.0)
            } else {
                if isSyncInitiated {
                    text = NSLocalizedString("merge_result_databases_identical_sync_initiated", comment: "Merge OK. Tap Done to Continue.")
                } else {
                    text = NSLocalizedString("merge_result_databases_identical", comment: "No changes to merge into first.")
                }
            }
        } else {
            if diffSummary.diffExists {
                text = String(format: NSLocalizedString("diff_result_percentage_difference_fmt", comment: "Second database is %0.1f%% different."), diffSummary.differenceMeasure * 100.0)
            } else {
                text = NSLocalizedString("diff_result_databases_identical", comment: "Identical databases.")
            }
        }

        let progress = 1.0 - diffSummary.differenceMeasure
        let newRed = (1.0 - progress) * 1 + progress * 0
        let newGreen = (1.0 - progress) * 0 + progress * 1
        let newBlue = (1.0 - progress) * 0 + progress * 0
        let col = NSColor(red: newRed, green: newGreen, blue: newBlue, alpha: 1.0)

        rows.append(Row(type: .summary, text: text, icon: NSImage(named: "ok"), iconTintColor: col))

        

        if diffSummary.databasePropertiesDifferent {
            let text = isCompareForMerge ? NSLocalizedString("merge_result_databases_properties_will_change", comment: "Some database properties will change.") :
                NSLocalizedString("diff_result_databases_properties_different", comment: "Database properties are different.")

            rows.append(Row(type: .databaseProperties, text: text, icon: NSImage(named: "list")))
        }

        

        if willBeChangedOrEdited.count > 0 {
            let fmt = isCompareForMerge ? NSLocalizedString("diff_view_section_header_entry_will_be_changed_count_fmt", comment: "Will be Changed (%lu)") : NSLocalizedString("diff_view_section_header_entry_differences_fmt", comment: "Items with Differences (%lu)")
            let text = String(format: fmt, willBeChangedOrEdited.count)
            rows.append(Row(type: .header, text: text, icon: nil, dataIndex: 0))

            var index = 0
            for diffPair in willBeChangedOrEdited {
                let node = diffPair.a
                let title = dereference(text: node.title, node: node)
                let icon = getIconForNode(node)
                rows.append(Row(type: .edit, text: title, icon: icon, iconTintColor: .systemBlue, dataIndex: index))
                index = index + 1
            }
        }

        

        if willBeMovedOrDifferentLocation.count > 0 {
            let fmt = isCompareForMerge ? NSLocalizedString("diff_view_section_header_entry_will_be_moved_count_fmt", comment: "Will be Moved (%lu)") : NSLocalizedString("diff_view_section_header_items_in_different_loc_fmt", comment: "Items in Different Locations (%lu)")

            let text = String(format: fmt, willBeMovedOrDifferentLocation.count)
            rows.append(Row(type: .header, text: text, icon: nil, dataIndex: 0))

            var index = 0
            for diffPair in willBeMovedOrDifferentLocation {
                let node = diffPair.a
                let title = dereference(text: node.title, node: node)
                let icon = getIconForNode(node)
                rows.append(Row(type: .moved, text: title, icon: icon, iconTintColor: .systemBlue, dataIndex: index))
                index = index + 1
            }
        }

        
        

        

        if willChangeHistoryOrHasDifferentHistory.count > 0 {
            let fmt = isCompareForMerge ? NSLocalizedString("diff_view_section_header_entry_history_will_change_count_fmt", comment: "History will Change (%lu)") : NSLocalizedString("diff_view_section_header_historical_diffs_fmt", comment: "Items with Historical Differences (%lu)")

            let text = String(format: fmt, willChangeHistoryOrHasDifferentHistory.count)

            rows.append(Row(type: .header, text: text, icon: nil, dataIndex: 0))

            var index = 0
            for node in willChangeHistoryOrHasDifferentHistory {
                let title = dereference(text: node.title, node: node)
                let icon = getIconForNode(node)
                rows.append(Row(type: .historyChange, text: title, icon: icon, iconTintColor: .systemBlue, dataIndex: index))
                index = index + 1
            }
        }

        

        if willBeDeletedOrOnlyInFirst.count > 0 {
            let fmt = isCompareForMerge ? NSLocalizedString("diff_view_section_header_entry_will_be_deleted_count_fmt", comment: "Will be Deleted (%lu)") : NSLocalizedString("diff_view_section_header_only_in_first_fmt", comment: "Only in First Database (%lu)")

            let text = String(format: fmt, willBeDeletedOrOnlyInFirst.count)

            rows.append(Row(type: .header, text: text, icon: nil, dataIndex: 0))

            var index = 0
            for node in willBeDeletedOrOnlyInFirst {
                let title = dereference(text: node.title, node: node)
                let icon = getIconForNode(node)
                rows.append(Row(type: .onlyInFirst, text: title, icon: icon, iconTintColor: .systemBlue, dataIndex: index))
                index = index + 1
            }
        }

        

        if willBeAddedOrOnlyInSecond.count > 0 {
            let fmt = isCompareForMerge ? NSLocalizedString("diff_view_section_header_entry_will_be_added_count_fmt", comment: "Will be Added (%lu)") : NSLocalizedString("diff_view_section_header_only_in_second_fmt", comment: "Only in Second Database (%lu)")

            let text = String(format: fmt, willBeAddedOrOnlyInSecond.count)

            rows.append(Row(type: .header, text: text, icon: nil, dataIndex: 0))

            var index = 0
            for node in willBeAddedOrOnlyInSecond {
                let title = dereference(text: node.title, node: node)
                let icon = getIconForNode(node)
                rows.append(Row(type: .onlyInSecond, text: title, icon: icon, iconTintColor: .systemBlue, dataIndex: index))
                index = index + 1
            }
        }
    }

    func getIconForNode(_ node: Node) -> IMAGE_TYPE_PTR {
        NodeIconHelper.getIconFor(node, predefinedIconSet: firstModel.metadata.keePassIconSet, format: firstModel.originalFormat, large: false)
    }

    func showDrillDownForDiffPair(pair: MMcGPair<Node, Node>?, popoverView: NSView) {
        let vc = DiffDrillDownViewController.fromStoryboard()

        vc.firstDatabase = firstModel.database
        vc.secondDatabase = secondModel
        vc.diffPair = pair
        vc.isCompareForMerge = isCompareForMerge

        present(vc, asPopoverRelativeTo: NSZeroRect, of: popoverView, preferredEdge: .minY, behavior: .transient)
    }

    @IBAction func onCancel(_: Any) {
        dismiss(nil)
        onDone?(false, false)
    }

    @IBAction func onMerge(_: Any) {
        dismiss(nil)
        onDone?(true, false)
    }

    @IBAction func onMergeSynchronize(_: Any) {
        MacAlerts.twoOptions(withCancel: NSLocalizedString("compare_merge_merge_or_synchronize_title", comment: "Merge In or Synchronize?"),
                             informativeText: NSLocalizedString("compare_merge_merge_or_synchronize_message", comment: "A 'Merge In' merges changes into the first database only. A 'Synchronize' also updates the second database to match."),
                             option1AndDefault: NSLocalizedString("compare_merge_merge_or_synchronize_option_merge", comment: "Merge In Only (Update First)"),
                             option2: NSLocalizedString("compare_merge_merge_or_synchronize_option_synchronize", comment: "Synchronize (Update Both)"),
                             window: view.window)
        { [weak self] response in
            swlog("%d", response)

            self?.dismiss(nil)

            if response == 0 || response == 1 {
                self?.onDone?(true, response == 1)
            }
        }
    }

    @IBAction func onUpgrade(_: Any) {
        dismiss(nil)

        NSApplication.shared.sendAction(#selector(AppDelegate.onUpgradeToFullVersion(_:)), to: nil, from: self)
    }
}

extension CompareDatabasesViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
        let row = rows[row]

        return row.type == .header
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let row = rows[row]

        if row.type == .header {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "HeaderCell"), owner: self) as! NSTableCellView

            cell.imageView?.image = nil 
            cell.imageView?.isHidden = true
            cell.textField?.stringValue = row.text

            return cell
        } else {
            let cell = tableView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! TitleAndIconCell
            cell.setContent(row.text, iconImage: row.icon, iconTintColor: row.iconTintColor)
            return cell
        }
    }

    func dereference(text: String, node: Node) -> String {
        firstModel.dereference(text, node: node)
    }
}
