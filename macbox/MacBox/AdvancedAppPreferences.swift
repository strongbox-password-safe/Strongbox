//
//  AdvancedAppPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import CloudKit
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
    @IBOutlet var stripHistoricalIcons: NSButton!

    @IBOutlet var enableThirdParty: NSButton!
    @IBOutlet var quitClosesAllWindowsNotTerminate: NSButton!
    @IBOutlet var concealedClipboard: NSButton!
    @IBOutlet var atomicSftpWrites: NSButton!

    @IBOutlet var stackViewStrongboxSyncStatus: NSStackView!
    @IBOutlet var labelStrongboxSyncStatus: NSTextField!
    @IBOutlet var imageViewStrongboxSyncStatus: NSImageView!

    @IBOutlet var hardwareKeyCaching: NSButton!

    

    override func viewDidLoad() {
        super.viewDidLoad()

        useIsolatedDropbox.isHidden = !StrongboxProductBundle.supports3rdPartyStorageProviders
        atomicSftpWrites.isHidden = !StrongboxProductBundle.supportsSftpWebDAV


        bindUI()

        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: nil) { [weak self] _ in
            self?.bindUI()
        }

        NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: nil) { [weak self] _ in
            self?.bindUI()
        }
    }

    func bindUI() {
        let settings = Settings.sharedInstance()

        newEntryUsesParentGroupIcon.state = settings.useParentGroupIconOnCreate ? .on : .off
        makeBackups.state = settings.makeLocalRollingBackups ? .on : .off
        autoSave.state = settings.autoSave ? .on : .off
        rememberKeyFile.state = (!settings.doNotRememberKeyFile) ? .on : .off
        hideKeyFile.state = settings.hideKeyFileNameOnLockScreen ? .on : .off
        useColorBindPalette.state = settings.colorizeUseColorBlindPalette ? .on : .off
        addTotpOtpAuth.state = settings.addOtpAuthUrl ? .on : .off
        addLegacyTotpFields.state = settings.addLegacySupplementaryTotpCustomFields ? .on : .off
        useIsolatedDropbox.state = settings.useIsolatedDropbox ? .on : .off

        stripUnusedIcons.state = Settings.sharedInstance().stripUnusedIconsOnSave ? .on : .off
        stripHistoricalIcons.state = Settings.sharedInstance().stripUnusedHistoricalIcons ? .on : .off

        enableThirdParty.state = settings.isPro && settings.runBrowserAutoFillProxyServer ? .on : .off
        quitClosesAllWindowsNotTerminate.state = settings.quitTerminatesProcessEvenInSystemTrayMode ? .off : .on
        concealedClipboard.state = settings.concealClipboardFromMonitors ? .on : .off
        atomicSftpWrites.state = settings.atomicSftpWrite ? .on : .off

        

        quitClosesAllWindowsNotTerminate.isHidden = !Settings.sharedInstance().configuredAsAMenuBarApp

        useColorBindPalette.isHidden = !settings.colorizePasswords
        hideKeyFile.isHidden = settings.doNotRememberKeyFile
        enableThirdParty.isEnabled = settings.isPro



        

        stackViewStrongboxSyncStatus.isHidden = Settings.sharedInstance().disableNetworkBasedFeatures

        #if !NO_NETWORKING
            labelStrongboxSyncStatus.textColor = .secondaryLabelColor
            labelStrongboxSyncStatus.stringValue = NSLocalizedString("generic_loading", comment: "Loading...")
            imageViewStrongboxSyncStatus.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)!

            Task.detached(priority: .background) { [weak self] in
                guard let self else { return }

                do {
                    let status = try await CloudKitDatabasesInteractor.shared.getCloudKitAccountStatus()

                    await updateStrongboxSyncStatus(status: status, error: nil)
                } catch {
                    await updateStrongboxSyncStatus(status: nil, error: error)
                }
            }
        #endif

        hardwareKeyCaching.state = settings.hardwareKeyCachingBeta ? .on : .off
    }

    #if !NO_NETWORKING
        @MainActor
        func updateStrongboxSyncStatus(status: CKAccountStatus?, error: Error?) {
            if let error {
                labelStrongboxSyncStatus.textColor = .systemRed
                labelStrongboxSyncStatus.stringValue = "\(error)"

                imageViewStrongboxSyncStatus.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)!
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemRed))
            } else if let status {
                labelStrongboxSyncStatus.textColor = status == .available ? .secondaryLabelColor : .systemOrange
                labelStrongboxSyncStatus.stringValue = CloudKitDatabasesInteractor.getAccountStatusString(status: status)

                if status == .available {
                    imageViewStrongboxSyncStatus.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)!
                        .withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemGreen))
                } else {
                    imageViewStrongboxSyncStatus.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)!
                        .withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemOrange))
                }
            } else {
                labelStrongboxSyncStatus.textColor = .systemRed
                labelStrongboxSyncStatus.stringValue = NSLocalizedString("generic_unknown", comment: "Unknown")

                imageViewStrongboxSyncStatus.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)!
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemRed))
            }
        }
    #endif

    @IBAction func onHardwareKeyCaching(_ sender: Any) {
        if hardwareKeyCaching.state == .on {
            MacAlerts.yesNo(NSLocalizedString("experimental_feature_warning_title", comment: "Experimental Feature Warning"),
                            informativeText: NSLocalizedString("experimental_feature_warning_message_yes_no", comment: "Caution is required using this feature. While we have performed extensive testing, this is still an early release feature which could corrupt your database. You should only use this if you are an advanced and technical user with a regular backup system in place.\n\nThank you for helping to test Strongbox. Feedback welcome."),
                            window: view.window)
            { [weak self] response in
                guard let self else { return }

                if response {
                    for database in MacDatabasePreferences.allDatabases {
                        database.clearCachedChallengeResponses()
                    }

                    onChanged(sender)
                } else {
                    bindUI()
                }
            }
        } else {
            for database in MacDatabasePreferences.allDatabases {
                database.clearCachedChallengeResponses()
            }

            onChanged(sender)
        }
    }

    @IBAction func onChanged(_: Any) {
        let settings = Settings.sharedInstance()

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
        settings.stripUnusedHistoricalIcons = stripHistoricalIcons.state == .on
        settings.quitTerminatesProcessEvenInSystemTrayMode = quitClosesAllWindowsNotTerminate.state == .off
        settings.runBrowserAutoFillProxyServer = enableThirdParty.state == .on
        settings.concealClipboardFromMonitors = concealedClipboard.state == .on
        settings.atomicSftpWrite = atomicSftpWrites.state == .on


        settings.hardwareKeyCachingBeta = hardwareKeyCaching.state == .on

        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    @IBAction func onFactoryReset(_: Any) {
        MacAlerts.areYouSure("WARNING: This will completely remove all settings, databases, directories, caches and connections belonging to Strongbox.\n\nIt will NOT delete the database files themselves whether on cloud or locally stored.\n\nAre you sure you want to Factory Reset Strongbox?",
                             window: view.window)
        { [weak self] response in
            if response {
                self?.startFactoryReset()
            }
        }
    }

    func startFactoryReset() {
        let allLocked = DatabasesCollection.shared.unlockedCollection.allKeys.isEmpty

        if !allLocked {
            DatabasesCollection.shared.tryToLockAll()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in 
                self?.continueFactoryResetAfterLockAllAttempt()
            }
        } else {
            continueFactoryResetAfterLockAllAttempt()
        }
    }

    func continueFactoryResetAfterLockAllAttempt() {
        let allLocked = DatabasesCollection.shared.unlockedCollection.allKeys.isEmpty

        swlog("Factory Reset: All Locked: %hhd", allLocked)

        if allLocked {
            let allDocsClosed = DocumentController.shared.documents.isEmpty

            if !allDocsClosed {
                DocumentController.shared.closeAllDocuments(withDelegate: nil, didCloseAllSelector: nil, contextInfo: nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in 
                    self?.continueFactoryResetAfterAllDocsClosed()
                }
            } else {
                continueFactoryResetAfterAllDocsClosed()
            }
        } else {
            MacAlerts.info("Strongbox could not lock, close and sync all databases before resetting. Please make sure all syncs are done, lock any open databases and close any open Strongbox windows. Then try Factory Reset again.",
                           window: view.window)
        }
    }

    func continueFactoryResetAfterAllDocsClosed() {


        let allDocsClosed = DocumentController.shared.documents.isEmpty

        if !allDocsClosed {
            MacAlerts.info("Strongbox could not lock, close and sync all databases before resetting. Please make sure all syncs are done, lock any open databases and close any open Strongbox windows. Then try Factory Reset again.",
                           window: view.window)
            return
        }

        let asyncUpdatesInProgress = MacDatabasePreferences.allDatabases.first { obj in
            obj.asyncUpdateId != nil
        }

        let syncInProgress = asyncUpdatesInProgress != nil || MacSyncManager.sharedInstance().syncInProgress

        if syncInProgress {
            MacAlerts.info("Strongbox could not lock, close and sync all databases before resetting. Please make sure all syncs are done, lock any open databases and close any open Strongbox windows. Then try Factory Reset again.",
                           window: view.window)
            return
        }



        

        DBManagerPanel.sharedInstance.hide()

        

        AutoFillProxyServer.sharedInstance().stop()

        

        SSHAgentServer.sharedInstance().stop()

        

        Settings.sharedInstance().factoryReset()

        

        SecretStore.sharedInstance().factoryReset()

        



        NSApp.terminate(self)
        exit(0)
    }

    func restartStrongbox(afterDelay seconds: TimeInterval = 1.0) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
        task.launch()

        NSApp.terminate(self)
        exit(0)
    }

    @IBAction func onUseDropboxIsolated(_ sender: Any) {
        #if !NO_3RD_PARTY_STORAGE_PROVIDERS
            onChanged(sender)

            DropboxV2StorageProvider.sharedInstance().signOut()

            MacAlerts.info(NSLocalizedString("generic_restart_required", comment: "Restart Required"),
                           informativeText: NSLocalizedString("generic_restart_required_for_changes_to_take_effect", comment: "You must restart Strongbox for these changes to take effect."),
                           window: view.window,
                           completion: nil)
        #endif
    }

    @IBAction func onEnableThirdParty(_ sender: Any) {
        onChanged(sender)

        let settings = Settings.sharedInstance()

        if settings.runBrowserAutoFillProxyServer {
            NativeMessagingManifestInstallHelper.installNativeMessagingHostsFiles()
            AutoFillProxyServer.sharedInstance().start()
        } else {
            AutoFillProxyServer.sharedInstance().stop()
            NativeMessagingManifestInstallHelper.removeNativeMessagingHostsFiles()
        }
    }
}
