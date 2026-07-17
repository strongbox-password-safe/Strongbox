import Foundation
import StoreKit
import RevenueCat

@objc public class RCStrongbox: NSObject {

    
    
    public enum ProductType: String {
        case monthly = "monthly"
        case yearly = "yearly"
        case lifetime = "lifetime"
    }

    private enum SBProductIdentifier: String {
        case lifetime = "com.markmcguill.strongbox.pro"
        case trial = "com.markmcguill.strongbox.ios.iap.freetrial"
    }

    enum Entitlement: String, CaseIterable {
        case pro = "pro"
    }

    

    private static var latestPurchaserInfo: CustomerInfo? = nil {
        didSet {
            guard latestPurchaserInfo != nil else { return }
            updateStatus()
        }
    }
    public static var currentOffering: Offering? = nil
    private static let syncInfoKey = "sync_info_key__"
    private static let restoreKey = "restore_info_key__"
    private static let defaultOfferingIdentifier = "default"

    
    public static var onSubscriptionUpdated: ((Bool) -> Void)?
    
    public static var onFetchComplete: (() -> Void)?

    private static var tipIdentifiers: [String] = []
    public static var tipProducts: [StoreProduct] = []

    
    @objc public static func initializeRevenueCat(
        key: String,
        tipIdentifiers: [String] = [],
        collectAdServicesAttribution: Bool = false
    ) {
        Purchases.configure(
            withAPIKey: key,
            appUserID: nil,
            purchasesAreCompletedBy: .revenueCat,
            storeKitVersion: .storeKit1
        )

        #if os(iOS)
        if collectAdServicesAttribution, #available(iOS 14.3, *) {
            Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()
        }
        #endif

        print("🐱 RevenueCat \(Purchases.shared.appUserID)")

        
        self.latestPurchaserInfo = Purchases.shared.cachedCustomerInfo
        print("🐱 Info at launch \(Purchases.shared.cachedCustomerInfo)")
        self.tipIdentifiers = tipIdentifiers

