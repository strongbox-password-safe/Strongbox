//
//  RecordType.swift
//  MacBox
//
//  Created by Strongbox on 25/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

// import Cocoa

enum RecordType: String, Codable {
    case Unknown
    case SavedSearch
    case RegularFolder
    case WebForm
    case SecureNote
    case CreditCard
    case Password
    case Identity
    case BankAccountUS
    case Database
    case DriversLicense
    case Membership
    case EmailV2
    case HuntingLicense
    case RewardProgram
    case Passport
    case UnixServer
    case SsnUS
    case Router
    case License

    func icon() -> KeePassIconNames {
        switch self {
        case .WebForm:
            return .World
        case .SecureNote:
            return .Note
        case .CreditCard:
            return .Money
        case .Password:
            return .Key
        case .Identity:
            return .Identity
        case .BankAccountUS:
            return .Homebanking
        case .Database:
            return .Drive
        case .DriversLicense:
            return .Certificate
        case .Membership:
            return .Certificate
        case .EmailV2:
            return .EMail
        case .HuntingLicense:
            return .Certificate
        case .RewardProgram:
            return .Homebanking
        case .Passport:
            return .Identity
        case .UnixServer:
            return .NetworkServer
        case .SsnUS:
            return .Identity
        case .Router:
            return .IRCommunication
        case .License:
            return .Certificate
        default:
            return .Key
        }
    }

    func category() -> ItemCategory {
        switch self {
        case .WebForm:
            return .Logins
        case .SecureNote:
            return .SecureNotes
        case .CreditCard:
            return .CreditCards
        case .Password:
            return .Passwords
        case .Identity:
            return .Identities
        case .BankAccountUS:
            return .BankAccounts
        case .Database:
            return .Databases
        case .DriversLicense:
            return .DriverLicenses
        case .Membership:
            return .Memberships
        case .EmailV2:
            return .EmailAccounts
        case .HuntingLicense:
            return .OutdoorLicenses
        case .RewardProgram:
            return .RewardPrograms
        case .Passport:
            return .Passports
        case .UnixServer:
            return .Servers
        case .SsnUS:
            return .SocialSecurityNumbers
        case .Router:
            return .WirelessRouters
        case .License:
            return .SoftwareLicenses
        default:
            return .Unknown
        }
    }
}
