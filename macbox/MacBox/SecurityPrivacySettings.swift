//
//  SecurityPrivacySettings.swift
//  MacBox
//
//  Created by Strongbox on 31/10/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

@MainActor
class SecurityPrivacySettings: NSViewController {
    @IBOutlet var blockScreenshots: NSButton!
    @IBOutlet var quickReveal: NSButton!
    @IBOutlet var revealImmediately: NSButton!

    @IBOutlet var hideOnCopy: NSButton!
    @IBOutlet var miniaturizeOnCopy: NSButton!
    @IBOutlet var autoClearClipboard: NSButton!
    @IBOutlet var autoClearClipboardTimeout: NSTextField!
    @IBOutlet var stepperAutoClearClipboard: NSStepper!
    @IBOutlet var allowClipboardHandoff: NSButton!

    @IBOutlet var lockOnScreenLock: NSButton!
    @IBOutlet var lockEvenIfEditing: NSButton!

    @IBOutlet var autoLockDatabase: NSButton!
    @IBOutlet var autoLockTimeoutTextField: NSTextField!
    @IBOutlet var autoLockStepper: NSStepper!

    @IBOutlet var autoLockAppInBackground: NSButton!
    @IBOutlet var autoLockAppInBackgroundTimeoutTextField: NSTextField!
    @IBOutlet var autoLockAppInBackgroundStepper: NSStepper!

    @IBOutlet var lockDatabaseOnWindowClose: NSButton!

    private let preferencesModel = SecurityPrivacySettingsViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("security_privacy_settings_tab_title", comment: "Security & Privacy")
        installAppPreferencesHostingView(SecurityPrivacySettingsView(model: preferencesModel))
    }

    @IBAction func onChanged(_: Any) {
        preferencesModel.bindUI()
    }

    @IBAction func onClearClipboardTextFieldEdited(_: Any) {
        preferencesModel.setClearClipboardAfterSeconds(autoClearClipboardTimeout.integerValue)
    }

    @IBAction func onClearClipboardStepper(_: Any) {
        preferencesModel.setClearClipboardAfterSeconds(stepperAutoClearClipboard.integerValue)
    }

    @IBAction func onClearClipboardCheckbox(_: Any) {
        preferencesModel.setClearClipboardEnabled(autoClearClipboard.state == .on)
    }

    @IBAction func onAutoLockTextFieldEdited(_: Any) {
        preferencesModel.setAutoLockTimeoutMinutes(autoLockTimeoutTextField.integerValue)
    }

    @IBAction func onAutoLockStepperChanged(_: Any) {
        preferencesModel.setAutoLockTimeoutMinutes(autoLockStepper.integerValue)
    }

    @IBAction func onAutoLockTimeoutChanged(_: Any) {
        preferencesModel.setAutoLockEnabled(autoLockDatabase.state == .on)
    }

    @IBAction func onAutoLockAppInBackgroundTextFieldEdited(_: Any) {
        preferencesModel.setAutoLockInBackgroundTimeoutMinutes(autoLockAppInBackgroundTimeoutTextField.integerValue)
    }

    @IBAction func onAutoLockAppInBackgroundStepperChanged(_: Any) {
        preferencesModel.setAutoLockInBackgroundTimeoutMinutes(autoLockAppInBackgroundStepper.integerValue)
    }

    @IBAction func onAutoLockAppInBackgroundTimeoutChanged(_: Any) {
        preferencesModel.setAutoLockInBackgroundEnabled(autoLockAppInBackground.state == .on)
    }
}

@MainActor
private final class SecurityPrivacySettingsViewModel: NSObject, ObservableObject {
    @Published var screenCaptureBlocked = false
    @Published var quickRevealWithOptionKey = false
    @Published var revealPasswordsImmediately = false

    @Published var clearClipboardEnabled = false
    @Published var clearClipboardAfterSeconds = 60
    @Published var clipboardHandoff = false
    @Published var miniaturizeOnCopy = false
    @Published var hideOnCopy = false

