import StrongboxPurchases
import RevenueCat


@objcMembers
public class SBPaywallModel: ObservableObject {
    @Published public var monthlyProduct: Package?
    @Published public var yearlyProduct: Package?
    @Published public var isFreeTrialAvailable: Bool = false
    @Published public var error: Error?
    @Published public var paywallType: String?
    @Published var subtitleText: String?
    @Published var billingText: String?

    public init(
        paywallType: String?
    ) {
        self.paywallType = paywallType
        fetchProducts()
        checkFreeTrial()
    }

    
    public func fetchProducts() {
        RCStrongbox.loadAppStoreProducts { products, nsError in
            DispatchQueue.main.async {
                if let offering = RCStrongbox.currentOffering {
                    self.monthlyProduct = offering.monthly
                    self.yearlyProduct = offering.annual
                    
                    guard let ppm = self.yearlyProduct?.storeProduct.pricePerMonth,
                          let formattedPPM = self.yearlyProduct?.storeProduct.priceFormatter?.string(
                            from: ppm.decimalValue as NSNumber
                          ) else {
                        return
                    }
                    
                    let format = NSLocalizedString("paywall_just_a_month", comment: "")
                    self.subtitleText = String(
                        format: format,
                        formattedPPM
                    )

                    
                    if let yearlyPrice = self.yearlyProduct?.storeProduct.localizedPriceString {
                        let billingFormat = NSLocalizedString("paywall_billed_annually_fmt", comment: "%@ billed annually")
                        self.billingText = String(format: billingFormat, yearlyPrice)
                    }
                }
                if let error = nsError {
                    self.error = error
                }
            }
        }
    }

    
    public func checkFreeTrial() {
        isFreeTrialAvailable = RCStrongbox.isFreeTrialAvailable()
    }

    
    public func purchaseMonthly(onComplete: @escaping (NSError?) -> ()) {
        guard let product = monthlyProduct?.storeProduct.sk1Product else { return }
        RCStrongbox.purchaseProduct(product) { error in
            self.error = error
            onComplete(error)
        }
    }

    
    public func purchaseYearly(onComplete: @escaping (NSError?) -> ()) {
        guard let product = yearlyProduct?.storeProduct.sk1Product else { return }
        RCStrongbox.purchaseProduct(product) { error in
            self.error = error
            onComplete(error)
        }
    }

    public func restore(onComplete: @escaping (NSError?) -> ()) {
        RCStrongbox.restorePurchases { error in
            self.error = error
            onComplete(error)
        }
    }
}
