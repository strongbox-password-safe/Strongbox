//
//  WatchEntry.swift
//  Strongbox
//
//  Created by Strongbox on 07/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

enum WatchEntryIcon: Codable {
    static let Default = WatchEntryIcon.preset(icon: 0)

    case preset(icon: Int)
    case custom(iconDataB64: String)

    func getUIImage(iconSet: KeePassIconSet) -> UIImage {
        switch self {
        case let .preset(icon):
            return NodeIconHelper.getNodeIcon(NodeIcon.withPreset(icon), predefinedIconSet: iconSet)
        case let .custom(iconDataB64):
            guard let data = Data(base64Encoded: iconDataB64) else {
                return NodeIconHelper.defaultIcon
            }

            return NodeIconHelper.getNodeIcon(NodeIcon.withCustom(data), predefinedIconSet: iconSet)
        }
    }

    var sfSymbolName: String {
        switch self {
        case let .preset(icon):
            NodeIconHelper.getSfSymbolName(NodeIcon.withPreset(icon))
        case .custom:
            NodeIconHelper.getSfSymbolName(NodeIcon.withPreset(0))
        }
    }
}

struct WatchCustomField: Identifiable, Codable {
    var id: String { key }

    let key: String
    let value: String
    let concealable: Bool
}

struct WatchEntry: Identifiable, Codable {
    var id: UUID = .init()
    var title: String = ""
    var icon: WatchEntryIcon
    var username: String = ""
    var password: String = ""
    var email: String = ""
    var url: String = ""
    var alternativeUrls: [String] = []
    var twoFaOtpAuthUrl: String? = nil
    var customFields: [[String: WatchCustomField]] = []
    var notes: String = ""
}
