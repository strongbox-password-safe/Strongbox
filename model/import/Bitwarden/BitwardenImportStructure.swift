//
//  BitwardenImportStructure.swift
//  MacBox
//
//  Created by Strongbox on 24/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

struct BitwardenJsonFile: Decodable {
    var encrypted: Bool?
    var folders: [BitwardenFolder?]?
    var collections: [BitwardenCollection?]?
    var items: [BitwardenItem?]?
}

struct BitwardenFolder: Decodable {
    var id: String?
    var name: String?
}

struct BitwardenCollection: Decodable {
    var id: String?
    var name: String?
}

struct BitwardenItem: Decodable {
    var creationDate: Date?
    var revisionDate: Date?
    var deletedDate: Date? 
    var id: String?
    var name: String?
    var notes: String?
    var favorite: Bool?
    var folderId: String?
    var collectionIds: [String?]?
    var login: BitwardenLogin?
    var card: BitwardenCard?
    var fields: [BitwardenField?]?
    var identity: BitwardenIdentity?

    var passwordHistory: [BitwardenPasswordHistoryItem?]?
}





struct BitwardenPasswordHistoryItem: Decodable {
    var lastUsedDate: Date?
    var password: String?
}

struct BitwardenField: Decodable {
    var name: String?
    var value: String?
    var type: Int? 
}

struct BitwardenCard: Decodable {
    var cardholderName: String?
    var brand: String?
    var number: String?
    var code: String?
    var expYear: String?
    var expMonth: String?
}

struct BitwardenIdentity: Decodable {
    var title: String?
    var firstName: String?
    var middleName: String?
    var lastName: String?
    var address1: String?
    var address2: String?
    var address3: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?
    var company: String?
    var email: String?
    var phone: String?
    var ssn: String?
    var username: String?
    var passportNumber: String?
    var licenseNumber: String?
}

struct BitwardenLogin: Decodable {
    var uris: [BitwardenUri?]?
    var username: String?
    var password: String?
    var totp: String?
}

struct BitwardenUri: Decodable {
    var uri: String?
}
