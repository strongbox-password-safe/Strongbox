//
//  PasswordGenerationPreferences.swift
//  MacBox
//
//  Created by Strongbox on 16/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class PasswordGenerationPreferences: NSViewController {
    @IBOutlet var segmentAlgorithm: NSSegmentedControl!
    @IBOutlet var tabViewAlgo: NSTabView!
    @IBOutlet var samplePassword: ClickableTextField!
    @IBOutlet var progressStrength: NSProgressIndicator!
    @IBOutlet var labelStrength: NSTextField!
    @IBOutlet var wordCountSlider: NSSlider!
    @IBOutlet var wordCountLabel: NSTextField!
    @IBOutlet var wordSeparatorLabel: NSTextField!
    @IBOutlet var wordCasingPopup: NSPopUpButton!
    @IBOutlet var addSaltPopup: NSPopUpButton!
    @IBOutlet var hackerifyPopup: NSPopUpButton!
    @IBOutlet var wordListsLabel: NSTextField!
    @IBOutlet var characterCountSlider: NSSlider!
    @IBOutlet var characterGroups: NSSegmentedControl!
    @IBOutlet var pickCharactersForAll: NSButton!
    @IBOutlet var nonAmbiguousOnly: NSButton!
    @IBOutlet var easyReadOnly: NSButton!
    @IBOutlet var buttonGenerate: NSButton!
    @IBOutlet var excludedCharactersLabel: NSTextField!
    @IBOutlet var dicewareAdditionalCharacterGroups: NSSegmentedControl!

    @IBOutlet var characterCountTextField: NSTextField!

    @objc
    class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("PasswordGenerationPreferences"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        samplePassword.onClick = { [weak self] in
            guard let self else {
                return
            }

            self.onSamplePasswordClicked()
        }

        buttonGenerate.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        buttonGenerate.symbolConfiguration = .init(scale: .large)

        bindUI()

        refreshSample()
    }

    var onClickSampleOverride: ((_ sample: String) -> Void)?

    func onSamplePasswordClicked() {
        if let onClickSampleOverride {
            onClickSampleOverride(samplePassword.stringValue)
        } else {
            copySample()
        }
    }

    func copySample() {
        ClipboardManager.sharedInstance().copyConcealedString(samplePassword.stringValue)

        guard let hud = MBProgressHUD.showAdded(to: samplePassword, animated: true) else {
            return
        }

        let color = CIColor(cgColor: NSColor.systemBlue.cgColor)
        let defaultColor = NSColor(deviceRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)

        hud.labelText = NSLocalizedString("item_details_password_copied", comment: "Password Copied")
        hud.color = defaultColor
        hud.mode = MBProgressHUDModeText
        hud.margin = 0.0
        hud.yOffset = 2.0
        hud.removeFromSuperViewOnHide = true
        hud.dismissible = false
        hud.cornerRadius = 5.0
        hud.dimBackground = false

        let when = DispatchTime.now() + 0.5
        DispatchQueue.main.asyncAfter(deadline: when) {
            hud.hide(true)
        }
    }

    func bindUI() {
        let config = Settings.sharedInstance().passwordGenerationConfig

        segmentAlgorithm.selectedSegment = config.algorithm == .algorithmDiceware ? 1 : 0
        tabViewAlgo.selectTabViewItem(at: segmentAlgorithm.selectedSegment)

        

        characterCountSlider.integerValue = config.basicLength
        characterCountTextField.stringValue = String(config.basicLength)

        characterGroups.setSelected(false, forSegment: 0)
        characterGroups.setSelected(false, forSegment: 1)
        characterGroups.setSelected(false, forSegment: 2)
        characterGroups.setSelected(false, forSegment: 3)
        characterGroups.setSelected(false, forSegment: 4)

        for num in config.useCharacterGroups {
            if num.intValue == PasswordGenerationCharacterPool.upper.rawValue {
                characterGroups.setSelected(true, forSegment: 0)
            } else if num.intValue == PasswordGenerationCharacterPool.lower.rawValue {
                characterGroups.setSelected(true, forSegment: 1)
            } else if num.intValue == PasswordGenerationCharacterPool.numeric.rawValue {
                characterGroups.setSelected(true, forSegment: 2)
            } else if num.intValue == PasswordGenerationCharacterPool.symbols.rawValue {
                characterGroups.setSelected(true, forSegment: 3)
            } else if num.intValue == PasswordGenerationCharacterPool.latin1Supplement.rawValue {
                characterGroups.setSelected(true, forSegment: 4)
            }
        }

        easyReadOnly.state = config.easyReadCharactersOnly ? .on : .off
        nonAmbiguousOnly.state = config.nonAmbiguousOnly ? .on : .off
        pickCharactersForAll.state = config.pickFromEveryGroup ? .on : .off

        excludedCharactersLabel.stringValue = config.basicExcludedCharacters.count > 0 ? config.basicExcludedCharacters : NSLocalizedString("generic_none", comment: "None")

        

        wordCountSlider.integerValue = config.wordCount
        wordCountLabel.stringValue = String(config.wordCount)
        wordSeparatorLabel.stringValue = "\"" + config.wordSeparator + "\""
        wordCasingPopup.select(wordCasingPopup.menu?.item(at: config.wordCasing.rawValue))
        hackerifyPopup.select(hackerifyPopup.menu?.item(at: config.hackerify.rawValue))
        addSaltPopup.select(addSaltPopup.menu?.item(at: config.saltConfig.rawValue))

        let wordlists = PasswordGenerationConfig.wordListsMap()

        wordListsLabel.stringValue = config.wordLists.map { key in
            wordlists[key]?.name ?? "Unknown"
        }.sorted().joined(separator: ", ")

        dicewareAdditionalCharacterGroups.setSelected(config.dicewareAddUpper, forSegment: 0)
        dicewareAdditionalCharacterGroups.setSelected(config.dicewareAddLower, forSegment: 1)
        dicewareAdditionalCharacterGroups.setSelected(config.dicewareAddNumber, forSegment: 2)
        dicewareAdditionalCharacterGroups.setSelected(config.dicewareAddSymbols, forSegment: 3)
        dicewareAdditionalCharacterGroups.setSelected(config.dicewareAddLatin1Supplement, forSegment: 4)
    }

    @IBAction func onRefresh(_: Any) {
        refreshSample()
    }

    func refreshSample() {
        let config = Settings.sharedInstance().passwordGenerationConfig

        let sample = PasswordMaker.sharedInstance().generate(for: config) ?? NSLocalizedString("password_gen_vc_generation_failed", comment: "<Generation Failed>")

        let colorize = Settings.sharedInstance().colorizePasswords
        let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
        let dark = DarkMode.isOn
        let colored = ColoredStringHelper.getColorizedAttributedString(sample, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: samplePassword.font)

        

        let mut = NSMutableAttributedString(attributedString: colored)

        let paragraphStyle = NSMutableParagraphStyle()

        paragraphStyle.lineBreakMode = .byTruncatingTail 
        paragraphStyle.alignment = .center

        mut.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, sample.count))
        mut.addAttribute(.baselineOffset, value: -8.0, range: NSMakeRange(0, sample.count)) 

        samplePassword.attributedStringValue = mut

        bindPasswordStrength()
    }

    func bindPasswordStrength() {
        let pw = samplePassword.stringValue

        PasswordStrengthUIHelper.bindPasswordStrength(pw, labelStrength: labelStrength, progress: progressStrength)
    }

    @IBAction func onSettingsChanged(_: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        config.algorithm = segmentAlgorithm.selectedSegment == 0 ? .algorithmBasic : .algorithmDiceware

        

        config.basicLength = characterCountSlider.integerValue
        config.easyReadCharactersOnly = easyReadOnly.state == .on
        config.nonAmbiguousOnly = nonAmbiguousOnly.state == .on
        config.pickFromEveryGroup = pickCharactersForAll.state == .on

        

        config.wordCount = wordCountSlider.integerValue
        config.wordCasing = PasswordGenerationWordCasing(rawValue: wordCasingPopup.itemArray.firstIndex(of: wordCasingPopup.selectedItem!) ?? 0) ?? .title
        config.hackerify = PasswordGenerationHackerifyLevel(rawValue: hackerifyPopup.itemArray.firstIndex(of: hackerifyPopup.selectedItem!) ?? 0) ?? .basicSome
        config.saltConfig = PasswordGenerationSaltConfig(rawValue: addSaltPopup.itemArray.firstIndex(of: addSaltPopup.selectedItem!) ?? 0) ?? .none

        Settings.sharedInstance().passwordGenerationConfig = config

        bindUI()

        refreshSample()
    }

    @IBAction func onEditSeparator(_: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        guard let ret = MacAlerts().input(NSLocalizedString("mac_password_gen_enter_new_separator", comment: "Please Enter a New Word Separator"), defaultValue: config.wordSeparator, allowEmpty: true) else {
            return
        }

        config.wordSeparator = ret

        Settings.sharedInstance().passwordGenerationConfig = config

        bindUI()

        refreshSample()
    }

    @IBAction func onEditExcludedCharacters(_: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        guard let ret = MacAlerts().input(NSLocalizedString("password_gen_vc_prompt_excluded_characters", comment: "Excluded Characters"), defaultValue: config.basicExcludedCharacters, allowEmpty: true) else {
            return
        }

        config.basicExcludedCharacters = ret

        Settings.sharedInstance().passwordGenerationConfig = config

        bindUI()

        refreshSample()
    }

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == "segueToWordLists" {
            let vc = segue.destinationController as! WordListsController
            vc.onUpdated = { [weak self] in
                guard let self else { return }

                self.bindUI()

                self.refreshSample()
            }
        }
    }

    @IBAction func onAddCharacterToDiceware(_: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        config.dicewareAddUpper = dicewareAdditionalCharacterGroups.isSelected(forSegment: 0)
        config.dicewareAddLower = dicewareAdditionalCharacterGroups.isSelected(forSegment: 1)
        config.dicewareAddNumber = dicewareAdditionalCharacterGroups.isSelected(forSegment: 2)
        config.dicewareAddSymbols = dicewareAdditionalCharacterGroups.isSelected(forSegment: 3)
        config.dicewareAddLatin1Supplement = dicewareAdditionalCharacterGroups.isSelected(forSegment: 4)

        Settings.sharedInstance().passwordGenerationConfig = config

        bindUI()

        refreshSample()
    }

















    @IBAction func onEditBasicCharacterCount(_: Any) {
        let config = Settings.sharedInstance().passwordGenerationConfig

        guard let ret = MacAlerts().input(NSLocalizedString("password_gen_vc_prompt_excluded_characters", comment: "Excluded Characters"),
                                          defaultValue: String(config.basicLength),
                                          allowEmpty: false)
        else {
            return
        }

        guard let integer = Int(ret) else {
            return
        }

        characterCountSlider.integerValue = integer

        config.basicLength = characterCountSlider.integerValue

        Settings.sharedInstance().passwordGenerationConfig = config

        bindUI()

        refreshSample()
    }

    @IBAction func onCharacterGroups(_: Any) {
        let upper = characterGroups.isSelected(forSegment: 0)
        let lower = characterGroups.isSelected(forSegment: 1)
        let numeric = characterGroups.isSelected(forSegment: 2)
        let symbol = characterGroups.isSelected(forSegment: 3)
        let latin1 = characterGroups.isSelected(forSegment: 4)

        var arr: [NSNumber] = []

        if upper {
            arr.append(PasswordGenerationCharacterPool.upper.rawValue as NSNumber)
        }
        if lower {
            arr.append(PasswordGenerationCharacterPool.lower.rawValue as NSNumber)
        }
        if numeric {
            arr.append(PasswordGenerationCharacterPool.numeric.rawValue as NSNumber)
        }
        if symbol {
            arr.append(PasswordGenerationCharacterPool.symbols.rawValue as NSNumber)
        }
        if latin1 {
            arr.append(PasswordGenerationCharacterPool.latin1Supplement.rawValue as NSNumber)
        }

        if !arr.isEmpty { 
            let config = Settings.sharedInstance().passwordGenerationConfig

            config.useCharacterGroups = arr

            Settings.sharedInstance().passwordGenerationConfig = config
        }

        bindUI()

        refreshSample()
    }
}
