//
//  AuditExcludedItems.swift
//  MacBox
//
//  Created by Strongbox on 10/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AuditExcludedItems: NSViewController {
    var database: ViewModel!

    var excludedItems: [Node] = []

    @IBOutlet var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        excludedItems = database.excludedFromAuditEntries

        tableView.register(NSNib(nibNamed: TitleAndIconCell.NibIdentifier.rawValue, bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)

        tableView.delegate = self
        tableView.dataSource = self
    }
}

extension AuditExcludedItems: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        excludedItems.count
    }

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let node = excludedItems[row]
        return getTitleCell(node: node)
    }

    func getTitleCell(node: Node) -> NSTableCellView {
        let cell = tableView.makeView(withIdentifier: TitleAndIconCell.NibIdentifier, owner: self) as! TitleAndIconCell

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
