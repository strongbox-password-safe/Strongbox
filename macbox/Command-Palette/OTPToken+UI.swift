//
//  OTPToken+UI.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

extension OTPToken {
    struct TwoFactorDisplayValues {
        var totpString: String
        var totpStringPair: [String]
        var totpColor: Color
        var totpSeconds: String
        var totpProgress: Double
    }

    static func getTotpDisplayValues(from totp: OTPToken, colorize: Bool) -> TwoFactorDisplayValues {
        let totpString = totp.codeDisplayString
        let totpStringPair: [String]
        let totpColor: Color

        if let codeSeparated = totp.codeSeparated {
            totpStringPair = codeSeparated
        } else {
            totpStringPair = []
        }

        let totpSeconds = String(format: "%d", totp.remainingSeconds)
        let totpProgress = totp.progress

        if colorize, let color = totp.color {
            totpColor = Color(color)
        } else {
            totpColor = .primary
        }

        return TwoFactorDisplayValues(totpString: totpString, totpStringPair: totpStringPair, totpColor: totpColor, totpSeconds: totpSeconds, totpProgress: totpProgress)
    }

    @objc
    var codeSeparated: [String]? {
        let code = codeDisplayString

        guard code.count > 5, code.count % 2 == 0 else {
            return nil
        }

        let length = code.count / 2

        return [String(code.prefix(length)), String(code.suffix(length))]
    }

    @objc
    var codeDisplayString: String {
        password
    }

    @objc
    var remainingSeconds: Int {
        let epoch = Int(NSDate().timeIntervalSince1970)
        let seconds = epoch % Int(period)

        let ret = Int(period) - seconds

        return ret
    }

    var progress: Double {
        let seconds = NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: period)

        let remainingSeconds = period - seconds

        return remainingSeconds / period
    }

    #if os(iOS)
        @objc
        var color: UIColor? {
            remainingSeconds < 6 ? .systemRed : (remainingSeconds < 10) ? .systemOrange : nil
        }

    #elseif os(watchOS)
        @objc
        var color: UIColor? {
            remainingSeconds < 6 ? .red : (remainingSeconds < 10) ? .orange : nil
        }
    #else
        @objc
        var color: NSColor? {
            remainingSeconds < 6 ? .systemRed : (remainingSeconds < 10) ? .systemOrange : nil
        }
    #endif

    var issuerAndName: String? {
        let issuer = issuer
        let name = name

        if let issuer, !issuer.isEmpty, issuer != "<Unknown>", issuer != "Strongbox" {
            if let name, !name.isEmpty, name != "<Unknown>", name != "Strongbox" {
                return String(format: "%@: %@", issuer, name)
            } else {
                return issuer
            }
        } else if let name, !name.isEmpty, name != "<Unknown>", name != "Strongbox" {
            return name
        }

        return nil
    }
}
