//
//  AppearanceSettings.swift
//  MacBox
//
//  Created by Strongbox on 31/10/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class AppearanceSettings: NSViewController {
    @IBOutlet var markdown: NSButton!
    @IBOutlet var colorizePasswords: NSButton!
    @IBOutlet var showCopyFieldsButton: NSButton!
    @IBOutlet var showManagerOnAllClosed: NSButton!
    @IBOutlet var hideManagerAfterLaunching: NSButton!
    @IBOutlet var showManagerOnAppLaunch: NSButton!
    @IBOutlet var popupAppearance: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        

        showManagerOnAllClosed.isHidden = true

        bindUI()
    }

    private func bindUI() {
        let settings = Settings.sharedInstance()

        markdown.state = settings.markdownNotes ? .on : .off
        colorizePasswords.state = settings.colorizePasswords ? .on : .off
        showCopyFieldsButton.state = settings.showCopyFieldButton ? .on : .off
        showManagerOnAllClosed.state = settings.showDatabasesManagerOnCloseAllWindows ? .on : .off
        hideManagerAfterLaunching.state = settings.closeManagerOnLaunch ? .on : .off
        showManagerOnAppLaunch.state = settings.showDatabasesManagerOnAppLaunch ? .on : .off

        let index = Int(settings.appAppearance.rawValue)
        let item = popupAppearance.item(at: index)

        popupAppearance.select(item)
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().markdownNotes = markdown.state == .on
        Settings.sharedInstance().colorizePasswords = colorizePasswords.state == .on
        Settings.sharedInstance().showCopyFieldButton = showCopyFieldsButton.state == .on
        Settings.sharedInstance().showDatabasesManagerOnCloseAllWindows = showManagerOnAllClosed.state == .on
        Settings.sharedInstance().closeManagerOnLaunch = hideManagerAfterLaunching.state == .on
        Settings.sharedInstance().showDatabasesManagerOnAppLaunch = showManagerOnAppLaunch.state == .on

        let index = UInt(popupAppearance.indexOfSelectedItem)
        let appearance = AppAppearance(rawValue: index)

        if Settings.sharedInstance().appAppearance != appearance {
            Settings.sharedInstance().appAppearance = appearance

            if appearance == kAppAppearanceSystem {
                NSApp.appearance = nil
            } else {
                NSApp.appearance = appearance == kAppAppearanceLight ? NSAppearance(named: .aqua) : NSAppearance(named: .darkAqua)
            }
        }

        bindUI()

        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}
