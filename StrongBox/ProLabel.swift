//
//  ProLabel.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import UIKit

class ProLabel: UILabel {
    override func awakeFromNib() {
        super.awakeFromNib()

        bindUi()
    }

    func bindUi() {
        clipsToBounds = true
        layer.cornerRadius = 3

        let proString = NSLocalizedString("pro_badge_text", comment: "Pro")
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        backgroundColor = .systemBlue

        attributedText = NSAttributedString(string: proString, attributes: [.font: proFont])
    }

    @objc
    var proFont: UIFont = FontManager.sharedInstance().headlineItalicFont {
        didSet {
            bindUi()
        }
    }
}
