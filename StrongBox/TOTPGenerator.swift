//
//  TOTPGenerator.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import CryptoKit
import Foundation

@objc
class SwiftTOTPGenerator: NSObject {
    @objc class func cryptoKitOTP(secret: Data, digits: Int = 6, period: Int = 30, algorithm: OTPAlgorithm = .SHA1) -> UInt32 {
        
        var counter = UInt64(Date().timeIntervalSince1970 / TimeInterval(period)).bigEndian

        let counterMessage = withUnsafeBytes(of: &counter) { Array($0) }

        
        var hmac = Data()

        switch algorithm {
        case .SHA1:
            hmac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterMessage, using: SymmetricKey(data: secret)))
        case .SHA256:
            hmac = Data(HMAC<SHA256>.authenticationCode(for: counterMessage, using: SymmetricKey(data: secret)))
        case .SHA512:
            hmac = Data(HMAC<SHA512>.authenticationCode(for: counterMessage, using: SymmetricKey(data: secret)))
        case .steam:
            swlog("🔴 WARNWARN - Using Swift Generator with Steam algo!")
            hmac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterMessage, using: SymmetricKey(data: secret)))
        @unknown default:
            swlog("🔴 WARNWARN - Using Swift Generator with unknown algo")
            hmac = Data(HMAC<Insecure.SHA1>.authenticationCode(for: counterMessage, using: SymmetricKey(data: secret)))
        }

        var truncatedHash = hmac.withUnsafeBytes { ptr -> UInt32 in
            let offset = ptr[hmac.count - 1] & 0x0F
            let truncatedHashPtr = ptr.baseAddress! + Int(offset)
            return truncatedHashPtr.bindMemory(to: UInt32.self, capacity: 1).pointee
        }

        truncatedHash = UInt32(bigEndian: truncatedHash)
        truncatedHash = truncatedHash & 0x7FFF_FFFF
        truncatedHash = truncatedHash % UInt32(pow(10, Float(digits)))

        return truncatedHash
    }
}
