//
//  TotpTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 20/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class TotpTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    deinit {
        NSLog("😎 DEINIT [TotpTableCellView]")
        NotificationCenter.default.removeObserver(self)
    }

    @IBOutlet var labelFieldName: NSTextField!
    @IBOutlet var progressTotp: NSProgressIndicator!
    @IBOutlet var labelTotp: NSTextField!
    @IBOutlet var popupButton: NSPopUpButton!
    @IBOutlet var copyButton: NSButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        NotificationCenter.default.addObserver(forName: .totpUpdate, object: nil, queue: nil) { [weak self] _ in
            self?.bindTOTP()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        token = nil
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
            bindTOTP()
        }
    }

    @objc func bindTOTP() {
        if let totp = token {
            let current = NSDate().timeIntervalSince1970
            let period = totp.period

            let remainingSeconds = period - (current.truncatingRemainder(dividingBy: period))

            labelTotp.stringValue = totp.password
            labelTotp.textColor = (remainingSeconds < 5) ? .systemRed : (remainingSeconds < 9) ? .systemOrange : .controlTextColor

            progressTotp.minValue = 0
            progressTotp.maxValue = totp.period
            progressTotp.doubleValue = remainingSeconds
        } else {
            labelTotp.stringValue = "000000"
            labelTotp.textColor = nil
        }
    }

    func showPopupButtonMenu() {
        NSLog("✅ showPopupButton")

        popupButton.performClick(nil)
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
