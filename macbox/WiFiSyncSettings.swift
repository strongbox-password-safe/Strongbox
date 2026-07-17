//
//  WiFiSyncSettings.swift
//  MacBox
//
//  Created by Strongbox on 10/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI
import SystemConfiguration

@MainActor
class WiFiSyncSettings: NSViewController {
    @IBOutlet var onOff: NSSwitch!
    @IBOutlet var textFieldPasscode: NSTextField!
    @IBOutlet var serviceName: NSTextField!

    @IBOutlet var textFieldLastError: NSTextField!
    @IBOutlet var changePasscode: ClickableTextField!
    @IBOutlet var changeServiceName: ClickableTextField!

    @IBOutlet var textFieldPasscodeLastError: NSTextField!

    private lazy var preferencesModel = WiFiSyncSettingsViewModel(windowProvider: { [weak self] in
        self?.view.window
    })

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("wifi_sync_settings_title", comment: "Wi-Fi Sync")
        installAppPreferencesHostingView(WiFiSyncSettingsView(model: preferencesModel))
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        preferencesModel.bindUI()
    }

    func bindUI() {
        preferencesModel.bindUI()
    }

    @IBAction func onSwitchToggleOnOff(_: Any) {
        preferencesModel.setWiFiSyncEnabled(onOff.state == .on)
    }

    func requestNewPasscodeAndRestart() {
        preferencesModel.requestNewPasscodeAndRestart()
    }

    func onChangePasscode(_: Any?) {
        preferencesModel.changePasscode()
    }

    func onChangeServiceName(_: Any?) {
        preferencesModel.changeServiceName()
    }

    func restartWiFiSyncServerAndBindUI() {
        preferencesModel.restartWiFiSyncServerAndBindUI()
    }

    var resolvedServiceName: String {
        preferencesModel.resolvedServiceName
    }

    func defaultBonjourHostName() -> String? {
        preferencesModel.defaultBonjourHostName()
    }
}

