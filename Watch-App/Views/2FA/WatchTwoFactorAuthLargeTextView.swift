//
//  WatchTwoFactorAuthLargeTextView.swift
//  Strongbox
//
//  Created by Strongbox on 15/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct WatchTwoFactorAuthLargeTextView: View {
    var totp: OTPToken
    var easyReadSeparator: Bool
    var isPro: Bool
    var hideCountdownDigits: Bool

    var body: some View {
        VStack {
            TwoFactorCodeView(totp: totp, updateMode: .automatic, easyReadSeparator: easyReadSeparator, isPro: isPro, limitNonPro: true, colorize: false)

            Spacer()

            TwoFactorCodeCircularProgressView(totp: totp, radius: 80, updateMode: .automatic, hideCountdownDigits: hideCountdownDigits)
                .padding()
        }
    }
}

#Preview {
    let otpAuthUrl = "otpauth:
    let token = OTPToken(url: URL(string: otpAuthUrl))!

    WatchTwoFactorAuthLargeTextView(totp: token, easyReadSeparator: true, isPro: true, hideCountdownDigits: true)
}
