//
//  TotpTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 20/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

class TotpTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    deinit {
        swlog("😎 DEINIT [TotpTableCellView]")
        NotificationCenter.default.removeObserver(self)
    }

    @IBOutlet var labelOtpAuthURLIssuer: NSTextField!
    @IBOutlet var labelFieldName: NSTextField!
    @IBOutlet var progressTotp: NSProgressIndicator!
    @IBOutlet var labelTotp: NSTextField!
    @IBOutlet var popupButton: NSPopUpButton!
    @IBOutlet var copyButton: NSButton!
    @IBOutlet weak var qrCodeButton: NSButton!
    
    var hostingView: NSHostingView<AnyView>?

    override func awakeFromNib() {
        super.awakeFromNib()

        NotificationCenter.default.addObserver(forName: .totpUpdate, object: nil, queue: nil) { [weak self] _ in
            self?.bind2FACode()
        }

        if #available(macOS 13.0, *) {
            let host = NSHostingView(rootView: AnyView(EmptyView()))
            host.translatesAutoresizingMaskIntoConstraints = false
            addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: leadingAnchor),
                host.trailingAnchor.constraint(equalTo: trailingAnchor),
                host.topAnchor.constraint(equalTo: topAnchor),
                host.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            hostingView = host

            labelOtpAuthURLIssuer.isHidden = true
            labelFieldName.isHidden = true
            progressTotp.isHidden = true
            labelTotp.isHidden = true
            qrCodeButton.isHidden = true
            copyButton.isHidden = true
            popupButton.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        token = nil
        if #available(macOS 13.0, *) {
            hostingView?.rootView = AnyView(EmptyView())
        }
    }

    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var onCopyButton: ((DetailsViewField?) -> Void)?
    var onQrCodeButton: ((DetailsViewField?) -> Void)?

    var field: DetailsViewField?

    func setContent(_ field: DetailsViewField,
                    popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil,
                    onCopyButton: ((DetailsViewField?) -> Void)? = nil,
                    onQrCodeButton: ((DetailsViewField?) -> Void)? = nil)
    {
        self.field = field
        labelFieldName.stringValue = field.name
        self.popupMenuUpdater = popupMenuUpdater
        popupButton.menu?.delegate = self

        self.onCopyButton = onCopyButton
        copyButton.isHidden = onCopyButton == nil

        self.onQrCodeButton = onQrCodeButton

        token = field.object as? OTPToken
    }

    var token: OTPToken? {
        didSet {
            bind2FACode()
        }
    }

    @objc func bind2FACode() {
        if #available(macOS 13.0, *) {
            guard let totp = token else {
                hostingView?.rootView = AnyView(EmptyView())
                return
            }

            let font = Font(FontManager.sharedInstance().easyReadFontForTotp)
            hostingView?.rootView = AnyView(
                TwoFactorView(
                    totp: totp,
                    updateMode: .automatic,
                    easyReadSeparator: true,
                    font: font,
                    hideCountdownDigits: true,
                    radius: 25,
                    onQrCode: { [weak self] in
                        guard let self else { return }
                        self.onQrCodeButton?(self.field)
                    }
                )
            )
            
            labelOtpAuthURLIssuer.isHidden = true
            labelFieldName.isHidden = true
            progressTotp.isHidden = true
            labelTotp.isHidden = true
            qrCodeButton.isHidden = true
            copyButton.isHidden = true
            popupButton.isHidden = true
        } else {
            if let totp = token {
                let current = NSDate().timeIntervalSince1970
                let period = totp.period

                let remainingSeconds = period - (current.truncatingRemainder(dividingBy: period))

                labelTotp.stringValue = totp.password
                labelTotp.textColor = (remainingSeconds < 5) ? .systemRed : (remainingSeconds < 9) ? .systemOrange : .controlTextColor

                progressTotp.minValue = 0
                progressTotp.maxValue = totp.period
                progressTotp.doubleValue = remainingSeconds

                if let issuer = totp.issuer, !issuer.isEmpty, issuer != "<Unknown>", issuer != "Strongbox" {
                    if let name = totp.name, !name.isEmpty, name != "<Unknown>", name != "Strongbox" {
                        labelOtpAuthURLIssuer.stringValue = String(format: "%@: %@", issuer, name)
                    } else {
                        labelOtpAuthURLIssuer.stringValue = issuer
                    }
                    labelOtpAuthURLIssuer.isHidden = false
                } else if let name = totp.name, !name.isEmpty, name != "<Unknown>", name != "Strongbox" {
                    labelOtpAuthURLIssuer.stringValue = name
                    labelOtpAuthURLIssuer.isHidden = false
                } else {
                    labelOtpAuthURLIssuer.stringValue = ""
                    labelOtpAuthURLIssuer.isHidden = true
                }
            } else {
                labelTotp.stringValue = "000000"
                labelTotp.textColor = nil
                labelOtpAuthURLIssuer.stringValue = ""
                labelOtpAuthURLIssuer.isHidden = true
            }
        }
    }

    func showPopupButtonMenu() {
        swlog("✅ showPopupButton")

        let menu = NSMenu()

        if let field {
            popupMenuUpdater?(menu, field)
        }

        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: self)
    }

    @IBAction func onQrCode(_: Any) {
        onQrCodeButton?(field)
    }

    @IBAction func onCopy(_: Any) {
        onCopyButton?(field)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
}