@MainActor
private final class WiFiSyncSettingsViewModel: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isPossible = false
    @Published var passcode = ""
    @Published var serviceName = ""
    @Published var serverError: String?
    @Published var passcodeError: String?
    @Published var isPro: Bool = false
    @Published var showProFeatureBadge = false
    @Published var showProUpsell = false

    private let windowProvider: () -> NSWindow?
    private var observerTokens: [NSObjectProtocol] = []

    init(windowProvider: @escaping () -> NSWindow?) {
        self.windowProvider = windowProvider
        super.init()

        bindUI()

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .wiFiSyncServiceNameDidChange, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.bindUI()
                }
            }
        )

        observerTokens.append(
            NotificationCenter.default.addObserver(forName: .proStatusChanged, object: nil, queue: .main) { [weak self] _ in
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
        isPro = WiFiSyncServer.shared.settings.isPro
        showProFeatureBadge = SettingsProUpsell.isEligibleAudience
        showProUpsell = SettingsProUpsell.shouldShow
        isPossible = WiFiSyncServer.shared.wiFiSyncIsPossible
        isRunning = WiFiSyncServer.shared.isRunning && isPossible
        passcode = Settings.sharedInstance().wiFiSyncPasscode ?? "—"
        serviceName = resolvedServiceName
        serverError = WiFiSyncServer.shared.lastError
        passcodeError = Settings.sharedInstance().lastWiFiSyncPasscodeError
    }

    func dismissProUpsell() {
        SettingsProUpsell.dismiss()
        showProUpsell = false
    }

    func setWiFiSyncEnabled(_ enabled: Bool) {
        guard WiFiSyncServer.shared.wiFiSyncIsPossible else {
            bindUI()
            return
        }

        Settings.sharedInstance().runAsWiFiSyncSourceDevice = enabled

        if enabled, Settings.sharedInstance().wiFiSyncPasscode == nil {
            requestNewPasscodeAndRestart()
        } else {
            restartWiFiSyncServerAndBindUI()
        }
    }

    func requestNewPasscodeAndRestart() {
        let alert = MacAlerts()
        let newPasscode = alert.input(
            NSLocalizedString("wifi_sync_enter_new_passcode", comment: "Enter New Passcode"),
            defaultValue: Settings.sharedInstance().wiFiSyncPasscode ?? "",
            allowEmpty: false
        )

        if let newPasscode {
            if newPasscode.count > 3 {
                Settings.sharedInstance().wiFiSyncPasscode = newPasscode
                restartWiFiSyncServerAndBindUI()
            } else {
                MacAlerts.info(
                    NSLocalizedString("wifi_sync_invalid_passcode", comment: "Invalid Passcode"),
                    window: windowProvider()
                )
                bindUI()
            }
        } else {
            bindUI()
        }
    }

    func changePasscode() {
        MacAlerts.areYouSure(
            NSLocalizedString("wifi_sync_change_passcode_warning", comment: "Changing the passcode or service name will break any existing connections on other devices."),
            window: windowProvider()
        ) { [weak self] go in
            guard let self, go else { return }

            requestNewPasscodeAndRestart()
        }
    }

    func changeServiceName() {
        MacAlerts.areYouSure(
            NSLocalizedString("wifi_sync_change_passcode_warning", comment: "Changing the passcode or service name will break any existing connections on other devices."),
            window: windowProvider()
        ) { [weak self] go in
            guard let self, go else { return }

            let alert = MacAlerts()
            let newServiceName = alert.input(
                NSLocalizedString("wifi_sync_enter_new_service_name", comment: "Enter new Service Name or leave blank for default"),
                defaultValue: Settings.sharedInstance().wiFiSyncServiceName ?? "",
                allowEmpty: true
            )

            if let newServiceName {
                Settings.sharedInstance().wiFiSyncServiceName = newServiceName.count > 0 ? newServiceName : nil
                restartWiFiSyncServerAndBindUI()
            } else {
                bindUI()
            }
        }
    }

    func restartWiFiSyncServerAndBindUI() {
        do {
            try WiFiSyncServer.shared.startOrStopWiFiSyncServerAccordingToSettings()
        } catch {
            MacAlerts.error(error, window: windowProvider())
        }

        bindUI()
        notifyChanged()
    }

    var resolvedServiceName: String {
        WiFiSyncServer.shared.lastRegisteredServiceName ?? (Settings.sharedInstance().wiFiSyncServiceName ?? (defaultBonjourHostName() ?? NSLocalizedString("generic_unknown", comment: "Unknown")))
    }

    func defaultBonjourHostName() -> String? {
        let store = SCDynamicStoreCreate(nil, "ipmenu" as CFString, nil, nil)
        if let hostNames = SCDynamicStoreCopyValue(store, "Setup:/Network/HostNames" as CFString),
           let hostName: String = hostNames[kSCPropNetLocalHostName] as? String
        {
            return hostName
        }

        return nil
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

private struct WiFiSyncSettingsView: View {
    @ObservedObject var model: WiFiSyncSettingsViewModel

    var body: some View {
        AppPreferencesPage {
            if model.showProUpsell {
                StrongboxProUpsellView(variant: .wifisync, onDismiss: model.dismissProUpsell)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            AppPreferencesSection(title: NSLocalizedString("wifi_sync_settings_title", comment: "Wi-Fi Sync")) {
                HStack(alignment: .top, spacing: 12) {
                    Toggle(
                        NSLocalizedString("wifi_sync_settings_title", comment: "Wi-Fi Sync"),
                        isOn: binding(get: { model.isRunning }, set: model.setWiFiSyncEnabled)
                    )
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!model.isPossible)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("wifi_sync_settings_title", comment: "Wi-Fi Sync"))
                                .font(.body)

                            if model.showProFeatureBadge {
                                NewProBadge()
                            }
                        }

                        AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_description", comment: "Enable this device to act as a database source so that Strongbox on other devices can access and sync databases with this device."))
                    }
                }

                if let serverError = model.serverError {
                    PreferenceErrorLabel(text: serverError)
                }
            }

            AppPreferencesSection(title: NSLocalizedString("wifi_sync_passcode_noun", comment: "Passcode")) {
                AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_passcode_description", comment: "You'll need the passcode to securely connect to this device."))

                WiFiSyncValueRow(
                    value: model.passcode,
                    isActive: model.isRunning,
                    actionTitle: NSLocalizedString("wifi_sync_settings_change_button", comment: "Change"),
                    action: model.changePasscode
                )

                if let passcodeError = model.passcodeError {
                    PreferenceErrorLabel(text: passcodeError)
                }
            }

            AppPreferencesSection(title: NSLocalizedString("wifi_sync_properties_service_name", comment: "Service Name")) {
                AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_service_name_description", comment: "This is the name of the Wi-Fi Sync service as it appears to other Strongbox apps on your network."))

                WiFiSyncValueRow(
                    value: model.serviceName,
                    isActive: model.isRunning,
                    actionTitle: NSLocalizedString("wifi_sync_settings_change_button", comment: "Change"),
                    action: model.changeServiceName
                )
            }

            AppPreferencesSection(title: NSLocalizedString("wifi_sync_settings_more_section_title", comment: "More about Wi-Fi Sync")) {
                AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_local_network_message", comment: "Wi-Fi Sync is only available on your local network, and not on the Internet."))
                AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_lan_message", comment: "Wi-Fi Sync does not require Wi-Fi, it is also available over any regular LAN connection, e.g. via a wired Ethernet cable."))
                AppPreferencesHelpText(text: NSLocalizedString("wifi_sync_settings_tls_message", comment: "TLS is used to secure all connections and your database(s) are always transferred in their encrypted form."))
            }
        }
    }

    private func binding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }
}

private struct WiFiSyncValueRow: View {
    let value: String
    let isActive: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(isActive ? Color(nsColor: .systemCyan) : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
                .clipShape(.rect(cornerRadius: 8))

            Spacer(minLength: 32)

            if isActive {
                SettingsButton(
                    title: actionTitle,
                    type: .primary,
                    action: action
                )
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
    }
}

private struct PreferenceErrorLabel: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.body)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}
