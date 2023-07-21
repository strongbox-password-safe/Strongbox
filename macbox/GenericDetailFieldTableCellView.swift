//
//  GenericDetailFieldTableCellView.swift
//  MacBox
//
//  Created by Strongbox on 10/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import AppKit
import Foundation

class GenericDetailFieldTableCellView: NSTableCellView, DetailTableCellViewPopupButton, NSMenuDelegate {
    @IBOutlet var textFieldFieldName: NSTextField!
    @IBOutlet var textFieldFieldValue: NSTextField!
    @IBOutlet var imageViewIcon: NSImageView!
    @IBOutlet var buttonConcealReveal: NSButton!
    @IBOutlet var buttonPopup: NSPopUpButton!
    @IBOutlet var labelStrength: NSTextField!
    @IBOutlet var progressStrength: NSProgressIndicator!
    @IBOutlet var stackViewStrength: NSStackView!
    @IBOutlet var stackViewParent: NSStackView!
    @IBOutlet var copyButton: NSButton!
    @IBOutlet var buttonHistory: NSPopUpButton!
    @IBOutlet var shareButton: NSButton!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if #available(macOS 11, *) {
            buttonConcealReveal.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)
            imageViewIcon.symbolConfiguration = NSImage.SymbolConfiguration(scale: .large)
        }

        buttonHistory.isHidden = true
        textFieldFieldValue.lineBreakMode = .byTruncatingTail
        
        monitorForQuickRevealKey()
    }

    func monitorForQuickRevealKey() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(kUpdateNotificationQuickRevealStateChanged), object: nil, queue: nil) { [weak self] notification in
            if let concealable = self?.concealable, concealable, (self?.containingWindow?.isKeyWindow ?? false) {

                
                if let optionKeyDown = notification.object as? NSNumber {
                    self?.concealed = !optionKeyDown.boolValue
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        buttonHistory.menu = nil
        buttonHistory.isHidden = true

        setContent(nil)
    }

    let colorize = Settings.sharedInstance().colorizePasswords
    let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
    let dark = DarkMode.isOn

    var value: String = ""
    var popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)?
    var onCopyButton: ((DetailsViewField?) -> Void)?
    var onShareButton: ((DetailsViewField?) -> Void)?

    var field: DetailsViewField?
    var concealable: Bool = false
    var textColorOverride: NSColor?

    var history : NSMenu? = nil {
        didSet {
            buttonHistory.menu = history
            buttonHistory.isHidden = history == nil
        }
    }
    
    var concealed: Bool = false {
        didSet {
            if concealed {
                if #available(macOS 11.0, *) {
                    buttonConcealReveal.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
                } else {
                    buttonConcealReveal.image = NSImage(named: "show")
                }

                textFieldFieldValue.attributedStringValue = NSAttributedString(string: "••••••••••••")
            } else {
                if #available(macOS 11.0, *) {
                    buttonConcealReveal.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
                } else {
                    buttonConcealReveal.image = NSImage(named: "hide")
                }

                if concealable {
                    let colored = ColoredStringHelper.getColorizedAttributedString(value, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: FontManager.shared.easyReadFont)
                    textFieldFieldValue.attributedStringValue = colored
                } else {
                    let attr: NSAttributedString
                    let paragraphStyle = NSMutableParagraphStyle()
                    
                    if ( singleLineMode ) {
                        paragraphStyle.lineBreakMode = .byTruncatingTail
                    }
                    
                    if let textColor = textColorOverride {
                        attr = NSAttributedString(string: value, attributes: [.foregroundColor: textColor, .paragraphStyle: paragraphStyle])
                    } else {
                        attr = NSAttributedString(string: value, attributes: [.paragraphStyle: paragraphStyle])
                    }

                    textFieldFieldValue.usesSingleLineMode = singleLineMode
                    
                    textFieldFieldValue.attributedStringValue = attr
                }
            }
        }
    }
    weak var containingWindow : NSWindow? = nil
    
    var singleLineMode : Bool = false
    
    func setContent(_ field: DetailsViewField?,
                    popupMenuUpdater: ((NSMenu, DetailsViewField) -> Void)? = nil,
                    image: NSImage? = nil,
                    onCopyButton: ((DetailsViewField?) -> Void)? = nil,
                    onShareButton: ((DetailsViewField?) -> Void)? = nil,
                    containingWindow : NSWindow? = nil,
                    singleLineMode : Bool = false ) {
        self.field = field
        
        textColorOverride = nil

        var name = "<Not Set>"
        var value = "<Not Set>"
        var concealed = false
        
        let showStrength = (field?.showStrength ?? false)
        stackViewStrength.isHidden = !showStrength

        if let field = field {
            name = field.name
            concealed = field.concealed
            concealable = field.concealable
            value = field.value

            if showStrength {
                PasswordStrengthUIHelper.bindPasswordStrength(field.value, labelStrength: labelStrength, progress: progressStrength)
            }

            if field.fieldType == .expiry {
                let expires = field.object as! Date
                let dateExpires = expires as NSDate
                let nearly = NodeFields.nearlyExpired(expires)

                let str = dateExpires.friendlyDateTimeString
                value = str











                textColorOverride = (dateExpires.isInPast ? .systemRed : (nearly ? .systemOrange : nil))
            }
        }

        textFieldFieldName.stringValue = name
        imageViewIcon.image = image
        imageViewIcon.isHidden = (image == nil)
        buttonConcealReveal.isHidden = !concealable
        
        self.singleLineMode = singleLineMode
        self.popupMenuUpdater = popupMenuUpdater
        buttonPopup.menu?.delegate = self

        self.onCopyButton = onCopyButton;
        self.copyButton.isHidden = onCopyButton == nil
        
        self.onShareButton = onShareButton;
        self.shareButton.isHidden = onShareButton == nil
        
        self.value = value
        self.concealed = concealable && concealed
        self.containingWindow = containingWindow
    }

    @IBAction func onToggleConcealReveal(_: Any?) {
        concealed = !concealed
    }

    func showPopupButtonMenu() {


        buttonPopup.performClick(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {


        guard let field = field else {
            return
        }

        popupMenuUpdater?(menu, field)
    }
    
    @IBAction func onShare(_ sender: Any) {
        self.onShareButton?(self.field)
    }
    
    @IBAction func onCopy(_ sender: Any) {
        self.onCopyButton?(self.field)
    }
}
