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
    @IBOutlet weak var checkboxRequireApproval: NSButton!
    
    @IBOutlet weak var labelHeaderConfig: NSTextField!
    @IBOutlet weak var labelSymlnkBody: NSTextField!
    @IBOutlet weak var buttonCreateSymlink: NSButton!
    @IBOutlet weak var labelSnippetText: NSTextField!
    @IBOutlet weak var buttonCopySnippet: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
    
    @IBAction func onRequireApproval(_ sender: Any) {
        let settings = Settings.sharedInstance();
        
        settings.requireApprovalSshAgent = checkboxRequireApproval.state == .on
        
        bindUi()
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
        
        checkboxRequireApproval.state = settings.requireApprovalSshAgent ? .on : .off
        
        checkboxRunSshAgent.isEnabled = settings.isPro
        checkboxRequireApproval.isEnabled = settings.runSshAgent && settings.isPro
        
        
        labelHeaderConfig.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        labelSymlnkBody.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        labelSnippetText.textColor = (settings.runSshAgent && settings.isPro) ? .labelColor : .secondaryLabelColor
        
        buttonCreateSymlink.isEnabled = (settings.runSshAgent && settings.isPro)
        buttonCopySnippet.isEnabled = (settings.runSshAgent && settings.isPro)
        textView.textColor = (settings.runSshAgent && settings.isPro) ? .systemGreen : .secondaryLabelColor
        textView.isSelectable = settings.isPro
    }
}
