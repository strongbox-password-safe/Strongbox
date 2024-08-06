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
    @IBOutlet var checkboxRunSshAgent: NSButton!
    @IBOutlet var stackSymLink: NSStackView!
    @IBOutlet var stackErrorLaunching: NSStackView!
    @IBOutlet var onLearnMore: ClickableTextField!
    @IBOutlet var comboExpiry: NSPopUpButton!
    @IBOutlet var labelHeaderConfig: NSTextField!
    @IBOutlet var labelSymlnkBody: NSTextField!
    @IBOutlet var buttonCreateSymlink: NSButton!
    @IBOutlet var labelSnippetText: NSTextField!
    @IBOutlet var buttonCopySnippet: NSButton!
    @IBOutlet var stackViewApprovals: NSStackView!
    @IBOutlet var checkboxPreventRapidUnlocks: NSButton!
    @IBOutlet var checkboxAllowUnlockRequests: NSButton!

    @IBAction func onSetExpiry(_: Any) {
        let idx = comboExpiry.indexOfSelectedItem

        var hours: Int = -1
        if idx == 0 {
            hours = 4
        } else if idx == 1 {
            hours = 12
        } else if idx == 2 {
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

        NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: nil) { [weak self] _ in
            self?.bindUi()
        }

        bindUi()
    }

    override func viewDidAppear() {
        bindUi()
    }

    @IBAction func onCreateSymLink(_: Any) {
        MacAlerts.info("Save Symlink", 
                       informativeText: "Strongbox needs file permissions to create the Symlink.\n\nPlease click 'Save' on the following Save Panel.", 
                       window: view.window)
        { [weak self] in
            SSHAgentServer.sharedInstance().createSymLink()
            self?.bindUi()
        }
    }

    @IBAction func onToggleSshAgent(_: Any) {
        let settings = Settings.sharedInstance()

        settings.runSshAgent = checkboxRunSshAgent.state == .on
        if settings.runSshAgent, settings.isPro {
            if !SSHAgentServer.sharedInstance().start() {
                swlog("🔴 Could not start SSH Agent")
            }
        } else {
            SSHAgentServer.sharedInstance().stop()

            SSHAgentRequestHandler.shared.clearAllOfflinePublicKeys()
        }

        bindUi()
    }

    @IBAction func onCopySnippet(_: Any) {
        ClipboardManager.sharedInstance().copyNoneConcealedString(textView.string)
    }

    @IBAction func onPreferenceChanged(_: Any) {
        Settings.sharedInstance().sshAgentRequestDatabaseUnlockAllowed = checkboxAllowUnlockRequests.state == .on

        Settings.sharedInstance().sshAgentPreventRapidRepeatedUnlockRequests = checkboxPreventRapidUnlocks.state == .on

        bindUi()
    }

    func bindUi() {
        if let socketPath = SSHAgentServer.sharedInstance().socketPathForSshConfig {
            textView.string = String(format: template, socketPath)
        } else {
            textView.string = "<Error retrieving Socket Path>"
        }

        stackSymLink.isHidden = true 

        let settings = Settings.sharedInstance()
        let pro = settings.isPro

        checkboxRunSshAgent.state = (settings.runSshAgent && pro) ? .on : .off

        stackErrorLaunching.isHidden = !(settings.runSshAgent && pro && !SSHAgentServer.sharedInstance().isRunning)

        stackViewApprovals.isHidden = !(settings.runSshAgent && pro && SSHAgentServer.sharedInstance().isRunning)

        checkboxRunSshAgent.isEnabled = pro

        let mins = settings.sshAgentApprovalDefaultExpiryMinutes

        if mins == -1 {
            comboExpiry.selectItem(at: 3)
        } else {
            var idx = 0
            let hours = mins / 60

            if hours == 4 {
                idx = 0
            } else if hours == 12 {
                idx = 1
            } else {
                idx = 2
            }

            comboExpiry.selectItem(at: idx)
        }

        labelHeaderConfig.textColor = (settings.runSshAgent && pro) ? .labelColor : .secondaryLabelColor
        labelSymlnkBody.textColor = (settings.runSshAgent && pro) ? .labelColor : .secondaryLabelColor
        labelSnippetText.textColor = (settings.runSshAgent && pro) ? .labelColor : .secondaryLabelColor

        buttonCreateSymlink.isEnabled = (settings.runSshAgent && pro)
        buttonCopySnippet.isEnabled = (settings.runSshAgent && pro)
        textView.textColor = (settings.runSshAgent && pro) ? .systemGreen : .secondaryLabelColor
        textView.isSelectable = pro



        checkboxAllowUnlockRequests.state = settings.sshAgentRequestDatabaseUnlockAllowed ? .on : .off
        checkboxPreventRapidUnlocks.state = settings.sshAgentPreventRapidRepeatedUnlockRequests ? .on : .off

        checkboxAllowUnlockRequests.isEnabled = pro
        checkboxPreventRapidUnlocks.isEnabled = pro
    }
}
