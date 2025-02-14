// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.



import UIKit







class MFIKeyActionSheetViewConfiguration {
    let presentAnimationDuration = 0.3
    let dismissAnimationDuration = 0.2

    let presentAnimationDurationSlow = 0.5
    let dismissAnimationDurationSlow = 0.4

    var currentPresentAnimationDuration: TimeInterval {
        let cores = ProcessInfo.processInfo.processorCount
        return cores >= 4 ? presentAnimationDuration : presentAnimationDurationSlow
    }

    var currentDismissAnimationDuration: TimeInterval {
        let cores = ProcessInfo.processInfo.processorCount
        return cores >= 4 ? dismissAnimationDuration : dismissAnimationDurationSlow
    }

    let actionSheetViewFadeViewAlpha: CGFloat = 0.6

    let actionSheetViewBottomConstraintConstant: CGFloat = 5.0
    let keyImageViewTopConstraintDisconnectedConstant: CGFloat = 8
    let keyImageViewTopConstraintConnectedConstant: CGFloat = -19
}







@objc
public protocol MFIKeyActionSheetViewDelegate: NSObjectProtocol {
    func mfiKeyActionSheetDidDismiss()
}

@objc
public class MFIKeyActionSheetView: UIView {
    let contentView = Bundle.main.loadNibNamed("MFIKeyActionSheetView", owner: nil, options: nil)!.first as! MFIKeyActionSheetContentView

    private let configuration = MFIKeyActionSheetViewConfiguration()
    private static let viewNibName = String(describing: MFIKeyActionSheetView.self)

    private var isPresenting = false
    private var isDismissing = false

    

    











