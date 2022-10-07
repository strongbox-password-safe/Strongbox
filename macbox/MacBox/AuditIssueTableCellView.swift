//
//  AuditIssueTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 09/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AuditIssueTableCellView: NSTableCellView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("AuditIssueTableCellView")
    static let nibName = NSNib.Name("AuditIssueTableCellView")

    @IBOutlet var icon: NSImageView!
    @IBOutlet var labelIssue: ClickableTextField!

    override func awakeFromNib() {
        super.awakeFromNib()

        icon.image = Icon.auditShield.image()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        labelIssue.onClick = nil
    }

    func setContent(_ issue: String, onClick: (() -> Void)? = nil) {
        if issue.count == 0 {
            labelIssue.stringValue = NSLocalizedString("audit_status_item_is_exluded", comment: "Item is excluded from Audits")
            icon.contentTintColor = .secondaryLabelColor
        } else {
            labelIssue.stringValue = issue
            icon.contentTintColor = .systemOrange
        }

        labelIssue.onClick = onClick
    }
}
