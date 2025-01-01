//
//  TwoFactorCodeView.swift
//  Strongbox
//
//  Created by Strongbox on 16/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(iOS 16.0, *)
struct TwoFactorCodeView: View {
    @State private var totpString: String
    @State private var totpStringPair: [String]
    @State private var totpColor: Color

    var totp: OTPToken
    var updateMode: TwoFactorUpdateMode

    var easyReadSeparator: Bool
    var isPro: Bool
    var limitNonPro: Bool
    var font: Font = .system(size: 50).monospaced().bold()
    var separatorSize: CGFloat = 6
    var colorize: Bool

    var shouldObfuscate: Bool {
        limitNonPro && !isPro
    }

    init(totp: OTPToken, updateMode: TwoFactorUpdateMode, easyReadSeparator: Bool, isPro: Bool, limitNonPro: Bool, font: Font = .system(size: 50).monospaced().bold(), separatorSize: CGFloat = 6.0, colorize: Bool) {
        
        
        
        

        self.totp = totp
        self.updateMode = updateMode
        self.easyReadSeparator = easyReadSeparator
        self.isPro = isPro
        self.limitNonPro = limitNonPro
        self.font = font
        self.separatorSize = separatorSize
        self.colorize = colorize

        let displayValues = OTPToken.getTotpDisplayValues(from: totp, colorize: colorize)

        totpString = displayValues.totpString
        totpStringPair = displayValues.totpStringPair
        totpColor = displayValues.totpColor
    }

    var body: some View {
        let view = ZStack {
            if easyReadSeparator, totpStringPair.count == 2 {
                let view = HStack(spacing: 2) {
                    Text(totpStringPair[0])
                        .lineLimit(1)

                    Circle()
                        .foregroundStyle(.tertiary)
                        .frame(width: separatorSize)

                    Text(totpStringPair[1])
                        .lineLimit(1)
                }

                if !shouldObfuscate {
                    view
                } else {
                    VStack {
                        ProBadge()

                        view.blur(radius: 10)
                    }
                }
            } else {
                let view = Text(totpString)
                    .lineLimit(1)

                if !shouldObfuscate {
                    view
                } else {
                    VStack {
                        ProBadge()

                        view.blur(radius: 10)
                    }
                }
            }
        }

        if #available(macOS 13.0, *) {
            view
                .font(font)
                .foregroundStyle(totpColor)
                .minimumScaleFactor(0.1)
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: totpString)
                .twoFactorUpdater(mode: updateMode, onUpdate: updateTotp)
        } else {
            view
                .font(font)
                .foregroundStyle(totpColor)
                .minimumScaleFactor(0.1)
                .animation(.default, value: totpString)
                .twoFactorUpdater(mode: updateMode, onUpdate: updateTotp)
        }
    }

    func updateTotp() {
        let displayValues = OTPToken.getTotpDisplayValues(from: totp, colorize: colorize)

        totpString = displayValues.totpString
        totpStringPair = displayValues.totpStringPair
        totpColor = displayValues.totpColor
    }
}

@available(iOS 16.0, *)
#Preview {
    let otpAuthUrl = "otpauth:

    let token = OTPToken(url: URL(string: otpAuthUrl))!

    return TwoFactorCodeView(totp: token, updateMode: .automatic, easyReadSeparator: true, isPro: true, limitNonPro: true, colorize: true)
}
