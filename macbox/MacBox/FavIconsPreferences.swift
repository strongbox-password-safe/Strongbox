//
//  FavIconsPreferences.swift
//  MacBox
//
//  Created by Strongbox on 20/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class FavIconsPreferences: NSViewController, NSTextFieldDelegate {
    @IBOutlet var duckDuckGo: NSButton!
    @IBOutlet var scanCommon: NSButton!
    @IBOutlet var ignoreSsl: NSButton!
    @IBOutlet var scanHtml: NSButton!
    @IBOutlet var google: NSButton!
    @IBOutlet var domainOnly: NSButton!

    @IBOutlet var textFieldIdealSize: NSTextField!
    @IBOutlet var textFieldMaxSize: NSTextField!
    @IBOutlet var textFieldIdealDimension: NSTextField!

    @IBOutlet var stepperIdealDimension: NSStepper!
    @IBOutlet var stepperMaxSize: NSStepper!
    @IBOutlet var stepperIdealSize: NSStepper!

    override func viewDidLoad() {
        super.viewDidLoad()

        textFieldMaxSize.delegate = self
        textFieldIdealSize.delegate = self
        textFieldIdealDimension.delegate = self

        bindUI()
    }

    func bindUI() {
        let options = Settings.sharedInstance().favIconDownloadOptions

        duckDuckGo.state = options.duckDuckGo ? .on : .off
        scanCommon.state = options.checkCommonFavIconFiles ? .on : .off
        ignoreSsl.state = options.ignoreInvalidSSLCerts ? .on : .off
        scanHtml.state = options.scanHtml ? .on : .off
        google.state = options.google ? .on : .off
        domainOnly.state = options.domainOnly ? .on : .off

        stepperMaxSize.integerValue = options.maxSize / 1024
        stepperIdealSize.integerValue = options.idealSize / 1024
        stepperIdealDimension.integerValue = options.idealDimension

        textFieldMaxSize.stringValue = String(stepperMaxSize.integerValue)
        textFieldIdealSize.stringValue = String(stepperIdealSize.integerValue)
        textFieldIdealDimension.stringValue = String(stepperIdealDimension.integerValue)
    }

    @IBAction func onStepperIdealSize(_: Any?) {


        let options = Settings.sharedInstance().favIconDownloadOptions

        options.idealSize = stepperIdealSize.integerValue * 1024

        Settings.sharedInstance().favIconDownloadOptions = options

        bindUI()
    }

    @IBAction func onStepperMaxSize(_: Any?) {


        let options = Settings.sharedInstance().favIconDownloadOptions

        options.maxSize = stepperMaxSize.integerValue * 1024

        Settings.sharedInstance().favIconDownloadOptions = options

        bindUI()
    }

    @IBAction func onStepperIdealDimensions(_: Any?) {


        let options = Settings.sharedInstance().favIconDownloadOptions

        options.idealDimension = stepperIdealDimension.integerValue

        Settings.sharedInstance().favIconDownloadOptions = options

        bindUI()
    }

    func controlTextDidChange(_ obj: Notification) {
        if let ob = obj.object as? NSTextField {
            if ob == textFieldMaxSize {
                stepperMaxSize.integerValue = Int(textFieldMaxSize.stringValue) ?? stepperMaxSize.integerValue
                onStepperMaxSize(nil)
            } else if ob == textFieldIdealSize {
                stepperIdealSize.integerValue = Int(textFieldIdealSize.stringValue) ?? stepperIdealSize.integerValue
                onStepperIdealSize(nil)
            } else if ob == textFieldIdealDimension {
                stepperIdealDimension.integerValue = Int(textFieldIdealDimension.stringValue) ?? stepperIdealDimension.integerValue
                onStepperIdealDimensions(nil)
            }
        }
    }

    @IBAction func onChanged(_: Any) {
        let options = Settings.sharedInstance().favIconDownloadOptions

        options.duckDuckGo = duckDuckGo.state == .on
        options.checkCommonFavIconFiles = scanCommon.state == .on
        options.ignoreInvalidSSLCerts = ignoreSsl.state == .on
        options.scanHtml = scanHtml.state == .on
        options.google = google.state == .on
        options.domainOnly = domainOnly.state == .on

        if options.isValid {
            Settings.sharedInstance().favIconDownloadOptions = options
        }

        bindUI()
    }
}
