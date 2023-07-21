//
//  KeeAgentSshCellView.swift
//  MacBox
//
//  Created by Strongbox on 29/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class KeeAgentSshCellView: NSTableCellView {
    @IBOutlet weak var labelFilename: NSTextField!
    @IBOutlet weak var stackPassphrase: NSStackView!
    @IBOutlet weak var labelPassPhrase: NSTextField!
    @IBOutlet weak var imageViewPassphrase: NSImageView!
    
    @IBOutlet weak var labelKeyType: NSTextField!
    
    @IBOutlet weak var imageViewAgentStatus: NSImageView!
    @IBOutlet weak var labelSshAgentStatus: NSTextField!
    
    func setContent( _ field : DetailsViewField ) {
        guard let key = field.object as? KeeAgentSshKeyViewModel else {
            NSLog("Could not convert field into KeeAgentSshKeyViewModel")
            return
        }
        
        labelFilename.stringValue = key.filename
        stackPassphrase.isHidden = !key.openSshKey.isPassphraseProtected
        
        if ( key.openSshKey.isPassphraseProtected) {
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
