//
//  OTPToken+UI.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

extension OTPToken {
    @objc
    var codeDisplayString: String {
        guard let pw = password else {
            return password
        }

        if type == .timer, algorithm != .steam, algorithm != .yandex {
            let len = pw.count / 2
            return String(format: "%@%@", String(pw.prefix(len)), String(pw.suffix(pw.count - len)))
        }

        return pw
    }

    @objc
    var remainingSeconds: Double {
        period - (NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: period))
    }

    #if os(iOS)
        @objc
        var color: UIColor? {
            remainingSeconds < 6 ? .systemRed : (remainingSeconds < 10) ? .systemOrange : nil
        }
    #else
        @objc
        var color: NSColor? {
            remainingSeconds < 6 ? .systemRed : (remainingSeconds < 10) ? .systemOrange : nil
        }
    #endif
}
