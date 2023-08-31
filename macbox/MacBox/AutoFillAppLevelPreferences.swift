//
//  AutoFillAppLevelPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoFillAppLevelPreferences: NSViewController {
    @IBOutlet var autoLaunchSingleDatabase: NSButton!
    @IBOutlet var labelProWarning: NSTextField!
    @IBOutlet var viewInstructions: NSView!
    @IBOutlet var viewSettings: NSView!

    var timer: Timer?

    override func viewDidDisappear() {
        super.viewDidDisappear()

        killRefreshTimer()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        startRefreshTimer()
    }

    func startRefreshTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let self else { return }

            self.bindUI()
        })
    }

    func killRefreshTimer() {
        if timer != nil {
            timer?.invalidate()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindUI()
    }

    func bindUI() {
        let pro = Settings.sharedInstance().isPro
        let isOnForStrongbox = AutoFillManager.sharedInstance().isOnForStrongbox
        let featureIsAvailable = true

        if !pro {
            labelProWarning.isHidden = false
        } else if isOnForStrongbox {
            labelProWarning.isHidden = false
            labelProWarning.stringValue = NSLocalizedString("strongbox_is_enabled_for_autofill", comment: "✅ Strongbox is enabled for Password AutoFill")
            labelProWarning.textColor = .secondaryLabelColor
            labelProWarning.alignment = .left
        } else {
            labelProWarning.isHidden = true
        }

        

        viewInstructions.isHidden = isOnForStrongbox || !pro || !featureIsAvailable
        viewSettings.isHidden = !isOnForStrongbox || !featureIsAvailable

        

        autoLaunchSingleDatabase.isEnabled = pro

        

        autoLaunchSingleDatabase.state = Settings.sharedInstance().autoFillAutoLaunchSingleDatabase ? .on : .off
    }

    @IBAction func onChanged(_: Any) {
        Settings.sharedInstance().autoFillAutoLaunchSingleDatabase = autoLaunchSingleDatabase.state == .on

        bindUI()
    }

    @IBAction func onOpenSystemPreferences(_: Any) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }
}
