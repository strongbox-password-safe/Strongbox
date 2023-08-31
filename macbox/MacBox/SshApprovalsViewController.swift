//
//  SshApprovalsViewController.swift
//  MacBox
//
//  Created by Strongbox on 17/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class SshApprovalsViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet var tableView: NSTableView!

    var datasource: [SSHAgentApproval] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(NSNib(nibNamed: NSNib.Name(GenericAutoLayoutTableViewCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier)

        datasource = SSHAgentRequestHandler.shared.approvals

        tableView.dataSource = self
        tableView.delegate = self
    }

    func numberOfRows(in _: NSTableView) -> Int {
        datasource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier, owner: nil) as! GenericAutoLayoutTableViewCell

        guard let approval = datasource[safe: row] else {
            return cell
        }

        if tableColumn?.identifier.rawValue == "Process" {
            cell.title.stringValue = String(format: "%@", approval.processName)
        } else {
            if case let .timed(time: timestamp) = approval.expiry {
                cell.title.stringValue = (timestamp as NSDate).friendlyDateTimeStringPrecise
            } else {
                cell.title.stringValue = NSLocalizedString("ssh_agent_remember_approval_until_strongbox_quits", comment: "until Strongbox quits")
            }
        }

        return cell
    }
}
