//
//  PasswordGenerationPreferences.swift
//  MacBox
//
//  Created by Strongbox on 16/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class PasswordGenerationPreferences: NSViewController {
    @IBOutlet weak var segmentAlgorithm: NSSegmentedControl!
    @IBOutlet weak var tabViewAlgo: NSTabView!
    @IBOutlet weak var samplePassword: ClickableTextField!
    @IBOutlet weak var progressStrength: NSProgressIndicator!
    @IBOutlet weak var labelStrength: NSTextField!
    @IBOutlet weak var wordCountSlider: NSSlider!
    @IBOutlet weak var wordCountLabel: NSTextField!
    @IBOutlet weak var wordSeparatorLabel: NSTextField!
    @IBOutlet weak var wordCasingPopup: NSPopUpButton!
    @IBOutlet weak var addSaltPopup: NSPopUpButton!
    @IBOutlet weak var hackerifyPopup: NSPopUpButton!
    @IBOutlet weak var wordListsLabel: NSTextField!
    @IBOutlet weak var characterCountSlider: NSSlider!
    @IBOutlet weak var characterCountLabel: NSTextField!
    @IBOutlet weak var characterGroups: NSSegmentedControl!
    @IBOutlet weak var pickCharactersForAll: NSButton!
    @IBOutlet weak var nonAmbiguousOnly: NSButton!
    @IBOutlet weak var easyReadOnly: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        samplePassword.onClick = { [weak self] in
            guard let self = self else {
                return
            }

            self.onSamplePasswordClicked()
        }
        
        bindUI()
        
        refreshSample()
    }
    
    func onSamplePasswordClicked() {
        ClipboardManager.sharedInstance().copyConcealedString(samplePassword.stringValue)
        
        guard let hud = MBProgressHUD.showAdded(to: samplePassword, animated: true) else {
            return
        }
        
        let color = CIColor(cgColor: NSColor.systemBlue.cgColor)
        let defaultColor = NSColor (deviceRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        
        hud.labelText = NSLocalizedString("item_details_password_copied", comment: "Password Copied")
        hud.color = defaultColor
        hud.mode = MBProgressHUDModeText;
        hud.margin = 0.0
        hud.yOffset = 2.0
        hud.removeFromSuperViewOnHide = true
        hud.dismissible = false
        hud.cornerRadius = 5.0
        hud.dimBackground = true
        
        let when = DispatchTime.now() + 0.75
        DispatchQueue.main.asyncAfter(deadline: when) {
            hud.hide(true)
        }
    }
    
    func bindUI () {
        let config = Settings.sharedInstance().passwordGenerationConfig
        
        segmentAlgorithm.selectedSegment = config.algorithm == .algorithmDiceware ? 1 : 0
        tabViewAlgo.selectTabViewItem(at: segmentAlgorithm.selectedSegment)
        
        
        
        characterCountSlider.integerValue = config.basicLength
        characterCountLabel.stringValue = String(config.basicLength)
        
        characterGroups.setSelected(false, forSegment: 0)
        characterGroups.setSelected(false, forSegment: 1)
        characterGroups.setSelected(false, forSegment: 2)
        characterGroups.setSelected(false, forSegment: 3)
        characterGroups.setSelected(false, forSegment: 4)
        
        for num in config.useCharacterGroups {
            if ( num.intValue == PasswordGenerationCharacterPool.upper.rawValue ) {
                characterGroups.setSelected(true, forSegment: 0)
            }
            else if ( num.intValue == PasswordGenerationCharacterPool.lower.rawValue ) {
                characterGroups.setSelected(true, forSegment: 1)
            }
            else if ( num.intValue == PasswordGenerationCharacterPool.numeric.rawValue ) {
                characterGroups.setSelected(true, forSegment: 2)
            }
            else if ( num.intValue == PasswordGenerationCharacterPool.symbols.rawValue ) {
                characterGroups.setSelected(true, forSegment: 3)
            }
            else if ( num.intValue == PasswordGenerationCharacterPool.latin1Supplement.rawValue ) {
                characterGroups.setSelected(true, forSegment: 4)
            }
        }
        
        easyReadOnly.state = config.easyReadCharactersOnly ? .on : .off
        nonAmbiguousOnly.state = config.nonAmbiguousOnly ? .on : .off
        pickCharactersForAll.state = config.pickFromEveryGroup ? .on : .off

        
        
        wordCountSlider.integerValue = config.wordCount
        wordCountLabel.stringValue = String(config.wordCount)
        wordSeparatorLabel.stringValue = "\"" + config.wordSeparator + "\""
        wordCasingPopup.select(wordCasingPopup.menu?.item(at: config.wordCasing.rawValue))
        hackerifyPopup.select(hackerifyPopup.menu?.item(at: config.hackerify.rawValue))
        addSaltPopup.select(addSaltPopup.menu?.item(at: config.saltConfig.rawValue))
        
        let wordlists = PasswordGenerationConfig.wordListsMap()

        wordListsLabel.stringValue = config.wordLists.map({ key in
            wordlists[key]?.name ?? "Unknown"
        }).sorted().joined(separator: ", ")
    }
    
    @IBAction func onRefresh(_ sender: Any) {
        refreshSample()
    }
    
    func refreshSample() {
        let config = Settings.sharedInstance().passwordGenerationConfig

        let sample = PasswordMaker.sharedInstance().generate(for: config) ?? NSLocalizedString("password_gen_vc_generation_failed", comment: "<Generation Failed>")
    
        let colorize = Settings.sharedInstance().colorizePasswords
        let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
        let dark = DarkMode.isOn
        let colored = ColoredStringHelper.getColorizedAttributedString(sample, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: samplePassword.font)
        
        
        
        let mut : NSMutableAttributedString = NSMutableAttributedString.init(attributedString: colored)

        let paragraphStyle : NSMutableParagraphStyle = NSMutableParagraphStyle()
        
        paragraphStyle.lineBreakMode = .byTruncatingTail 
        paragraphStyle.alignment = .center

        mut.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, sample.count))
        
        samplePassword.attributedStringValue = mut
        
        bindPasswordStrength()
    }
    
    func bindPasswordStrength() {
        let pw = samplePassword.stringValue
        let strength = PasswordStrengthTester.getStrength(pw, config: PasswordStrengthConfig.defaults()) 

        labelStrength.stringValue = strength.summaryString
        
        let relativeStrength = min(strength.entropy / 128.0, 1.0); 
            
        progressStrength.doubleValue = relativeStrength * 100.0;
        
        guard let colorPoly = CIFilter(name: "CIColorPolynomial") else {
            return;
        }
        
        colorPoly.setDefaults()
        
        let red = 1.0 - relativeStrength;
        let green = relativeStrength;

        let redVector = CIVector(x: red, y: 0, z: 0, w: 0)
        let greenVector = CIVector(x: green, y: 0, z: 0, w: 0)
        let blueVector = CIVector(x: 0, y: 0, z: 0, w: 0)

        colorPoly.setValue(redVector, forKey: "inputRedCoefficients")
        colorPoly.setValue(greenVector, forKey: "inputGreenCoefficients")
        colorPoly.setValue(blueVector, forKey: "inputBlueCoefficients")

        progressStrength.contentFilters = [colorPoly]
    }
    
    @IBAction func onSettingsChanged(_ sender: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig
        
        config.algorithm = segmentAlgorithm.selectedSegment == 0 ? .algorithmBasic : .algorithmDiceware
        
        
        
        config.basicLength = characterCountSlider.integerValue
        config.easyReadCharactersOnly = easyReadOnly.state == .on
        config.nonAmbiguousOnly = nonAmbiguousOnly.state == .on
        config.pickFromEveryGroup = pickCharactersForAll.state == .on
        
        
        
        config.wordCount = wordCountSlider.integerValue;
        config.wordCasing = PasswordGenerationWordCasing ( rawValue: wordCasingPopup.itemArray.firstIndex(of: wordCasingPopup.selectedItem!) ?? 0 ) ?? .title
        config.hackerify = PasswordGenerationHackerifyLevel ( rawValue: hackerifyPopup.itemArray.firstIndex(of: hackerifyPopup.selectedItem!) ?? 0 ) ?? .basicSome
        config.saltConfig = PasswordGenerationSaltConfig ( rawValue: addSaltPopup.itemArray.firstIndex(of: addSaltPopup.selectedItem!) ?? 0 ) ?? .none
        
        Settings.sharedInstance().passwordGenerationConfig = config
        
        bindUI()
        
        refreshSample()
    }
    
    @IBAction func onEditSeparator(_ sender: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        guard let ret = MacAlerts().input(NSLocalizedString("mac_password_gen_enter_new_separator", comment: "Please Enter a New Word Separator"), defaultValue: config.wordSeparator, allowEmpty: true) else {
            return
        }
        
        config.wordSeparator = ret

        Settings.sharedInstance().passwordGenerationConfig = config
        
        bindUI()
        
        refreshSample()
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if ( segue.identifier == "segueToWordLists" ) {
            let vc = segue.destinationController as! WordListsController
            vc.onUpdated = { [weak self] in
                guard let self = self else { return }
                
                self.bindUI()
                
                self.refreshSample()
            }
        }
    }
    
    @IBAction func onCharacterGroups(_ sender: Any) {
        let upper = characterGroups.isSelected(forSegment: 0)
        let lower = characterGroups.isSelected(forSegment: 1)
        let numeric = characterGroups.isSelected(forSegment: 2)
        let symbol = characterGroups.isSelected(forSegment: 3)
        let latin1 = characterGroups.isSelected(forSegment: 4)

        var arr : [NSNumber] = []
        
        if ( upper ) {
            arr.append( PasswordGenerationCharacterPool.upper.rawValue as NSNumber )
        }
        if ( lower ) {
            arr.append( PasswordGenerationCharacterPool.lower.rawValue as NSNumber )
        }
        if ( numeric ) {
            arr.append( PasswordGenerationCharacterPool.numeric.rawValue as NSNumber )
        }
        if ( symbol ) {
            arr.append( PasswordGenerationCharacterPool.symbols.rawValue as NSNumber )
        }
        if ( latin1 ) {
            arr.append( PasswordGenerationCharacterPool.latin1Supplement.rawValue as NSNumber )
        }

        if ( !arr.isEmpty ) { 
            let config = Settings.sharedInstance().passwordGenerationConfig

            config.useCharacterGroups = arr

            Settings.sharedInstance().passwordGenerationConfig = config;
        }

        bindUI()
        
        refreshSample()
    }
}
