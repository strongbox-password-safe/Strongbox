//
//  TitleCellView.swift
//  MacBox
//
//  Created by Strongbox on 15/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class TitleCellView: NSTableCellView {
    @IBOutlet var titleLabel: ClickableTextField!
    @IBOutlet var image: ClickableImageView!
    @IBOutlet var buttonToggleFavourite: NSButton!

    var isFavourite: Bool = false {
        didSet {
            if oldValue != isFavourite { 
                bindFavourite()
            }
        }
    }

    var onToggle: (() -> Void)? = nil


    func setContent(_ title: String, _ image: NSImage, _ fav: Bool, _ favToggleEnabled: Bool, _ onToggle: @escaping (() -> Void), _ onClickTitleOrIcon: @escaping (() -> Void)) {
        titleLabel.stringValue = title
        self.image.image = image
        buttonToggleFavourite.isEnabled = favToggleEnabled
        isFavourite = fav

        self.onToggle = onToggle


        self.image.clickable = true
        self.image.onClick = {
            onClickTitleOrIcon()
        }

        titleLabel.onClick = {
            onClickTitleOrIcon()
        }
    }

    @IBAction func onToggleFavourite(_: Any) {
        isFavourite = !isFavourite 

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            onToggle?()
        }
    }

    func bindFavourite() {
        buttonToggleFavourite.contentTintColor = isFavourite ? .systemYellow : .systemGray
        buttonToggleFavourite.image = NSImage(systemSymbolName: isFavourite ? "star.fill" : "star", accessibilityDescription: nil)
    }
}
