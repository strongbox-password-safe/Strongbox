//
//  MMcGSecureTextField.swift
//  MacBox
//
//  Created by Strongbox on 03/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class MMcGSecurePlainTextFieldCell: NSSecureTextFieldCell {}

class MMcGSecureSecureTextFieldCell: NSSecureTextFieldCell {}

class MMcGSecureTextField: NSSecureTextField {
    var showsText: Bool = false

    override class var cellClass: AnyClass? = NSSecureTextFieldCell.class
}