    override init(frame: CGRect) {
        super.init(frame: frame)
        embed(contentView)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    public weak var delegate: MFIKeyActionSheetViewDelegate? {
        didSet {
            contentView.delegate = delegate
        }
    }

    private func setupView() {
        if UIDevice.current.ykd_hasHomeButton() {
            contentView.deviceImageView.image = UIImage(named: "LASPhone")
        } else {
            contentView.deviceImageView.image = UIImage(named: "LASPhoneNew")
        }
        resetState()
    }

    

    private func resetState() {
        contentView.borderView.backgroundColor = NamedColor.mfiKeyActionSheetIdleColor
        contentView.messageLabel.text = nil

        contentView.layer.removeAllAnimations()
        contentView.keyImageView.layer.removeAllAnimations()
    }

    @objc
    public func animateProcessing(message: String) {
        resetState()

        contentView.borderView.backgroundColor = NamedColor.mfiKeyActionSheetProcessingColor
        contentView.messageLabel.text = message

        animateKeyConnected()
        pulsateBorderView(duration: 1.5)
    }

    @objc
    public func animateInsertKey(message: String) {
        resetState()

        contentView.borderView.backgroundColor = NamedColor.mfiKeyActionSheetIdleColor
        contentView.messageLabel.text = message

        animateConnectKey()
    }

    @objc
    public func animateKeyInserted(message: String) {
        resetState()

        contentView.borderView.backgroundColor = NamedColor.mfiKeyActionSheetIdleColor
        contentView.messageLabel.text = message

        animateConnectKey()
    }

    @objc
    public func animateTouchKey(message: String) {
        resetState()

        contentView.borderView.backgroundColor = NamedColor.mfiKeyActionSheetTouchColor
        contentView.messageLabel.text = message

        animateKeyConnected()
        pulsateBorderView(duration: 1)
    }

    

    @objc
    public func present(animated _: Bool, completion: @escaping () -> Void) {
        guard !isPresenting else {
            return
        }
        isPresenting = true

        contentView.actionSheetBottomConstraint.constant = -(contentView.actionSheetBottomConstraint.constant + contentView.actionSheetView.frame.size.height)
        contentView.backgroundFadeView.alpha = 0

        layoutIfNeeded()

        contentView.actionSheetBottomConstraint.constant = configuration.actionSheetViewBottomConstraintConstant

        let options: UIView.AnimationOptions = [.beginFromCurrentState, .curveEaseOut]

        UIView.animate(withDuration: configuration.currentPresentAnimationDuration, delay: 0, options: options, animations: { [weak self] in
            guard let self else {
                return
            }
            self.layoutIfNeeded()
            self.contentView.backgroundFadeView.alpha = self.configuration.actionSheetViewFadeViewAlpha
        }) { [weak self] _ in
            completion()
            self?.isPresenting = false
        }
    }

    @objc
    public func dismiss(animated _: Bool, delayed: Bool = true, completion: @escaping () -> Void) {
        guard !isDismissing else {
            return
        }
        isDismissing = true

        contentView.actionSheetBottomConstraint.constant = configuration.actionSheetViewBottomConstraintConstant
        layoutIfNeeded()

        contentView.actionSheetBottomConstraint.constant = -(contentView.actionSheetBottomConstraint.constant + contentView.actionSheetView.frame.size.height)

        
        let delay = delayed ? 1.0 : 0
        let options: UIView.AnimationOptions = [.beginFromCurrentState, .curveEaseIn]

        UIView.animate(withDuration: configuration.currentDismissAnimationDuration, delay: delay, options: options, animations: { [weak self] in
            guard let self else {
                return
            }
            self.layoutIfNeeded()
            self.contentView.backgroundFadeView.alpha = 0
        }) { [weak self] _ in
            completion()
            self?.isDismissing = false
        }
    }

    

    private func animateConnectKey() {
        layoutIfNeeded()

        UIView.animateKeyframes(withDuration: 3, delay: 0, options: .repeat, animations: { [weak self] in
            guard let self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2, animations: {
                self.contentView.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintConnectedConstant
                self.layoutIfNeeded()
            })
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.4, animations: {
                
            })
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.2, animations: {
                self.contentView.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintDisconnectedConstant
                self.layoutIfNeeded()
            })
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2, animations: {
                
            })
        }, completion: nil)
    }

    private func animateKeyConnected() {
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: .beginFromCurrentState, animations: { [weak self] in
            guard let self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1, animations: {
                self.contentView.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintConnectedConstant
                self.layoutIfNeeded()
            })
        }, completion: nil)
    }

    private func pulsateBorderView(duration: TimeInterval) {
        contentView.borderView.alpha = 0

        UIView.animateKeyframes(withDuration: duration, delay: 0, options: .repeat, animations: { [weak self] in
            guard let self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1, animations: {
                self.contentView.borderView.alpha = 1
            })
            UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.8, animations: {
                
            })
            UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.1, animations: {
                self.contentView.borderView.alpha = 0
            })
        }, completion: nil)
    }

    

    @objc
    public func updateInterfaceOrientation(orientation: UIInterfaceOrientation) {
        var rotationAngle: CGFloat = 0
        switch orientation {
        case .unknown:
            fallthrough
        case .portrait:
            break
        case .landscapeLeft:
            rotationAngle = CGFloat(Double.pi / 2)
        case .landscapeRight:
            rotationAngle = CGFloat(-Double.pi / 2)
        case .portraitUpsideDown:
            rotationAngle = CGFloat(Double.pi)
        @unknown default:
            fatalError()
        }
        contentView.keyActionContainerView.transform = CGAffineTransform(rotationAngle: rotationAngle)
    }
}







extension UIDevice /* MFI Key Action Sheet */ {
    func ykd_hasHomeButton() -> Bool {
        if #available(iOS 11.0, *) {
            guard let keyWindow = UIApplication.shared.keyWindow else {
                return true
            }
            return keyWindow.safeAreaInsets.bottom == 0.0
        }
        return true
    }
}

extension NamedColor /* MFI Key Action Sheet */ {
    
    static var mfiKeyActionSheetIdleColor = UIColor.white

    
    static var mfiKeyActionSheetTouchColor = UIColorFrom(hex: 0xBAE950)

    
    static var mfiKeyActionSheetProcessingColor = UIColorFrom(hex: 0x76D6FF)
}

class MFIKeyActionSheetContentView: UIView {
    @IBOutlet var actionSheetBottomConstraint: NSLayoutConstraint!
    @IBOutlet var actionSheetView: UIView!

    @IBOutlet var keyImageView: UIImageView!
    @IBOutlet var keyImageViewTopConstraint: NSLayoutConstraint!

    @IBOutlet var deviceImageView: UIImageView!

    @IBOutlet var keyActionContainerView: UIView!
    @IBOutlet var backgroundFadeView: UIView!
    @IBOutlet var borderView: UIView!

    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var messageLabel: UILabel!

    

    public weak var delegate: MFIKeyActionSheetViewDelegate?

    @IBAction func cancelButtonPressed(_: Any) {
        guard let delegate else {
            return
        }
        delegate.mfiKeyActionSheetDidDismiss()
    }
}
