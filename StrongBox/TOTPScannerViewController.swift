//
//  TOTPScannerViewController.swift
//  Strongbox
//
//  Created by Strongbox on 08/05/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import AVFoundation
import UIKit

@objc
class TOTPScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var cancelButton: UIButton!

    @objc
    var onFoundTOTP: ((URL) -> Void)!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            failed()
            return
        }

        requestCameraPermission { [weak self] success in
            guard let self else { return }
            if success {
                onGotPermissions(videoCaptureDevice: videoCaptureDevice)
            } else {
                failed()
            }
        }
    }

    func onGotPermissions(videoCaptureDevice: AVCaptureDevice) {
        captureSession = AVCaptureSession()

        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            swlog("🔴 AVCaptureDeviceInput - Error = \(error)")
            failed()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            swlog("🔴 captureSession.canAddInput")
            failed()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            swlog("🔴 captureSession.canAddOutput")
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        addDismissButton()

        DispatchQueue.global().async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func addDismissButton() {
        let button = UIButton()

        button.backgroundColor = .black
        button.alpha = 0.4
        button.setTitleColor(.white, for: .normal)
        button.setTitle("", for: .normal)
        button.addTarget(self, action: #selector(onDismiss), for: .touchUpInside)
        button.layer.cornerRadius = 5
        button.setImage(UIImage(systemName: "x.circle"), for: .normal)
        button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(font: FontManager.sharedInstance().headlineFont, scale: .large), forImageIn: .normal)
        button.tintColor = UIColor.white

        view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.safeAreaLayoutGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
        button.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8).isActive = true
    }

    @objc func onDismiss(sender _: UIButton!) {
        dismiss(animated: true)
    }

    func failed() {
        Alerts.info(self,
                    title: NSLocalizedString("qr_code_vc_warn_problem_accessing_camera_title", comment: "Could not access camera"),
                    message: NSLocalizedString("qr_code_vc_warn_problem_accessing_camera_message", comment: "Strongbox could not access the camera on this device. Does it have permission?"))
        { [weak self] in
            self?.dismiss(animated: true)
        }

        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession?.isRunning == false {
            DispatchQueue.global().async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }

    func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  let url = stringValue.urlExtendedParse,
                  let scheme = url.scheme,
                  scheme.lowercased() == kOtpAuthScheme
            else {
                swlog("Not a proper OTPAUTH TOTP URL... Ignoring")
                return
            }

            captureSession.stopRunning()

            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

            onFoundOtpAuthURL(url: url)
        }
    }

    func onFoundOtpAuthURL(url: URL) {
        dismiss(animated: true) { [weak self] in
            self?.onFoundTOTP(url)
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    func requestCameraPermission(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .restricted:
            swlog("🔴 Camera Access restricted")
            completion(false)
        case .denied:
            swlog("🔴 Camera Access denied")
            completion(false)
        @unknown default:
            swlog("🔴 Unknown return from AVCaptureDevice.authorizationStatus")
            completion(false)
        }
    }
}
