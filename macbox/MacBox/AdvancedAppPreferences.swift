//
//  AdvancedAppPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AdvancedAppPreferences: NSViewController {
    @IBOutlet var newEntryUsesParentGroupIcon: NSButton!
    @IBOutlet var makeBackups: NSButton!
    @IBOutlet var autoSave: NSButton!
    @IBOutlet var rememberKeyFile: NSButton!
    @IBOutlet var hideKeyFile: NSButton!
    @IBOutlet var useColorBindPalette: NSButton!
    @IBOutlet var addTotpOtpAuth: NSButton!
    @IBOutlet var addLegacyTotpFields: NSButton!
    @IBOutlet var useIsolatedDropbox: NSButton!
    @IBOutlet var stripUnusedIcons: NSButton!
    @IBOutlet var enableThirdParty: NSButton!
    @IBOutlet var useNextGenUI: NSButton!
    @IBOutlet var quitClosesAllWindowsNotTerminate: NSButton!
    @IBOutlet var concealedClipboard: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad() 

        bindUI()
        
        NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: nil) { [weak self] _ in
            self?.bindUI()
        }
    }

    func bindUI() {
        let settings = Settings.sharedInstance()
     
        newEntryUsesParentGroupIcon.state = settings.useParentGroupIconOnCreate ? .on : .off;
        makeBackups.state = settings.makeLocalRollingBackups ? .on : .off
        autoSave.state = settings.autoSave ? .on : .off
        rememberKeyFile.state = (!settings.doNotRememberKeyFile) ? .on : .off
        hideKeyFile.state = settings.hideKeyFileNameOnLockScreen ? .on : .off
        useColorBindPalette.state = settings.colorizeUseColorBlindPalette ? .on : .off
        addTotpOtpAuth.state = settings.addOtpAuthUrl ? .on : .off
        addLegacyTotpFields.state = settings.addLegacySupplementaryTotpCustomFields ? .on : .off
        useIsolatedDropbox.state = settings.useIsolatedDropbox ? .on : .off
        stripUnusedIcons.state = Settings.sharedInstance().stripUnusedIconsOnSave ? .on : .off
        enableThirdParty.state = settings.isPro && settings.runBrowserAutoFillProxyServer ? .on : .off;
        useNextGenUI.state = settings.nextGenUI ? .on : .off
        quitClosesAllWindowsNotTerminate.state = settings.quitTerminatesProcessEvenInSystemTrayMode ? .off : .on;
        concealedClipboard.state = settings.concealClipboardFromMonitors ? .on : .off
        
        
        
        quitClosesAllWindowsNotTerminate.isHidden = !Settings.sharedInstance().configuredAsAMenuBarApp;
        
        useColorBindPalette.isHidden = !settings.colorizePasswords
        hideKeyFile.isHidden = settings.doNotRememberKeyFile
        enableThirdParty.isEnabled = settings.isPro;
        
        if #available(macOS 11.0, *) {
        } else {
            useNextGenUI.isHidden = true
        }
    }

    @IBAction func onChanged(_: Any) {
        let settings = Settings.sharedInstance();

        settings.useParentGroupIconOnCreate = newEntryUsesParentGroupIcon.state == .on
        settings.makeLocalRollingBackups = makeBackups.state == .on
        settings.autoSave = autoSave.state == .on
        settings.doNotRememberKeyFile = rememberKeyFile.state != .on
        settings.hideKeyFileNameOnLockScreen = hideKeyFile.state == .on
        settings.colorizeUseColorBlindPalette = useColorBindPalette.state == .on
        settings.addOtpAuthUrl = addTotpOtpAuth.state == .on
        settings.addLegacySupplementaryTotpCustomFields = addLegacyTotpFields.state == .on
        settings.useIsolatedDropbox = useIsolatedDropbox.state == .on
        settings.stripUnusedIconsOnSave = stripUnusedIcons.state == .on
        settings.nextGenUI = useNextGenUI.state == .on
        settings.quitTerminatesProcessEvenInSystemTrayMode = quitClosesAllWindowsNotTerminate.state == .off;
        settings.runBrowserAutoFillProxyServer = enableThirdParty.state == .on
        settings.concealClipboardFromMonitors = concealedClipboard.state == .on
        
        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
    
    @IBAction func onUseDropboxIsolated(_ sender: Any) {
        onChanged(sender)
        
        DropboxV2StorageProvider.sharedInstance().signOut()
        
        MacAlerts.info(NSLocalizedString("generic_restart_required", comment: "Restart Required"),
                       informativeText: NSLocalizedString("generic_restart_required_for_changes_to_take_effect", comment: "You must restart Strongbox for these changes to take effect."),
                       window: view.window,
                       completion: nil)
    }
    
    @IBAction func onEnableThirdParty(_ sender: Any) {
        onChanged(sender)
        
        let settings = Settings.sharedInstance();
    
        if ( settings.runBrowserAutoFillProxyServer ) {
            NativeMessagingManifestInstallHelper.installNativeMessagingHostsFiles();
            AutoFillProxyServer.sharedInstance().start();
        }
        else {
            AutoFillProxyServer.sharedInstance().stop();
            NativeMessagingManifestInstallHelper.removeNativeMessagingHostsFiles();
        }
    }
}
