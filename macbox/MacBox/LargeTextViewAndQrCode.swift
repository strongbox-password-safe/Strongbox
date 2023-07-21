//
//  LargeTextViewAndQrCode.swift
//  MacBox
//
//  Created by Strongbox on 24/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class LargeTextViewAndQrCode: NSViewController {
    class func instantiateFromStoryboard() -> Self {
        let sb = NSStoryboard(name: "LargeTextViewAndQrCode", bundle: nil)
        let vc = sb.instantiateInitialController() as? Self

        return vc!
    }

    let colorize = Settings.sharedInstance().colorizePasswords
    let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
    let dark = DarkMode.isOn

    @IBOutlet var labelFieldName: NSTextField!
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var label: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var scrollViewMaximumHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelSubtext: NSTextField!
    @IBOutlet weak var labelLargeTextHeader: NSTextField!
    
    var largeText: Bool = true
    var string: String = "" {
        didSet {
            characters = Array(string)
        }
    }

    var subtext : String = ""
    
    var characters: [Character] = []
    var fieldName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        let flowLayout = NSCollectionViewFlowLayout()

        flowLayout.minimumInteritemSpacing = 12
        flowLayout.minimumLineSpacing = 12
        flowLayout.itemSize = NSSize(width: 36, height: 65) 

        view.wantsLayer = true

        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 5

        collectionView.collectionViewLayout = flowLayout
        collectionView.wantsLayer = true

        collectionView.register(LargeTextIndexedCharacter.self, forItemWithIdentifier: LargeTextIndexedCharacter.reuseIdentifier)

        collectionView.dataSource = self

        

        let image = Utils.getQrCode(string, pointSize: 128)
        imageView.image = image

        

        let colored = ColoredStringHelper.getColorizedAttributedString(string, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.easyReadFont)

        label.attributedStringValue = colored

        scrollView.isHidden = !largeText

        labelFieldName.stringValue = fieldName

        labelSubtext.stringValue = subtext
        labelSubtext.isHidden = subtext.count == 0
        
        labelLargeTextHeader.stringValue = NSLocalizedString("generic_totp_secret", comment: "TOTP Secret")
        labelLargeTextHeader.isHidden = subtext.count == 0
        
        

        updateHeightConstraint()
    }

    @IBOutlet var buttonDismiss: NSButton! 
    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeFirstResponder(buttonDismiss)
    }

    func updateHeightConstraint() {
        guard let size = collectionView.collectionViewLayout?.collectionViewContentSize else {
            return
        }

        scrollViewHeightConstraint.constant = min(scrollViewMaximumHeightConstraint.constant, size.height)
    }

    @IBAction func onDismiss(_: Any) {
        dismiss(nil)
    }
}

extension LargeTextViewAndQrCode: NSCollectionViewDataSource {
    func collectionView(_: NSCollectionView, numberOfItemsInSection _: Int) -> Int {
        return characters.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: LargeTextIndexedCharacter.reuseIdentifier, for: indexPath) as! LargeTextIndexedCharacter

        let character = String(characters[indexPath.item])

        let colored = ColoredStringHelper.getColorizedAttributedString(character, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.largeTextEasyReadFont)

        item.labelCharacter.attributedStringValue = colored
        item.labelIndex.stringValue = String(indexPath.item + 1)

        return item
    }
}
