//
//  WordListsController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class WordListsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onUpdated: (() -> Void)!
    @IBOutlet var tableView: NSTableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        setupPasswordGenerationUi()
    }

    func numberOfRows(in _: NSTableView) -> Int {
        sortedWordListKeys.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let result: NSCheckboxTableCellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CheckboxCell"), owner: self) as! NSCheckboxTableCellView
        let params = Settings.sharedInstance().passwordGenerationConfig
        let wordListKey = sortedWordListKeys[row]

        result.checkbox!.state = params.wordLists.contains(wordListKey) ? .on : .off

        let wl = PasswordGenerationConfig.wordListsMap()[wordListKey]
        result.checkbox!.title = wl!.name

        result.onClicked = { checked in
            swlog("%@ - %d", wordListKey, checked)

            let immutable = Settings.sharedInstance().passwordGenerationConfig.wordLists
            var set = immutable

            if checked {
                set.append(wordListKey)
            } else {
                if let index = set.firstIndex(of: wordListKey) {
                    if set.count > 1 { 
                        set.remove(at: index)
                    }
                }
            }

            let config = Settings.sharedInstance().passwordGenerationConfig
            config.wordLists = set
            Settings.sharedInstance().passwordGenerationConfig = config

            self.onUpdated()

            tableView.reloadData()
        }

        return result
    }

    var sortedWordListKeys: [String] = []
    func setupPasswordGenerationUi() {
        let wordlists = PasswordGenerationConfig.wordListsMap()

        sortedWordListKeys = wordlists.keys.sorted { a, b in
            let v1 = wordlists[a]?.name
            let v2 = wordlists[b]?.name

            return finderStringCompare(v1!, v2!) == .orderedAscending
        }

        tableView.register(NSNib(nibNamed: "CheckboxCell", bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: "CheckboxCell"))
        tableView.delegate = self
        tableView.dataSource = self
    }
}
