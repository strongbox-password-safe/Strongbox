//
//  TipJarViewController.swift
//  MacBox
//
//  Created by Strongbox on 27/07/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class TipJarViewController: NSViewController {
    @IBOutlet var labelTerms: ClickableTextField!
    @IBOutlet var labelPrivacy: ClickableTextField!
    @IBOutlet var labelRestorePurchases: ClickableTextField!
    @IBOutlet var labelDismiss: ClickableTextField!

    @IBOutlet var buttonLittle: NSButton!
    @IBOutlet var buttonSmall: NSButton!
    @IBOutlet var buttonMedium: NSButton!
    @IBOutlet var buttonLarge: NSButton!
    @IBOutlet var buttonHuge: NSButton!
    @IBOutlet var buttonYearly: NSButton!
    @IBOutlet var buttonMonthly: NSButton!

    @objc
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "TipJar", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    @objc func presentInNewWindow() {
        let window = EscapableWindow(contentViewController: self)

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        view.window?.styleMask.remove(.miniaturizable)

        window.makeKeyAndOrderFront(self)
    }

    var originalLittleTitle: String = ""
    var originalSmallTitle: String = ""
    var originalMediumTitle: String = ""
    var originalLargeTitle: String = ""
    var originalHugeTitle: String = ""
    var originalMonthlyTitle: String = ""
    var originalYearlyTitle: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        labelTerms.onClick = { [weak self] in
            self?.onTerms()
        }
        labelPrivacy.onClick = { [weak self] in
            self?.onPrivacy()
        }
        labelDismiss.onClick = { [weak self] in
            self?.dismissWindow()
        }
        labelRestorePurchases.onClick = { [weak self] in
            self?.onRestorePurchases()
        }

        originalLittleTitle = buttonLittle.title
        originalSmallTitle = buttonSmall.title
        originalMediumTitle = buttonMedium.title
        originalLargeTitle = buttonLarge.title
        originalHugeTitle = buttonHuge.title
        originalMonthlyTitle = buttonMonthly.title
        originalYearlyTitle = buttonYearly.title

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
        buttonLittle.title = String(format: "%@ (%@)", originalLittleTitle, TipJarLogic.sharedInstance.getTipPrice(.little))
        buttonSmall.title = String(format: "%@ (%@)", originalSmallTitle, TipJarLogic.sharedInstance.getTipPrice(.small))
        buttonMedium.title = String(format: "%@ (%@)", originalMediumTitle, TipJarLogic.sharedInstance.getTipPrice(.medium))
        buttonLarge.title = String(format: "%@ (%@)", originalLargeTitle, TipJarLogic.sharedInstance.getTipPrice(.large))
        buttonHuge.title = String(format: "%@ (%@)", originalHugeTitle, TipJarLogic.sharedInstance.getTipPrice(.huge))
        buttonMonthly.title = String(format: "%@ (%@)", originalMonthlyTitle, TipJarLogic.sharedInstance.getTipPrice(.monthly))
        buttonYearly.title = String(format: "%@ (%@)", originalYearlyTitle, TipJarLogic.sharedInstance.getTipPrice(.annual))
    }

    let isPresentedAsSheet: Bool = false

    func dismissWindow() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.isPresentedAsSheet {
                self.dismiss(nil)
            } else {
                self.view.window?.close()
            }
        }
    }

    func onTerms() {
        NSWorkspace.shared.open(URL(string: "https:
    }

    func onPrivacy() {
        NSWorkspace.shared.open(URL(string: "https:
    }

    func enableButtons(_ enable: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.buttonLittle.isEnabled = enable
            self?.buttonSmall.isEnabled = enable
            self?.buttonMedium.isEnabled = enable
            self?.buttonLarge.isEnabled = enable
            self?.buttonHuge.isEnabled = enable
            self?.buttonMonthly.isEnabled = enable
            self?.buttonYearly.isEnabled = enable

            self?.labelRestorePurchases.isEnabled = enable
            self?.labelDismiss.isEnabled = enable

            self?.labelRestorePurchases.textColor = enable ? .linkColor : .disabledControlTextColor
            self?.labelDismiss.textColor = enable ? .linkColor : .disabledControlTextColor
        }
    }

    var purchaseInProgress: Bool = false
    @IBAction func onLittle(_: Any) {
        beginPurchase(.little)
    }

    @IBAction func onSmall(_: Any) {
        beginPurchase(.small)
    }

    @IBAction func onMedium(_: Any) {
        beginPurchase(.medium)
    }

    @IBAction func onLarge(_: Any) {
        beginPurchase(.large)
    }

    @IBAction func onHuge(_: Any) {
        beginPurchase(.huge)
    }

    @IBAction func onMonthly(_: Any) {
        beginPurchase(.monthly)
    }

    @IBAction func onYearly(_: Any) {
        beginPurchase(.annual)
    }

    func beginPurchase(_ tip: TipJarLogic.Tip) {
        if !TipJarLogic.sharedInstance.isLoaded || purchaseInProgress {
            return
        }

        macOSSpinnerUI.sharedInstance().show(nil, viewController: self)

        purchaseInProgress = true
        enableButtons(false)

        TipJarLogic.sharedInstance.purchase(tip, completion: onPurchaseCompleted(error:))
    }

    func onPurchaseCompleted(error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.onPurchaseCompletedInt(error: error)
        }
    }

    func onPurchaseCompletedInt(error: Error?) {
        macOSSpinnerUI.sharedInstance().dismiss()
        purchaseInProgress = false
        enableButtons(true)

        let nsError = error as NSError?

        if nsError != nil {
            if nsError?.code != SKError.Code.paymentCancelled.rawValue {
                MacAlerts.error(error, window: view.window)
            }
        } else if error != nil {
            MacAlerts.error(error, window: view.window)
        } else {
            MacAlerts.info(NSLocalizedString("tip_purchased_title", comment: "⭐️ Wow ⭐️"), informativeText: NSLocalizedString("tip_purchased_message", comment: "\n❤️ Thank you so much ❤️\n\nSending good vibes your way from everyone at Strongbox HQ!"), window: view.window, completion: { [weak self] in
                guard let self else { return }

                self.dismissWindow()
            })
        }
    }

    func onRestorePurchases() {
        macOSSpinnerUI.sharedInstance().show(NSLocalizedString("upgrade_vc_progress_restoring", comment: "Restoring..."), viewController: self)

        enableButtons(false)

        TipJarLogic.sharedInstance.restorePrevious { [weak self] error in
            self?.onPurchaseCompleted(error: error)
        }
    }
}
