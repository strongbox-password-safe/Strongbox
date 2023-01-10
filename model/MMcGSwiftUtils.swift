//
//  MMcGSwiftUtils.swift
//  Strongbox
//
//  Created by Strongbox on 11/07/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class MMcGSwiftUtils : NSObject {
//    class func generateRoundCornerImage(image : UIImage , radius : CGFloat) -> UIImage {
//        let imageLayer = CALayer()
//        imageLayer.frame = CGRect(0, 0, image.size.width, image.size.height)
//        imageLayer.contents = image.cgImage
//        imageLayer.masksToBounds = true









        
    @objc class func navTitleWithImageAndText(titleText: String, image : UIImage?, tint : UIColor?) -> UIView {
        let imageView = UIImageView()
        imageView.image = image
        imageView.tintColor = tint
        imageView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.text = titleText
        label.sizeToFit()
        label.textAlignment = NSTextAlignment.center

        label.font = FontManager.sharedInstance().headlineFont
        
        let stackViewTitle = UIStackView(arrangedSubviews: [imageView, label])

        stackViewTitle.spacing = 4
        stackViewTitle.axis = .horizontal
        stackViewTitle.alignment = .center
        stackViewTitle.distribution = .fill; 
        stackViewTitle.isLayoutMarginsRelativeArrangement = true
        stackViewTitle.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 26),
            imageView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        stackViewTitle.sizeToFit()
        
        return stackViewTitle
    }
}
