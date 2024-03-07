//
//  OnePuxStructure.swift
//  MacBox
//
//  Created by Strongbox on 01/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

enum OnePuxLoginFieldType: String, Codable {
    case TextOrHtml = "T"
    case EmailAddress = "E"
    case URL = "U"
    case Number = "N"
    case Password = "P"
    case TextArea = "A"
    case PhoneNumber = "TEL"
    case CheckBox = "C"
}

enum OnePuxCategory: String, Codable {
    case Login = "001"
    case CreditCard = "002"
    case SecureNote = "003"
    case Identity = "004"
    case Password = "005"
    case Document = "006"
    case SoftwareLicense = "100"
    case BankAccount = "101"
    case Database = "102"
    case DriversLicense = "103"
    case OutdoorLicense = "104"
    case Membership = "105"
    case Passport = "106"
    case RewardsProgram = "107"
    case SocialSecurityNumber = "108"
    case WirelessRouter = "109"
    case Server = "110"
    case EmailAccount = "111"
    case API_Credential = "112"
    case MedicalRecord = "113"
    case SshKey = "114"
    case CryptoWallet = "115"

    var displayName: String {
        switch self {
        case .Login:
            return "Logins"
        case .CreditCard:
            return "Credit Cards"
        case .SecureNote:
            return "Secure Notes"
        case .Identity:
            return "Identities"
        case .Password:
            return "Passwords"
        case .Document:
            return "Documents"
        case .SoftwareLicense:
            return "Software Licenses"
        case .BankAccount:
            return "Bank Accounts"
        case .Database:
            return "Databases"
        case .DriversLicense:
            return "Drivers Licenses"
        case .OutdoorLicense:
            return "Outdoor Licenses"
        case .Membership:
            return "Memberships"
        case .Passport:
            return "Passports"
        case .RewardsProgram:
            return "Rewards Programs"
        case .SocialSecurityNumber:
            return "Social Security Numbers"
        case .WirelessRouter:
            return "Wireless Routers"
        case .Server:
            return "Servers"
        case .EmailAccount:
            return "Email Accounts"
        case .API_Credential:
            return "API Credentials"
        case .MedicalRecord:
            return "Medical Records"
        case .SshKey:
            return "SSH Keys"
        case .CryptoWallet:
            return "Crypto Wallet"
        }
    }

    var icon: KeePassIconNames {
        switch self {
        case .Login:
            return .Identity
        case .SecureNote:
            return .Note
        case .CreditCard:
            return .Money
        case .Identity:
            return .Identity
        case .Password:
            return .Key
        case .BankAccount:
            return .Homebanking
        case .Database:
            return .Drive
        case .DriversLicense:
            return .Certificate
        case .Membership:
            return .Certificate
        case .EmailAccount:
            return .EMail
        case .OutdoorLicense:
            return .Certificate
        case .RewardsProgram:
            return .Homebanking
        case .Passport:
            return .Identity
        case .Server:
            return .NetworkServer
        case .SocialSecurityNumber:
            return .Identity
        case .WirelessRouter:
            return .IRCommunication
        case .SoftwareLicense:
            return .Certificate
        case .Document:
            return .Screen
        case .API_Credential:
            return .TerminalEncrypted
        case .MedicalRecord:
            return .UserKey
        case .SshKey:
            return .TerminalEncrypted
        case .CryptoWallet:
            return .Money
        }
    }
}

class OnePuxSshKeyMetadata: Decodable {
    let keyType: String?
    let privateKey: String?
    let fingerprint: String?
    let publicKey: String?
}

class OnePuxSshKey: Decodable {
    let metadata: OnePuxSshKeyMetadata?
    let privateKey: String?
}

class OnePuxItemOverviewAdditionalUrl: Decodable {
    let label: String?
    let url: String?
}

struct OnePuxFileAttachment: Decodable {
    let fileName: String?
    let documentId: String?
    let decryptedSize: Int64?
}

class OnePuxLoginField: Decodable {
    let designation: String?
    let name: String?
    let value: String?
    let fieldType: String?
}

class OnePuxSectionField: Decodable {
    let title: String?
    let id: String?
    let value: [String: JSONAny]?
    let file: OnePuxFileAttachment?
    let guarded: Bool?
}

class OnePuxSection: Decodable {
    let title: String?
    let fields: [OnePuxSectionField]?
}

class OnePuxHistoricalPassword: Decodable {
    let value: String?
    let time: Int64?
}

class OnePuxItemDetails: Decodable {
    let notesPlain: String?
    let documentAttributes: OnePuxFileAttachment?
    let loginFields: [OnePuxLoginField]?
    let sections: [OnePuxSection]?
    let password: String? 
    let passwordHistory: [OnePuxHistoricalPassword]?
}

class OnePuxItemOverview: Decodable {
    let title: String?
    let url: String?
    let urls: [OnePuxItemOverviewAdditionalUrl]?
    let tags: [String]?
}

class OnePuxVaultItem: Decodable {
    let uuid: String?
    let favIndex: Int64?
    let createdAt: Int64?
    let updatedAt: Int64?
    let trashed: Bool?
    let categoryUuid: String?
    let overview: OnePuxItemOverview?
    let details: OnePuxItemDetails?
    let state: String?
}

class OnePuxVaultAttributes: Decodable {
    let name: String?
    let uuid: String?
}

class OnePuxVault: Decodable {
    let attrs: OnePuxVaultAttributes?
    let items: [OnePuxVaultItem]?
}

class OnePuxAccountAttributes: Decodable {
    let accountName: String?
    let name: String?
    let uuid: String?
}

class OnePuxAccount: Decodable {
    let attrs: OnePuxAccountAttributes?
    let vaults: [OnePuxVault]?
}

class OnePuxContainer: Decodable {
    let accounts: [OnePuxAccount]?
}
