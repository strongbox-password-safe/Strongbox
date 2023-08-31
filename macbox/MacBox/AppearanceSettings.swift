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
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().markdownNotes = markdown.state == .on
        Settings.sharedInstance().colorizePasswords = colorizePasswords.state == .on
        Settings.sharedInstance().showCopyFieldButton = showCopyFieldsButton.state == .on
        Settings.sharedInstance().showDatabasesManagerOnCloseAllWindows = showManagerOnAllClosed.state == .on
        Settings.sharedInstance().closeManagerOnLaunch = hideManagerAfterLaunching.state == .on
        Settings.sharedInstance().showDatabasesManagerOnAppLaunch = showManagerOnAppLaunch.state == .on

        bindUI()

        notifyChanged()
    }

    func notifyChanged() {
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
