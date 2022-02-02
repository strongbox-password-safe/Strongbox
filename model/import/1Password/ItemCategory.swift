//
//  ItemCategory.swift
//  MacBox
//
//  Created by Strongbox on 25/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

// import Cocoa

enum ItemCategory: String {
    case Unknown
    case Logins
    case SecureNotes = "Secure Notes"
    case CreditCards = "Credit Cards"
    case Passwords
    case Identities
    case BankAccounts = "Bank Accounts"
    case Databases
    case DriverLicenses = "Drivers Licenses"
    case Memberships
    case EmailAccounts = "Email Accounts"
    case OutdoorLicenses = "Outdoor Licenses"
    case RewardPrograms = "Reward Programs"
    case Passports
    case Servers
    case SocialSecurityNumbers = "Social Security Numbers"
    case WirelessRouters = "Wireless Routers"
    case SoftwareLicenses = "Software Licenses"

    func icon() -> KeePassIconNames {
        switch self {
        case .Logins:
            return .Identity
        case .SecureNotes:
            return .Note
        case .CreditCards:
            return .Money
        case .Identities:
            return .Identity
        case .Passwords:
            return .Key
        case .BankAccounts:
            return .Homebanking
        case .Databases:
            return .Drive
        case .DriverLicenses:
            return .Certificate
        case .Memberships:
            return .Certificate
        case .EmailAccounts:
            return .EMail
        case .OutdoorLicenses:
            return .Certificate
        case .RewardPrograms:
            return .Homebanking
        case .Passports:
            return .Identity
        case .Servers:
            return .NetworkServer
        case .SocialSecurityNumbers:
            return .Identity
        case .WirelessRouters:
            return .IRCommunication
        case .SoftwareLicenses:
            return .Certificate
        default:
            return .Key
        }
    }
}
