//
//  Icon.swift
//  MacBox
//
//  Created by Strongbox on 15/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

enum Icon {
    case folder
    case tag
    case tagFill
    case house
    case houseFill
    case calendarBadgeClock
    case listStar
    case auditShield
    case auditShieldFill
    case preferences
    case totp
    case expired
    case nearlyExpired
    case attachment
    case recycleBin
    case viewFinderCircleFill
    case favourite
    case sshKey
    case passkey
    case algorithm
    case auditExclusion

    func image() -> NSImage {
        switch self {
        case .favourite:
            return NSImage(systemSymbolName: "star", accessibilityDescription: nil)!
        case .recycleBin:
            return NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil)!
        case .attachment:
            return NSImage(systemSymbolName: "paperclip", accessibilityDescription: nil)!
        case .expired:
            return NSImage(systemSymbolName: "deskclock.fill", accessibilityDescription: nil)!
        case .nearlyExpired:
            return NSImage(systemSymbolName: "deskclock", accessibilityDescription: nil)!
        case .totp:
            return NSImage(systemSymbolName: "timer", accessibilityDescription: nil)!
        case .preferences:
            return NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!
        case .auditShield:
            return NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: nil)!
        case .auditShieldFill:
            return NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)!
        case .listStar:
            return NSImage(systemSymbolName: "list.star", accessibilityDescription: nil)!
        case .calendarBadgeClock:
            return NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: nil)!
        case .folder:
            return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
        case .tag:
            return NSImage(systemSymbolName: "tag", accessibilityDescription: nil)!
        case .tagFill:
            return NSImage(systemSymbolName: "tag.fill", accessibilityDescription: nil)!
        case .house:
            return NSImage(systemSymbolName: "house", accessibilityDescription: nil)!
        case .houseFill:
            return NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)!
        case .viewFinderCircleFill:
            return NSImage(systemSymbolName: "viewfinder.circle.fill", accessibilityDescription: nil)!
        case .sshKey:
            return NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: nil)!
        case .passkey:
            if #available(macOS 12.3, *) {
                return NSImage(systemSymbolName: "person.badge.key.fill", accessibilityDescription: nil)!
            }
            return NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)!
        case .algorithm:
            return NSImage(systemSymbolName: "function", accessibilityDescription: nil)!
        case .auditExclusion:
            return NSImage(systemSymbolName: "shield.slash", accessibilityDescription: nil)!
        }
    }
}
