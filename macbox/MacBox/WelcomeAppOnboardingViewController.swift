//
//  WelcomeAppOnboardingViewController.swift
//  MacBox
//
//  Created by Strongbox on 06/03/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa
import ServiceManagement

class WelcomeAppOnboardingModule: OnboardingModule {
    var window: NSWindow? = nil
    var isAppModal: Bool = false

    var shouldDisplay: Bool {
        !Settings.sharedInstance().hasShownFirstRunWelcome && MacDatabasePreferences.allDatabases.count == 0
    }

    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let ret = WelcomeAppOnboardingViewController.fromStoryboard()

        ret.completion = completion

        return ret
    }
}

class WelcomeAppOnboardingViewController: NSViewController {
    @IBOutlet var checkboxStartAtLogin: NSButton!
    @IBOutlet var checkboxAutoFill: NSButton!
    @IBOutlet var checkboxKeepInMenuBar: NSButton!
    @IBOutlet var stackViewStartAtLogin: NSStackView!
    @IBOutlet var stackViewAutoFill: NSStackView!

    @IBOutlet var checkboxWiFi: NSButton!
    @IBOutlet var stackWiFI: NSStackView!

    @IBOutlet var checkboxMarkdownNotes: NSButton!

    var completion: (() -> Void)!

    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "WelcomeAppOnboarding", bundle: nil)

        let initial = storyboard.instantiateInitialController() as! Self

        return initial
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(macOS 13.0, *) {
            stackViewStartAtLogin.isHidden = false
        } else {
            stackViewStartAtLogin.isHidden = true
        }

        stackViewAutoFill.isHidden = !Settings.sharedInstance().isPro

        checkboxStartAtLogin.state = .off
        checkboxKeepInMenuBar.state = .off

        checkboxAutoFill.state = Settings.sharedInstance().isPro ? .on : .off
        checkboxAutoFill.isEnabled = Settings.sharedInstance().isPro

        checkboxMarkdownNotes.state = Settings.sharedInstance().markdownNotes ? .on : .off
        checkboxWiFi.state = Settings.sharedInstance().runAsWiFiSyncSourceDevice ? .on : .off

        stackWiFI.isHidden = !StrongboxProductBundle.supportsWiFiSync
    }

    @IBAction func onLetsGo(_: Any) {
        

        if #available(macOS 13.0, *) {
            if checkboxStartAtLogin.state == .on, SMAppService.mainApp.status != .enabled {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    MacAlerts.error(error, window: self.view.window)
                    swlog("🔴 Error registering startup item: [%@]", String(describing: error))
                }
            } else if checkboxStartAtLogin.state == .off, SMAppService.mainApp.status == .enabled {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    MacAlerts.error(error, window: self.view.window)
                    swlog("🔴 Error unregistering startup item: [%@]", String(describing: error))
                }
            }
        }

        

        Settings.sharedInstance().showSystemTrayIcon = checkboxKeepInMenuBar.state == .on

        

        if Settings.sharedInstance().isPro {
            Settings.sharedInstance().hasPromptedForThirdPartyAutoFill = true

            let autofill = checkboxAutoFill.state == .on

            Settings.sharedInstance().runBrowserAutoFillProxyServer = autofill

            if autofill {
                NativeMessagingManifestInstallHelper.installNativeMessagingHostsFiles()
                AutoFillProxyServer.sharedInstance().start()
            } else {
                AutoFillProxyServer.sharedInstance().stop()
                NativeMessagingManifestInstallHelper.removeNativeMessagingHostsFiles()
            }
        }

        

        Settings.sharedInstance().markdownNotes = checkboxMarkdownNotes.state == .on

        

        Settings.sharedInstance().runAsWiFiSyncSourceDevice = checkboxWiFi.state == .on

        try? WiFiSyncServer.shared.startOrStopWiFiSyncServerAccordingToSettings()

        

        NotificationCenter.default.post(name: .settingsChanged, object: nil)

        Settings.sharedInstance().hasShownFirstRunWelcome = true

        completion()
    }
}
