//
//  CustomAppIconCellView.swift
//  Strongbox
//
//  Created by Strongbox on 16/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import UIKit

class CustomAppIconCellView: UICollectionViewCell {
    static let reuseIdentifier = "CustomAppIconCellView"

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var labelPro: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        imageView.layer.cornerRadius = 14
    }

    func setContent(_ image: UIImage, isPro: Bool = true) {
        imageView.image = image

        labelPro.backgroundColor = .systemPurple
        labelPro.isHidden = !isPro
    }
}
