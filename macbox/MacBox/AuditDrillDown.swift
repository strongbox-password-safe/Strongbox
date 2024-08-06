//
//  AuditDrillDown.swift
//  MacBox
//
//  Created by Strongbox on 09/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AuditDrillDown: NSViewController {
    var uuid: UUID!
    var database: ViewModel!
    var duplicated: [Node] = []

    @IBOutlet var checkboxAuditItem: NSButton!
    @IBOutlet var tableDupes: NSTableView!
    @IBOutlet var duplicatesStack: NSStackView!

    @IBOutlet var dupesHeightConstraint: NSLayoutConstraint!

    @IBOutlet var icon: NSImageView!
    @IBOutlet var summaryItemsStack: NSStackView!
    class func fromStoryboard() -> Self {
        let sb = NSStoryboard(name: NSStoryboard.Name("AuditDrillDown"), bundle: nil)
        return sb.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        icon.image = Icon.auditShield.image()
        icon.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)

        let issueSummaries = database.getQuickAuditAllIssuesSummary(forNode: uuid)

        for subview in summaryItemsStack.arrangedSubviews {
            summaryItemsStack.removeView(subview)
        }

        for issueSummary in issueSummaries {
            let label = NSTextField()

            label.stringValue = String(format: "• %@", issueSummary)
            label.usesSingleLineMode = true
            label.isEditable = false
            label.font = FontManager.shared.bodyFont
            label.isBordered = false
            label.backgroundColor = .clear
            label.textColor = .labelColor

            summaryItemsStack.addView(label, in: .top)
        }

        

        if database.isExcluded(fromAudit: uuid) {
            let label = NSTextField()

            label.stringValue = String(format: "• %@", NSLocalizedString("audit_status_item_is_exluded", comment: "Item is excluded from Audits"))
            label.usesSingleLineMode = true
            label.isEditable = false
            label.font = FontManager.shared.bodyFont
            label.isBordered = false
            label.backgroundColor = .clear
            label.textColor = .labelColor

            summaryItemsStack.addView(label, in: .top)
        }

        let dupes = database.getDuplicatedPasswordNodeSet(uuid)
        let sims = database.getSimilarPasswordNodeSet(uuid)

        let both = dupes.union(sims)

        if both.count == 0 {
            duplicatesStack.isHidden = true
        } else {
            let unsorted = Array(both) as NSArray
            let sorted = unsorted.sortedArray(comparator: finderStyleNodeComparator) as! [Node]
            duplicated = sorted
        }

        checkboxAuditItem.state = database.isExcluded(fromAudit: uuid) ? .off : .on

        tableDupes.enclosingScrollView?.borderType = .noBorder
        tableDupes.backgroundColor = .clear

        tableDupes.register(NSNib(nibNamed: TitleAndIconCell.NibIdentifier.rawValue, bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)
        tableDupes.dataSource = self
        tableDupes.delegate = self

        let height = tableDupes.fittingSize.height
        dupesHeightConstraint.constant = min(200, height + 32)

        preferredContentSize = view.fittingSize

        checkboxAuditItem.isEnabled = !database.isEffectivelyReadOnly
    }

    @IBAction func onAuditThisItem(_: Any) {
        let exclude = checkboxAuditItem.state == .off

        guard let node = database.getItemBy(uuid) else { return }

        database.setItemAuditExclusion(node, exclude: exclude, isPartOfBatch: false)

        checkboxAuditItem.state = database.isExcluded(fromAudit: uuid) ? .off : .on
    }

    @IBAction func onPreferences(_: Any) {
        let vc = DatabaseSettingsTabViewController.fromStoryboard()

        vc.setModel(database, initialTab: .audit)

        presentingViewController?.presentAsSheet(vc)
    }
}

extension AuditDrillDown: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        duplicated.count
    }
}

extension AuditDrillDown: NSTableViewDelegate {
    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let node = duplicated[row]
        return getTitleCell(node: node)
    }

    func getTitleCell(node: Node) -> NSTableCellView {
        let cell = tableDupes.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! TitleAndIconCell

        cell.setContent(dereference(text: node.title, node: node), iconImage: getIconForNode(node), iconTintColor: .systemBlue)




        return cell
    }

    func getIconForNode(_ node: Node) -> IMAGE_TYPE_PTR {
        NodeIconHelper.getIconFor(node, predefinedIconSet: database!.keePassIconSet, format: database!.format, large: false)
    }

    func dereference(text: String, node: Node) -> String {
        database.dereference(text, node: node)
    }
}
