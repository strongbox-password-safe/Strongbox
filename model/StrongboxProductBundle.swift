//
//  StrongboxProductBundle.swift
//  MacBox
//
//  Created by Strongbox on 13/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc
public class StrongboxProductBundle: NSObject {
    enum BundleIdentifiers: String {
        case unifiedFreemium = "com.markmcguill.strongbox"
        case unifiedPro = "com.markmcguill.strongbox.pro"
        case business = "com.markmcguill.strongbox.business"
        case zero = "com.markmcguill.strongbox.graphene"
        case scotus = "com.markmcguill.strongbox.scotus"
        case macOSStandaloneFreemium = "com.markmcguill.strongbox.mac"
        case macOSStandalonePro = "com.markmcguill.strongbox.mac.pro"

        var isPro: Bool {
            switch self {
            case .unifiedFreemium:
                return false
            case .unifiedPro:
                return true
            case .business:
                return true
            case .zero:
                return true
            case .scotus:
                return true
            case .macOSStandaloneFreemium:
                return false
            case .macOSStandalonePro:
                return true
            }
        }

        var supportsTipJar: Bool {
            switch self {
            case .unifiedFreemium:
                return true
            case .unifiedPro:
                return true
            case .business:
                return false
            case .zero:
                return false
            case .scotus:
                return false
            case .macOSStandaloneFreemium:
                return false
            case .macOSStandalonePro:
                return false
            }
        }

        var supports3rdPartyStorageProviders: Bool {
            switch self {
            case .unifiedFreemium:
                return true
            case .unifiedPro:
                return true
            case .business:
                return true
            case .zero:
                return false
            case .scotus:
                return false
            case .macOSStandaloneFreemium:
                return true
            case .macOSStandalonePro:
                return true
            }
        }

        var supportsWiFiSync: Bool {
            switch self {
            case .unifiedFreemium:
                return true
            case .unifiedPro:
                return true
            case .business:
                return true
            case .zero:
                return false
            case .scotus:
                return false
            case .macOSStandaloneFreemium:
                return true
            case .macOSStandalonePro:
                return true
            }
        }

        var supportsSftpWebDAV: Bool {
            switch self {
            case .unifiedFreemium:
                return true
            case .unifiedPro:
                return true
            case .business:
                return true
            case .zero:
                return false
            case .scotus:
                return false
            case .macOSStandaloneFreemium:
                return true
            case .macOSStandalonePro:
                return true
            }
        }

        var supportsFavIconDownloader: Bool {
            switch self {
            case .unifiedFreemium:
                return true
            case .unifiedPro:
                return true
            case .business:
                return true
            case .zero:
                return false
            case .scotus:
                return false
            case .macOSStandaloneFreemium:
                return true
            case .macOSStandalonePro:
                return true
            }
        }

        var displayName: String {
            switch self {
            case .unifiedFreemium:
                return "Universal (macOS & iOS, Freemium)"
            case .unifiedPro:
                return "Universal (macOS & iOS, Outright Pro)"
            case .business:
                return "Universal (macOS & iOS, Business Pro)"
            case .zero:
                return "Zero"
            case .scotus:
                return "SCOTUS"
            case .macOSStandaloneFreemium:
                return "Non-Universal (macOS only, Freemium)"
            case .macOSStandalonePro:
                return "Non-Universal (macOS only, Outright Pro)"
            }
        }
    }

    @objc class var isUnifiedProBundle: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .unifiedPro || bundle == .business
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isUnifiedProBundle()")
            return false
        }
    }

    @objc class var isBusinessBundle: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .business
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isBusinessBundle()")
            return false
        }
    }

    @objc class var isUnifiedFreemiumBundle: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .unifiedFreemium
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isUnifiedFreemiumBundle()")
            return false
        }
    }

    @objc class var isScotusEdition: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .scotus
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isScotusEdition()")
            return false
        }
    }

    @objc class var isZeroEdition: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .zero
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isZeroEdition()")
            return false
        }
    }

    @objc class var isAProBundle: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle.isPro
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isAProBundle()")
            return false
        }
    }

    @objc class var isTestFlightBuild: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" 
    }

    @objc class var displayName: String {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle.displayName
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.displayName")
            return NSLocalizedString("generic_unknown", comment: "Unknown")
        }
    }

    @objc class var supportsTipJar: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            
            return bundle.supportsTipJar
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isAProBundle()")
            return false
        }
    }

    @objc class var supportsWiFiSync: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            
            return bundle.supportsWiFiSync
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.supportsWiFiSync()")
            return false
        }
    }

    @objc class var supports3rdPartyStorageProviders: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            
            return bundle.supports3rdPartyStorageProviders
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.supports3rdPartyStorageProviders()")
            return false
        }
    }

    @objc class var supportsSftpWebDAV: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            
            return bundle.supportsSftpWebDAV
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isAProBundle()")
            return false
        }
    }

    @objc class var supportsFavIconDownloader: Bool {
        let bundleId = Utils.getAppBundleId()

        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            
            return bundle.supportsFavIconDownloader
        } else {
            swlog("🔴 Unknown Bundle in StrongboxProductBundle.isAProBundle()")
            return false
        }
    }
}
