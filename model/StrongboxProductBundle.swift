//
//  Bundle.swift
//  MacBox
//
//  Created by Strongbox on 13/06/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc
public class StrongboxProductBundle : NSObject {
    enum BundleIdentifiers : String {
        case unifiedFreemium = "com.markmcguill.strongbox"
        case unifiedPro = "com.markmcguill.strongbox.pro"
        case zero = "com.markmcguill.strongbox.graphene"
        case scotus = "com.markmcguill.strongbox.scotus"
        case macOSStandaloneFreemium = "com.markmcguill.strongbox.mac"
        case macOSStandalonePro = "com.markmcguill.strongbox.mac.pro"
        
        var isPro : Bool {
            switch self {
            case .unifiedFreemium:
                return false
            case .unifiedPro:
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
    }
    
    @objc class var isUnifiedProBundle : Bool {
        let bundleId = Utils.getAppBundleId()
        
        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .unifiedPro
        }
        else {
            NSLog("🔴 Unknown Bundle in StrongboxProductBundle.isUnifiedProBundle()")
            return false
        }
    }

    @objc class var isUnifiedFreemiumBundle : Bool {
        let bundleId = Utils.getAppBundleId()
        
        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .unifiedFreemium
        }
        else {
            NSLog("🔴 Unknown Bundle in StrongboxProductBundle.isUnifiedFreemiumBundle()")
            return false
        }
    }

    @objc class var isScotusEdition : Bool {
        let bundleId = Utils.getAppBundleId()
        
        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .scotus
        }
        else {
            NSLog("🔴 Unknown Bundle in StrongboxProductBundle.isScotusEdition()")
            return false
        }
    }
    
    @objc class var isZeroEdition : Bool {
        let bundleId = Utils.getAppBundleId()
        
        if let bundle = BundleIdentifiers(rawValue: bundleId) {

            return bundle == .zero
        }
        else {
            NSLog("🔴 Unknown Bundle in StrongboxProductBundle.isZeroEdition()")
            return false
        }
    }

    @objc class var isAProBundle : Bool {
        let bundleId = Utils.getAppBundleId()
        
        if let bundle = BundleIdentifiers(rawValue: bundleId) {
            NSLog("✅ Recognized Product Bundle: [%@] - [%hhd]", String(describing: bundle), bundle.isPro)
            return bundle.isPro
        }
        else {
            NSLog("🔴 Unknown Bundle in StrongboxProductBundle.isAProBundle()")
            return false
        }
    }
}
