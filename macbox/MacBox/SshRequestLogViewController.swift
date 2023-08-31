//
//  SshRequestLogViewController.swift
//  MacBox
//
//  Created by Strongbox on 17/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class SshRequestLogViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var tableView: NSTableView!
    var datasource: [SSHAgentSignRequest] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(NSNib(nibNamed: NSNib.Name(GenericAutoLayoutTableViewCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier)

        datasource = SSHAgentRequestHandler.shared.signRequests.allObjects().reversed()

        tableView.dataSource = self
        tableView.delegate = self
    }

    func numberOfRows(in _: NSTableView) -> Int {
        datasource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier, owner: nil) as! GenericAutoLayoutTableViewCell

        guard let request = datasource[safe: row] else {
            return cell
        }

        if tableColumn?.identifier.rawValue == "Timestamp" {
            cell.title.stringValue = (request.timestamp as NSDate).friendlyDateTimeStringPrecise
        } else if tableColumn?.identifier.rawValue == "Process" {
            let processName = request.processName ?? NSLocalizedString("generic_unknown", comment: "Unknown")


            cell.title.stringValue = String(format: "%@", processName)
        } else if tableColumn?.identifier.rawValue == "Database" {
            let db = MacDatabasePreferences.getById(request.databaseUuid)
            cell.title.stringValue = db?.nickName ?? NSLocalizedString("generic_unknown", comment: "Unknown")
        } else if tableColumn?.identifier.rawValue == "Key" {
            let db = MacDatabasePreferences.getById(request.databaseUuid)
            cell.title.stringValue = NSLocalizedString("generic_unknown", comment: "Unknown")

            if let db, let unlocked = DatabasesCollection.shared.getUnlocked(uuid: db.uuid), let node = unlocked.getItemBy(request.nodeId) {
                cell.title.stringValue = node.title
            }
        } else {
            cell.title.stringValue = localizedYesOrNoFromBool(request.approved)
        }

        return cell
    }
}
