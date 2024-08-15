//
//  DatabaseWelcomeOnboardingModule.swift
//  MacBox
//
//  Created by Strongbox on 14/08/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class DatabaseWelcomeOnboardingModule: OnboardingModule {
    var window: NSWindow? = nil
    var isAppModal: Bool { false }

    var model: Model {
        viewModel.commonModel!
    }

    let viewModel: ViewModel
    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var shouldPromptForBiometricEnrol: Bool {
        let featureAvailable = Settings.sharedInstance().isPro
        let watchAvailable = BiometricIdHelper.sharedInstance().isWatchUnlockAvailable
        let touchAvailable = BiometricIdHelper.sharedInstance().isTouchIdUnlockAvailable
        let convenienceAvailable = watchAvailable || touchAvailable
        let convenienceIsPossible = convenienceAvailable && featureAvailable

        return convenienceIsPossible && !model.metadata.hasPromptedForTouchIdEnrol
    }

    var shouldPromptForAutoFillEnrol: Bool {
        let featureAvailable = Settings.sharedInstance().isPro
        return featureAvailable && !model.metadata.hasPromptedForAutoFillEnrol
    }

    var shouldDisplay: Bool {
        shouldPromptForBiometricEnrol || shouldPromptForAutoFillEnrol
    }

    var welcomeVc: OnboardingWelcomeViewController!
    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let sb = NSStoryboard(name: "DatabaseOnboarding", bundle: nil)
        welcomeVc = sb.instantiateInitialController()

        let showTouchId = shouldPromptForBiometricEnrol
        let showAutoFill = shouldPromptForAutoFillEnrol
        let hasAutoFillDatabase = MacDatabasePreferences.allDatabases.first(where: { $0.autoFillEnabled }) != nil

        welcomeVc.showTouchID = showTouchId
        welcomeVc.showAutoFill = showAutoFill
        welcomeVc.enableAutoFill = !hasAutoFillDatabase

        welcomeVc.onNext = { [weak self] userCancelled, enableTouchID, enableAutoFill in
            guard let self else { return }

            let enableTouchID = showTouchId && enableTouchID
            let enableAutoFill = showAutoFill && enableAutoFill

            onWelcomeDone(userCancelled: userCancelled, shouldSetTouchID: showTouchId, enableTouchID: enableTouchID, shouldSetAutoFill: showAutoFill, enableAutoFill: enableAutoFill, completion: completion)
        }

        return welcomeVc
    }

    func onWelcomeDone(userCancelled: Bool, shouldSetTouchID: Bool, enableTouchID: Bool, shouldSetAutoFill: Bool, enableAutoFill: Bool, completion: @escaping (() -> Void)) {
        if userCancelled {
            completion()
            return
        }

        if shouldSetTouchID {
            model.metadata.isTouchIdEnabled = enableTouchID
            model.metadata.isWatchUnlockEnabled = enableTouchID

            if enableTouchID {
                model.metadata.conveniencePasswordHasBeenStored = true
                model.metadata.conveniencePassword = model.ckfs.password
            } else {
                model.metadata.conveniencePasswordHasBeenStored = false
                model.metadata.conveniencePassword = nil
            }

            model.metadata.hasPromptedForTouchIdEnrol = true
        }

        if shouldSetAutoFill {
            AutoFillManager.sharedInstance().clearAutoFillQuickTypeDatabase()

            model.metadata.autoFillEnabled = enableAutoFill
            model.metadata.quickTypeEnabled = enableAutoFill

            if enableAutoFill {
                AutoFillManager.sharedInstance().updateAutoFillQuickTypeDatabase(model, clearFirst: false)
            }

            viewModel.rebuildMapsAndCaches()

            model.metadata.hasPromptedForAutoFillEnrol = true
        }

        completion()
    }
}
