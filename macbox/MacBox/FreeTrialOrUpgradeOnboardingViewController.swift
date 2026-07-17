//
//  FreeTrialOrUpgradeOnboardingViewController.swift
//  MacBox
//
//  Created by Strongbox on 20/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import CryptoKit

class FreeTrialOrUpgradeOnboardingModule: OnboardingModule {
    var window: NSWindow? = nil
    var isAppModal: Bool = false

    var shouldDisplay: Bool {
        if Settings.sharedInstance().isPro {
            return false
        }

        if MacCustomizationManager.isUnifiedFreemiumBundle {
            guard let _ = ProUpgradeIAPManager.sharedInstance().yearlyProduct else {
                return false
            }
        }

        if Settings.sharedInstance().freeTrialOrUpgradeNudgeCount == 0 { 
            return true
        }

        var ProNudgeIntervalDays = 7 

        if Settings.sharedInstance().freeTrialOrUpgradeNudgeCount < 3 { 
            ProNudgeIntervalDays = 1
        }

        guard let dueDate = NSCalendar.current.date(byAdding: .day, value: ProNudgeIntervalDays, to: Settings.sharedInstance().lastFreeTrialOrUpgradeNudge) else {
            return false
        }

        swlog("Free Trial or Upgrade Nudge Due: [%@] - Nudge Count: [%lu]", String(describing: dueDate), Settings.sharedInstance().freeTrialOrUpgradeNudgeCount)

        let nudgeDue = dueDate.timeIntervalSinceNow < 0 

        return nudgeDue
    }

    func instantiateViewController(completion: @escaping (() -> Void)) -> NSViewController {
        let ret = FreeTrialOrUpgradeOnboardingViewController.fromStoryboard()

        ret.completion = completion

        return ret
    }
}

class FreeTrialOrUpgradeOnboardingViewController: NSViewController {
    @IBOutlet var labelLearnMore: ClickableTextField!
    @IBOutlet var labelTitle: NSTextField!
    @IBOutlet var labelSubtitle: NSTextField!
    @IBOutlet var buttonSubscribeToYearly: NSButton!
    @IBOutlet var labelPricing: NSTextField!

    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "FreeTrialOrUpgradeOnboarding", bundle: nil)

        let initial = storyboard.instantiateInitialController() as! Self

        return initial
    }

    var completion: (() -> Void)!

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.title = title ?? ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Settings.sharedInstance().freeTrialOrUpgradeNudgeCount += 1
        Settings.sharedInstance().lastFreeTrialOrUpgradeNudge = Date()

        if let product = ProUpgradeIAPManager.sharedInstance().yearlyProduct {
            let priceText = getPriceString(product: product)

            if !ProUpgradeIAPManager.sharedInstance().isFreeTrialAvailable {
                labelTitle.stringValue = NSLocalizedString("generic_upgrade_to_pro", comment: "Upgrade to Pro")
                labelSubtitle.stringValue = NSLocalizedString("upgrade_body_text", comment: "Upgrade to Strongbox Pro and enjoy all these great features")
                buttonSubscribeToYearly.title = NSLocalizedString("generic_upgrade_to_pro", comment: "Upgrade to Pro")
                let fmt = String(format: NSLocalizedString("upgrade_vc_price_per_year_fmt", comment: "%@ / year"), priceText)
                labelPricing.stringValue = fmt
            } else {
                let trialDuration = ProUpgradeIAPManager.sharedInstance().freeTrialDurationText()

                if let trialDuration, !trialDuration.isEmpty {
                    let messageFmt = NSLocalizedString(
                        "fwY-jx-AUt.title",
                        tableName: "FreeTrialOrUpgradeOnboarding",
                        value: "Strongbox includes %@ of Strongbox Pro for you to try, for free",
                        comment: ""
                    )
                    labelSubtitle.stringValue = String(format: messageFmt, trialDuration)

                    let redeemFmt = NSLocalizedString(
                        "iiH-ir-M2u.title",
                        tableName: "FreeTrialOrUpgradeOnboarding",
                        value: "Redeem Your %@ Free Trial",
                        comment: ""
                    )
                    buttonSubscribeToYearly.title = String(format: redeemFmt, trialDuration)
                } else {
                    labelSubtitle.stringValue = NSLocalizedString(
                        "generic_free_trial_available_message",
                        comment: "Strongbox includes a free trial of Pro for you to try"
                    )
                    buttonSubscribeToYearly.title = NSLocalizedString("generic_start_free_trial", comment: "Start Free Trial")
                }

                let fmt = String(format: NSLocalizedString("price_per_year_after_free_trial_fmt", comment: "Then %@ every year"), priceText)
                labelPricing.stringValue = fmt
            }
        } else { 
            labelTitle.stringValue = NSLocalizedString("generic_upgrade_to_pro", comment: "Upgrade to Pro")
            labelSubtitle.stringValue = NSLocalizedString("upgrade_body_text", comment: "Upgrade to Strongbox Pro and enjoy all these great features")
            buttonSubscribeToYearly.title = NSLocalizedString("generic_upgrade_to_pro", comment: "Upgrade to Pro")
            labelPricing.isHidden = true
            labelLearnMore.isHidden = true
        }

        labelLearnMore.onClick = onLearnMore
    }

    func getPriceString(product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? NSLocalizedString("generic_error", comment: "Error")
    }

    @IBAction func onRedeem(_: Any) {
        if let product = ProUpgradeIAPManager.sharedInstance().yearlyProduct {
            macOSSpinnerUI.sharedInstance().show(NSLocalizedString("upgrade_vc_progress_purchasing", comment: "Purchasing..."), viewController: self)

            ProUpgradeIAPManager.sharedInstance().purchaseAndCheckReceipts(product) { [weak self] error in
                DispatchQueue.main.async {
                    macOSSpinnerUI.sharedInstance().dismiss()

                    if let error {
                        if (error as NSError).code != SKError.paymentCancelled.rawValue {
                            swlog("⚠️ Purchase done with error = [%@]", String(describing: error))
                            MacAlerts.error(error, window: self?.view.window)
                        }
                    } else {
                        self?.dismissAndContinueOnboarding()
                    }
                }
            }
        } else {
            onLearnMore()

        }
    }

    @IBAction func onMaybeLater(_: Any?) {
        dismissAndContinueOnboarding()
    }

    func onLearnMore() {
        if MacCustomizationManager.isUnifiedFreemiumBundle {
            let vc = UnifiedUpgrade.fromStoryboard()

            vc.naggy = false
            vc.isPresentedAsSheet = true
            vc.completion = { [weak self] in
                self?.dismissAndContinueOnboarding()
            }

            presentAsSheet(vc)
        } else {
            UpgradeWindowController.show(0)
        }
    }

    func dismissAndContinueOnboarding() {
        swlog("dismissAndContinueOnboarding")

        completion()
    }
}
