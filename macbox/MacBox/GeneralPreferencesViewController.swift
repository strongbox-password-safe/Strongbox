//
//  GeneralPreferencesViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa
import ServiceManagement

class GeneralPreferencesViewController: NSViewController {
    @IBOutlet var stackStartAtLogin: NSStackView!
    @IBOutlet var stackLegacyRegularAppOptions: NSStackView!
    @IBOutlet var buttonStartAtLogin: NSButton!
    @IBOutlet var showInSystemTray: NSButton!
    @IBOutlet var shortcutView: MASShortcutView!
    @IBOutlet var commandPaletteShortcutView: MASShortcutView!
    @IBOutlet var quitWhenAllClosed: NSButton!
    @IBOutlet var checkboxAlwaysShowDockIcon: NSButton!
    @IBOutlet var stackAlwaysShowDockIcon: NSStackView!
    @IBOutlet var passwordGenShortcut: MASShortcutView!

    override func viewDidLoad() {
        super.viewDidLoad()

        shortcutView.associatedUserDefaultsKey = NSNotification.Name.preferenceGlobalShowShortcut.rawValue
        commandPaletteShortcutView.associatedUserDefaultsKey = kPreferenceLaunchQuickSearchShortcut
        passwordGenShortcut.associatedUserDefaultsKey = kPreferencePasswordGeneratorShortcut

        bindUI()
    }

    private func bindUI() {
        let settings = Settings.sharedInstance()

        if #available(macOS 13.0, *) {
            stackStartAtLogin.isHidden = false
            buttonStartAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        } else {
            stackStartAtLogin.isHidden = true
        }

        stackLegacyRegularAppOptions.isHidden = settings.showSystemTrayIcon

        showInSystemTray.state = settings.showSystemTrayIcon ? .on : .off
        quitWhenAllClosed.state = settings.quitStrongboxOnAllWindowsClosed ? .on : .off

        stackAlwaysShowDockIcon.isHidden = !settings.showSystemTrayIcon
        checkboxAlwaysShowDockIcon.state = settings.hideDockIconOnAllMinimized ? .off : .on
    }

    @IBAction func onStartAtLogin(_: Any) {
        let start = buttonStartAtLogin.state == .on

        if #available(macOS 13.0, *) {
            if start {
                do {
                    try SMAppService.mainApp.register()
                } catch {
                    MacAlerts.error(error, window: self.view.window)
                    swlog("🔴 Error registering startup item: [%@]", String(describing: error))
                }
            } else {
                do {
                    try SMAppService.mainApp.unregister()
                } catch {
                    MacAlerts.error(error, window: self.view.window)
                    swlog("🔴 Error unregistering startup item: [%@]", String(describing: error))
                }
            }
        }

        bindUI()

        notifyChanged()
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().showSystemTrayIcon = showInSystemTray.state == .on
        Settings.sharedInstance().quitStrongboxOnAllWindowsClosed = quitWhenAllClosed.state == .on
        Settings.sharedInstance().hideDockIconOnAllMinimized = checkboxAlwaysShowDockIcon.state == .off

        bindUI()

        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}
