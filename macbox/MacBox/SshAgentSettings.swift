//
//  SshAgentSettings.swift
//  MacBox
//
//  Created by Strongbox on 27/05/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

let template = """
        Host *
           IdentityAgent %@
        """

class SshAgentSettings: NSViewController {
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var checkboxRunSshAgent: NSButton!
    @IBOutlet weak var stackSymLink: NSStackView!
    @IBOutlet weak var stackErrorLaunching: NSStackView!
    
    @IBOutlet weak var onLearnMore: ClickableTextField!
    
    @IBOutlet weak var comboExpiry: NSPopUpButton!
    @IBOutlet weak var labelHeaderConfig: NSTextField!
    @IBOutlet weak var labelSymlnkBody: NSTextField!
    @IBOutlet weak var buttonCreateSymlink: NSButton!
    @IBOutlet weak var labelSnippetText: NSTextField!
    @IBOutlet weak var buttonCopySnippet: NSButton!
    
    @IBOutlet weak var stackViewApprovals: NSStackView!
    
    @IBAction func onSetExpiry(_ sender: Any) {
        let idx = comboExpiry.indexOfSelectedItem
        
        var hours : Int = -1
        if idx == 0 {
            hours = 4
        }
        else if idx == 1 {
            hours = 12
        }
        else if idx == 2 {
            hours = 24
        }

        Settings.sharedInstance().sshAgentApprovalDefaultExpiryMinutes = hours == -1 ? -1 : hours * 60
        
        bindUi()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        comboExpiry.menu?.removeAllItems()

        let fmt = NSLocalizedString("generic_for_n_hours_suffix_fmt", comment: "for %@ hours")
        
        comboExpiry.menu?.addItem(withTitle: String(format: fmt, "4"), action: nil, keyEquivalent: "")
        comboExpiry.menu?.addItem(withTitle: String(format: fmt, "12"), action: nil, keyEquivalent: "")
        comboExpiry.menu?.addItem(withTitle: String(format: fmt, "24"), action: nil, keyEquivalent: "")
        
        comboExpiry.menu?.addItem(withTitle: NSLocalizedString("ssh_agent_remember_approval_until_strongbox_quits", comment: "until Strongbox quits"), action: nil, keyEquivalent: "")
    
        guard let scrollView = textView.enclosingScrollView, let textContainer = textView.textContainer else {
            return
        }
        
        scrollView.hasHorizontalScroller = true
        textView.isHorizontallyResizable = true
        textContainer.widthTracksTextView = false
        scrollView.autohidesScrollers = false
        
        let infiniteSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = infiniteSize
        textContainer.size = infiniteSize
        
        onLearnMore.onClick = {
            NSWorkspace.shared.open(URL(string: "https:
        }
        
        bindUi()
    }
    
    override func viewDidAppear() {
        bindUi()
    }
    
    @IBAction func onCreateSymLink(_ sender: Any) {
        MacAlerts.info("Save Symlink", 
                       informativeText: "Strongbox needs file permissions to create the Symlink.\n\nPlease click 'Save' on the following Save Panel.", 
                       window: view.window ) { [weak self] in
            SSHAgentServer.sharedInstance().createSymLink()
            self?.bindUi()
        }
    }
    
    @IBAction func onToggleSshAgent(_ sender: Any) {
        let settings = Settings.sharedInstance();
        
        settings.runSshAgent = checkboxRunSshAgent.state == .on
        if settings.runSshAgent && settings.isPro {
            if !SSHAgentServer.sharedInstance().start() {
                NSLog("🔴 Could not start SSH Agent")
            }
        }
        else {
            SSHAgentServer.sharedInstance().stop();
            
            SSHAgentRequestHandler.shared.clearAllOfflinePublicKeys()
        }
        
        bindUi()
    }
    
    @IBAction func onCopySnippet(_ sender: Any) {
        ClipboardManager.sharedInstance().copyNoneConcealedString(textView.string)
    }

    func bindUi() {
        if let socketPath = SSHAgentServer.sharedInstance().socketPathForSshConfig {
            textView.string = String(format: template, socketPath)
        }
        else {
            textView.string = "<Error retrieving Socket Path>"
        }
        
        stackSymLink.isHidden = true 
        
        let settings = Settings.sharedInstance()
        
        checkboxRunSshAgent.state = (settings.runSshAgent && settings.isPro) ? .on : .off
        
        stackErrorLaunching.isHidden = !(settings.runSshAgent && settings.isPro && !SSHAgentServer.sharedInstance().isRunning)
        
        stackViewApprovals.isHidden = !(settings.runSshAgent && settings.isPro && SSHAgentServer.sharedInstance().isRunning)
        
        checkboxRunSshAgent.isEnabled = settings.isPro
        
        let mins = settings.sshAgentApprovalDefaultExpiryMinutes
        
        if ( mins == -1 ) {
            comboExpiry.selectItem(at: 3)
        }
        else {
            var idx = 0
            let hours = mins / 60
            
            if hours == 4 {
                idx = 0
            }
            else if hours == 12 {
                idx = 1
            }
            else {
                idx = 2
            }
            
            comboExpiry.selectItem(at: idx)
        }
        
        labelHeaderConfig.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        labelSymlnkBody.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        labelSnippetText.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        
        buttonCreateSymlink.isEnabled = (settings.runSshAgent && settings.isPro)
        buttonCopySnippet.isEnabled = (settings.runSshAgent && settings.isPro)
        textView.textColor = (settings.runSshAgent && settings.isPro) ? .systemGreen : .secondaryLabelColor
        textView.isSelectable = settings.isPro
        


        
    }
}
