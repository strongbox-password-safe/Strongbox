//
//  GeneralPreferencesViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class GeneralPreferencesViewController: NSViewController {
    @IBOutlet var autoLockDatabase: NSButton!
    @IBOutlet var miniaturizeOnCopy: NSButton!
    @IBOutlet var autoClearClipboard: NSButton!
    @IBOutlet var shortcutView: MASShortcutView!
    @IBOutlet var autoClearClipboardTimeout: NSTextField!
    @IBOutlet var autoLockTimeoutTextField: NSTextField!
    @IBOutlet var stepperAutoClearClipboard: NSStepper!
    @IBOutlet var autoLockStepper: NSStepper!
    @IBOutlet var hideDockIcon: NSButton!
    @IBOutlet var showInSystemTray: NSButton!
    @IBOutlet var quitWhenAllClosed: NSButton!
    @IBOutlet weak var lockEvenIfEditing: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        shortcutView.associatedUserDefaultsKey = kPreferenceGlobalShowShortcut

        bindUI()
    }

    private func bindUI() {
        bindAutoLock()
        bindClipboard()

        showInSystemTray.state = Settings.sharedInstance().showSystemTrayIcon ? .on : .off
        hideDockIcon.isEnabled = Settings.sharedInstance().showSystemTrayIcon
        hideDockIcon.state = Settings.sharedInstance().hideDockIconOnAllMinimized ? .on : .off
        quitWhenAllClosed.isEnabled = !Settings.sharedInstance().showSystemTrayIcon
        quitWhenAllClosed.state = Settings.sharedInstance().quitStrongboxOnAllWindowsClosed ? .on : .off

        miniaturizeOnCopy.state = Settings.sharedInstance().miniaturizeOnCopy ? .on : .off
        lockEvenIfEditing.state = Settings.sharedInstance().lockEvenIfEditing ? .on : .off
    }

    func bindAutoLock() {
        let alt = Settings.sharedInstance().autoLockTimeoutSeconds

        autoLockDatabase.state = alt != 0 ? .on : .off
        autoLockTimeoutTextField.isEnabled = alt != 0
        autoLockStepper.isEnabled = alt != 0
        autoLockStepper.integerValue = alt
        autoLockTimeoutTextField.stringValue = alt != 0 ? autoLockStepper.stringValue : "120"
    }

    func bindClipboard() {
        autoClearClipboard.state = Settings.sharedInstance().clearClipboardEnabled ? .on : .off
        autoClearClipboardTimeout.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.integerValue = Settings.sharedInstance().clearClipboardAfterSeconds
        autoClearClipboardTimeout.stringValue = stepperAutoClearClipboard.stringValue
    }

    @IBAction func onClearClipboardTextFieldEdited(_: Any) {
        stepperAutoClearClipboard.integerValue = autoClearClipboardTimeout.integerValue

        Settings.sharedInstance().clearClipboardAfterSeconds = stepperAutoClearClipboard.integerValue

        bindUI()

        notifyChanged()
    }

    @IBAction func onClearClipboardStepper(_: Any) {
        Settings.sharedInstance().clearClipboardAfterSeconds = stepperAutoClearClipboard.integerValue

        bindUI()

        notifyChanged()
    }

    @IBAction func onClearClipboardCheckbox(_: Any) {
        Settings.sharedInstance().clearClipboardEnabled = autoClearClipboard.state == .on

        bindUI()

        notifyChanged()
    }

    @IBAction func onAutoLockTextFieldEdited(_: Any) {
        autoLockStepper.integerValue = autoLockTimeoutTextField.integerValue

        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue

        bindUI()

        notifyChanged()
    }

    @IBAction func onAutoLockStepperChanged(_: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue

        bindUI()

        notifyChanged()
    }

    @IBAction func onAutoLockTimeoutChanged(_: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockDatabase.state == .on ? 120 : 0

        bindUI()

        notifyChanged()
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().showSystemTrayIcon = showInSystemTray.state == .on
        Settings.sharedInstance().hideDockIconOnAllMinimized = hideDockIcon.state == .on
        Settings.sharedInstance().miniaturizeOnCopy = miniaturizeOnCopy.state == .on
        Settings.sharedInstance().quitStrongboxOnAllWindowsClosed = quitWhenAllClosed.state == .on
        Settings.sharedInstance().lockEvenIfEditing = lockEvenIfEditing.state == .on
        
        bindUI()

        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
