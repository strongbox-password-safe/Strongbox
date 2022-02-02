//
//  QRCodeScanner.swift
//  MacBox
//
//  Created by Strongbox on 09/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

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

        bindUI()

        if hasPermissions {
            startScanning()
        }
    }

    var hasPermissions: Bool {
        if #available(macOS 11.0, *) {
            
            

            return CGPreflightScreenCaptureAccess()
        } else {
            return checkForScreenRecordingPermissionsOnMac()
        }
    }

    @IBAction func onLooksGood(_: Any) {
        if let totp = scanResult?.totpString {
            onSetTotp?(totp)
        }
    }

    @IBAction func onScanAgain(_: Any) {
        scanResult = nil
        startScanning()
        bindUI()
    }

    func bindUI() {
        stackViewPermissions.isHidden = hasPermissions
        stackViewSearching.isHidden = !hasPermissions || !isScanning
        stackViewResultConfirm.isHidden = scanResult == nil
        stackViewNoneFound.isHidden = scanResult != nil || isScanning || !hasPermissions

        if let result = scanResult {
            imageView.image = result.image
            labelTotpUrl.stringValue = result.totpString

            let locString = NSLocalizedString("found_totp_code_in_x_window_fmt", comment: "Found TOTP Code in '%@' Window")
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
        if let scanResult = scanResult,
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

    var dontDismissOnNextDismissal: Bool = false
    @IBAction func onLaunchPreferences(_: Any) {




        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
            dontDismissOnNextDismissal = true 
        }

    }

    func popoverShouldClose(_: NSPopover) -> Bool {
        if dontDismissOnNextDismissal {
            dontDismissOnNextDismissal = false
            return false
        }

        return true
    }

    func popoverDidClose(_: Notification) {
        stopTotpRefreshTimer()
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
                    self?.onFinishedScanningForTOTPCode(result: result)
                }
            }
        }
    }

    func onFinishedScanningForTOTPCode(result: ScanResult?) {
        progressIndicator.stopAnimation(nil)
        isScanning = false

        if let result = result {

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
                  let windowIDNum = dict[kCGWindowNumber as String] as? NSNumber,
                  let windowImage: CGImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowIDNum.uint32Value as CGWindowID, [.boundsIgnoreFraming, .nominalResolution])
            else {
                continue
            }

            let ciImage = CIImage(cgImage: windowImage)

            let features = qrDetector.features(in: ciImage)

            if let qrc = features.first as? CIQRCodeFeature, let string = qrc.messageString {
                let image = NSImage(cgImage: windowImage, size: .zero)

                if let url = URL(string: string), let _ = OTPToken(url: url) {
                    completionHandler(ScanResult(totpString: string, ownerWindow: ownerWindow, image: image))
                    return
                }
            }
        }

        completionHandler(nil)
    }
}
