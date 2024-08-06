//
//  UnifiedUpgrade.swift
//  Mac-Unified-Freemium
//
//  Created by Strongbox on 14/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

public extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0 ..< elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                continue
            }
        }

        return path
    }
}

class EscapableWindow: NSWindow {
    override func cancelOperation(_: Any?) {
        close()
    }
}

class UnifiedUpgrade: NSViewController {
    @IBOutlet var buttonDismissSheet: NSButton!

    @IBOutlet var yearlyColumnStack: NSStackView!
    @IBOutlet var yearlyBackgroundView: NSView!
    @IBOutlet var monthlyBackgroundView: NSView!
    @IBOutlet var buttonNoThanks: ClickableTextField!
    @IBOutlet var yearlyFreeTrialBadge: NSView!
    @IBOutlet var buttonLifetime: ClickableTextField!
    @IBOutlet var buttonRestorePurchases: ClickableTextField!

    @IBOutlet var labelFreeTrial: NSTextField!
    @IBOutlet var labelMonthlyPrice: NSTextField!
    @IBOutlet var labelYearlyPrice: NSTextField!
    @IBOutlet var labelYearlySaving: NSTextField!

    @IBOutlet var buttonYearly: NSButton!
    @IBOutlet var buttonMonthly: NSButton!

    @IBOutlet var labelFreeTrialPromoText: NSTextField!
    @IBOutlet var labelMonthlyDummyFreeTrialText: NSTextField!

    @IBOutlet var labelPrivacy: ClickableTextField!
    @IBOutlet var labelTerms: ClickableTextField!

    @IBOutlet var labelDismiss: ClickableTextField!
    @objc var naggy: Bool = false
    @objc var isPresentedAsSheet: Bool = false

    var completion: (() -> Void)?

