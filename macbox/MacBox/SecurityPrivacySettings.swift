//
//  LockingSettings.swift
//  MacBox
//
//  Created by Strongbox on 31/10/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class SecurityPrivacySettings: NSViewController {
    @IBOutlet var blockScreenshots: NSButton!
    @IBOutlet var quickReveal: NSButton!
    @IBOutlet var revealImmediately: NSButton!

    @IBOutlet var miniaturizeOnCopy: NSButton!
    @IBOutlet var autoClearClipboard: NSButton!
    @IBOutlet var autoClearClipboardTimeout: NSTextField!
    @IBOutlet var stepperAutoClearClipboard: NSStepper!
    @IBOutlet var allowClipboardHandoff: NSButton!
    
    @IBOutlet var lockOnScreenLock: NSButton!
    @IBOutlet var lockEvenIfEditing: NSButton!
    @IBOutlet var autoLockDatabase: NSButton!
    @IBOutlet var autoLockTimeoutTextField: NSTextField!
    @IBOutlet var autoLockStepper: NSStepper!
    @IBOutlet var lockDatabaseOnWindowClose: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    private func bindUI() {
        bindGeneral()
        bindClipboard()
        bindLocking()
    }
    
    func bindGeneral () {
        let settings = Settings.sharedInstance()

        blockScreenshots.state = settings.screenCaptureBlocked ? .on : .off
        quickReveal.state = settings.quickRevealWithOptionKey ? .on : .off
        revealImmediately.state = settings.revealPasswordsImmediately ? .on : .off
    }
    
    func bindClipboard() {
        autoClearClipboard.state = Settings.sharedInstance().clearClipboardEnabled ? .on : .off
        autoClearClipboardTimeout.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.integerValue = Settings.sharedInstance().clearClipboardAfterSeconds
        autoClearClipboardTimeout.stringValue = stepperAutoClearClipboard.stringValue
        allowClipboardHandoff.state = Settings.sharedInstance().clipboardHandoff ? .on : .off
        miniaturizeOnCopy.state = Settings.sharedInstance().miniaturizeOnCopy ? .on : .off
    }
    
    func bindLocking() {
        let alts = Settings.sharedInstance().autoLockTimeoutSeconds
        let mins = alts / 60
        
        autoLockDatabase.state = mins != 0 ? .on : .off
        autoLockTimeoutTextField.isEnabled = mins != 0
        autoLockStepper.isEnabled = mins != 0
        
        autoLockStepper.integerValue = mins
        autoLockTimeoutTextField.stringValue = mins != 0 ? autoLockStepper.stringValue : ""

        lockDatabaseOnWindowClose.state = Settings.sharedInstance().lockDatabaseOnWindowClose ? .on : .off
        lockOnScreenLock.state = Settings.sharedInstance().lockDatabasesOnScreenLock ? .on : .off;
        lockEvenIfEditing.state = Settings.sharedInstance().lockEvenIfEditing ? .on : .off
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().screenCaptureBlocked = blockScreenshots.state == .on
        Settings.sharedInstance().quickRevealWithOptionKey = quickReveal.state == .on
        Settings.sharedInstance().revealPasswordsImmediately = revealImmediately.state == .on
        
        Settings.sharedInstance().clipboardHandoff = allowClipboardHandoff.state == .on
        Settings.sharedInstance().miniaturizeOnCopy = miniaturizeOnCopy.state == .on
        
        Settings.sharedInstance().lockDatabaseOnWindowClose = lockDatabaseOnWindowClose.state == .on
        Settings.sharedInstance().lockDatabasesOnScreenLock = lockOnScreenLock.state == .on
        Settings.sharedInstance().lockEvenIfEditing = lockEvenIfEditing.state == .on
        
        bindUI()
        
        notifyChanged()
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

        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue * 60
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onAutoLockStepperChanged(_: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue * 60
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onAutoLockTimeoutChanged(_: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockDatabase.state == .on ? 600 : 0
        
        bindUI()
        
        notifyChanged()
    }

    
    
    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
