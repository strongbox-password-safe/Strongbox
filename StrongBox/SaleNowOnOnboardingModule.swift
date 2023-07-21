//
//  SaleNowOnOnboardingModule.swift
//  Strongbox
//
//  Created by Strongbox on 13/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

@objc
public class SaleNowOnOnboardingModule : NSObject, OnboardingModule {
    public required init(model: Model?) {
        
    }
    
    public func shouldDisplay() -> Bool {
        let existingSubscriber = ProUpgradeIAPManager.sharedInstance().hasActiveYearlySubscription 
        let nonePro = !AppPreferences.sharedInstance().isPro
        let saleNowOn = SaleScheduleManager.sharedInstance().saleNowOn;
        let hasBeenPrompted = SaleScheduleManager.sharedInstance().userHasBeenPromptedAboutCurrentSale

        return !CustomizationManager.isAProBundle && saleNowOn && !hasBeenPrompted && (existingSubscriber || nonePro)
    }
        
    public func instantiateViewController(_ onDone: @escaping OnboardingModuleDoneBlock) -> VIEW_CONTROLLER_PTR? {
        let existingSubscriber = ProUpgradeIAPManager.sharedInstance().hasActiveYearlySubscription;
        
        guard let saleEndDate = SaleScheduleManager.sharedInstance().currentSaleEndDate,
              let inclusiveEndDate = Calendar.current.date(byAdding: .day, value: -1, to: saleEndDate) else {
            return nil
        }
        
        let vcc = SwiftUIViewFactory.makeSaleOfferViewController(saleEndDate: inclusiveEndDate,
                                                              existingSubscriber: existingSubscriber) {
            SaleScheduleManager.sharedInstance().userHasBeenPromptedAboutCurrentSale = true
            SKPaymentQueue.default().presentCodeRedemptionSheet()
            onDone(false, true)
        } onLifetimeHandler: { [weak self] in
            self?.showLifetimePurchaseScreen()
            onDone(false, true)
            SaleScheduleManager.sharedInstance().userHasBeenPromptedAboutCurrentSale = true
        } dismissHandler: {
            SaleScheduleManager.sharedInstance().userHasBeenPromptedAboutCurrentSale = true
            onDone(false, false)
        }
        
        return vcc
    }

    func showLifetimePurchaseScreen ( ) {
        let vc = SKStoreProductViewController()
     
        vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier : NSNumber(value: 1481853033)])
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let viewController = appDelegate.getVisibleViewController() {

            viewController.present(vc, animated: true)
        }
        else {
            NSLog("🔴 Could find a view controller to present on!")
        }
    }
}
