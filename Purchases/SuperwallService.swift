import Foundation
import SuperwallKit
import StrongboxPurchases

@objc class SuperwallService: NSObject {
    @objc static let shared = SuperwallService()

    
    private var currentPaywallDelegate: PaywallPresenterDelegate?

    override init() {
        super.init()
        
        let options = SuperwallOptions()
        options.storeKitVersion = .storeKit1
        
        Superwall.configure(
            apiKey: "pk_yTiRdHMFQ4ZyM5HF2FZbo",
            purchaseController: SuperwallPurchaseController(),
            options: options
        )

        
        updateSubscriptionStatus(isPro: AppPreferences.sharedInstance().isPro)

        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionStatusChanged(_:)),
            name: NSNotification.Name("SubscriptionStatusChangedNotification"),
            object: nil
        )
    }

    @objc
    static func configure() {
        _ = shared
    }

    @objc private func subscriptionStatusChanged(_ notification: Notification) {
        let isPro = notification.userInfo?["isPro"] as? Bool ?? false
        updateSubscriptionStatus(isPro: isPro)
    }

    private func updateSubscriptionStatus(isPro: Bool) {
        Superwall.shared.subscriptionStatus = isPro ? .active([Entitlement(id: "pro")]) : .inactive
    }
    
    @objc
    func present(
        campaign: SuperwallCampaign,
        completion: @escaping (Bool) -> Void
    ) {
        Superwall.shared.register(placement: campaign.campaignValue, handler: nil)
    }

    
    
    @objc
    func presentPaywall(
        from viewController: UIViewController,
        campaign: SuperwallCampaign,
        completion: @escaping (Bool) -> Void
    ) {
        
        let delegate = PaywallPresenterDelegate { [weak self] subscribed in
            self?.currentPaywallDelegate = nil
            completion(subscribed)
        }
        currentPaywallDelegate = delegate

        Superwall.shared.getPaywall(
            forPlacement: campaign.campaignValue,
            params: nil,
            paywallOverrides: nil,
            delegate: delegate
        ) { [weak self] paywall, skippedReason, error in
            DispatchQueue.main.async {
                if let paywall = paywall {
                    
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        paywall.modalPresentationStyle = .fullScreen
                    }
                    viewController.present(paywall, animated: true)
                } else {
                    
                    self?.currentPaywallDelegate = nil

                    if let skippedReason = skippedReason {
                        swlog("Superwall paywall skipped for \(campaign.campaignValue): \(skippedReason)")
                    }
                    if let error = error {
                        swlog("Superwall paywall error for \(campaign.campaignValue): \(error)")
                    }
                    
                    completion(false)
                }
            }
        }
    }
}


private class PaywallPresenterDelegate: NSObject, PaywallViewControllerDelegate {
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func paywall(
        _ paywall: PaywallViewController,
        didFinishWith result: PaywallResult,
        shouldDismiss: Bool
    ) {
        let subscribed: Bool
        switch result {
        case .purchased, .restored:
            subscribed = true
        case .declined:
            subscribed = false
        }

        if shouldDismiss {
            paywall.dismiss(animated: true) { [weak self] in
                self?.completion(subscribed)
            }
        } else {
            completion(subscribed)
        }
    }

    func paywall(
        _ paywall: PaywallViewController,
        loadingStateDidChange loadingState: PaywallLoadingState
    ) {
        
    }
}

class SuperwallPurchaseController: PurchaseController {
    func purchase(product: SuperwallKit.StoreProduct) async -> SuperwallKit.PurchaseResult {
        guard let product = product.sk1Product else {
            return .cancelled
        }
        
        do {
            try await ProUpgradeIAPManager.sharedInstance().purchaseAndCheckReceipts(product)
            return .purchased
        } catch let error {
            return .failed(error)
        }
    }
    
    func restorePurchases() async -> SuperwallKit.RestorationResult {
        do {
            try await ProUpgradeIAPManager.sharedInstance().restorePrevious()
            return .restored
        } catch let error {
            return .failed(error)
        }
    }
}

@objc enum SuperwallCampaign: Int {
    case settings
    case onboarding
    case nudge
    
    var campaignValue: String {
        switch self {
        case .settings: return "Settings"
        case .onboarding: return "Onboarding"
        case .nudge: return "Nudge"
        }
    }
}
