//
//  MacOnboardingManager.swift
//  MacBox
//
//  Created by Strongbox on 16/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

protocol OnboardingModule {
    var shouldDisplay : Bool { get }
    func instantiateViewController ( completion : @escaping (() -> Void)) -> NSViewController
}

class MacOnboardingManager: NSObject {
    static var window : OnboardingWindow? = nil

    @objc class func beginAppOnboarding ( completion : @escaping () -> Void ) {
        let modules : [OnboardingModule] = [ 
            OnboardingModules.getFirstRunWelcomeModule(),
            FreeTrialOrUpgradeOnboardingModule (),
            OnboardingModules.getHasBeenDowngradedModule() 
        ]
        
        if let window = window {
            window.onboardingDoneCompletion = nil
            window.close()
        }
        window = nil

        showNextModule(modules: modules, index: 0, onboardingDoneCompletion: completion )
    }
    
    class func showNextModule ( modules : [OnboardingModule], index : Int, onboardingDoneCompletion : @escaping () -> Void ) {
        if let module = modules[safe: index] {
            if module.shouldDisplay {
                let vc = module.instantiateViewController {
                    showNextModule(modules: modules, index: index + 1, onboardingDoneCompletion: onboardingDoneCompletion )
                }
                
                if let window = window {
                    window.contentViewController = vc
                }
                else {
                    window = OnboardingWindow.createOnboardingWindow(vc: vc, onboardingDoneCompletion: onboardingDoneCompletion )
                }

                window?.center()
            }
            else {
                showNextModule(modules: modules, index: index + 1, onboardingDoneCompletion: onboardingDoneCompletion)
            }
        }
        else {
            if let window = window {
                window.close()
            }
            else {
                onboardingDoneCompletion() 
            }
        }
    }
}
