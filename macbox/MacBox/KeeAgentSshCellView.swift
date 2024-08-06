//
//  KeeAgentSshCellView.swift
//  MacBox
//
//  Created by Strongbox on 29/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class KeeAgentSshCellView: NSTableCellView {
    @IBOutlet var labelFilename: NSTextField!
    @IBOutlet var stackPassphrase: NSStackView!
    @IBOutlet var labelPassPhrase: NSTextField!
    @IBOutlet var imageViewPassphrase: NSImageView!

    @IBOutlet var labelKeyType: NSTextField!

    @IBOutlet var imageViewAgentStatus: NSImageView!
    @IBOutlet var labelSshAgentStatus: NSTextField!

    func setContent(_ field: DetailsViewField) {
        guard let key = field.object as? KeeAgentSshKeyViewModel else {
            swlog("Could not convert field into KeeAgentSshKeyViewModel")
            return
        }

        labelFilename.stringValue = key.filename
        stackPassphrase.isHidden = !key.openSshKey.isPassphraseProtected

        if key.openSshKey.isPassphraseProtected {
            let valid = key.openSshKey.validatePassphrase(field.value)

            labelPassPhrase.stringValue = valid ? NSLocalizedString("ssh_agent_passphrase_protected", comment: "Passphrase Protected") : NSLocalizedString("ssh_agent_passphrase_protected_incorrect", comment: "Passphrase Protected (Entry Password Incorrect)")

            labelPassPhrase.textColor = valid ? .labelColor : .systemOrange
            imageViewPassphrase.contentTintColor = valid ? .labelColor : .systemOrange
        }

        labelKeyType.stringValue = key.openSshKey.type

        labelSshAgentStatus.stringValue = key.enabled ? NSLocalizedString("ssh_agent_key_enabled_for_agent", comment: "Enabled for SSH Agent") : NSLocalizedString("ssh_agent_disabled_for_agent", comment: "Disabled for SSH Agent")

        imageViewAgentStatus.contentTintColor = key.enabled ? .systemGreen : .secondaryLabelColor
    }
}
