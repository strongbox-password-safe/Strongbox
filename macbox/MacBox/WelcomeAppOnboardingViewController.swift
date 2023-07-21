//
//  WelcomeAppOnboarding.swift
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
        return !Settings.sharedInstance().hasShownFirstRunWelcome && MacDatabasePreferences.allDatabases.count == 0
    }
    
    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let ret = WelcomeAppOnboardingViewController.fromStoryboard()
        
        ret.completion = completion
        
        return ret
    }
}

class WelcomeAppOnboardingViewController: NSViewController {
    @IBOutlet weak var checkboxStartAtLogin: NSButton!
    @IBOutlet weak var checkboxAutoFill: NSButton!
    @IBOutlet weak var checkboxKeepInMenuBar: NSButton!
    @IBOutlet weak var stackViewStartAtLogin: NSStackView!
    @IBOutlet weak var stackViewAutoFill: NSStackView!
    
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
        }
        else {
            stackViewStartAtLogin.isHidden = true
        }
        
        stackViewAutoFill.isHidden = !Settings.sharedInstance().isPro
        
        checkboxStartAtLogin.state = .off
        checkboxKeepInMenuBar.state = .off
        
        checkboxAutoFill.state = Settings.sharedInstance().isPro ? .on : .off
        checkboxAutoFill.isEnabled = Settings.sharedInstance().isPro
    }
    
    @IBAction func onLetsGo(_ sender: Any) {
        
        
        if #available(macOS 13.0, *) {
            if checkboxStartAtLogin.state == .on && SMAppService.mainApp.status != .enabled  {
                do {
                    try SMAppService.mainApp.register()
                }
                catch {
                    MacAlerts.error(error, window: self.view.window)
                    NSLog("🔴 Error registering startup item: [%@]", String(describing: error))
                }
            }
            else if checkboxStartAtLogin.state == .off && SMAppService.mainApp.status == .enabled {
                do {
                    try SMAppService.mainApp.unregister()
                }
                catch {
                    MacAlerts.error(error, window: self.view.window)
                    NSLog("🔴 Error unregistering startup item: [%@]", String(describing: error))
                }
            }
        }
        
        
            
        Settings.sharedInstance().showSystemTrayIcon = checkboxKeepInMenuBar.state == .on

        
        
        if ( Settings.sharedInstance().isPro ) {
            Settings.sharedInstance().hasPromptedForThirdPartyAutoFill = true
            
            let autofill = checkboxAutoFill.state == .on
            
            Settings.sharedInstance().runBrowserAutoFillProxyServer = autofill;
            
            if autofill {
                NativeMessagingManifestInstallHelper.installNativeMessagingHostsFiles();
                AutoFillProxyServer.sharedInstance().start();
            }
            else {
                AutoFillProxyServer.sharedInstance().stop();
                NativeMessagingManifestInstallHelper.removeNativeMessagingHostsFiles();
            }
        }
        
        
        
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        
        Settings.sharedInstance().hasShownFirstRunWelcome = true 
        
        completion()
    }
}
