//
//  ProgressHudView.swift
//  AcmeBankDemo
//
//  Created by Conrad Ciobanica on 2018-02-26.
//  Copyright © 2018 Yubico. All rights reserved.
//

import UIKit

class ProgressHudView: UIView {

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var messageLabel: UILabel!
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if superview != nil {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}
