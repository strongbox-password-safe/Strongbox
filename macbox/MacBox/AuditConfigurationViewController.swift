//
//  AuditConfigurationViewController.swift
//  MacBox
//
//  Created by Strongbox on 09/02/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AuditConfigurationViewController: NSViewController {
    @IBOutlet var checkboxAuditDatabase: NSButton!

    @IBOutlet var stackViewDupe: NSStackView!
    @IBOutlet var stackViewLength: NSStackView!
    @IBOutlet var stackViewEntropy: NSStackView!
    @IBOutlet var stackViewSimilar: NSStackView!
    @IBOutlet var stackViewStatus: NSStackView!
    @IBOutlet var stackViewConfig: NSStackView!

    @IBOutlet var popupHibpInterval: NSPopUpButton!
    @IBOutlet var stackViewHibpConfig: NSStackView!

    @IBOutlet var checkboxEmpty: NSButton!
    @IBOutlet var chckboxCommon: NSButton!
    @IBOutlet var checkboxTwoFactor: NSButton!
    @IBOutlet var checkboxHibp: NSButton!
    @IBOutlet var checkboxDuplicated: NSButton!
    @IBOutlet var checkboxDuplicateCaseInsensitive: NSButton!

    @IBOutlet var checkboxLength: NSButton!
    @IBOutlet var sliderLength: NSSlider!
    @IBOutlet var labelLength: NSTextField!

    @IBOutlet var checkboxEntropy: NSButton!
    @IBOutlet var sliderEntropy: NSSlider!
    @IBOutlet var labelEntropy: NSTextField!

    @IBOutlet var checkboxSimilar: NSButton!
    @IBOutlet var sliderSimilar: NSSlider!
    @IBOutlet var labelSimilar: NSTextField!

    @IBOutlet var buttonExcludedItems: NSButton!

    @IBOutlet var labelStatus: NSTextField!
    @IBOutlet var labelSubStatus: NSTextField!

    @IBOutlet var labelOnlineHibpInterval: NSTextField!
    @objc var database: ViewModel!

    @IBOutlet var ignoreShortNumericOnly: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        popupHibpInterval.menu?.removeAllItems()

        let always = NSMenuItem(title: NSLocalizedString("hibp_check_interval_always_check", comment: "Always Check"),
                                action: #selector(onSetHibpIntervalAlways), keyEquivalent: "")
        always.target = self
        popupHibpInterval.menu?.addItem(always)

        let daily = NSMenuItem(title: NSLocalizedString("hibp_check_interval_once_a_day", comment: "Once a Day"),
                               action: #selector(onSetHibpIntervalOnceADay), keyEquivalent: "")
        daily.target = self
        popupHibpInterval.menu?.addItem(daily)

        let weekly = NSMenuItem(title: NSLocalizedString("hibp_check_interval_once_a_week", comment: "Once a Week"),
                                action: #selector(onSetHibpIntervalOnceAWeek), keyEquivalent: "")
        weekly.target = self
        popupHibpInterval.menu?.addItem(weekly)

        let monthly = NSMenuItem(title: NSLocalizedString("hibp_check_interval_once_every_30_days", comment: "Once Every 30 days"),
                                 action: #selector(onSetHibpIntervalOnceAMonth), keyEquivalent: "")
        monthly.target = self
        popupHibpInterval.menu?.addItem(monthly)

        bindUI()

        NotificationCenter.default.addObserver(forName: .auditProgress, object: nil, queue: nil) { [weak self] notification in
            self?.bindAuditStatus(notification)
        }

        NotificationCenter.default.addObserver(forName: .auditCompleted, object: nil, queue: nil) { [weak self] notification in
            self?.bindAuditStatus(notification)
        }
    }

    func bindAuditStatus(_ notification: Notification) {
        bindAuditStatusWithProgress(notification.object as? NSNumber)
    }

    func bindAuditStatusWithProgress(_ progress: NSNumber? = nil) {
        switch database.auditState {
        case .done:
            labelStatus.stringValue = NSLocalizedString("audit_status_complete", comment: "Status: Complete")

            var loc: String

            if database.auditHibpErrorCount > 0 {
                loc = NSLocalizedString("audit_status_done_with_hibp_errors_fmt", comment: "Found %@ issues in %@ entries (with %@ HIBP Errors)")
            } else {
                loc = (database.auditIssueCount != nil && database.auditIssueCount!.intValue > 0) ?
                    NSLocalizedString("audit_status_fmt", comment: "Found %@ issues in %@ entries") : NSLocalizedString("audit_status_no_issues_found", comment: "No issues found")
            }

            labelSubStatus.stringValue = String(format: loc, database.auditIssueCount ?? 0, String(database.auditIssueNodeCount), String(database.auditHibpErrorCount))
            labelSubStatus.isHidden = false
        case .initial:
            labelStatus.stringValue = database.auditConfig.auditInBackground ? NSLocalizedString("audit_status_initialized", comment: "Database Auditor Initialized") : NSLocalizedString("audit_status_initialized_but_disabled", comment: "audit_status_initialized_but_disabled")
            labelSubStatus.isHidden = true
        case .running:
            let unknownString = NSLocalizedString("audit_status_running_with_ellipsis", comment: "Auditing...")
            labelStatus.stringValue = progress != nil ? String(format: NSLocalizedString("audit_status_running_with_progress_fmt", comment: "Auditing... (%d%%)"), Int(progress!.floatValue * 100.0)) : unknownString
            labelSubStatus.isHidden = true
        case .stoppedIncomplete:
            labelStatus.stringValue = NSLocalizedString("audit_status_stopped", comment: "Audit Stopped")
            labelSubStatus.isHidden = true
        @unknown default:
            swlog("🔴 Unknown Audit State!")
        }
    }

    @IBAction func onClose(_: Any) {
        view.window?.cancelOperation(nil)
    }

    func bindUI() {
        let config = database.auditConfig

        checkboxAuditDatabase.state = config.auditInBackground ? .on : .off

        checkboxEmpty.state = config.checkForNoPasswords ? .on : .off
        chckboxCommon.state = config.checkForCommonPasswords ? .on : .off
        checkboxTwoFactor.state = config.checkForTwoFactorAvailable ? .on : .off
        checkboxHibp.state = config.checkHibp ? .on : .off

        checkboxDuplicated.state = config.checkForDuplicatedPasswords ? .on : .off
        checkboxDuplicateCaseInsensitive.state = config.caseInsensitiveMatchForDuplicates ? .on : .off

        checkboxLength.state = config.checkForMinimumLength ? .on : .off
        sliderLength.intValue = Int32(config.minimumLength)
        bindLabelLength()

        checkboxEntropy.state = config.checkForLowEntropy ? .on : .off
        sliderEntropy.intValue = Int32(config.lowEntropyThreshold)
        bindLabelEntropy()

        checkboxSimilar.state = config.checkForSimilarPasswords ? .on : .off
        sliderSimilar.intValue = Int32(config.levenshteinSimilarityThreshold * 100)
        bindLabelSimilarity()

        

        checkboxEmpty.isEnabled = config.auditInBackground
        chckboxCommon.isEnabled = config.auditInBackground
        checkboxTwoFactor.isEnabled = config.auditInBackground

        let hibpPossible = config.auditInBackground && Settings.sharedInstance().isPro
        checkboxHibp.isEnabled = hibpPossible
        if !hibpPossible {

        }

        popupHibpInterval.isEnabled = hibpPossible && config.checkHibp
        labelOnlineHibpInterval.textColor = hibpPossible && config.checkHibp ? .controlTextColor : .disabledControlTextColor

        bindHibpInterval(config)

        checkboxDuplicated.isEnabled = config.auditInBackground
        checkboxDuplicateCaseInsensitive.isEnabled = config.auditInBackground && config.checkForDuplicatedPasswords

        checkboxLength.isEnabled = config.auditInBackground
        sliderLength.isEnabled = config.auditInBackground && config.checkForMinimumLength
        labelLength.textColor = (config.auditInBackground && config.checkForMinimumLength) ? .controlTextColor : .disabledControlTextColor

        let similarPossible = config.auditInBackground && Settings.sharedInstance().isPro
        checkboxSimilar.isEnabled = similarPossible

        if !similarPossible {

        }

        sliderSimilar.isEnabled = similarPossible && config.checkForSimilarPasswords
        labelSimilar.textColor = (similarPossible && config.checkForSimilarPasswords) ? .controlTextColor : .disabledControlTextColor

        checkboxEntropy.isEnabled = config.auditInBackground
        sliderEntropy.isEnabled = config.auditInBackground && config.checkForLowEntropy
        labelEntropy.textColor = (config.auditInBackground && config.checkForLowEntropy) ? .controlTextColor : .disabledControlTextColor

        buttonExcludedItems.isEnabled = config.auditInBackground

        ignoreShortNumericOnly.state = config.excludeShortNumericPINCodes ? .on : .off
        ignoreShortNumericOnly.isEnabled = config.auditInBackground

        bindAuditStatusWithProgress()
    }

    let kHibpAlwaysCheck: UInt = 0
    let kHibpOnceADay: UInt = 24 * 60 * 60
    let kHibpOnceAWeek: UInt = 24 * 60 * 60 * 7
    let kHibpOnceEvery30Days: UInt = 24 * 60 * 60 * 30

    @objc func onSetHibpIntervalAlways() {
        let config = database.auditConfig

        config.hibpCheckForNewBreachesIntervalSeconds = kHibpAlwaysCheck
        database.auditConfig = config
        restartAuditor()
    }

    @objc func onSetHibpIntervalOnceADay() {
        let config = database.auditConfig

        config.hibpCheckForNewBreachesIntervalSeconds = kHibpOnceADay
        database.auditConfig = config
        restartAuditor()
    }

    @objc func onSetHibpIntervalOnceAWeek() {
        let config = database.auditConfig

        config.hibpCheckForNewBreachesIntervalSeconds = kHibpOnceAWeek
        database.auditConfig = config

        restartAuditor()
    }

    @objc func onSetHibpIntervalOnceAMonth() {
        let config = database.auditConfig
        config.hibpCheckForNewBreachesIntervalSeconds = kHibpOnceEvery30Days

        database.auditConfig = config

        bindUI()

        restartAuditor()
    }

    func bindHibpInterval(_ config: DatabaseAuditorConfiguration) {
        switch config.hibpCheckForNewBreachesIntervalSeconds {
        case kHibpAlwaysCheck:
            popupHibpInterval.selectItem(at: 0)
        case kHibpOnceADay:
            popupHibpInterval.selectItem(at: 1)
        case kHibpOnceAWeek:
            popupHibpInterval.selectItem(at: 2)
        case kHibpOnceEvery30Days:
            popupHibpInterval.selectItem(at: 3)
        default:
            swlog("🔴 Unknown/unusual Jibp Interval: [%@]", String(describing: config.hibpCheckForNewBreachesIntervalSeconds))
            popupHibpInterval.selectItem(at: 0)
        }
    }

    @IBAction func onHibpChanged(_: Any) {
        if checkboxHibp.state != .on {
            let config = database.auditConfig
            config.lastHibpOnlineCheck = nil
            database.auditConfig = config
        }

        if checkboxHibp.state == .on, !database.auditConfig.checkHibp, !database.auditConfig.hibpCaveatAccepted {
            let loc1 = NSLocalizedString("audit_hibp_warning_title", comment: "HIBP Disclaimer")
            let loc2 = NSLocalizedString("audit_hibp_warning_message", comment: "I understand that my passwords will be sent over the web (HTTPS) to the 'Have I Been Pwned?' password checking service (using k-anonymity) and that I fully consent to this functionality. I also absolve Strongbox, Mark McGuill and Phoebe Code Limited of all liabilty for using this feature.")
            let locNo = NSLocalizedString("audit_hibp_warning_no", comment: "No, I don't want to use this feature")
            let locYes = NSLocalizedString("audit_hibp_warning_yes", comment: "Yes, I understand and agree")

            MacAlerts.twoOptions(withCancel: loc1, informativeText: loc2, option1AndDefault: locNo, option2: locYes, window: view.window) { [weak self] response in
                guard let self else { return }

                if response == 1 { 
                    let config = self.database.auditConfig

                    config.hibpCaveatAccepted = true
                    self.database.auditConfig = config

                    self.onSimpleChanged(nil)
                } else { 
                    self.bindUI()
                }
            }
        } else {
            onSimpleChanged(nil)
        }
    }

    @IBAction func onSimpleChanged(_: Any?) {


        let config = database.auditConfig

        let newlySwitchedOff = config.auditInBackground && checkboxAuditDatabase.state == .off

        config.auditInBackground = checkboxAuditDatabase.state == .on

        config.checkForNoPasswords = checkboxEmpty.state == .on
        config.checkForCommonPasswords = chckboxCommon.state == .on
        config.checkForTwoFactorAvailable = checkboxTwoFactor.state == .on
        config.checkHibp = checkboxHibp.state == .on

        config.checkForDuplicatedPasswords = checkboxDuplicated.state == .on
        config.caseInsensitiveMatchForDuplicates = checkboxDuplicateCaseInsensitive.state == .on

        config.checkForMinimumLength = checkboxLength.state == .on
        config.minimumLength = UInt(sliderLength.intValue)

        config.checkForLowEntropy = checkboxEntropy.state == .on
        config.lowEntropyThreshold = UInt(sliderEntropy.intValue)

        config.checkForSimilarPasswords = checkboxSimilar.state == .on
        config.levenshteinSimilarityThreshold = (Double(sliderSimilar.intValue) / 100.0)

        config.excludeShortNumericPINCodes = ignoreShortNumericOnly.state == .on

        

        database.auditConfig = config

        bindUI()

        restartAuditor(newlySwitchedOff: newlySwitchedOff)
    }

    @IBAction func onSliderLengthChanged(_: Any) {
        if sliderLength.intValue != database.auditConfig.minimumLength {
            onSimpleChanged(nil)
        } else {
            bindLabelLength()
        }
    }

    @IBAction func onSliderEntopyChanged(_: Any) {
        if sliderEntropy.intValue != database.auditConfig.lowEntropyThreshold {
            onSimpleChanged(nil)
        } else {
            bindLabelEntropy()
        }
    }

    @IBAction func onSliderSimilarityChanged(_: Any) {
        onSimpleChanged(nil)
    }

    func bindLabelLength() {
        let loc = NSLocalizedString("num_of_characters_fmt", comment: "%@ characters")

        labelLength.stringValue = String(format: loc, String(sliderLength.intValue))
    }

    func bindLabelEntropy() {
        let loc = NSLocalizedString("num_of_bits_fmt", comment: "%@ bits")

        labelEntropy.stringValue = String(format: loc, String(sliderEntropy.intValue))
    }

    func bindLabelSimilarity() {
        labelSimilar.stringValue = String(format: "%0.1f%%", sliderSimilar.doubleValue)
    }

    func restartAuditor(newlySwitchedOff: Bool = false) {
        if refreshTimer != nil {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.foo(newlySwitchedOff: newlySwitchedOff)
        }
    }

    func foo(newlySwitchedOff: Bool) {
        database.restartBackgroundAudit()

        if newlySwitchedOff {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                NotificationCenter.default.post(name: NSNotification.Name(rawValue: kAuditNewSwitchedOffNotificationKey), object: [
                    "model": database.commonModel,
                ])
            }
        }
    }

    var refreshTimer: Timer?

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == "segueToExcludedItems" {
            let vc = segue.destinationController as! AuditExcludedItems

            vc.database = database
        }
    }
}
