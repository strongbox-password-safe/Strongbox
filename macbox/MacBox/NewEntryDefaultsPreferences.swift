//
//  NewEntryDefaultsPreferences.swift
//  MacBox
//
//  Created by Strongbox on 21/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class NewEntryDefaultsPreferences: NSViewController {
    @IBOutlet weak var titleSegment: NSSegmentedControl!
    @IBOutlet weak var usernameSegment: NSSegmentedControl!
    @IBOutlet weak var passwordSegment: NSSegmentedControl!
    @IBOutlet weak var emailSegment: NSSegmentedControl!
    @IBOutlet weak var urlSegment: NSSegmentedControl!
    @IBOutlet weak var notesSegment: NSSegmentedControl!
    
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var usernameLabel: NSTextField!
    @IBOutlet weak var passwordLabel: NSTextField!
    @IBOutlet weak var emailLabel: NSTextField!
    @IBOutlet weak var urlLabel: NSTextField!
    @IBOutlet weak var notesLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    func bindUI() {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        var index = autoFillModeToSegmentIndex(mode: settings.titleAutoFillMode)
        titleSegment.selectedSegment = index;
        titleLabel.stringValue = settings.titleAutoFillMode == .custom ? settings.titleCustomAutoFill : ""

        

        

        index = autoFillModeToSegmentIndex(mode: settings.usernameAutoFillMode)
        usernameSegment.selectedSegment = index;
        usernameLabel.stringValue = settings.usernameAutoFillMode == .custom ? settings.usernameCustomAutoFill : ""

        

        index = autoFillModeToSegmentIndex(mode: settings.passwordAutoFillMode)
        passwordSegment.selectedSegment = index;
        passwordLabel.stringValue = settings.passwordAutoFillMode == .custom ? settings.passwordCustomAutoFill : ""

        

        index = autoFillModeToSegmentIndex(mode: settings.emailAutoFillMode)
        emailSegment.selectedSegment = index;
        emailLabel.stringValue = settings.emailAutoFillMode == .custom ? settings.emailCustomAutoFill : ""

        

        index = autoFillModeToSegmentIndex(mode: settings.urlAutoFillMode)
        urlSegment.selectedSegment = index;
        urlLabel.stringValue = settings.urlAutoFillMode == .custom ? settings.urlCustomAutoFill : ""

        

        index = autoFillModeToSegmentIndex(mode: settings.notesAutoFillMode)
        notesSegment.selectedSegment = index;
        notesLabel.stringValue = settings.notesAutoFillMode == .custom ? settings.notesCustomAutoFill : ""
    }
    
    @IBAction func onTitleChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = titleSegment.selectedSegment;
        settings.titleAutoFillMode = selected == 0 ? .default : (selected == 1 ? .smartUrlFill : .custom)
        if(settings.titleAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_title_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.titleCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.titleCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings
        
        bindUI()
    }
    
    @IBAction func onUsernameChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = usernameSegment.selectedSegment;
        settings.usernameAutoFillMode = selected == 0 ? .none : (selected == 1 ? .mostUsed : .custom)
        if(settings.usernameAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_username_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.usernameCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.usernameCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings;
        
        bindUI()
    }
    
    @IBAction func onPasswordChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = passwordSegment.selectedSegment;
        settings.passwordAutoFillMode = selected == 0 ? .none : (selected == 1 ? .generated : .custom)
        if(settings.passwordAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_password_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.passwordCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.passwordCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings;
        
        bindUI()
    }
    
    @IBAction func onEmailChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = emailSegment.selectedSegment;
        settings.emailAutoFillMode = selected == 0 ? .none : (selected == 1 ? .mostUsed : .custom)
        if(settings.emailAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_email_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.emailCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.emailCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings;
        
        bindUI()
    }
    
    @IBAction func onUrlChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = urlSegment.selectedSegment;
        settings.urlAutoFillMode = selected == 0 ? .none : (selected == 1 ? .smartUrlFill : .custom)
        if(settings.urlAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_url_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.urlCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.urlCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings;
        
        bindUI()
    }
    
    @IBAction func onNotesChanged(_ sender: Any) {
        let settings = Settings.sharedInstance().autoFillNewRecordSettings

        let selected = notesSegment.selectedSegment;
        settings.notesAutoFillMode = selected == 0 ? .none : (selected == 1 ? .clipboard : .custom)
        if(settings.notesAutoFillMode == .custom) {
            let loc = NSLocalizedString("mac_enter_custom_notes_default", comment: "Please enter your custom Title auto fill")
            let response = MacAlerts().input(loc, defaultValue: settings.notesCustomAutoFill, allowEmpty: false)
            
            if ( response != nil ) {
                settings.notesCustomAutoFill = response!
            }
        }
        
        Settings.sharedInstance().autoFillNewRecordSettings = settings;
        
        bindUI()
    }
    
    func autoFillModeToSegmentIndex(mode : AutoFillMode) -> Int {
        
        
        switch (mode) {
        case .none, .default:
            return 0;
        case .mostUsed, .smartUrlFill, .clipboard, .generated:
            return 1;
        case .custom:
            return 2;
        default:
            NSLog("Ruh Roh... ")
            return -1;
        }
    }
}
