//
//  SecureTextFieldClearFix.swift
//  Strongbox
//
//  Created by Strongbox on 24/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import UIKit

@objc
class SecureTextFieldClearFix: UITextField {
    override var isSecureTextEntry: Bool {
        didSet {
            if isFirstResponder {
                _ = becomeFirstResponder()
            }
        }
    }

    

    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if isSecureTextEntry, let text {
            self.text?.removeAll()
            insertText(text)
        }
        return success
    }
}
