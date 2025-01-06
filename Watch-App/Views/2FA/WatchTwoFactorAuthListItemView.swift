//
//  WatchTwoFactorAuthListItemView.swift
//  Strongbox
//
//  Created by Strongbox on 14/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Combine
import SwiftUI

struct WatchTwoFactorAuthDigitsView: View {
    var totp: OTPToken
    var easyReadSeparator: Bool

    @State private var totpString: String? = nil
    @State private var totpStringPair: [String]? = nil

    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        Group {
            if easyReadSeparator, let totpStringPair, totpStringPair.count == 2 {
                let view = HStack(spacing: 2) {
                    Text(totpStringPair[0])
                        .lineLimit(1)

                    Circle()
                        .foregroundStyle(.tertiary)
                        .frame(width: 4)

                    Text(totpStringPair[1])
                        .lineLimit(1)
                }

                if model.settings.pro {
                    view
                } else {
                    ZStack(alignment: .leading) {
                        ProBadge()

                        view.blur(radius: 6)
                    }
                }
            } else {
                let view = Text(totpString ?? "")
                    .lineLimit(1)

                if model.settings.pro {
                    view
                } else {
                    ZStack(alignment: .leading) {
                        ProBadge()

                        view.blur(radius: 6)
                    }
                }
            }
        }
        .font(.system(size: 26).monospaced().bold())
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText(countsDown: true))
        .animation(.default, value: totpString)
        .onAppear { updateTotp() }
        .twoFactorUpdater { updateTotp() }
    }

    func updateTotp() {
        totpString = totp.codeDisplayString

        if let codeSeparated = totp.codeSeparated {
            totpStringPair = codeSeparated
        }
    }
}

struct WatchTwoFactorAuthListItemView: View {
    var totp: OTPToken
    var easyReadSeparator: Bool
    var hideCountdownDigits: Bool

    @EnvironmentObject
    var model: WatchAppModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("generic_fieldname_totp")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                WatchTwoFactorAuthDigitsView(totp: totp, easyReadSeparator: easyReadSeparator)
            }

            Spacer()

            TwoFactorCodeCircularProgressView(totp: totp, radius: 35, updateMode: .automatic, hideCountdownDigits: hideCountdownDigits)
                .padding(2)
                .frame(width: 32)
        }
    }
}

#if DEBUG
    #Preview {
        let otpAuthUrl = "otpauth:

        let token = OTPToken(url: URL(string: otpAuthUrl))!

        let otpAuthUrl8Digit = "otpauth:
        let token8Digit = OTPToken(url: URL(string: otpAuthUrl8Digit))!

        let otpAuthUrl8Digits60Seconds = "otpauth:
        let token8Digits60Seconds = OTPToken(url: URL(string: otpAuthUrl8Digits60Seconds))!

        let otpAuthUrl8Digits120Seconds = "otpauth:
        let token8Digits120Seconds = OTPToken(url: URL(string: otpAuthUrl8Digits120Seconds))!

        let otpAuthUrlSha25645Seconds = "otpauth:
        let tokenSha25645Seconds = OTPToken(url: URL(string: otpAuthUrlSha25645Seconds))!

        let otpAuthUrlSha51215Seconds = "otpauth:
        let tokenSha51215Seconds = OTPToken(url: URL(string: otpAuthUrlSha51215Seconds))!

        let otpAuthUrlSteam = "otpauth:
        let tokenSteam = OTPToken(url: URL(string: otpAuthUrlSteam))!

        List {
            WatchTwoFactorAuthListItemView(totp: token, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: tokenSteam, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: token8Digits120Seconds, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: token8Digit, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: token8Digits60Seconds, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: tokenSha25645Seconds, easyReadSeparator: true, hideCountdownDigits: true)
            WatchTwoFactorAuthListItemView(totp: tokenSha51215Seconds, easyReadSeparator: true, hideCountdownDigits: true)
        }
        .environmentObject(WatchAppModel())
    }
#endif
