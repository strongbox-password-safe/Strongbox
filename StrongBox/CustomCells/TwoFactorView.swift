//
//  TwoFactorView.swift
//  Strongbox
//
//  Created by Strongbox on 26/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

@available(iOS 16.0, *)
struct TwoFactorView: View {
    var totp: OTPToken
    var updateMode: TwoFactorUpdateMode
    var easyReadSeparator: Bool
    var font: Font

    var title: String? = nil
    var subtitle: String? = nil
    var image: IMAGE_TYPE_PTR? = nil

    var onQrCode: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(3.0)
                        .shadow(radius: 3)
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        if let title {
                            Text(title)
                                .font(.headline)
                                .lineLimit(1)
                        }

                        if let subtitle {
                            Text(subtitle)
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                                .lineLimit(1)
                        } else {
                            Text("generic_fieldname_totp")
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }

                    TwoFactorCodeView(totp: totp, updateMode: updateMode, easyReadSeparator: easyReadSeparator, isPro: true, limitNonPro: false, font: font, colorize: false)

                    if let issuerAndName = totp.issuerAndName {
                        Text(issuerAndName)
                            .foregroundStyle(.tertiary)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack {
                    TwoFactorCodeCircularProgressView(totp: totp, radius: 55, updateMode: updateMode)

                    if let onQrCode {
                        Button {
                            onQrCode()
                        } label: {
                            Image(systemName: "qrcode").font(.title)
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 16.0, *)
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

    let bar = UIImage(named: "AppIcon-2019-1024")!

    return NavigationView {
        List {
            TwoFactorView(totp: token, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp), title: "HSBC", subtitle: "markymark", image: bar) {}

            TwoFactorView(totp: tokenSteam, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
            TwoFactorView(totp: token8Digits120Seconds, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
            TwoFactorView(totp: token8Digit, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
            TwoFactorView(totp: token8Digits60Seconds, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
            TwoFactorView(totp: tokenSha25645Seconds, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
            TwoFactorView(totp: tokenSha51215Seconds, updateMode: .automatic, easyReadSeparator: true, font: Font(FontManager.sharedInstance().easyReadFontForTotp))
        }
        .navigationTitle("Sample Item")
        .navigationBarTitleDisplayMode(.inline)
    }
}
