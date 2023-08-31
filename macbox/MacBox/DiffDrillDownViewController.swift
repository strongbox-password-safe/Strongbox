//
//  DiffDrillDownViewController.swift
//  MacBox
//
//  Created by Strongbox on 05/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class DiffDrillDownViewController: NSViewController {
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "DrillDownDiff", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    @IBOutlet var tableView: NSTableView!

    var firstDatabase: DatabaseModel!
    var secondDatabase: DatabaseModel!
    var diffPair: MMcGPair<Node, Node>?
    var isCompareForMerge: Bool = false

    var diffs: MutableOrderedDictionary<NSString, NSString> = MutableOrderedDictionary()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self

        initializeDiffs()

        tableView.reloadData()
    }

    func initializeDiffs() {
        if let diffPair {
            diffs = DiffDrillDownDetailer.initializePairWiseDiffs(firstDatabase,
                                                                  secondDatabase: secondDatabase,
                                                                  diffPair: diffPair,
                                                                  isMergeDiff: isCompareForMerge)
        } else {
            diffs = DiffDrillDownDetailer.initializePropertiesDiff(firstDatabase, secondDatabase: secondDatabase, isMergeDiff: isCompareForMerge)
        }
    }
}

extension DiffDrillDownViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        Int(diffs.count)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let key = diffs.keys[row]

        if let tableColumn, tableColumn.identifier.rawValue == "DrillDownKeyColumn" {
            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DrillDownKeyCell"), owner: self) as! NSTableCellView

            cell.textField?.stringValue = key as String

            return cell
        } else {
            let value = diffs[key] ?? ""

            let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DrillDownValueCell"), owner: self) as! NSTableCellView

            cell.textField?.stringValue = value as String

            return cell
        }
    }
}