        Task {
            if !Purchases.shared.appUserID.contains("$RCAnonymousID") {
                
                
                
                _ = try? await Purchases.shared.logOut()
                UserDefaults.standard.set(false, forKey: restoreKey)
            }
            self.latestPurchaserInfo = try? await Purchases.shared.customerInfo()
            print("🐱 Info fetched \(self.latestPurchaserInfo)")
            self.syncPurchasesIfNeeded()
            self.fetchOfferings()
        }
    }
    
    
    
    private static func fetchOfferings() {
        Task(priority: .userInitiated) {
            self.tipProducts = await Purchases.shared.products(tipIdentifiers)
            print("🐱 Tips Fetched: \(tipProducts)")

            
            do {
                let offerings = try await Purchases.shared.offerings()
                currentOffering = offerings.current ?? offerings.offering(identifier: defaultOfferingIdentifier)
                print("🐱 Current offering fetched: \(currentOffering?.identifier ?? "none")")
            } catch {
                print("🐱 Error fetching offerings: \(error.localizedDescription)")
            }

            onFetchComplete?()
        }
    }
    
    @objc public static func loadAppStoreProducts(completion: @escaping ([SKProduct]?, NSError?) -> Void) {
        Purchases.shared.getOfferings { offerings, error in
            if let error = error {
                print("🐱 Error fetching offerings: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil, error as NSError)
                }
                return
            }
            
            if let offerings = offerings {
                currentOffering = offerings.current ?? offerings.offering(identifier: defaultOfferingIdentifier)
                
                if let offering = currentOffering {
                    let products = offering.availablePackages.compactMap { $0.storeProduct.sk1Product }
                    DispatchQueue.main.async {
                        completion(products, nil)
                    }
                } else {
                    let error = NSError(domain: "com.strongbox.revenueCat", 
                                       code: 1001, 
                                       userInfo: [NSLocalizedDescriptionKey: "No offerings available"])
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            } else {
                let error = NSError(domain: "com.strongbox.revenueCat", 
                                   code: 1000, 
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to fetch offerings"])
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    @objc public static func setProperties(
        props: [String: String]
    ) {
        Purchases.shared.attribution.setAttributes(props)
    }
    
    @objc public static func availableProducts() -> [String: SKProduct] {
        guard let offering = currentOffering else { return [:] }
        
        var products: [String: SKProduct] = [:]
        for package in offering.availablePackages {
            if let storeProduct = package.storeProduct.sk1Product {
                products[storeProduct.productIdentifier] = storeProduct
            }
        }

        return products
    }
    
    public static func getPackage(for productType: ProductType) -> Package? {
        guard let offering = currentOffering else { return nil }
    
        
        
        
        
        if let package = offering.package(identifier: productType.rawValue) {
            return package
        }
        
        
        switch productType {
        case .monthly:
            return offering.availablePackages.first(where: { $0.packageType == .monthly })
        case .yearly:
            return offering.availablePackages.first(where: { $0.packageType == .annual })
        case .lifetime:
            return offering.availablePackages.first(where: { $0.packageType == .lifetime })
        }
    }
    
    @objc public static func getProduct(for productType: String) -> SKProduct? {
        guard let type = ProductType(rawValue: productType) else { return nil }
        guard let package = getPackage(for: type) else { return nil }
        return package.storeProduct.sk1Product
    }

    

    @objc public static func isReceiptVerified() -> Bool {
        guard let _ = latestPurchaserInfo?.entitlements else { return false }
        return true
    }

    @objc public static func isActive() -> Bool {
        guard let entitlements = latestPurchaserInfo?.entitlements else { return false }
        let entitlementsKeys = Entitlement.allCases.map(\.rawValue)
        let isActive = entitlements.active.keys.contains { entitlementsKeys.contains($0) }
        return isActive || hasPurchasedLifeTime()
    }
    
    
    @objc public static func hasAnnualTrialEligibility() async -> Bool {
        guard let yearlyProduct = currentOffering?.annual else { return false }
        let status = await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: yearlyProduct.storeProduct)
        return status == .eligible
    }
    
    @objc public static func hasActiveYearlySubscription() -> Bool {
        guard let entitlements = latestPurchaserInfo?.entitlements else { return false }

        
        if let proEntitlement = entitlements.active[Entitlement.pro.rawValue],
           proEntitlement.productIdentifier.contains(ProductType.yearly.rawValue) {
            return true
        }
        
        return false
    }
    
    @objc public static func hasActiveMonthlySubscription() -> Bool {
        guard let entitlements = latestPurchaserInfo?.entitlements else { return false }
        
        
        if let proEntitlement = entitlements.active[Entitlement.pro.rawValue],
           proEntitlement.productIdentifier.contains(ProductType.monthly.rawValue) {
            return true
        }
        
        return false
    }
    
    @objc public static func hasPurchasedLifeTime() -> Bool {
        guard let entitlements = latestPurchaserInfo?.entitlements else { return false }
        
        
        if let proEntitlement = entitlements.active[Entitlement.pro.rawValue],
           proEntitlement.productIdentifier.contains(ProductType.lifetime.rawValue) {
            return true
        }

        
        if let proEntitlement = entitlements.active[Entitlement.pro.rawValue], [
            SBProductIdentifier.trial.rawValue,
            SBProductIdentifier.lifetime.rawValue
        ]
        .contains(proEntitlement.productIdentifier) {
            return true
        }

        
        if latestPurchaserInfo?.allPurchasedProductIdentifiers.contains("com.markmcguill.strongbox.pro") ?? false {
            return true
        }

        return false
    }
    
    @objc public static func currentSubscriptionRenewalOrExpiry() -> Date? {
        guard let info = latestPurchaserInfo else { return nil }
        
        
        return info.expirationDate(forEntitlement: Entitlement.pro.rawValue)
    }
    
    @objc public static func isFreeTrialAvailable() -> Bool {
        
        let yearlyPackage = getPackage(for: .yearly)
        let monthlyPackage = getPackage(for: .monthly)

        
        if let yearlyProduct = yearlyPackage?.storeProduct.sk1Product,
           let intro = yearlyProduct.introductoryPrice,
           intro.price.compare(NSDecimalNumber.zero) == .orderedSame {
            return true
        }

        if let monthlyProduct = monthlyPackage?.storeProduct.sk1Product,
           let intro = monthlyProduct.introductoryPrice,
           intro.price.compare(NSDecimalNumber.zero) == .orderedSame {
            return true
        }

        return false
    }

    
    
    @objc public static func freeTrialDurationText() -> String? {
        guard let yearlyPackage = getPackage(for: .yearly),
              let yearlyProduct = yearlyPackage.storeProduct.sk1Product,
              let intro = yearlyProduct.introductoryPrice,
              intro.paymentMode == .freeTrial || intro.price.compare(NSDecimalNumber.zero) == .orderedSame else {
            return nil
        }
        let period = intro.subscriptionPeriod

        return localizedDuration(from: period)
    }

    private static func localizedDuration(from period: SKProductSubscriptionPeriod) -> String? {
        guard period.numberOfUnits > 0 else { return nil }

        
        if period.numberOfUnits == 1 {
            return singularUnitName(for: period.unit)
        }

        
        let components = DateComponents(
            year: period.unit == .year ? period.numberOfUnits : nil,
            month: period.unit == .month ? period.numberOfUnits : nil,
            day: period.unit == .day ? period.numberOfUnits : nil,
            weekOfMonth: period.unit == .week ? period.numberOfUnits : nil
        )

        let allowedUnit: NSCalendar.Unit
        switch period.unit {
        case .day:
            allowedUnit = .day
        case .week:
            allowedUnit = .weekOfMonth
        case .month:
            allowedUnit = .month
        case .year:
            allowedUnit = .year
        @unknown default:
            return nil
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = allowedUnit
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1

        return formatter.string(from: components)
    }

    private static func singularUnitName(for unit: SKProduct.PeriodUnit) -> String {
        switch unit {
        case .day:
            return NSLocalizedString("duration_singular_day", comment: "day")
        case .week:
            return NSLocalizedString("duration_singular_week", comment: "week")
        case .month:
            return NSLocalizedString("duration_singular_month", comment: "month")
        case .year:
            return NSLocalizedString("duration_singular_year", comment: "year")
        @unknown default:
            return ""
        }
    }

    

    @objc public static func syncPurchasesIfNeeded() {
        let defaults = UserDefaults.standard

        Task(priority: .userInitiated) {
            if !defaults.bool(forKey: restoreKey) {
                print("🐱 Restoring Purchases")
                do {
                    let latestInfo = try await Purchases.shared.restorePurchases()
                    
                    
                    
                    defaults.set(true, forKey: restoreKey)
                    defaults.synchronize()
                    latestPurchaserInfo = latestInfo
                    _ = try? await Purchases.shared.syncPurchases()
                } catch { }
            } else {
                print("🐱 Skipping Restoring Purchases")
            }
            if !defaults.bool(forKey: syncInfoKey) {
                print("🐱 Syncing Purchases")
                do {
                    let latestInfo = try await Purchases.shared.syncPurchases()
                    latestPurchaserInfo = latestInfo
                    defaults.set(true, forKey: syncInfoKey)
                    defaults.synchronize()
                } catch {
                    print("🐱 Skipping Syncing Purchases")
                }
            }
            latestPurchaserInfo = (try? await Purchases.shared.customerInfo()) ?? latestPurchaserInfo
        }
    }

    enum SubscriptionStatusPush: Equatable {
        case push(pro: Bool)
        case suppress
    }

    
    
    
    static func statusPushDecision(isActive: Bool, hasCompletedRestore: Bool) -> SubscriptionStatusPush {
        if !isActive, !hasCompletedRestore {
            return .suppress
        }

        return .push(pro: isActive)
    }

    static func updateStatus() {
        
        
        let decision = statusPushDecision(isActive: isActive(),
                                          hasCompletedRestore: UserDefaults.standard.bool(forKey: restoreKey))

        switch decision {
        case .suppress:
            return
        case let .push(pro):
            onSubscriptionUpdated?(pro)
        }
    }

    

    @objc public static func restorePurchases(withCompletion completion: @escaping (NSError?) -> Void) {
        Purchases.shared.restorePurchases { purchaserInfo, error in
            Purchases.shared.syncPurchases { syncInfo, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(error as NSError)
                    } else {
                        if let info = syncInfo {
                            
                            
                            
                            UserDefaults.standard.set(true, forKey: restoreKey)
                            latestPurchaserInfo = info
                        }
                        completion(nil)
                    }
                }
            }
        }
    }

    
    @objc public static func purchaseProduct(_ product: SKProduct, completion: @escaping (NSError?) -> Void) {
        Purchases.shared.purchase(
            product: StoreProduct(sk1Product: product)
        ) { (transaction, purchaserInfo, error, cancelled) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error as NSError)
                } else {
                    if let info = purchaserInfo {
                        latestPurchaserInfo = info
                    }
                    completion(nil)
                }
            }
        }
    }
    
    @objc public static func purchasePackage(with productType: String, completion: @escaping (NSError?) -> Void) {
        guard let type = ProductType(rawValue: productType),
              let package = getPackage(for: type) else {
            let error = NSError(domain: "com.strongbox.revenueCat", 
                              code: 1002, 
                              userInfo: [NSLocalizedDescriptionKey: "Package not found for product type: \(productType)"])
            DispatchQueue.main.async {
                completion(error)
            }
            return
        }
        
        Purchases.shared.purchase(package: package) { (transaction, customerInfo, error, userCancelled) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error as NSError)
                } else {
                    if let info = customerInfo {
                        latestPurchaserInfo = info
                    }
                    completion(nil)
                }
            }
        }
    }
}
