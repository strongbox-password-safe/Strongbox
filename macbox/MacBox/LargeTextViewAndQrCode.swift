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

    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var label: NSTextField!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var scrollViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var scrollViewMaximumHeightConstraint: NSLayoutConstraint!
    @IBOutlet var labelSubtext: NSTextField!
    @IBOutlet var labelLargeTextHeader: NSTextField!

    private var largeText: Bool = true
    private var string: String = "" {
        didSet {
            characters = Array(string)
        }
    }

    private var qrCodeString: String?

    private var subtext: String = ""
    private var characters: [Character] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func setContent(string: String, largeText: Bool = true, subtext: String = "", qrCodeString: String? = nil) {
        self.string = string
        self.largeText = largeText
        self.subtext = subtext
        self.qrCodeString = qrCodeString

        bindUI()
    }

    func bindUI() {
        let flowLayout = NSCollectionViewFlowLayout()

        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 4
        flowLayout.itemSize = NSSize(width: 36, height: 65) 

        view.wantsLayer = true

        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 5

        collectionView.collectionViewLayout = flowLayout
        collectionView.wantsLayer = true

        collectionView.register(LargeTextIndexedCharacter.self, forItemWithIdentifier: LargeTextIndexedCharacter.reuseIdentifier)

        collectionView.dataSource = self
        collectionView.delegate = self
        

        let qrCodeText = qrCodeString ?? string
        let image = Utils.getQrCode(qrCodeText, pointSize: 128)
        imageView.image = image

        

        let colored = ColoredStringHelper.getColorizedAttributedString(string, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.easyReadFont)

        label.attributedStringValue = colored

        scrollView.isHidden = !largeText

        labelSubtext.stringValue = subtext
        labelSubtext.isHidden = subtext.count == 0

        labelLargeTextHeader.stringValue = NSLocalizedString("generic_totp_secret", comment: "2FA Secret")
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
        characters.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: LargeTextIndexedCharacter.reuseIdentifier, for: indexPath) as! LargeTextIndexedCharacter

        let character = String(characters[indexPath.item])

        let colored = ColoredStringHelper.getColorizedAttributedString(character, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.largeTextEasyReadFont)

        item.setContent(index: indexPath.item + 1, attributedString: colored)

        return item
    }
}

extension LargeTextViewAndQrCode: NSCollectionViewDelegate {
    func collectionView(_: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let singleItem = indexPaths.first, let char = characters[safe: singleItem.item] else {
            return
        }

        ClipboardManager.sharedInstance().copyConcealedString(String(char))

        showToastMessage(index: singleItem.item + 1)
    }

    func showToastMessage(index: Int) {
        guard let hud = MBProgressHUD.showAdded(to: collectionView, animated: true) else {
            return
        }

        let color = CIColor(cgColor: NSColor.systemBlue.cgColor)
        let defaultColor = NSColor(deviceRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)

        hud.labelText = String(format: NSLocalizedString("character_number_n_copied_fmt", comment: "Character %@ Copied"), String(index))

        hud.color = defaultColor
        hud.mode = MBProgressHUDModeText
        hud.margin = 0.0
        hud.yOffset = 2.0
        hud.removeFromSuperViewOnHide = true
        hud.dismissible = false
        hud.cornerRadius = 5.0
        hud.dimBackground = false

        let when = DispatchTime.now() + 0.75
        DispatchQueue.main.asyncAfter(deadline: when) {
            hud.hide(true)
        }
    }
}
