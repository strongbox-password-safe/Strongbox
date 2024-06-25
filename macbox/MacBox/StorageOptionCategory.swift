//
//  StorageOptionCategory.swift
//  MacBox
//
//  Created by Strongbox on 09/06/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

enum StorageOptionCategory: Int, CaseIterable, Codable, Identifiable {
    var id: Int { rawValue }

    case native
    case wifiSync
    case thirdParty
    case servers

    var localizedName: LocalizedStringKey {
        switch self {
        case .native:
            "select_storage_header_built_in"
        case .thirdParty:
            "select_storage_header_third_party"
        case .servers:
            "select_storage_header_servers"
        case .wifiSync:
            "storage_provider_name_wifi_sync"
        }
    }

    func localizedDescription(createMode: Bool) -> LocalizedStringKey {
        switch self {
        case .native:
            #if !NO_NETWORKING
                return createMode ? "select_storage_create_mode_title" : "select_storage_add_mode_title"
            #else
                return createMode ? "select_storage_no_networking_create_mode_title" : "select_storage_add_mode_title"
            #endif
        case .thirdParty:
            return "select_storage_third_party_description_macos"
        case .servers:
            return "select_storage_footer_servers"
        case .wifiSync:
            return "select_storage_footer_wifi"
        }
    }
}