    @Published var autoLockEnabled = false
    @Published var autoLockTimeoutMinutes = 10
    @Published var autoLockInBackgroundEnabled = false
    @Published var autoLockInBackgroundTimeoutMinutes = 10
    @Published var lockDatabaseOnWindowClose = false
    @Published var lockDatabasesOnScreenLock = false
    @Published var lockEvenIfEditing = false

    private var observerTokens: [NSObjectProtocol] = []

    override init() {
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )
    }

    deinit {
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    func bindUI() {
        let settings = Settings.sharedInstance()
        let autoLockMinutes = settings.autoLockTimeoutSeconds / 60
        let backgroundLockMinutes = settings.autoLockIfInBackgroundTimeoutSeconds / 60

        screenCaptureBlocked = settings.screenCaptureBlocked
        quickRevealWithOptionKey = settings.quickRevealWithOptionKey
        revealPasswordsImmediately = settings.revealPasswordsImmediately

        clearClipboardEnabled = settings.clearClipboardEnabled
        clearClipboardAfterSeconds = settings.clearClipboardAfterSeconds
        clipboardHandoff = settings.clipboardHandoff
        miniaturizeOnCopy = settings.miniaturizeOnCopy
        hideOnCopy = settings.hideOnCopy

        autoLockEnabled = autoLockMinutes != 0
        autoLockTimeoutMinutes = autoLockMinutes != 0 ? autoLockMinutes : 10
        autoLockInBackgroundEnabled = backgroundLockMinutes != 0
        autoLockInBackgroundTimeoutMinutes = backgroundLockMinutes != 0 ? backgroundLockMinutes : 10
        lockDatabaseOnWindowClose = settings.lockDatabaseOnWindowClose
        lockDatabasesOnScreenLock = settings.lockDatabasesOnScreenLock
        lockEvenIfEditing = settings.lockEvenIfEditing
    }

    func setScreenCaptureBlocked(_ enabled: Bool) {
        set(enabled, keyPath: \.screenCaptureBlocked, setter: { Settings.sharedInstance().screenCaptureBlocked = $0 })
    }

    func setQuickRevealWithOptionKey(_ enabled: Bool) {
        set(enabled, keyPath: \.quickRevealWithOptionKey, setter: { Settings.sharedInstance().quickRevealWithOptionKey = $0 })
    }

    func setRevealPasswordsImmediately(_ enabled: Bool) {
        set(enabled, keyPath: \.revealPasswordsImmediately, setter: { Settings.sharedInstance().revealPasswordsImmediately = $0 })
    }

    func setClearClipboardEnabled(_ enabled: Bool) {
        set(enabled, keyPath: \.clearClipboardEnabled, setter: { Settings.sharedInstance().clearClipboardEnabled = $0 })
    }

    func setClearClipboardAfterSeconds(_ seconds: Int) {
        let clampedSeconds = min(max(seconds, 15), 1200)
        guard clearClipboardAfterSeconds != clampedSeconds else { return }

        Settings.sharedInstance().clearClipboardAfterSeconds = clampedSeconds
        bindUI()
        notifyChanged()
    }

    func setClipboardHandoff(_ enabled: Bool) {
        set(enabled, keyPath: \.clipboardHandoff, setter: { Settings.sharedInstance().clipboardHandoff = $0 })
    }

    func setMiniaturizeOnCopy(_ enabled: Bool) {
        set(enabled, keyPath: \.miniaturizeOnCopy, setter: { Settings.sharedInstance().miniaturizeOnCopy = $0 })
    }

    func setHideOnCopy(_ enabled: Bool) {
        set(enabled, keyPath: \.hideOnCopy, setter: { Settings.sharedInstance().hideOnCopy = $0 })
    }

    func setAutoLockEnabled(_ enabled: Bool) {
        let timeoutSeconds = enabled ? 600 : 0
        guard Settings.sharedInstance().autoLockTimeoutSeconds != timeoutSeconds else { return }

        Settings.sharedInstance().autoLockTimeoutSeconds = timeoutSeconds
        bindUI()
        notifyChanged()
    }

    func setAutoLockTimeoutMinutes(_ minutes: Int) {
        let clampedMinutes = min(max(minutes, 1), 7200)
        guard autoLockTimeoutMinutes != clampedMinutes else { return }

        Settings.sharedInstance().autoLockTimeoutSeconds = clampedMinutes * 60
        bindUI()
        notifyChanged()
    }

    func setAutoLockInBackgroundEnabled(_ enabled: Bool) {
        let timeoutSeconds = enabled ? 600 : 0
        guard Settings.sharedInstance().autoLockIfInBackgroundTimeoutSeconds != timeoutSeconds else { return }

        Settings.sharedInstance().autoLockIfInBackgroundTimeoutSeconds = timeoutSeconds
        bindUI()
        notifyChanged()
    }

    func setAutoLockInBackgroundTimeoutMinutes(_ minutes: Int) {
        let clampedMinutes = min(max(minutes, 1), 7200)
        guard autoLockInBackgroundTimeoutMinutes != clampedMinutes else { return }

        Settings.sharedInstance().autoLockIfInBackgroundTimeoutSeconds = clampedMinutes * 60
        bindUI()
        notifyChanged()
    }

    func setLockDatabaseOnWindowClose(_ enabled: Bool) {
        set(enabled, keyPath: \.lockDatabaseOnWindowClose, setter: { Settings.sharedInstance().lockDatabaseOnWindowClose = $0 })
    }

    func setLockDatabasesOnScreenLock(_ enabled: Bool) {
        set(enabled, keyPath: \.lockDatabasesOnScreenLock, setter: { Settings.sharedInstance().lockDatabasesOnScreenLock = $0 })
    }

    func setLockEvenIfEditing(_ enabled: Bool) {
        set(enabled, keyPath: \.lockEvenIfEditing, setter: { Settings.sharedInstance().lockEvenIfEditing = $0 })
    }

    private func set(_ enabled: Bool, keyPath: KeyPath<SecurityPrivacySettingsViewModel, Bool>, setter: (Bool) -> Void) {
        guard self[keyPath: keyPath] != enabled else { return }

        setter(enabled)
        bindUI()
        notifyChanged()
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

private struct SecurityPrivacySettingsView: View {
    @ObservedObject var model: SecurityPrivacySettingsViewModel

    var body: some View {
        AppPreferencesPage {
            AppPreferencesSection(title: NSLocalizedString("security_privacy_settings_privacy_section_title", comment: "Privacy")) {
                Toggle(NSLocalizedString("security_privacy_settings_block_screenshots_title", comment: "Block Screenshots"), isOn: binding(get: { model.screenCaptureBlocked }, set: model.setScreenCaptureBlocked))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_quick_reveal_title", comment: "Hold Option Key to Toggle Concealed Fields"), isOn: binding(get: { model.quickRevealWithOptionKey }, set: model.setQuickRevealWithOptionKey))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_reveal_immediately_title", comment: "Always Reveal Passwords and Concealed Fields"), isOn: binding(get: { model.revealPasswordsImmediately }, set: model.setRevealPasswordsImmediately))
                    .font(.body)
            }

            AppPreferencesSection(title: NSLocalizedString("security_privacy_settings_clipboard_section_title", comment: "Clipboard")) {
                AppPreferencesHelpText(text: NSLocalizedString("security_privacy_settings_clipboard_description", comment: "Control when the clipboard is cleared and other copy and paste settings."))

                SecurityPrivacyTimedToggleRow(
                    title: NSLocalizedString("security_privacy_settings_auto_clear_clipboard_title", comment: "Auto Clear Clipboard on Exit and After:"),
                    unit: NSLocalizedString("security_privacy_settings_seconds_unit", comment: "seconds"),
                    isOn: binding(get: { model.clearClipboardEnabled }, set: model.setClearClipboardEnabled),
                    value: binding(get: { model.clearClipboardAfterSeconds }, set: model.setClearClipboardAfterSeconds),
                    range: 15...1200
                )

                Toggle(NSLocalizedString("security_privacy_settings_allow_clipboard_handoff_title", comment: "Allow Clipboard Handoff (Universal Clipboard)"), isOn: binding(get: { model.clipboardHandoff }, set: model.setClipboardHandoff))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_miniaturize_on_copy_title", comment: "Miniaturize On Copy"), isOn: binding(get: { model.miniaturizeOnCopy }, set: model.setMiniaturizeOnCopy))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_hide_on_copy_title", comment: "Hide On Copy"), isOn: binding(get: { model.hideOnCopy }, set: model.setHideOnCopy))
                    .font(.body)
            }

            AppPreferencesSection(title: NSLocalizedString("security_privacy_settings_locking_section_title", comment: "Locking")) {
                AppPreferencesHelpText(text: NSLocalizedString("security_privacy_settings_locking_description", comment: "Configure automatic locking of your databases after a timeout or on other events."))

                SecurityPrivacyTimedToggleRow(
                    title: NSLocalizedString("security_privacy_settings_lock_after_idle_title", comment: "Lock after Computer is Idle for:"),
                    unit: NSLocalizedString("security_privacy_settings_minutes_unit", comment: "minute(s)"),
                    isOn: binding(get: { model.autoLockEnabled }, set: model.setAutoLockEnabled),
                    value: binding(get: { model.autoLockTimeoutMinutes }, set: model.setAutoLockTimeoutMinutes),
                    range: 1...7200
                )

                SecurityPrivacyTimedToggleRow(
                    title: NSLocalizedString("security_privacy_settings_lock_after_background_title", comment: "Lock after Strongbox in Background for:"),
                    unit: NSLocalizedString("security_privacy_settings_minutes_unit", comment: "minute(s)"),
                    isOn: binding(get: { model.autoLockInBackgroundEnabled }, set: model.setAutoLockInBackgroundEnabled),
                    value: binding(get: { model.autoLockInBackgroundTimeoutMinutes }, set: model.setAutoLockInBackgroundTimeoutMinutes),
                    range: 1...7200
                )

                Toggle(NSLocalizedString("security_privacy_settings_lock_on_window_close_title", comment: "Lock Immediately on Window Close"), isOn: binding(get: { model.lockDatabaseOnWindowClose }, set: model.setLockDatabaseOnWindowClose))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_lock_on_screen_lock_title", comment: "Lock on Sleep, Screensaver, or Switching Users"), isOn: binding(get: { model.lockDatabasesOnScreenLock }, set: model.setLockDatabasesOnScreenLock))
                    .font(.body)

                Toggle(NSLocalizedString("security_privacy_settings_lock_even_if_editing_title", comment: "Lock Even if Editing"), isOn: binding(get: { model.lockEvenIfEditing }, set: model.setLockEvenIfEditing))
                    .font(.body)
            }
        }
    }

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }

    private func binding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<Int> {
        Binding(get: get, set: set)
    }
}

private struct SecurityPrivacyTimedToggleRow: View {
    let title: String
    let unit: String
    let isOn: Binding<Bool>
    let value: Binding<Int>
    let range: ClosedRange<Int>

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.allowsFloats = false
        formatter.minimumIntegerDigits = 1
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle(title, isOn: isOn)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 32)

            HStack(alignment: .center, spacing: 6) {
                TextField("", value: value, formatter: Self.integerFormatter)
                    .accessibilityLabel(Text(title))
                    .frame(width: 60)
                    .disabled(!isOn.wrappedValue)

                Stepper(title, value: value, in: range, step: 1)
                    .labelsHidden()
                    .disabled(!isOn.wrappedValue)

                Text(unit)
                    .foregroundStyle(isOn.wrappedValue ? .secondary : .tertiary)
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }
}
