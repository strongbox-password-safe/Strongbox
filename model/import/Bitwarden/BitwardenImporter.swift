//
//  BitwardenImporter.swift
//  MacBox
//
//  Created by Strongbox on 22/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class BitwardenImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["json"]

    var groups: [String: String] = [:]
    var tags: [String: String] = [:]

    func convert(url: URL) throws -> DatabaseModel {
        let result = try convertEx(url: url)

        return result.database
    }

    func convertEx(url: URL) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601withFractionalSeconds

        let jsonData = try Data(contentsOf: url)
        let container = try decoder.decode(BitwardenJsonFile.self, from: jsonData)

        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        guard let items = container.items else {
            return ImportResult(database: database, messages: [ImportMessage("No Items Found!", .warning)])
        }

        if let encrypted = container.encrypted, encrypted {
            return ImportResult(database: database, messages: [ImportMessage("JSON is encrypted, cannot import", .error)])
        }

        var messages: [ImportMessage] = []

        

        if let folders = container.folders {
            for folder in folders {
                if let folder, let id = folder.id, let name = folder.name {
                    groups[id] = name
                }
            }
        }

        

        if let collections = container.collections {
            for collection in collections {
                if let collection, let id = collection.id, let name = collection.name, !name.isEmpty {
                    tags[id] = name
                }
            }
        }

        

        for item in items {
            if let item {
                let messagesItem = processItem(database, item)
                messages.append(contentsOf: messagesItem)
            }
        }

        return ImportResult(database: database, messages: messages)
    }

    func processItem(_ database: DatabaseModel, _ item: BitwardenItem) -> [ImportMessage] {
        var messages: [ImportMessage] = []

        let title = item.name ?? NSLocalizedString("generic_unknown", comment: "Unknown")

        let uuid = item.id != nil ? (UUID(uuidString: item.id!) ?? UUID()) : UUID()

        var parentGroup = database.effectiveRootGroup

        if let folderId = item.folderId, let groupName = groups[folderId] {
            let components = groupName.split(separator: "/").map { String($0) } 
            if let subgroup = BaseImporter.getOrCreateGroup(database, components, nil) {
                parentGroup = subgroup
            }
        } else if item.folderId != nil {
            messages.append(ImportMessage("Could not read folderID for item", .warning))
            swlog("⚠️ Could not read folderID for item")
        }

        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: uuid)
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let created = item.creationDate {
            node.fields.setTouchPropertiesWithCreated(created, accessed: nil, modified: nil, locationChanged: nil, usageCount: nil)
        }

        if let modified = item.revisionDate {
            node.setModifiedDateExplicit(modified, setParents: false)
        }

        if item.deletedDate != nil { 
            database.recycleItems([node])
        }

        if let notes = item.notes {
            node.fields.notes = notes
        }

        if let fav = item.favorite, fav {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        

        if let collectionIds = item.collectionIds {
            for collectionId in collectionIds {
                if let collectionId, let tag = tags[collectionId] {
                    node.fields.tags.add(tag)
                }
            }
        }

        if let login = item.login {
            processItemLogin(node, login)
        }

        if let card = item.card {
            processItemCard(node, card)
        }

        if let fields = item.fields {
            for field in fields {
                if let field {
                    processItemField(node, field)
                }
            }
        }

        if let identity = item.identity {
            processItemIdentity(node, identity)
        }

        

        if let passwordHistories = item.passwordHistory {
            processPasswordHistories(node, passwordHistories)
        }

        return messages
    }

    func processItemLogin(_ node: Node, _ login: BitwardenLogin) {
        if let username = login.username, !username.isEmpty {
            node.fields.username = username
        }

        if let password = login.password, !password.isEmpty {
            node.fields.password = password
        }

        if let totp = login.totp, !totp.isEmpty {
            BaseImporter.addTotpOrCustom(node: node, name: "totp", value: totp)
        }

        if let uris = login.uris {
            for uri in uris {
                if let uri, let uriUri = uri.uri {
                    BaseImporter.addUrl(node, uriUri)
                }
            }
        }
    }

    func processItemCard(_ node: Node, _ card: BitwardenCard) {
        if let cardholderName = card.cardholderName, !cardholderName.isEmpty {
            BaseImporter.addUsernameOrCustom(node: node, name: "Cardholder Name", value: cardholderName)
        }

        if let brand = card.brand, !brand.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Brand", value: brand)
        }

        if let number = card.number, !number.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Number", value: number)
        }

        if let code = card.code, !code.isEmpty {
            BaseImporter.addCustomField(node: node, name: "code", value: code, protected: true)
        }

        if let expYear = card.expYear, !expYear.isEmpty, let expMonth = card.expMonth, !expMonth.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Expires", value: String(format: "%@/%@", expMonth, expYear))
        } else {
            if let expYear = card.expYear, !expYear.isEmpty {
                BaseImporter.addCustomField(node: node, name: "Expiry Year", value: expYear)
            }
            if let expMonth = card.expMonth, !expMonth.isEmpty {
                BaseImporter.addCustomField(node: node, name: "Expiry Month", value: expMonth)
            }
        }
    }

    func processItemField(_ node: Node, _ field: BitwardenField) {
        if let name = field.name, let value = field.value, !name.isEmpty {
            let concealed = field.type == 1
            BaseImporter.addCustomField(node: node, name: name, value: value, protected: concealed)
        }
    }

    func processItemIdentity(_ node: Node, _ identity: BitwardenIdentity) {
        if let username = identity.username, !username.isEmpty {
            BaseImporter.addUsernameOrCustom(node: node, name: "Username", value: username)
        }
        if let email = identity.email, !email.isEmpty {
            BaseImporter.addEmailOrCustom(node: node, name: "Email", value: email)
        }

        if let title = identity.title, !title.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Title", value: title)
        }
        if let firstName = identity.firstName, !firstName.isEmpty {
            BaseImporter.addCustomField(node: node, name: "First Name", value: firstName)
        }
        if let middleName = identity.middleName, !middleName.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Middle Name", value: middleName)
        }
        if let lastName = identity.lastName, !lastName.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Last Name", value: lastName)
        }
        if let address1 = identity.address1, !address1.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Address 1", value: address1)
        }
        if let address2 = identity.address2, !address2.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Address 2", value: address2)
        }
        if let address3 = identity.address3, !address3.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Address 3", value: address3)
        }
        if let city = identity.city, !city.isEmpty {
            BaseImporter.addCustomField(node: node, name: "City", value: city)
        }
        if let state = identity.state, !state.isEmpty {
            BaseImporter.addCustomField(node: node, name: "State / Province", value: state)
        }
        if let postalCode = identity.postalCode, !postalCode.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Zip / Postal Code", value: postalCode)
        }
        if let country = identity.country, !country.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Country", value: country)
        }
        if let company = identity.company, !company.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Company", value: company)
        }
        if let phone = identity.phone, !phone.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Phone", value: phone)
        }
        if let ssn = identity.ssn, !ssn.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Social Security Number", value: ssn)
        }
        if let passportNumber = identity.passportNumber, !passportNumber.isEmpty {
            BaseImporter.addCustomField(node: node, name: "Passport Number", value: passportNumber)
        }
        if let licenseNumber = identity.licenseNumber, !licenseNumber.isEmpty {
            BaseImporter.addCustomField(node: node, name: "License Number", value: licenseNumber)
        }
    }

    func processPasswordHistories(_ node: Node, _ passwordHistories: [BitwardenPasswordHistoryItem?]) {
        if let createdAt = node.fields.created { 
            var newMod = createdAt

            for passwordHistory in passwordHistories.reversed() { 
                if let passwordHistory, let pw = passwordHistory.password, let changedAt = passwordHistory.lastUsedDate {
                    

                    BaseImporter.addHistoricalPasswordEntry(node, pw, newMod)

                    newMod = changedAt 
                }
            }
        }
    }
}
