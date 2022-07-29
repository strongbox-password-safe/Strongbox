//
//  OnboardingModules.swift
//  MacBox
//
//  Created by Strongbox on 19/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class OnboardingModules {
    class func getFirstRunWelcomeModule() -> OnboardingModule {
        let image = NSImage(imageLiteralResourceName: "welcome-business")

        return GenericOnboardingModule(image: image,
                                       title: NSLocalizedString("onboarding_welcome_to_strongbox_first_run_title", comment: "Welcome Aboard"),
                                       body: NSLocalizedString("onboarding_welcome_to_strongbox_first_run_message_macos", comment: "Hi there 😎\n\nWe're excited you've decided to try us out and we just wanted to say thanks! So, without further ado, let's get started...\n\n❤️ The Strongbox Team ❤️"),
                                       button1Title: NSLocalizedString("generic_lets_go", comment: "Let's Go"),
                                       hideDismiss: true,
                                       shouldDisplay: {
                                           return !Settings.sharedInstance().hasShownFirstRunWelcome && MacDatabasePreferences.allDatabases.count == 0
                                       }, onButton1: { _, completion in
                                           Settings.sharedInstance().hasShownFirstRunWelcome = true
                                           completion()
                                       })
    }

    class func getHasBeenDowngradedModule() -> OnboardingModule {
        let image = NSImage(imageLiteralResourceName: "cry-emoji")

        let fmt = NSLocalizedString("generic_biometric_unlock_fmt", comment: "%@ Unlock")
        let bioFeature = String(format: fmt, BiometricIdHelper.sharedInstance().biometricIdName)

        let msgFmt = NSLocalizedString("upgrade_mgr_downgrade_message", comment: "Strongbox has been downgraded from Pro.\n\nDon't worry, all your databases are still available, but some convenient features (e.g. %@) will no longer work.\n\nThis is probably because your trial or subscription has just ended.\n\nWe'd love if you could support us by upgrading to Pro.\n\nWould you like to do that now?")

        let msg = String(format: msgFmt, bioFeature)

        return GenericOnboardingModule(image: image,
                                       title: NSLocalizedString("upgrade_mgr_downgrade_title", comment: "Strongbox Downgrade"),
                                       body: msg,
                                       button1Title: NSLocalizedString("generic_upgrade_ellipsis", comment: "Upgrade..."),
                                       button2Title: NSLocalizedString("generic_dont_tell_again", comment: "Don't Tell Me Again"),
                                       hideDismiss: true,
                                       shouldDisplay: {
                                           if Settings.sharedInstance().isPro {
                                               return false
                                           }

                                           return Settings.sharedInstance().appHasBeenDowngradedToFreeEdition && !Settings.sharedInstance().hasPromptedThatAppHasBeenDowngradedToFreeEdition
                                       },
                                       onButton1: { viewController, completion in
                                           if MacCustomizationManager.isUnifiedFreemiumBundle {
                                               let vc = UnifiedUpgrade.fromStoryboard()

                                               vc.naggy = false
                                               vc.isPresentedAsSheet = true
                                               vc.completion = {
                                                   completion()
                                               }

                                               viewController.presentAsSheet(vc)
                                           }
                                           else {
                                               UpgradeWindowController.show(0)
                                           }
                                       }, onButton2: { _, completion in
                                           Settings.sharedInstance().hasPromptedThatAppHasBeenDowngradedToFreeEdition = true
                                           completion()
                                       })
    }
}
