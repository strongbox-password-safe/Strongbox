//
//  StorageOption.swift
//  MacBox
//
//  Created by Strongbox on 09/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

enum StorageOption: Equatable, Hashable, Identifiable {
    var id: Self {
        self
    }

    case cloudKit
    case localDevice

    case wifiSync(server: WiFiSyncServerConfig)
    case noWiFiSyncDevicesFound

    case onedrive
    case dropbox
    case googledrive

    case sftp
    case webdav

    var storageProvider: StorageProvider {
        switch self {
        case .cloudKit:
            .kCloudKit
        case .localDevice:
            .kLocalDevice
        case .onedrive:
            .kOneDrive
        case .dropbox:
            .kDropbox
        case .googledrive:
            .kGoogleDrive
        case .sftp:
            .kSFTP
        case .webdav:
            .kWebDAV
        case .wifiSync(server: _):
            .kWiFiSync
        case .noWiFiSyncDevicesFound:
            .kWiFiSync
        }
    }

    var image: NSImage {
        if case .wifiSync = self {
            let image = NSImage(systemSymbolName: "externaldrive.fill.badge.wifi", accessibilityDescription: nil)!
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen, .systemBlue])
            return image.withSymbolConfiguration(config)!
        } else {
            return SafeStorageProviderFactory.getImageFor(storageProvider)
        }
    }

    var requiresPro: Bool {
        if case .sftp = self {
            return true
        }
        if case .webdav = self {
            return true
        }
        if case .wifiSync(server: _) = self {
            return true
        }
        if case .noWiFiSyncDevicesFound = self {
            return true
        }

        return false
    }

    var disabled: Bool {
        if case .noWiFiSyncDevicesFound = self {
            return true
        } else {
            return false
        }
    }

    var name: String {
        if case let .wifiSync(server) = self {
            return server.name
        } else if case .webdav = self {
            return NSLocalizedString("storage_provider_name_webdav", comment: "WebDAV")
        } else if case .noWiFiSyncDevicesFound = self {
            return NSLocalizedString("wifi_sync_no_devices_found", comment: "No Devices Found")
        } else {
            return SafeStorageProviderFactory.getStorageDisplayName(for: storageProvider)
        }
    }

    func description(_ createMode: Bool) -> String {
        switch self {
        case .cloudKit:
            return NSLocalizedString("strongbox_sync_storage_description", comment: "Our native cloud sync makes your databases available on all of your devices. Sharing with others is also supported.")
        case .localDevice:
            return createMode ?
                NSLocalizedString("storage_mac_file_description", comment: "Store your database anywhere within your Mac file system.") :
                NSLocalizedString("storage_add_existing_mac_file_description", comment: "Add a database from anywhere on your Mac file system.")
        case .wifiSync:
            return ""
        case .noWiFiSyncDevicesFound:
            return ""
        case .onedrive:
            return ""
        case .dropbox:
            return ""
        case .googledrive:
            return ""
        case .sftp:
            return ""
        case .webdav:
            return ""
        }
    }

    var category: StorageOptionCategory {
        switch self {
        case .cloudKit:
            .native
        case .localDevice:
            .native
        case .onedrive:
            .thirdParty
        case .dropbox:
            .thirdParty
        case .googledrive:
            .thirdParty
        case .sftp:
            .servers
        case .webdav:
            .servers
        case .wifiSync(server: _):
            .wifiSync
        case .noWiFiSyncDevicesFound:
            .wifiSync
        }
    }
}
