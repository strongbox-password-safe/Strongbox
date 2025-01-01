//
//  TheGarageView.swift
//  Strongbox
//
//  Created by Strongbox on 20/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

extension UserDefaults {
    static var StrongboxAppGroupUserDefaults: UserDefaults {
        AppPreferences.sharedInstance().sharedAppGroupDefaults!
    }
}

struct TheGarageViewModel {
    var watchStatus: WatchStatus
    var preferences: AppPreferences
}

enum SettingsKeys: String {
    case appleWatchIntegration
}

struct TheGarageView: View {
    @State
    var model: TheGarageViewModel

    

    @AppStorage(SettingsKeys.appleWatchIntegration.rawValue)
    private var appleWatchIntegration = true

    static let ZipExportBehaviours: [LocalizedStringKey] = ["generic_setting_ask_or_prompt_user",
                                                            "generic_setting_always",
                                                            "generic_setting_never"]

    var body: some View {
        List {
            Section {
                Toggle("allow_apple_watch_integration", isOn: $appleWatchIntegration)

                if appleWatchIntegration {
                    DisclosureGroup {
                        Text(String(format: "isSupportedOnThisDevice: %hhd", model.watchStatus.isSupportedOnThisDevice))
                        Text(String(format: "isPaired: %hhd", model.watchStatus.isPaired))
                        Text(String(format: "isInstalled: %hhd", model.watchStatus.isInstalled))
                        Text(String(format: "isReachable: %hhd", model.watchStatus.isReachable))
                        Text(String(format: "activationState: \(model.watchStatus.activationState)"))
                        if let lastError = model.watchStatus.lastError {
                            Text(String(format: "lastError: \(lastError)"))
                        }
                        if let lastSuccessfulComms = model.watchStatus.lastSuccessfulComms {
                            Text(String(format: "lastSuccessfulComms: \(lastSuccessfulComms)"))
                        }
                    } label: {
                        Text("Debug Info")
                    }
                }
            } header: {
                Text("apple_watch_title")
            }

            Section {
                Toggle("setting_split_2fa_codes", isOn: $model.preferences.twoFactorEasyReadSeparator)
                Toggle("setting_2fa_code_add_otpauth", isOn: $model.preferences.addOtpAuthUrl)
                Toggle("setting_2fa_code_add_legacy_fields", isOn: $model.preferences.addLegacySupplementaryTotpCustomFields)
            }
            header: {
                Text("generic_fieldname_totp")
            }

            Section {
                Picker(selection: $model.preferences.zipExportBehaviour, label: Text("zip_exports_setting_title")) {
                    ForEach(0 ..< Self.ZipExportBehaviours.count, id: \.self) {
                        Text(Self.ZipExportBehaviours[$0]).tag($0)
                    }
                }

                Toggle("hide_export_on_database_menu", isOn: $model.preferences.hideExportFromDatabaseContextMenu)
                Toggle("append_date_to_export_filenames", isOn: $model.preferences.appendDateToExportFileName)
            }
            header: {
                Text("generic_export")
            }

            if !model.preferences.disableExport {
                Section {
                    Toggle("setting_instant_pin_unlock", isOn: $model.preferences.instantPinUnlocking)
                    Toggle("setting_pin_code_haptics", isOn: $model.preferences.pinCodeHapticFeedback)
                }
                header: {
                    Text("setting_pin_code_title")
                }
            }

            Section {
                Toggle("setting_associated_websites", isOn: $model.preferences.associatedWebsites)
                Toggle("setting_markdown_notes", isOn: $model.preferences.markdownNotes)
                Toggle("setting_allow_third_party_keyboards", isOn: $model.preferences.allowThirdPartyKeyboards)

                Toggle("setting_color_blind_palette", isOn: $model.preferences.colorizeUseColorBlindPalette)
                Toggle("setting_show_metadata_on_details", isOn: $model.preferences.showMetadataOnDetailsScreen)
                Toggle("setting_show_databases_on_app_shortcut_menu", isOn: $model.preferences.showDatabasesOnAppShortcutMenu)
                Toggle("setting_new_entry_uses_parent_icon", isOn: $model.preferences.useParentGroupIconOnCreate)
                Toggle("setting_strip_unused_icons", isOn: $model.preferences.stripUnusedIconsOnSave)
                Toggle("setting_strip_historical_icons", isOn: $model.preferences.stripUnusedHistoricalIcons)

                if !model.preferences.disableNetworkBasedFeatures {
                    Toggle("setting_detect_if_offline", isOn: $model.preferences.monitorInternetConnectivity)
                    Toggle("setting_atomic_sftp_writes", isOn: $model.preferences.atomicSftpWrite)
                    Toggle("setting_user_dropbox_app_folder_only", isOn: $model.preferences.useIsolatedDropbox)
                }
            }
            header: {
                Text("misc_settings_title")
            }
        }
        .navigationTitle("settings_advanced_the_garage_title")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appleWatchIntegration, perform: { _ in
            if appleWatchIntegration {
                WatchAppManager.shared.quickActivate()
            }
        })
    }
}

#Preview {
    struct PreviewView: View {
        @State
        var viewModel = TheGarageViewModel(watchStatus:
            WatchStatus(isPaired: true, isSupportedOnThisDevice: true, isInstalled: true, isReachable: true, lastError: nil, lastSuccessfulComms: nil, activationState: .activated),
            preferences: AppPreferences.sharedInstance())

        var body: some View {
            NavigationView {
                TheGarageView(model: viewModel)
            }
        }
    }

    return PreviewView()
}
