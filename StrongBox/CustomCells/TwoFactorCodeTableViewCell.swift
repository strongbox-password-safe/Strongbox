//
//  TwoFactorCodeTableViewCell.swift
//  Strongbox
//
//  Created by Strongbox on 16/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 16.0, *)
@objc
class TwoFactorCodeTableViewCell: UITableViewCell {
    @objc
    static let CellIdentifier = "TwoFactorCodeTableViewCell"

    @objc
    func setContent(totp: OTPToken, easyReadSeparator: Bool, updateMode: TwoFactorUpdateMode, onQrCode: (() -> Void)?) {
        setContent(totp: totp, easyReadSeparator: easyReadSeparator, updateMode: updateMode, title: nil, subtitle: nil, icon: nil, onQrCode: onQrCode)
    }

    @objc
    func setContent(totp: OTPToken?, easyReadSeparator: Bool, updateMode: TwoFactorUpdateMode, title: String?, subtitle: String?, icon: UIImage?, onQrCode: (() -> Void)?) {
        if let totp {
            let font = Font(FontManager.sharedInstance().easyReadFontForTotp)

            let content = {
                TwoFactorView(totp: totp, updateMode: updateMode, easyReadSeparator: easyReadSeparator, font: font, title: title, subtitle: subtitle, image: icon, onQrCode: onQrCode)
            }

            contentConfiguration = UIHostingConfiguration(content: content)
            clipsToBounds = true
            selectionStyle = .default
        } else {
            setEmpty()
        }
    }

    private func setEmpty() {
        contentConfiguration = UIHostingConfiguration {
            EmptyView()
        }

        clipsToBounds = true
        selectionStyle = .none
    }
















}
