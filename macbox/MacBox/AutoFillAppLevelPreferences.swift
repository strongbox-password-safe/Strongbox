//
//  AutoFillAppLevelPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoFillAppLevelPreferences: NSViewController {
    @IBOutlet weak var autoLaunchSingleDatabase: NSButton!
    @IBOutlet weak var labelProWarning: NSTextField!
    @IBOutlet weak var viewInstructions: NSView!
    @IBOutlet weak var viewSettings: NSView!
    
    var timer : Timer? = nil
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        killRefreshTimer()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        startRefreshTimer()
    }

    func startRefreshTimer () {
        if #available(macOS 10.12, *) {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
                guard let self = self else { return }
                
                self.bindUI()
            })
        }
    }
    
    func killRefreshTimer() {
        if ( timer != nil ) {
            timer?.invalidate()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    func bindUI() {
        let pro = Settings.sharedInstance().isProOrFreeTrial
        let isOnForStrongbox = AutoFillManager.sharedInstance().isOnForStrongbox;
        let featureIsAvailable : Bool
        
        if #available(macOS 11.0, *) {
            featureIsAvailable = true
        }
        else {
            featureIsAvailable = false
        }
        
        if ( !pro ) {
            labelProWarning.isHidden = false
        }
        else if ( !featureIsAvailable ) {
            labelProWarning.isHidden = false
            labelProWarning.stringValue = NSLocalizedString("autofill_app_preferences_only_avail_big_sur", comment: "AutoFill is only available on macOS Big Sur+")
            labelProWarning.textColor = .systemOrange
            labelProWarning.alignment = .center
        }
        else if ( isOnForStrongbox ) {
            labelProWarning.isHidden = false
            labelProWarning.stringValue = NSLocalizedString("strongbox_is_enabled_for_autofill", comment: "✅ Strongbox is enabled for Password AutoFill")
            labelProWarning.textColor = .secondaryLabelColor
            labelProWarning.alignment = .left
        }
        else {
            labelProWarning.isHidden = true
        }

        

        viewInstructions.isHidden = isOnForStrongbox || !pro || !featureIsAvailable
        viewSettings.isHidden = !isOnForStrongbox || !featureIsAvailable
        
        
        
        autoLaunchSingleDatabase.isEnabled = pro
        
        
        
        autoLaunchSingleDatabase.state = Settings.sharedInstance().autoFillAutoLaunchSingleDatabase ? .on : .off
    }
    
    @IBAction func onChanged(_ sender: Any) {
        Settings.sharedInstance().autoFillAutoLaunchSingleDatabase = autoLaunchSingleDatabase.state == .on
        
        bindUI()
    }
    
    @IBAction func onOpenSystemPreferences(_ sender: Any) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane"))
    }
}
