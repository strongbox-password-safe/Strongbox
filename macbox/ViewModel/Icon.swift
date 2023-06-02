//
//  Images.swift
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
    
    func image() -> NSImage {
        switch self {
        case .favourite:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "star", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .recycleBin:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "trash", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .attachment:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "paperclip", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "document_empty_64")!
            }
        case .expired:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "deskclock.fill", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .nearlyExpired:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "deskclock", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .totp:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "timer", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .preferences:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "preferences")!
            }
        case .auditShield:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "checkmark.shield", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .auditShieldFill:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .listStar:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "list.star", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .calendarBadgeClock:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "calendar.badge.clock", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "timer")!
            }
        case .folder:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "folder", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "folder")!
            }
        case .tag:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "tag", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "tag")!
            }
        case .tagFill:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "tag.fill", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "tag")!
            }
        case .house:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "house", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "house")!
            }
        case .houseFill:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "house.fill", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "house")!
            }
        case .viewFinderCircleFill:
            if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "viewfinder.circle.fill", accessibilityDescription: nil)!
            } else {
                return NSImage(named: "house")!
            }
        case .sshKey:
            if #available(macOS 12.0, *) {
                return NSImage(systemSymbolName: "network.badge.shield.half.filled", accessibilityDescription: nil)!
            }
            else if #available(macOS 11.0, *) {
                return NSImage(systemSymbolName: "key", accessibilityDescription: nil)!
            }
            else {
                return NSImage(named: "house")!
            }
        }
    }
}
