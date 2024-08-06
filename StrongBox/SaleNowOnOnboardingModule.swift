//
//  SaleNowOnOnboardingModule.swift
//  Strongbox
//
//  Created by Strongbox on 13/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

@objc
public class SaleNowOnOnboardingModule: NSObject, OnboardingModule {
    public required init(model _: Model?) {}

    public func shouldDisplay() -> Bool {
        let existingSubscriber = false 

        let nonePro = !AppPreferences.sharedInstance().isPro
        let saleNowOn = SaleScheduleManager.sharedInstance().saleNowOn
        let hasBeenPrompted = SaleScheduleManager.sharedInstance().userHasBeenPromptedAboutCurrentSale

        return !CustomizationManager.isAProBundle && saleNowOn && !hasBeenPrompted && (existingSubscriber || nonePro)
    }

    public func instantiateViewController(_ onDone: @escaping OnboardingModuleDoneBlock) -> VIEW_CONTROLLER_PTR? {
        let existingSubscriber = false 

        guard let sale = SaleScheduleManager.sharedInstance().currentSale else {
            return nil
        }

        let vcc = SwiftUIViewFactory.makeSaleOfferViewController(sale: sale,
                                                                 existingSubscriber: existingSubscriber)
        {
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

    func showLifetimePurchaseScreen() {
        let vc = SKStoreProductViewController()

        vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: NSNumber(value: 1_481_853_033)])

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
           let viewController = appDelegate.getVisibleViewController()
        {
            viewController.present(vc, animated: true)
        } else {
            swlog("🔴 Could find a view controller to present on!")
        }
    }
}
