//
//  TipJarViewController.swift
//  Strongbox
//
//  Created by Strongbox on 26/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation


class TipJarViewController : UITableViewController {
    @IBOutlet weak var cellMonthlyTip: UITableViewCell!
    @IBOutlet weak var cellAnnualTip: UITableViewCell!
    
    @IBOutlet weak var cellLittleTip: UITableViewCell!
    @IBOutlet weak var cellSmallTip: UITableViewCell!
    @IBOutlet weak var cellMedium: UITableViewCell!
    @IBOutlet weak var cellLarge: UITableViewCell!
    @IBOutlet weak var cellHuge: UITableViewCell!
    
    @IBOutlet weak var littleTipPrice: UILabel!
    @IBOutlet weak var smallTipPrice: UILabel!
    @IBOutlet weak var mediumTipPrice: UILabel!
    @IBOutlet weak var largePrice: UILabel!
    @IBOutlet weak var hugePrice: UILabel!
    
    @IBOutlet weak var monthlyPrice: UILabel!
    @IBOutlet weak var annualPrice: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindPrices()
        
        NotificationCenter.default.addObserver(forName: .Tips.loaded, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.bindPrices()
            }
        }
    }
    
    func bindPrices () {
        littleTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.little)
        smallTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.small)
        mediumTipPrice.text = TipJarLogic.sharedInstance.getTipPrice(.medium)
        largePrice.text = TipJarLogic.sharedInstance.getTipPrice(.large)
        hugePrice.text = TipJarLogic.sharedInstance.getTipPrice(.huge)
        monthlyPrice.text = TipJarLogic.sharedInstance.getTipPrice(.monthly)
        annualPrice.text = TipJarLogic.sharedInstance.getTipPrice(.annual)
    }
    
    var purchaseInProgress : Bool = false
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if ( !TipJarLogic.sharedInstance.isLoaded || purchaseInProgress ) {
            return
        }
        
        let cell = tableView.cellForRow(at: indexPath)
        
        iOSSpinnerUI.sharedInstance().show(nil, viewController: self)
        purchaseInProgress = true
        
        if ( cell == cellMonthlyTip ) {
            TipJarLogic.sharedInstance.purchase(.monthly, completion: onPurchaseCompleted)
        }
        else if ( cell == cellAnnualTip ) {
            TipJarLogic.sharedInstance.purchase(.annual, completion: onPurchaseCompleted)
        }
        else if ( cell == cellLittleTip ) {
            TipJarLogic.sharedInstance.purchase(.little, completion: onPurchaseCompleted)
        }
        else if ( cell == cellSmallTip ) {
            TipJarLogic.sharedInstance.purchase(.small, completion: onPurchaseCompleted)
        }
        else if ( cell == cellMedium ) {
            TipJarLogic.sharedInstance.purchase(.medium, completion: onPurchaseCompleted)
        }
        else if ( cell == cellLarge ) {
            TipJarLogic.sharedInstance.purchase(.large, completion: onPurchaseCompleted)
        }
        else if ( cell == cellHuge ) {
            TipJarLogic.sharedInstance.purchase(.huge, completion: onPurchaseCompleted)
        }
    }
    
    func onPurchaseCompleted ( error : Error? ) {
        iOSSpinnerUI.sharedInstance().dismiss()
        purchaseInProgress = false
        
        let nsError = error as NSError?
        
        if ( nsError != nil ) {
            if ( nsError?.code != SKError.Code.paymentCancelled.rawValue ) {
                Alerts.error(self, error: error)
            }
        }
        else if ( error != nil ) {
            Alerts.error(self, error: error)
        }
        else {
            Alerts.info(self,
                        title: NSLocalizedString("tip_purchased_title", comment: "⭐️ Wow ⭐️"),
                        message: NSLocalizedString("tip_purchased_message", comment:"\n❤️ Thank you so much ❤️\n\nSending good vibes your way from everyone at Strongbox HQ!"),
                        completion: { [weak self] in
                guard let self = self else { return }

                self.dismiss(animated: true, completion: nil)
            })
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
