//
//  TipJarLogic.swift
//  Strongbox
//
//  Created by Strongbox on 27/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#if !os(macOS)
    import UIKit
#endif

#if canImport(StrongboxPurchases)
import StrongboxPurchases
#endif

extension Notification.Name {
    enum Tips {
        static let loaded = Notification.Name("TipsLoadedNotification")
    }
}

class TipJarLogic: NSObject {
    enum Tip: String, CaseIterable {
        case monthly = "tip.monthly"
        case annual = "tip.yearly"
        case little = "tip.little"
        case small = "tip.small"
        case medium = "tip.medium"
        case large = "tip.large"
        case huge = "tip.huge"
    }

    @objc
    static let sharedInstance = TipJarLogic()

    private var appStoreProducts: [Tip: SKProduct] = [:]

    override private init() {
        super.init()

        DispatchQueue.global().async {
            self.loadTips()
        }
    }

    @objc
    public func refresh() {
        loadTips()
    }

    @objc
    var isLoaded: Bool = false {
        didSet {
            notifyLoaded()
        }
    }

    private var errorLoading: Bool = false

    func notifyLoaded() {
        NotificationCenter.default.post(name: .Tips.loaded, object: nil)
    }

    func getProductId(_ tip: Tip) -> String {
        #if !os(macOS)
            if CustomizationManager.isAProBundle { 
                return String(format: "pro.%@", tip.rawValue)
            } else {
                return tip.rawValue
            }
        #else
            if MacCustomizationManager.supportsTipJar { 
                if MacCustomizationManager.isAProBundle { 
                    return String(format: "pro.%@", tip.rawValue)
                } else {
                    return tip.rawValue
                }
            } else {
                swlog("🔴 Tips not available on macOS standalone bundles!!")
                return tip.rawValue
            }
        #endif
    }

    private func loadTips() {
        guard StrongboxProductBundle.supportsTipJar else {
            swlog("🔴 Tips not available in this bundle! Don't call this from this bundle!")
            errorLoading = true
            return
        }

        #if canImport(StrongboxPurchases)
        let products = RCStrongbox.tipProducts
        if products.isEmpty {
            print("💰 TipJar Error")
            self.errorLoading = true
            return
        }

        print("💰 TipJar Products \(products)")


        self.appStoreProducts = products.reduce(into: [Tip: SKProduct]()) { partialResult, product in
            let p: SKProduct = product.sk1Product!

            var pid: String = p.productIdentifier
            if pid.starts(with: "pro.") {
                let index = pid.index(pid.startIndex, offsetBy: 4)
                pid = String(pid[index...])
            }

            let tip = Tip(rawValue: pid)

            if tip != nil {
                partialResult[tip!] = p
            }
        }

        print("💰 TipJar Dict \(appStoreProducts)")
        self.errorLoading = false
        self.isLoaded = true
        #else
        let productIds = Tip.allCases.map { tip in
                   getProductId(tip)
               }

               RMStore.default().requestProducts(Set(productIds)) { [weak self] products, invalidProducts in
                   guard let self else { return }

                   if invalidProducts != nil, !invalidProducts!.isEmpty {
                       swlog("Got Invalid Tips = [%@]", invalidProducts ?? "nil")
                   }

                   guard let ps = products else {
                       swlog("🔴 WARNWARN: Nil Tip Products Returned from App Store")
                       self.errorLoading = true
                       return
                   }

                   self.appStoreProducts = ps.reduce(into: [Tip: SKProduct]()) { partialResult, product in
                       let p: SKProduct = product as! SKProduct

                       var pid: String = p.productIdentifier
                       if pid.starts(with: "pro.") {
                           let index = pid.index(pid.startIndex, offsetBy: 4)
                           pid = String(pid[index...])
                       }

                       let tip = Tip(rawValue: pid)

                       if tip != nil {
                           partialResult[tip!] = p
                       }
                   }

                   self.isLoaded = true
               } failure: { [weak self] error in
                   guard let self else { return }

                   let err = error as NSError?
                   if err != nil {
                       swlog("🔴 WARNWARN: Error getting Tips Products: [%@]", err!)
                   }

                   

                   self.errorLoading = true
               }
        #endif
    }

    func getTipPrice(_ tip: Tip) -> String {
        if errorLoading {
            return NSLocalizedString("generic_error", comment: "Error")
        }

        guard let product = appStoreProducts[tip] else {
            return NSLocalizedString("generic_loading", comment: "Loading...")
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale

        let localCurrency = formatter.string(from: product.price) ?? NSLocalizedString("generic_error", comment: "Error")

        return localCurrency
    }

    func purchase(_ tip: Tip, completion: @escaping (_ error: Error?) -> Void) {
        if !SKPaymentQueue.canMakePayments() {
            let errorMessage = NSLocalizedString("upgrade_mgr_purchases_are_disabled", comment: "Purchases are disabled on your device.")
            let error = Utils.createNSError(errorMessage, errorCode: -1)
            completion(error)
            return
        }
        #if canImport(StrongboxPurchases)
        let identifier = getProductId(tip)
        guard let product = RCStrongbox.tipProducts.first(where: { $0.productIdentifier == identifier })?.sk1Product else {
            let errorMessage = "Unable to purchase" 
            let error = Utils.createNSError(errorMessage, errorCode: -1)
            completion(error)
            return
        }

        RCStrongbox.purchaseProduct(product) { error in
            if let error {
                swlog("Something went wrong: error = [%@]", error.localizedDescription)
                completion(error)
            } else {
                completion(nil)
            }
        }
        #else
        if !SKPaymentQueue.canMakePayments() {
                   let errorMessage = NSLocalizedString("upgrade_mgr_purchases_are_disabled", comment: "Purchases are disabled on your device.")
                   let error = Utils.createNSError(errorMessage, errorCode: -1)
                   completion(error)
                   return
               }

               RMStore.default().addPayment(getProductId(tip)) { transaction in
                   swlog("Product purchased: [%@]", transaction!)
                   completion(nil)
               } failure: { transaction, error in
                   swlog("Something went wrong: [%@] error = [%@]", transaction ?? "nil", error?.localizedDescription ?? "nil")
                   completion(error)
               }
        #endif
    }

    func restorePrevious(completion: @escaping (_ error: Error?) -> Void) {
        #if canImport(StrongboxPurchases)
        RCStrongbox.restorePurchases { error in
            if let error {
                swlog("Something went wrong: error = [%@]", error.localizedDescription)
                completion(error)
            } else {
                completion(nil)
            }
        }
        #else
        RMStore.default().restoreTransactions { _ in
                   swlog("Transactions Restoreed!")
                   completion(nil)
               } failure: { error in
                   swlog("Something went wrong: error = [%@]", error?.localizedDescription ?? "nil")
                   completion(error)
               }
        #endif
    }
}
