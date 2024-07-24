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
    var remainingSeconds: Double {
        period - (NSDate().timeIntervalSince1970.truncatingRemainder(dividingBy: period))
    }

    @objc
    var color: NSColor? {
        remainingSeconds < 5 ? .systemRed : (remainingSeconds < 9) ? .systemOrange : nil
    }
}
