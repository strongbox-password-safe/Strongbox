import Foundation
import StoreKit
import RevenueCat

@objc public class RCStrongbox: NSObject {

    
    
    public enum ProductType: String {
        case monthly = "monthly"
        case yearly = "yearly"
        case lifetime = "lifetime"
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
    private static var currentOffering: Offering? = nil
    private static let syncInfoKey = "sync_info_key_"
    private static let restoreKey = "restore_info_key_"
    private static let defaultOfferingIdentifier = "default"
    
    
    public static var onSubscriptionUpdated: ((Bool) -> Void)?
    
    public static var onFetchComplete: (() -> Void)?

    private static var tipIdentifiers: [String] = []
    public static var tipProducts: [StoreProduct] = []

    
    @objc public static func initializeRevenueCat(
        key: String,
        tipIdentifiers: [String] = []
    ) {
        Purchases.configure(
            withAPIKey: key,
            appUserID: UserIdentifier.id, 
            purchasesAreCompletedBy: .revenueCat,
            storeKitVersion: .storeKit1
        )

        print("🐱 Identifier \(UserIdentifier.id)")
        print("🐱 RevenueCat \(Purchases.shared.appUserID)")

        self.tipIdentifiers = tipIdentifiers

        Task {
            self.latestPurchaserInfo = try? await Purchases.shared.logIn(UserIdentifier.id).customerInfo
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
    
    private static func getPackage(for productType: ProductType) -> Package? {
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
        return isActive
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
            "com.markmcguill.strongbox.ios.iap.freetrial",
            "com.markmcguill.strongbox.pro"
        ]
        .contains(proEntitlement.productIdentifier) {
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

    

    @objc public static func syncPurchasesIfNeeded() {
        let defaults = UserDefaults.standard

        Task(priority: .userInitiated) {
            if !defaults.bool(forKey: restoreKey) {
                print("🐱 Restoring Purchases")
                do {
                    let latestInfo = try await Purchases.shared.restorePurchases()
                    latestPurchaserInfo = latestInfo
                    defaults.set(true, forKey: restoreKey)
                    defaults.synchronize()
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

    static func updateStatus() {
        let entitlementsKeys = Entitlement.allCases.map(\.rawValue)
        let isEntitled = latestPurchaserInfo?.entitlements.active.keys.contains(where: { entitlementsKeys.contains($0) })
        onSubscriptionUpdated?(isEntitled ?? false)
    }

    

    @objc public static func restorePurchases(withCompletion completion: @escaping (NSError?) -> Void) {
        Purchases.shared.restorePurchases { purchaserInfo, error in
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
