//
//  TipJarViewController.swift
//  Strongbox
//
//  Created by Strongbox on 26/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

class TipJarViewController: UITableViewController {
    @IBOutlet var cellMonthlyTip: UITableViewCell!
    @IBOutlet var cellAnnualTip: UITableViewCell!

    @IBOutlet var cellLittleTip: UITableViewCell!
    @IBOutlet var cellSmallTip: UITableViewCell!
    @IBOutlet var cellMedium: UITableViewCell!
    @IBOutlet var cellLarge: UITableViewCell!
    @IBOutlet var cellHuge: UITableViewCell!

    @IBOutlet var littleTipPrice: UILabel!
    @IBOutlet var smallTipPrice: UILabel!
    @IBOutlet var mediumTipPrice: UILabel!
    @IBOutlet var largePrice: UILabel!
    @IBOutlet var hugePrice: UILabel!

    @IBOutlet var monthlyPrice: UILabel!
    @IBOutlet var annualPrice: UILabel!

    @IBOutlet var cellTermsOfUse: UITableViewCell!
    @IBOutlet var cellPrivacyPolicy: UITableViewCell!

    @IBOutlet var cellRestore: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()

        bindPrices()

        TipJarLogic.sharedInstance.refresh()

        NotificationCenter.default.addObserver(forName: .Tips.loaded, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.bindPrices()
            }
        }
    }

    func bindPrices() {
        littleTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.little)
        smallTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.small)
        mediumTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.medium)
        largePrice.text = TipJarLogic.sharedInstance.getTipPrice(.large)
        hugePrice.text = TipJarLogic.sharedInstance.getTipPrice(.huge)
        monthlyPrice.text = TipJarLogic.sharedInstance.getTipPrice(.monthly)
        annualPrice.text = TipJarLogic.sharedInstance.getTipPrice(.annual)
    }

    var purchaseInProgress: Bool = false
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if !TipJarLogic.sharedInstance.isLoaded || purchaseInProgress {
            return
        }

        let cell = tableView.cellForRow(at: indexPath)

        if cell == cellMonthlyTip {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.monthly, completion: onPurchaseCompleted)
        } else if cell == cellAnnualTip {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.annual, completion: onPurchaseCompleted)
        } else if cell == cellLittleTip {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.little, completion: onPurchaseCompleted)
        } else if cell == cellSmallTip {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.small, completion: onPurchaseCompleted)
        } else if cell == cellMedium {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.medium, completion: onPurchaseCompleted)
        } else if cell == cellLarge {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.large, completion: onPurchaseCompleted)
        } else if cell == cellHuge {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.purchase(.huge, completion: onPurchaseCompleted)
        } else if cell == cellRestore {
            iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
            purchaseInProgress = true

            TipJarLogic.sharedInstance.restorePrevious(completion: onPurchaseCompleted)
        } else if cell == cellPrivacyPolicy {
            let url = URL(string: "https:
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if cell == cellTermsOfUse {
            let url = URL(string: "https:
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func onPurchaseCompleted(error: Error?) {
        iOSSpinnerUI.sharedInstance().dismiss()
        purchaseInProgress = false

        let nsError = error as NSError?

        if nsError != nil {
            if nsError?.code != SKError.Code.paymentCancelled.rawValue {
                Alerts.error(self, error: error)
            }
        } else if error != nil {
            Alerts.error(self, error: error)
        } else {
            Alerts.info(self,
                        title: NSLocalizedString("tip_purchased_title", comment: "⭐️ Wow ⭐️"),
                        message: NSLocalizedString("tip_purchased_message", comment: "\n❤️ Thank you so much ❤️\n\nSending good vibes your way from everyone at Strongbox HQ!"),
                        completion: { [weak self] in
                            guard let self else { return }

                            self.dismiss(animated: true, completion: nil)
                        })
        }
    }

    @IBAction func onCancel(_: Any) {
        dismiss(animated: true, completion: nil)
    }
}
