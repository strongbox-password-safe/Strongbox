//
//  QRCodeScanner.swift
//  MacBox
//
//  Created by Strongbox on 09/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import Foundation

class QRCodeScanner: NSViewController, NSPopoverDelegate {
    @IBOutlet var stackViewPermissions: NSStackView!
    @IBOutlet var stackViewSearching: NSStackView!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var stackViewResultConfirm: NSStackView!
    @IBOutlet var stackViewNoneFound: NSStackView!
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var labelTotpUrl: NSTextField!
    @IBOutlet var progressTotpCode: NSProgressIndicator!
    @IBOutlet var labelTotpCode: NSTextField!
    @IBOutlet var labelFoundInWindow: NSTextField!
    @IBOutlet var labelNoneFoundHeader: NSTextField!
    @IBOutlet var labelPermissionsHeader: NSTextField!
    @IBOutlet var stackViewPreviewTotp: NSStackView!
    @IBOutlet var checkboxAutoCommit: NSButton!

    struct ScanResult {
        var totpString: String
        var ownerWindow: String
        var image: NSImage
    }

    var onSetTotp: ((String) -> Void)?

    var scanResult: ScanResult?
    var isScanning: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()


        stackViewNoneFound.setCustomSpacing(8, after: labelNoneFoundHeader)
        stackViewResultConfirm.setCustomSpacing(8, after: labelFoundInWindow)
        stackViewResultConfirm.setCustomSpacing(12, after: checkboxAutoCommit)

        stackViewPreviewTotp.isHidden = true 

        bindUI()

        if hasPermissions {
            startScanning()
        }
    }

    var hasPermissions: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @IBAction func onClose(_: Any) {
        dismiss(nil)
    }

    @IBAction func onLooksGood(_: Any) {
        if let totp = scanResult?.totpString {
            onSetTotp?(totp)
            dismiss(nil)
        }
    }

    @IBAction func onScanAgain(_: Any) {
        scanResult = nil
        startScanning()
        bindUI()
    }

    @IBAction func onChangedAutoCommit(_: Any) {
        if checkboxAutoCommit.state == .off {
            MacAlerts.areYouSure(NSLocalizedString("are_you_sure_auto_commit_totp_msg", comment: "Disabling Auto-Commit could mean you lose this 2FA Code if you forget to commit later. Are you sure?"),
                                 window: view.window)
            { [weak self] response in
                if response {
                    Settings.sharedInstance().autoCommitScannedTotp = false
                }
                self?.bindUI()
            }
        } else {
            Settings.sharedInstance().autoCommitScannedTotp = true
            bindUI()
        }
    }

    func bindUI() {
        stackViewPermissions.isHidden = hasPermissions
        stackViewSearching.isHidden = !hasPermissions || !isScanning
        stackViewResultConfirm.isHidden = scanResult == nil
        stackViewNoneFound.isHidden = scanResult != nil || isScanning || !hasPermissions
        checkboxAutoCommit.state = Settings.sharedInstance().autoCommitScannedTotp ? .on : .off

        if let result = scanResult {
            imageView.image = result.image
            labelTotpUrl.stringValue = result.totpString

            let locString = NSLocalizedString("found_totp_code_in_x_window_fmt", comment: "Found 2FA Code in '%@' Window")
            labelFoundInWindow.stringValue = String(format: locString, result.ownerWindow)
            bindTotpCode()
            startTotpRefreshTimer()
        } else {
            stopTotpRefreshTimer()
        }
    }

    var timerRefreshOtp: Timer?
    func startTotpRefreshTimer() {
        if timerRefreshOtp == nil {
            timerRefreshOtp = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(bindTotpCode), userInfo: nil, repeats: true)
        }
    }

    func stopTotpRefreshTimer() {
        if timerRefreshOtp != nil {
            timerRefreshOtp?.invalidate()
            timerRefreshOtp = nil
        }
    }

    @objc func bindTotpCode() {
        if let scanResult,
           let url = URL(string: scanResult.totpString),
           let totp = OTPToken(url: url)
        {
            let current = NSDate().timeIntervalSince1970
            let period = totp.period

            let remainingSeconds = period - (current.truncatingRemainder(dividingBy: period))

            labelTotpCode.stringValue = totp.password
            labelTotpCode.textColor = (remainingSeconds < 5) ? .systemRed : (remainingSeconds < 9) ? .systemOrange : .controlTextColor

            progressTotpCode.minValue = 0
            progressTotpCode.maxValue = totp.period
            progressTotpCode.doubleValue = remainingSeconds
        }
    }


    @IBAction func onLaunchPreferences(_: Any) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }















    func startScanning() {
        isScanning = true
        bindUI()

        autoreleasepool {
            scanAllWindowsForQRCodes()
        }
    }

    func scanAllWindowsForQRCodes() {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements)
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray?,
              let infoList = windowListInfo as? [[String: AnyObject]],
              let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        else {
            return
        }

        progressIndicator.startAnimation(nil)

        DispatchQueue.global().async { [weak self] in
            self?.scanWindows(qrDetector: qrDetector, infoList: infoList) { result in
                DispatchQueue.main.async { [weak self] in
                    self?.onFinishedScanningFor2FACode(result: result)
                }
            }
        }
    }

    func onFinishedScanningFor2FACode(result: ScanResult?) {
        progressIndicator.stopAnimation(nil)
        isScanning = false

        if let result {

            scanResult = result
        } else {

            scanResult = nil
        }

        bindUI()
    }

    func scanWindows(qrDetector: CIDetector, infoList: [[String: AnyObject]], completionHandler: @escaping (ScanResult?) -> Void) {
        for dict in infoList {
            guard let maybeOwner = dict[kCGWindowOwnerName as String] as? String?,
                  let ownerWindow = maybeOwner,
                  ownerWindow != "Strongbox",
                  let windowIDNum = dict[kCGWindowNumber as String] as? NSNumber,
                  let windowImage: CGImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowIDNum.uint32Value as CGWindowID, [.boundsIgnoreFraming, .nominalResolution])
            else {
                continue
            }

            let ciImage = CIImage(cgImage: windowImage)
            let features = qrDetector.features(in: ciImage)

            if let qrc = features.first as? CIQRCodeFeature, let string = qrc.messageString {
                let image = NSImage(cgImage: windowImage, size: .zero)



                
                

                if let url = (string as NSString).urlExtendedParse {


                    if let _ = OTPToken(url: url) {



                        completionHandler(ScanResult(totpString: url.absoluteString, ownerWindow: ownerWindow, image: image))
                        return
                    }
                }
            }
        }

        completionHandler(nil)
    }
}
