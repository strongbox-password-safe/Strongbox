//
//  StorageSelectorView.swift
//  MacBox
//
//  Created by Strongbox on 08/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

struct StorageSelectorView: View {
    static let AddExistingOptions: [StorageOption] = [.localDevice,
                                                      .onedrive, .dropbox, .googledrive,
                                                      .sftp, .webdav]

    static let CreateModeOptions: [StorageOption] = [.cloudKit, .localDevice,
                                                     .onedrive, .dropbox, .googledrive,
                                                     .sftp, .webdav]

    var createMode: Bool
    var cloudKitUnavailableReason: String?
    var isImporting: Bool = false
    var isPro: Bool
    var testingOnlyWiFiSyncDevices: [WiFiSyncServerConfig]

    @ObservedObject
    var wifiSyncBrowser: WiFiSyncBrowser = .shared

    @State
    var selection: StorageOption?

    var completion: ((_ userCancelled: Bool, _ selected: StorageProvider, _ selectedWiFiSyncDevice: WiFiSyncServerConfig?) -> Void)?

    init(createMode: Bool,
         isImporting: Bool,
         isPro: Bool,
         cloudKitUnavailableReason: String?,
         initialSelection: StorageProvider,
         testingOnlyWiFiSyncDevices: [WiFiSyncServerConfig] = [],
         completion: ((_: Bool, _: StorageProvider, _: WiFiSyncServerConfig?) -> Void)? = nil)
    {
        self.createMode = createMode
        self.isImporting = isImporting
        self.isPro = isPro
        self.completion = completion
        self.testingOnlyWiFiSyncDevices = testingOnlyWiFiSyncDevices
        self.cloudKitUnavailableReason = cloudKitUnavailableReason

        let initial = filteredOptions.first { option in
            option.storageProvider == initialSelection
        }
        _selection = State(initialValue: initial)
    }

    var availableWiFiSyncDevices: [WiFiSyncServerConfig] {
        var all = wifiSyncBrowser.availableServers

        all.append(contentsOf: testingOnlyWiFiSyncDevices)

        if WiFiSyncServer.shared.isRunning { 
            if let myName = WiFiSyncServer.shared.lastRegisteredServiceName, myName.count > 0 {
                return all.filter { $0.name != myName }
            }
        }

        return all
    }

    var filteredOptions: [StorageOption] {
        var ret = createMode ? Self.CreateModeOptions : Self.AddExistingOptions

        
        
        

        
        
        
        
        

        

        if StrongboxProductBundle.supportsWiFiSync, !Settings.sharedInstance().disableWiFiSyncClientMode {
            if !createMode {
                if availableWiFiSyncDevices.count > 0 {
                    let wifiSyncOptions: [StorageOption] = availableWiFiSyncDevices.map { .wifiSync(server: $0) }
                    ret.append(contentsOf: wifiSyncOptions)
                } else {
                    ret.append(.noWiFiSyncDevicesFound)
                }
            }
        }

        return ret
    }

    func storageOptionButton(_ col1: StorageOption) -> some View {
        ZStack(alignment: .topTrailing) {
            let unavailablePro = !isPro && col1.requiresPro
            let disabled = col1.disabled || unavailablePro || (col1.storageProvider == .kCloudKit && cloudKitUnavailableReason != nil)
            let disabledReason: String? = col1.storageProvider == .kCloudKit ? cloudKitUnavailableReason : nil

            StorageOptionPickerItem(selection: $selection, option: col1, disabled: disabled, disabledReason: disabledReason, createMode: createMode)
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    onSelect()
                })

            if unavailablePro {
                ZStack {
                    Text("Pro")
                        .frame(minWidth: 40)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(2)
                        .background(.blue)
                        .cornerRadius(5)
                        .offset(x: 3, y: -3)
                }
            }
        }
    }

    func onSelect() {
        guard let selection else { return }

        if case let .wifiSync(server) = selection {
            completion?(false, selection.storageProvider, server)
        } else {
            completion?(false, selection.storageProvider, nil)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            VStack {
                let title: LocalizedStringKey = createMode ? (isImporting ?
                    "select_storage_title_import" : "safes_vc_new_advanced") : "select_storage_title_add_existing"

                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)

                let subtitle: LocalizedStringKey = createMode ?
                    (isImporting ? "storage_selector_where_store_new_import" : "storage_selector_where_store_new") :
                    "storage_selector_where_existing_located"

                Text(subtitle)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(StorageOptionCategory.allCases) { category in
                        let fo = filteredOptions.filter { $0.category == category }

                        if fo.count > 0 {
                            VStack(alignment: .leading) {
                                VStack(alignment: .leading) {
                                    Text(category.localizedName)
                                        .font(.title3)

                                    Text(category.localizedDescription(createMode: createMode))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Divider()
                                }

                                let rows = fo.splitInPairs()

                                VStack(alignment: .leading) {
                                    ForEach(Array(rows.enumerated()), id: \.offset) { _, option in
                                        HStack {
                                            if let col1 = option.0 {
                                                storageOptionButton(col1)
                                            }

                                            if let col2 = option.1 {
                                                storageOptionButton(col2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }

            VStack {
                Divider()

                HStack(spacing: 8) {
                    Spacer()

                    Button("generic_cancel") {
                        completion?(true, .kStorageProviderCount, nil)
                    }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)

                    Button(action: {
                        onSelect()
                    }, label: {
                        if let selection {
                            Text(String(format: NSLocalizedString("generic_select_param_in_single_quotes_fmt", comment: "Select '%@'"), selection.name))
                                .frame(minWidth: 100)
                        } else {
                            Text("generic_select")
                                .frame(minWidth: 100)
                        }
                    })
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selection == nil)
                    .controlSize(.large)
                }
            }
        }
        .scenePadding()
        .frame(width: 610, height: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

@available(macOS 13.0, *)
#Preview {
    let wifiSyncDevices = [
        WiFiSyncServerConfig(name: "Wi-Fi Sync Device #1"),
        WiFiSyncServerConfig(name: "Wi-Fi Sync Device #2"),
        WiFiSyncServerConfig(name: "Wi-Fi Sync Device #3"),
    ]




    return StorageSelectorView(createMode: false,
                               isImporting: true,
                               isPro: true,
                               cloudKitUnavailableReason: "Blah",
                               initialSelection: .kLocalDevice,
                               testingOnlyWiFiSyncDevices: wifiSyncDevices)
}