    @objc
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "UnifiedUpgrade", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    @objc func presentInNewWindow() {
        let window = naggy ? NSWindow(contentViewController: self) : EscapableWindow(contentViewController: self)

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = naggy

        view.window?.styleMask.remove(.miniaturizable)

        window.title = NSLocalizedString("mac_upgrade_button_title", comment: "Upgrade")
        window.makeKeyAndOrderFront(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let backgroundColor = NSColorFromRGB(0x2C2C2E)

        monthlyBackgroundView.wantsLayer = true
        monthlyBackgroundView.layer?.backgroundColor = backgroundColor.cgColor
        monthlyBackgroundView.layer?.cornerRadius = 10

        yearlyBackgroundView.wantsLayer = true
        yearlyBackgroundView.layer?.backgroundColor = backgroundColor.cgColor
        yearlyBackgroundView.layer?.cornerRadius = 10

        

        buttonDismissSheet.isHidden = !isPresentedAsSheet
        buttonDismissSheet.alphaValue = 0 
        labelDismiss.isHidden = !isPresentedAsSheet
        labelDismiss.onClick = { [weak self] in
            self?.dismissAndComplete()
        }

        

        buttonNoThanks.isHidden = !naggy || isPresentedAsSheet
        buttonNoThanks.onClick = { [weak self] in
            self?.dismissAndComplete()
        }

        buttonLifetime.onClick = { [weak self] in
            self?.onLifetime()
        }

        buttonRestorePurchases.onClick = { [weak self] in
            self?.onRestorePurchases()
        }

        labelTerms.onClick = { [weak self] in
            self?.onTerms()
        }
        labelPrivacy.onClick = { [weak self] in
            self?.onPrivacy()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        

        ProUpgradeIAPManager.sharedInstance().productsAvailableNotify = { [weak self] in
            self?.updatePrices()
        }

        updatePrices()
    }

    func updatePrices() {
        bindMonthlyPricing()
        bindYearlyPricing()
        customizeFreeTrialBadge()
    }

    func customizeFreeTrialBadge() {
        yearlyFreeTrialBadge.wantsLayer = true
        yearlyFreeTrialBadge.layer?.backgroundColor = NSColor.systemOrange.cgColor

        let bezierPath = NSBezierPath()



        let height = yearlyFreeTrialBadge.frame.height
        let width = yearlyFreeTrialBadge.frame.width

        let foo = height * 0.3

        bezierPath.move(to: NSPoint(x: 0, y: foo))
        bezierPath.line(to: NSPoint(x: width / 2, y: 0))
        bezierPath.line(to: NSPoint(x: width, y: foo))
        bezierPath.line(to: NSPoint(x: width, y: height))
        bezierPath.line(to: NSPoint(x: 0, y: height))

        bezierPath.lineJoinStyle = .round
        bezierPath.close()

        let mask = CAShapeLayer()
        mask.path = bezierPath.cgPath

        yearlyFreeTrialBadge.layer?.mask = mask
    }

    func bindMonthlyPricing() {
        let state = ProUpgradeIAPManager.sharedInstance().state

        labelMonthlyPrice.stringValue = NSLocalizedString("generic_loading", comment: "Loading...")
        buttonMonthly.isEnabled = false

        if let product = ProUpgradeIAPManager.sharedInstance().monthlyProduct, state == .ready {
            let priceText = getPriceString(product: product)
            let fmt = String(format: NSLocalizedString("upgrade_vc_price_per_month_fmt", comment: "%@ / month"), priceText)

            labelMonthlyPrice.stringValue = fmt
            buttonMonthly.isEnabled = true
        } else if state == .couldNotGetProducts {
            labelMonthlyPrice.stringValue = NSLocalizedString("upgrade_vc_price_not_currently_available", comment: "Unavailable... Check your network connection")
        }
    }

    func bindYearlyPricing() {
        let state = ProUpgradeIAPManager.sharedInstance().state

        labelYearlyPrice.stringValue = NSLocalizedString("generic_loading", comment: "Loading...")
        labelYearlySaving.stringValue = ""
        buttonYearly.isEnabled = false
        yearlyFreeTrialBadge.isHidden = !ProUpgradeIAPManager.sharedInstance().isFreeTrialAvailable
        labelFreeTrialPromoText.isHidden = !ProUpgradeIAPManager.sharedInstance().isFreeTrialAvailable
        labelMonthlyDummyFreeTrialText.isHidden = !ProUpgradeIAPManager.sharedInstance().isFreeTrialAvailable

        if let product = ProUpgradeIAPManager.sharedInstance().yearlyProduct, state == .ready {
            if let monthlyProduct = ProUpgradeIAPManager.sharedInstance().monthlyProduct {
                let percentSavings = calculatePercentageSavings(getEffectivePrice(product), getEffectivePrice(monthlyProduct), 12)
                labelYearlySaving.stringValue = String(format: NSLocalizedString("upgrade_vc_percentage_saving_fmt", comment: "(Save %@%%)"), String(percentSavings))
            }

            let priceText = getPriceString(product: product)
            let fmt = String(format: NSLocalizedString("upgrade_vc_price_per_year_fmt", comment: "%@ / year"), priceText)

            labelYearlyPrice.stringValue = fmt
            buttonYearly.isEnabled = true
        } else if state == .couldNotGetProducts {
            labelYearlyPrice.stringValue = NSLocalizedString("upgrade_vc_price_not_currently_available", comment: "Unavailable... Check your network connection")
        }
    }

    func calculatePercentageSavings(_ price: NSDecimalNumber, _ monthlyPrice: NSDecimalNumber, _ numberOfMonths: UInt64) -> Int32 {
        let div = NSDecimalNumber(mantissa: numberOfMonths, exponent: 0, isNegative: false)
        let monthlyCalculatedPrice = price.dividing(by: div)
        let oneHundred = NSDecimalNumber(mantissa: 100, exponent: 0, isNegative: false)
        let num = monthlyPrice.subtracting(monthlyCalculatedPrice).multiplying(by: oneHundred)

        let ret = num.dividing(by: monthlyPrice)

        return ret.int32Value
    }

    func getEffectivePrice(_ product: SKProduct) -> NSDecimalNumber {
        if let introPrice = product.introductoryPrice {
            if introPrice.price == NSDecimalNumber.zero {
                
                return product.price
            } else {
                return introPrice.price
            }
        }

        return product.price
    }

    func getPriceString(product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? NSLocalizedString("generic_error", comment: "Error")
    }

    func onTerms() {
        NSWorkspace.shared.open(URL(string: "https:
    }

    func onPrivacy() {
        NSWorkspace.shared.open(URL(string: "https:
    }

    func onLifetime() {
        NSWorkspace.shared.open(URL(string: "itms-apps:
    }

    func onRestorePurchases() {
        macOSSpinnerUI.sharedInstance().show(NSLocalizedString("upgrade_vc_progress_restoring", comment: "Restoring..."), viewController: self)
        enableButtons(false)

        ProUpgradeIAPManager.sharedInstance().restorePrevious { [weak self] error in
            swlog("✅ Restore purchases done: error = [%@]", String(describing: error))

            self?.enableButtons(true)
            macOSSpinnerUI.sharedInstance().dismiss()

            if let error {
                MacAlerts.error(NSLocalizedString("upgrade_vc_problem_restoring", comment: "Issue Restoring Purchase"), error: error, window: self?.view.window)
            } else {
                if !Settings.sharedInstance().isPro {
                    self?.tryRefreshReceiptRestore()
                } else {
                    self?.dismissAndComplete()
                }
            }
        }
    }

    func tryRefreshReceiptRestore() {
        swlog("Restore purchases didn't work... try to refresh receipt...")

        macOSSpinnerUI.sharedInstance().show(NSLocalizedString("upgrade_vc_progress_restoring", comment: "Restoring..."), viewController: self)
        enableButtons(false)

        ProUpgradeIAPManager.sharedInstance().refreshReceiptAndCheck {
            self.enableButtons(true)
            macOSSpinnerUI.sharedInstance().dismiss()

            if !Settings.sharedInstance().isPro {
                swlog("Refresh didn't work either...")

                DispatchQueue.main.async { [weak self] in
                    MacAlerts.info(NSLocalizedString("upgrade_vc_restore_unsuccessful_title", comment: "Restoration Unsuccessful"),
                                   informativeText: NSLocalizedString("upgrade_vc_restore_unsuccessful_message", comment: "Upgrade could not be restored from previous purchase. Are you sure you have purchased this item?"),
                                   window: self?.view.window,
                                   completion: nil)
                }
            } else {
                self.dismissAndComplete()
            }
        }
    }

    @IBAction func onYearly(_: Any) {
        if let product = ProUpgradeIAPManager.sharedInstance().yearlyProduct {
            purchase(product)
        }
    }

    @IBAction func onMonthly(_: Any) {
        if let product = ProUpgradeIAPManager.sharedInstance().monthlyProduct {
            purchase(product)
        }
    }

    func enableButtons(_ enable: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.buttonYearly.isEnabled = enable
            self?.buttonMonthly.isEnabled = enable
            self?.buttonRestorePurchases.isEnabled = enable
            self?.buttonRestorePurchases.textColor = enable ? .linkColor : .disabledControlTextColor
        }
    }

    func purchase(_ product: SKProduct) {
        if ProUpgradeIAPManager.sharedInstance().state != .ready {
            MacAlerts.info(NSLocalizedString("upgrade_vc_product_error_title", comment: "Product Error"),
                           informativeText: NSLocalizedString("upgrade_vc_product_error_message", comment: "Could not access Upgrade Products on App Store. Please try again later."),
                           window: view.window,
                           completion: nil)
        } else {
            macOSSpinnerUI.sharedInstance().show(NSLocalizedString("upgrade_vc_progress_purchasing", comment: "Purchasing..."), viewController: self)
            enableButtons(false)

            ProUpgradeIAPManager.sharedInstance().purchaseAndCheckReceipts(product) { [weak self] error in
                swlog("Purchase done => Error = [%@]", String(describing: error))

                self?.enableButtons(true)
                macOSSpinnerUI.sharedInstance().dismiss()

                if let error {
                    if let error = error as? SKError, error.code == SKError.Code.paymentCancelled {
                        swlog("User Cancelled")
                        return
                    }

                    DispatchQueue.main.async { [weak self] in
                        MacAlerts.error(error, window: self?.view.window)
                    }
                } else {
                    self?.dismissAndComplete()
                }
            }
        }
    }

    @IBAction func onDismiss(_: Any) {
        dismissAndComplete()
    }

    func dismissAndComplete() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.isPresentedAsSheet {
                self.dismiss(nil)
            } else {
                self.view.window?.close()
            }

            self.completion?()
        }
    }
}
