//
//  AdvancedAppPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AdvancedAppPreferences: NSViewController {
    @IBOutlet weak var quickReveal: NSButton!
    @IBOutlet weak var autoSave: NSButton!
    @IBOutlet weak var rememberKeyFile: NSButton!
    @IBOutlet weak var hideKeyFile: NSButton!
    @IBOutlet weak var useColorBindPalette: NSButton!
    @IBOutlet weak var revealImmediately: NSButton!
    @IBOutlet weak var makeBackups: NSButton!
    @IBOutlet weak var colorizePasswords: NSButton!
    @IBOutlet weak var markdown: NSButton! 
    @IBOutlet weak var showManagerOnAllClosed: NSButton!
    @IBOutlet weak var hideManagerAfterLaunching: NSButton!
    @IBOutlet weak var allowClipboardHandoff: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
        
        NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
                
            self.bindUI()
        }
    }
    
    func bindUI() {
        let settings = Settings.sharedInstance()
        
        quickReveal.state = settings.quickRevealWithOptionKey ? .on : .off
        autoSave.state = settings.autoSave ? .on : .off
        rememberKeyFile.state = (!settings.doNotRememberKeyFile) ? .on : .off
        hideKeyFile.state = settings.hideKeyFileNameOnLockScreen ? .on : .off
        showManagerOnAllClosed.state = settings.showDatabasesManagerOnCloseAllWindows ? .on : .off
        useColorBindPalette.state = settings.colorizeUseColorBlindPalette ? .on : .off
        revealImmediately.state = settings.revealPasswordsImmediately ? .on : .off
        hideManagerAfterLaunching.state = settings.closeManagerOnLaunch ? .on : .off
        makeBackups.state = settings.makeLocalRollingBackups ? .on : .off
        colorizePasswords.state = settings.colorizePasswords ? .on : .off
        markdown.state = settings.markdownNotes ? .on : .off
        allowClipboardHandoff.state = Settings.sharedInstance().clipboardHandoff ? .on : .off

        useColorBindPalette.isEnabled = settings.colorizePasswords
        hideKeyFile.isEnabled = !settings.doNotRememberKeyFile
        
        
        
        showManagerOnAllClosed.isEnabled = !settings.runningAsATrayApp
    }
    
    @IBAction func onChanged(_ sender: Any) {
        Settings.sharedInstance().quickRevealWithOptionKey = quickReveal.state ==  .on
        Settings.sharedInstance().autoSave = autoSave.state == .on
        Settings.sharedInstance().doNotRememberKeyFile = rememberKeyFile.state != .on
        Settings.sharedInstance().hideKeyFileNameOnLockScreen = hideKeyFile.state == .on
        Settings.sharedInstance().showDatabasesManagerOnCloseAllWindows = showManagerOnAllClosed.state == .on
        Settings.sharedInstance().colorizeUseColorBlindPalette = useColorBindPalette.state == .on
        Settings.sharedInstance().revealPasswordsImmediately = revealImmediately.state == .on
        Settings.sharedInstance().closeManagerOnLaunch = hideManagerAfterLaunching.state == .on
        Settings.sharedInstance().makeLocalRollingBackups = makeBackups.state == .on
        Settings.sharedInstance().colorizePasswords = colorizePasswords.state == .on
        Settings.sharedInstance().markdownNotes = markdown.state == .on
        Settings.sharedInstance().clipboardHandoff = allowClipboardHandoff.state == .on

        bindUI()
        
        notifyChanged()
    }
    
    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
