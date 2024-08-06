//
//  MMcGSwiftUtils.swift
//  Strongbox
//
//  Created by Strongbox on 11/07/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class MMcGSwiftUtils: NSObject {
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    @objc class func navTitleWithImageAndText(titleText: String, image: UIImage?, tint: UIColor?) -> UIView {
        let imageView = UIImageView()
        imageView.image = image
        imageView.tintColor = tint
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 3
        imageView.layer.masksToBounds = true

        let label = UILabel()
        label.text = titleText
        label.sizeToFit()
        label.textAlignment = NSTextAlignment.center

        label.font = FontManager.sharedInstance().headlineFont

        let stackViewTitle = UIStackView(arrangedSubviews: [imageView, label])

        stackViewTitle.spacing = 4
        stackViewTitle.axis = .horizontal
        stackViewTitle.alignment = .center
        stackViewTitle.distribution = .fill 
        stackViewTitle.isLayoutMarginsRelativeArrangement = true
        stackViewTitle.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 26),
            imageView.heightAnchor.constraint(equalToConstant: 26),
        ])

        stackViewTitle.sizeToFit()

        return stackViewTitle
    }

    @objc
    public class func stripInvalidFilenameCharacters(_ originalFilename: String) -> String {
        var invalidCharacters = CharacterSet(charactersIn: ":/")
        invalidCharacters.formUnion(.newlines)
        invalidCharacters.formUnion(.illegalCharacters)
        invalidCharacters.formUnion(.controlCharacters)

        let newFilename = originalFilename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "")

        return newFilename
    }
}
