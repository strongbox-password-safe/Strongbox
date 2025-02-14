//
//  ProgressHudView.swift
//  AcmeBankDemo
//
//  Created by Conrad Ciobanica on 2018-02-26.
//  Copyright © 2018 Yubico. All rights reserved.
//

import UIKit

class ProgressHudView: UIView {
    let contentView = Bundle.main.loadNibNamed("ProgressHudView", owner: nil, options: nil)!.first as! ProgressHudContentView

    var message: String {
        get {
            contentView.messageLabel.text ?? ""
        }
        set {
            contentView.messageLabel.text = newValue
        }
    }

    func startAnimating() {
        contentView.activityIndicator.startAnimating()
    }

    func stopAnimating() {
        contentView.activityIndicator.stopAnimating()
    }

    var showCheckmark: Bool {
        set {
            contentView.checkmark.isHidden = !newValue
        }
        get {
            !contentView.checkmark.isHidden
        }
    }

    var showError: Bool {
        set {
            contentView.error.isHidden = !newValue
        }
        get {
            !contentView.error.isHidden
        }
    }

    init() {
        super.init(frame: .zero)
        embed(contentView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func dismiss() {
        removeFromSuperview()
    }
}

class ProgressHudContentView: UIView {
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var messageLabel: UILabel!
    @IBOutlet var checkmark: UILabel!
    @IBOutlet var error: UILabel!
}

extension UIView {
    func embed(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        let left = NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0)
        let right = NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
        let top = NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0)
        let bottom = NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0)

        addConstraints([left, right, top, bottom])
    }
}
