//
//  WiFiSyncSettings.swift
//  MacBox
//
//  Created by Strongbox on 10/01/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa
import SystemConfiguration

class WiFiSyncSettings: NSViewController {
    @IBOutlet var onOff: NSSwitch!
    @IBOutlet var textFieldPasscode: NSTextField!
    @IBOutlet var serviceName: NSTextField!

    @IBOutlet var textFieldLastError: NSTextField!
    @IBOutlet var changePasscode: ClickableTextField!
    @IBOutlet var changeServiceName: ClickableTextField!

    @IBOutlet var textFieldPasscodeLastError: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        changePasscode.onClick = { [weak self] in
            self?.onChangePasscode(nil)
        }

        changeServiceName.onClick = { [weak self] in
            self?.onChangeServiceName(nil)
        }

        bindUI()

        NotificationCenter.default.addObserver(forName: .wiFiSyncServiceNameDidChange, object: nil, queue: nil) { [weak self] _ in
            self?.bindUI()
        }
    }

    func bindUI() {
        let running = WiFiSyncServer.shared.isRunning && WiFiSyncServer.shared.wiFiSyncIsPossible

        onOff.state = running ? .on : .off
        onOff.isEnabled = WiFiSyncServer.shared.wiFiSyncIsPossible

        textFieldPasscode.stringValue = Settings.sharedInstance().wiFiSyncPasscode ?? NSLocalizedString("generic_error", comment: "Error") 
        textFieldPasscode.textColor = running ? .systemCyan : .secondaryLabelColor

        serviceName.stringValue = resolvedServiceName
        serviceName.textColor = running ? .systemCyan : .secondaryLabelColor

        changePasscode.isEnabled = running
        changePasscode.isHidden = !running

        changeServiceName.isEnabled = running
        changeServiceName.isHidden = !running

        textFieldLastError.stringValue = WiFiSyncServer.shared.lastError ?? ""
        textFieldLastError.isHidden = WiFiSyncServer.shared.lastError == nil

        textFieldPasscodeLastError.stringValue = Settings.sharedInstance().lastWiFiSyncPasscodeError ?? ""
        textFieldPasscodeLastError.isHidden = Settings.sharedInstance().lastWiFiSyncPasscodeError == nil
    }

    @IBAction func onSwitchToggleOnOff(_: Any) {
        Settings.sharedInstance().runAsWiFiSyncSourceDevice = onOff.state == .on

        if let _ = Settings.sharedInstance().wiFiSyncPasscode {
            restartWiFiSyncServerAndBindUI()
        } else {
            requestNewPasscodeAndRestart()
        }
    }

    func requestNewPasscodeAndRestart() {
        let alert = MacAlerts()
        let newPasscode = alert.input(NSLocalizedString("wifi_sync_enter_new_passcode", comment: "Enter New Passcode"),
                                      defaultValue: Settings.sharedInstance().wiFiSyncPasscode ?? "",
                                      allowEmpty: false)

        if let newPasscode {
            
            if newPasscode.count > 3 {
                Settings.sharedInstance().wiFiSyncPasscode = newPasscode

                restartWiFiSyncServerAndBindUI()
            } else {
                MacAlerts.info(NSLocalizedString("wifi_sync_invalid_passcode", comment: "Invalid Passcode"),
                               window: view.window)
            }
        }
    }

    func onChangePasscode(_: Any?) {
        MacAlerts.areYouSure(NSLocalizedString("wifi_sync_change_passcode_warning", comment: "Changing the passcode or service name will break any existing connections on other devices."),
                             window: view.window)
        { [weak self] go in
            guard let self, go else { return }

            requestNewPasscodeAndRestart()
        }
    }

    func onChangeServiceName(_: Any?) {
        MacAlerts.areYouSure(NSLocalizedString("wifi_sync_change_passcode_warning", comment: "Changing the passcode or service name will break any existing connections on other devices."),
                             window: view.window)
        { [weak self] go in
            guard let self, go else { return }

            let alert = MacAlerts()
            let newServiceName = alert.input(NSLocalizedString("wifi_sync_enter_new_service_name", comment: "Enter new Service Name or leave blank for default"),
                                             defaultValue: Settings.sharedInstance().wiFiSyncServiceName ?? "",
                                             allowEmpty: true)

            if let newServiceName {
                Settings.sharedInstance().wiFiSyncServiceName = newServiceName.count > 0 ? newServiceName : nil

                restartWiFiSyncServerAndBindUI()
            }
        }
    }

    func restartWiFiSyncServerAndBindUI() {
        do {
            try WiFiSyncServer.shared.startOrStopWiFiSyncServerAccordingToSettings()
        } catch {
            MacAlerts.error(error, window: view.window)
        }

        bindUI()
    }

    var resolvedServiceName: String {
        WiFiSyncServer.shared.lastRegisteredServiceName ?? (Settings.sharedInstance().wiFiSyncServiceName ?? (defaultBonjourHostName() ?? NSLocalizedString("generic_unknown", comment: "Unknown")))
    }

    func defaultBonjourHostName() -> String? {
        let store = SCDynamicStoreCreate(nil, "ipmenu" as CFString, nil, nil)
        if let hostNames = SCDynamicStoreCopyValue(store, "Setup:/Network/HostNames" as CFString) {
            if let hostName: String = hostNames[kSCPropNetLocalHostName] as? String {
                print("Host name:\(hostName)")

                return hostName
            }
        }

        return nil
    }
}
