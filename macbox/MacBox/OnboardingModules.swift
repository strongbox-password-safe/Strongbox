//
//  OnboardingModules.swift
//  MacBox
//
//  Created by Strongbox on 19/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import ServiceManagement

class OnboardingModules {
    class func getTurnOnThirdPartyAutoFill() -> OnboardingModule {
        let image = NSImage(imageLiteralResourceName: "browser")

        return GenericOnboardingModule(image: image,
                                       title: NSLocalizedString("onboarding_autofill_title_turn_on", comment: "Turn On Browser AutoFill?"),
                                       body: NSLocalizedString("onboarding_autofill_msg_available_turn_on_question", comment: "Browser AutoFill is available but currently not turned on. Would you like to enable Browser AutoFill so that you can conveniently and securely login from within your browser?"),
                                       button1Title: NSLocalizedString("onboarding_autofill_option_turn_on_autofill", comment: "Turn On AutoFill"),
                                       button2Title: NSLocalizedString("generic_no_thanks", comment: "No Thanks"),
                                       hideDismiss: true,
                                       shouldDisplay: {
                                           let settings = Settings.sharedInstance()
                                           return settings.isPro && !settings.runBrowserAutoFillProxyServer && !settings.hasPromptedForThirdPartyAutoFill
                                       },
                                       onButton1: { _, completion in
                                           Settings.sharedInstance().hasPromptedForThirdPartyAutoFill = true
                                           Settings.sharedInstance().runBrowserAutoFillProxyServer = true
                                           completion()
                                       },
                                       onButton2: { _, completion in
                                           Settings.sharedInstance().hasPromptedForThirdPartyAutoFill = true
                                           Settings.sharedInstance().runBrowserAutoFillProxyServer = false
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
                                           } else {
                                               UpgradeWindowController.show(0)
                                           }
                                       }, onButton2: { _, completion in
                                           Settings.sharedInstance().hasPromptedThatAppHasBeenDowngradedToFreeEdition = true
                                           completion()
                                       })
    }

    

    class func getHardwareKeyCaching(viewModel: ViewModel) -> OnboardingModule {
        let image = NSImage(imageLiteralResourceName: "yubikey")

        let model = viewModel.commonModel!

        return GenericOnboardingModule(
            image: image,
            title: NSLocalizedString("feature_hardware_key_caching", comment: "Hardware Key Caching"),
            body: NSLocalizedString("hardware_key_caching_onboarding_msg", comment: "Using a hardware key is a great security choice but it can be a little inconvenient.\n\nWould you like to enable our caching feature?\n\nWith this enabled Strongbox will do things like remember the last challenge response for a period of time. This means you don't need to use your key so often.\n\nFull configuration is available in settings. For more details see online."),
            button1Title: NSLocalizedString("backup_settings_prompt_option_yes_looks_good", comment: "Yes, Sounds Great!"),
            button2Title: NSLocalizedString("generic_no_thanks", comment: "No Thanks"),
            hideDismiss: true,
            shouldDisplay: {
                !model.metadata.hasOnboardedHardwareKeyCaching &&
                    model.originalFormat == .keePass4 &&
                    model.ckfs.yubiKeyCR != nil &&
                    model.metadata.yubiKeyConfiguration != nil &&
                    !(model.metadata.yubiKeyConfiguration?.isVirtual ?? true) &&
                    Settings.sharedInstance().hardwareKeyCachingBeta &&
                    !model.metadata.hardwareKeyCRCaching
            },
            onButton1: { _, completion in
                model.metadata.hardwareKeyCRCaching = true
                model.metadata.challengeRefreshIntervalSecs = 1800 
                model.metadata.cacheChallengeDurationSecs = 8 * 3600 
                model.metadata.doNotRefreshChallengeInAF = true

                if let lastCr = model.ckfs.lastChallengeResponse {
                    model.metadata.addCachedChallengeResponse(lastCr)
                    model.metadata.lastChallengeRefreshAt = Date.now
                }
                model.metadata.hasOnboardedHardwareKeyCaching = true

                completion()
            },
            onButton2: { _, completion in
                model.metadata.hardwareKeyCRCaching = false
                model.metadata.hasOnboardedHardwareKeyCaching = true

                completion()
            }
        )
    }

    class func firstLaunchWelcome(viewModel: ViewModel) -> OnboardingModule {
        DatabaseWelcomeOnboardingModule(viewModel: viewModel)
    }
}
