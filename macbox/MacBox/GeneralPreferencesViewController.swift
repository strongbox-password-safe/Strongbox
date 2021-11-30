//
//  GeneralPreferencesViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class GeneralPreferencesViewController: NSViewController {
    @IBOutlet weak var autoLockDatabase: NSButton!
    @IBOutlet weak var miniaturizeOnCopy: NSButton!
    @IBOutlet weak var autoClearClipboard: NSButton!
    @IBOutlet weak var shortcutView: MASShortcutView!
    @IBOutlet weak var autoClearClipboardTimeout: NSTextField!
    @IBOutlet weak var autoLockTimeoutTextField: NSTextField!
    @IBOutlet weak var stepperAutoClearClipboard: NSStepper!
    @IBOutlet weak var autoLockStepper: NSStepper!
    @IBOutlet weak var hideDockIcon: NSButton!
    @IBOutlet weak var showInSystemTray: NSButton!

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
        miniaturizeOnCopy.state = Settings.sharedInstance().miniaturizeOnCopy ? .on : .off
    }
    
    func bindAutoLock() {
        let alt = Settings.sharedInstance().autoLockTimeoutSeconds
        
        autoLockDatabase.state = alt != 0 ? .on : .off
        autoLockTimeoutTextField.isEnabled = alt != 0;
        autoLockStepper.isEnabled = alt != 0;
        autoLockStepper.integerValue = alt;
        autoLockTimeoutTextField.stringValue = alt != 0 ? autoLockStepper.stringValue : "120";
    }
    
    func bindClipboard() {
        autoClearClipboard.state = Settings.sharedInstance().clearClipboardEnabled ? .on : .off
        autoClearClipboardTimeout.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.isEnabled = Settings.sharedInstance().clearClipboardEnabled
        stepperAutoClearClipboard.integerValue = Settings.sharedInstance().clearClipboardAfterSeconds
        autoClearClipboardTimeout.stringValue =  stepperAutoClearClipboard.stringValue
    }
    
    @IBAction func onClearClipboardTextFieldEdited(_ sender: Any) {
        stepperAutoClearClipboard.integerValue = autoClearClipboardTimeout.integerValue;
        
        Settings.sharedInstance().clearClipboardAfterSeconds = stepperAutoClearClipboard.integerValue;
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onClearClipboardStepper(_ sender: Any) {
        Settings.sharedInstance().clearClipboardAfterSeconds = stepperAutoClearClipboard.integerValue;
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onClearClipboardCheckbox(_ sender: Any) {
        Settings.sharedInstance().clearClipboardEnabled = autoClearClipboard.state == .on

        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onAutoLockTextFieldEdited(_ sender: Any) {
        autoLockStepper.integerValue = autoLockTimeoutTextField.integerValue;
        
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue;
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onAutoLockStepperChanged(_ sender: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockStepper.integerValue;
        
        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onAutoLockTimeoutChanged(_ sender: Any) {
        Settings.sharedInstance().autoLockTimeoutSeconds = autoLockDatabase.state == .on ? 120 : 0;

        bindUI()
        
        notifyChanged()
    }
    
    @IBAction func onChanged(_ sender: Any) {
        Settings.sharedInstance().showSystemTrayIcon = showInSystemTray.state == .on
        Settings.sharedInstance().hideDockIconOnAllMinimized = hideDockIcon.state == .on
        Settings.sharedInstance().miniaturizeOnCopy = miniaturizeOnCopy.state == .on
        
        bindUI()
        
        notifyChanged()
    }
    
    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
