//
//  MacOnboardingManager.swift
//  MacBox
//
//  Created by Strongbox on 16/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

protocol OnboardingModule {
    var shouldDisplay: Bool { get }
    var isAppModal: Bool { get }
    var window: NSWindow? { get set }

    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController
}

class MacOnboardingManager: NSObject {
    static var window: OnboardingWindow? = nil

    @objc class func beginAppOnboarding(completion: @escaping () -> Void) {
        let modules: [OnboardingModule] = [
            BusinessActivationOnboardingModule(),
            WelcomeAppOnboardingModule(),
            FreeTrialOrUpgradeOnboardingModule(),
            OnboardingModules.getHasBeenDowngradedModule(),
            OnboardingModules.getTurnOnThirdPartyAutoFill(),
        ]



        if let window {
            window.onboardingDoneCompletion = nil
            window.close()
        }
        window = nil

        showNextModule(modules: modules, index: 0, onboardingDoneCompletion: completion)
    }

    class func showNextModule(modules: [OnboardingModule], index: Int, onboardingDoneCompletion: @escaping () -> Void) {
        guard index < modules.count else {
            if let window {
                window.close()
            } else {
                onboardingDoneCompletion() 
            }

            return
        }

        var module = modules[index]

        if module.shouldDisplay {
            let vc = module.instantiateViewController {
                showNextModule(modules: modules, index: index + 1, onboardingDoneCompletion: onboardingDoneCompletion)
            }

            if let window {
                window.contentViewController = vc

                if let title = vc.title {
                    window.title = title
                }
            } else {
                window = OnboardingWindow.createOnboardingWindow(vc: vc, onboardingDoneCompletion: onboardingDoneCompletion)
            }

            guard let window else {
                return
            }

            module.window = window

            if module.isAppModal {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true

                window.styleMask.insert(.fullSizeContentView)
                window.styleMask.remove(.closable)
                window.allowEscapeToClose = false


            } else {
                window.titleVisibility = .visible
                window.titlebarAppearsTransparent = false

                window.styleMask.remove(.fullSizeContentView)
                window.styleMask.insert(.closable)
                window.allowEscapeToClose = true
            }

            
            
        } else {
            showNextModule(modules: modules, index: index + 1, onboardingDoneCompletion: onboardingDoneCompletion)
        }
    }
}
