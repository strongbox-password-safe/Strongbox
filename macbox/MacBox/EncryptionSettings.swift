//
//  EncryptionSettings.swift
//  MacBox
//
//  Created by Strongbox on 30/05/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class EncryptionSettings: NSViewController, NSMenuDelegate {
    let EditableKdfs: [KdfAlgorithm] = [.aes256, .argon2d, .argon2id]
    let EditableEncryption: [EncryptionAlgorithm] = [.aes256, .chaCha20, .twoFish256]

    @IBOutlet var labelFormatAndVersion: NSTextField!
    @IBOutlet var popupKdf: NSPopUpButton!
    @IBOutlet var textFieldArgon2Memory: NSTextField!
    @IBOutlet var textFieldIterations: NSTextField!
    @IBOutlet var textieldArgon2Parallelism: NSTextField!
    @IBOutlet var labelInnerStreamAlgo: NSTextField!
    @IBOutlet var labelKdf: NSTextField!
    @IBOutlet var textFieldParallelism: NSTextField!
    @IBOutlet var stepperParallelism: NSStepper!
    @IBOutlet var sliderIterations: NSSlider!
    @IBOutlet var stepperIterations: NSStepper!
    @IBOutlet var stepperMemory: NSStepper!
    @IBOutlet var popupEncryption: NSPopUpButton!
    @IBOutlet var labelEncryption: NSTextField!
    @IBOutlet var popupCompression: NSPopUpButton!
    @IBOutlet var labelCompression: NSTextField!
    @IBOutlet var compressionStack: NSStackView!
    @IBOutlet var innerProtectedStreamStack: NSStackView!
    @IBOutlet var parallelismStack: NSStackView!
    @IBOutlet var memoryStack: NSStackView!
    @IBOutlet var popupFormat: NSPopUpButton!
    @IBOutlet var labelUpgradeToV4Recommended: NSTextField!
    @IBOutlet var reduceArgonMemoryStack: NSStackView!
    @IBOutlet var upgradeToV4Stack: NSStackView!

    @IBOutlet var buttonRestoreDefaults: NSButton!
    @IBOutlet var buttonClose: NSButton!
    @IBOutlet var buttonSave: NSButton!
    @IBOutlet var buttonDiscardChanges: NSButton!

    @objc var model: ViewModel! {
        didSet {
            savedSettings = EncryptionSettingsViewModel.fromDatabaseModel(model.database)
            currentSettings = savedSettings.clone()
        }
    }

    var savedSettings: EncryptionSettingsViewModel!
    var currentSettings: EncryptionSettingsViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        let min: Double = 1
        let max: Double = 1024

        stepperMemory.minValue = min
        stepperMemory.maxValue = max

        stepperParallelism.minValue = 1
        stepperParallelism.maxValue = 32

        bindUI()
    }

    @objc var isDirty: Bool {
        let diff = currentSettings.isDifferent(from: savedSettings)
        return !model.isEffectivelyReadOnly && diff
    }

    func bindUI() {
        bindFormat()
        bindKdf()
        bindIterations()
        bindMemory()
        bindParallelism()
        bindEncryption()
        bindCompression()
        bindInnerProtectedStream()

        buttonSave.isEnabled = isDirty
        buttonSave.isHidden = !isDirty

        buttonRestoreDefaults.isEnabled = !currentSettings.isStrongboxDefaultEncryptionSettings
        buttonRestoreDefaults.isHidden = currentSettings.isStrongboxDefaultEncryptionSettings

        buttonClose.isHidden = isDirty
        buttonClose.isEnabled = !isDirty

        buttonDiscardChanges.isEnabled = isDirty
        buttonDiscardChanges.isHidden = !isDirty
    }

    func bindFormat() {
        labelFormatAndVersion.stringValue = currentSettings.formatAndVersion
        popupFormat.menu?.removeAllItems()

        if currentSettings.formatIsEditable, !model.isEffectivelyReadOnly {
            for format in [DatabaseFormat.keePass, DatabaseFormat.keePass4] {
                let title = EncryptionSettingsViewModel.getAlternativeFormatString(format)
                let item = NSMenuItem(title: title, action: #selector(onChangeFormat(sender:)), keyEquivalent: "")
                item.target = self

                popupFormat.menu?.addItem(item)
            }

            popupFormat.selectItem(at: currentSettings.format == .keePass4 ? 1 : 0)
            popupFormat.isHidden = false
            popupFormat.isEnabled = !model.isEffectivelyReadOnly
            labelFormatAndVersion.isHidden = true
        } else {
            popupFormat.isHidden = true
            labelFormatAndVersion.isHidden = false
        }

        upgradeToV4Stack.isHidden = !currentSettings.shouldUpgradeToV4
    }

    @objc func onChangeFormat(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupFormat.menu?.index(of: sender) else {
            swlog("🔴 Could not find this menu item in the menu?!")
            return
        }

        currentSettings.format = idx == 0 ? .keePass : .keePass4

        bindUI()
    }

    func bindInnerProtectedStream() {
        labelInnerStreamAlgo.stringValue = currentSettings.innerStreamCipher
        innerProtectedStreamStack.isHidden = !currentSettings.shouldShowInnerStreamEncryption
    }

    func bindCompression() {
        popupCompression.menu?.removeAllItems()
        labelCompression.stringValue = currentSettings.compressionString

        if currentSettings.shouldShowCompressionSwitch, !model.isEffectivelyReadOnly {
            for compression in [false, true] {
                let title = EncryptionSettingsViewModel.compressionString(forCompression: compression)
                let item = NSMenuItem(title: title, action: #selector(onChangeCompression(sender:)), keyEquivalent: "")
                item.target = self

                popupCompression.menu?.addItem(item)
            }

            popupCompression.selectItem(at: currentSettings.compression ? 1 : 0)

            popupCompression.isHidden = false
            popupCompression.isEnabled = !model.isEffectivelyReadOnly
            labelCompression.isHidden = true
        } else {
            popupCompression.isHidden = true
            labelCompression.isHidden = false
        }

        compressionStack.isHidden = !currentSettings.shouldShowCompressionSwitch
    }

    func bindEncryption() {
        popupEncryption.menu?.removeAllItems()
        labelEncryption.stringValue = currentSettings.encryption

        if currentSettings.encryptionIsEditable, !model.isEffectivelyReadOnly {
            for encryption in EditableEncryption {
                let title = EncryptionSettingsViewModel.encryptionString(forAlgo: encryption)
                let item = NSMenuItem(title: title, action: #selector(onChangeEncryption(sender:)), keyEquivalent: "")
                item.target = self

                popupEncryption.menu?.addItem(item)
            }

            if let idx = EditableEncryption.firstIndex(of: currentSettings.encryptionAlgorithm) {
                popupEncryption.selectItem(at: idx)
            } else {
                swlog("🔴 Couldn't find Encryption Algo!")
            }

            popupEncryption.isHidden = false
            popupEncryption.isEnabled = !model.isEffectivelyReadOnly
            labelEncryption.isHidden = true
        } else {
            popupEncryption.isHidden = true
            labelEncryption.isHidden = false
        }
    }

    func bindKdf() {
        popupKdf.menu?.removeAllItems()
        let title = EncryptionSettingsViewModel.kdfString(forKdf: currentSettings.kdfAlgorithm)

        labelKdf.stringValue = title

        if currentSettings.kdfIsEditable, !model.isEffectivelyReadOnly {
            for kdf in EditableKdfs {
                let title = EncryptionSettingsViewModel.kdfString(forKdf: kdf)
                let item = NSMenuItem(title: title, action: #selector(onChangeKdf(sender:)), keyEquivalent: "")
                item.target = self

                popupKdf.menu?.addItem(item)
            }

            if let idx = EditableKdfs.firstIndex(of: currentSettings.kdfAlgorithm) {
                popupKdf.selectItem(at: idx)
            } else {
                swlog("🔴 Couldn't find KDF!")
            }

            popupKdf.isHidden = false
            popupKdf.isEnabled = !model.isEffectivelyReadOnly
            labelKdf.isHidden = true
        } else {
            popupKdf.isHidden = true
            labelKdf.isHidden = false
        }
    }

    func bindIterations() {
        sliderIterations.minValue = currentSettings.minKdfIterations
        sliderIterations.maxValue = currentSettings.maxKdfIterations
        sliderIterations.doubleValue = log2(Double(currentSettings.iterations))

        stepperIterations.minValue = pow(2.0, currentSettings.minKdfIterations)
        stepperIterations.maxValue = pow(2.0, currentSettings.maxKdfIterations)
        stepperIterations.integerValue = Int(currentSettings.iterations)

        textFieldIterations.stringValue = String(stepperIterations.integerValue)

        sliderIterations.isEnabled = !model.isEffectivelyReadOnly
        stepperIterations.isEnabled = !model.isEffectivelyReadOnly
        textFieldIterations.isEnabled = !model.isEffectivelyReadOnly
    }

    func bindMemory() {
        stepperMemory.integerValue = Int(currentSettings.argonMemory) / (1024 * 1024)
        textFieldArgon2Memory.stringValue = String(Int64(currentSettings.argonMemory / (1024 * 1024)))

        memoryStack.isHidden = !currentSettings.shouldShowArgon2Fields
        reduceArgonMemoryStack.isHidden = !currentSettings.shouldReduceArgon2Memory

        stepperMemory.isEnabled = !model.isEffectivelyReadOnly
        textFieldArgon2Memory.isEnabled = !model.isEffectivelyReadOnly
    }

    func bindParallelism() {
        stepperParallelism.integerValue = Int(currentSettings.argonParallelism)
        textFieldParallelism.stringValue = String(currentSettings.argonParallelism)
        parallelismStack.isHidden = !currentSettings.shouldShowArgon2Fields

        stepperParallelism.isEnabled = !model.isEffectivelyReadOnly
        textFieldParallelism.isEnabled = !model.isEffectivelyReadOnly
    }

    @IBAction func onStepperMemoryChanged(_: Any) {
        currentSettings.argonMemory = UInt64(stepperMemory.integerValue) * 1024 * 1024

        bindUI()
    }

    @IBAction func onMemoryEdited(_: Any) {
        

        stepperMemory.integerValue = textFieldArgon2Memory.integerValue
        currentSettings.argonMemory = UInt64(stepperMemory.integerValue * 1024 * 1024)

        bindUI()
    }

    @objc func onChangeCompression(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupCompression.menu?.index(of: sender) else {
            swlog("🔴 Could not find this menu item in the menu?!")
            return
        }

        currentSettings.compression = idx == 1

        bindUI()
    }

    @objc func onChangeEncryption(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupEncryption.menu?.index(of: sender), let algo = EditableEncryption[safe: idx] else {
            swlog("🔴 Could not find this menu item in the menu?!")
            return
        }

        currentSettings.encryptionAlgorithm = algo

        bindUI()
    }

    @IBAction func onStepperParallelism(_: Any) {
        currentSettings.argonParallelism = UInt32(stepperParallelism.integerValue)

        bindUI()
    }

    @IBAction func onParallelismEdited(_: Any) {
        swlog("✅ onParallelismEdited = textField = [%ld]", textFieldParallelism.integerValue)

        stepperParallelism.integerValue = textFieldParallelism.integerValue

        currentSettings.argonParallelism = UInt32(stepperParallelism.integerValue)

        bindUI()
    }

    @objc func onChangeKdf(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupKdf.menu?.index(of: sender), let kdf = EditableKdfs[safe: idx] else {
            swlog("🔴 Could not find this menu item in the menu?!")
            return
        }

        currentSettings.kdfAlgorithm = kdf

        bindUI()
    }

    @IBAction func onSliderIterationsChanged(_: Any) {
        let iter = powf(2.0, sliderIterations.floatValue)

        currentSettings.iterations = UInt64(iter)

        bindUI()
    }

    @IBAction func onStepperIterationsChanged(_: Any) {
        

        currentSettings.iterations = UInt64(stepperIterations.integerValue)

        bindUI()
    }

    @IBAction func onIterationsChanged(_: Any) {
        

        stepperIterations.integerValue = textFieldIterations.integerValue
        currentSettings.iterations = UInt64(stepperIterations.integerValue)

        bindUI()
    }

    @objc func applyCurrentChanges() {
        model.applyEncryptionSettingsViewModelChanges(currentSettings)

        savedSettings = EncryptionSettingsViewModel.fromDatabaseModel(model.database)
        currentSettings = savedSettings.clone()

        bindUI()
    }

    @objc func discardCurrentChanges() {
        currentSettings = savedSettings.clone()

        bindUI()
    }

    @IBAction func onRestoreDefaults(_: Any) {
        let defaults = EncryptionSettingsViewModel.defaults(for: currentSettings.format)

        currentSettings = defaults.clone()

        bindUI()
    }

    @IBAction func onDiscardChange(_: Any) {
        discardCurrentChanges()
    }

    @IBAction func onClose(_: Any?) {
        view.window?.cancelOperation(nil)
    }

    @IBAction func onApplyChanges(_: Any?) {
        applyCurrentChanges()
    }
}
