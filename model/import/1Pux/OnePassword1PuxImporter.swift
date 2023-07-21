//
//  OnePassword1PuxImporter.swift
//  MacBox
//
//  Created by Strongbox on 01/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation
import SSZipArchive

enum OnePassword1PuxImporterError: Error {
    case Unknown
    case CouldNotUnzip
    case InvalidStructure ( detail : String )
}

class OnePassword1PuxImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["1pux"]
    
    func convert(url: URL) throws -> DatabaseModel {
        let result = try convertEx(url: url)
        
        return result.database
    }
    
    func convertEx(url: URL) throws -> ImportResult {
        let unzippedDir = try unzip1Pux ( url: url )
        
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        var messages = try processUnzippedDirectory (database: database, unzippedDir: unzippedDir )
        
        
        
        try? FileManager.default.removeItem(atPath: unzippedDir.path)
        
        return ImportResult(database: database, messages: messages)
    }
    
    func unzip1Pux ( url: URL ) throws -> URL {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
        let uniqDir = temp.appendingPathComponent(UUID().uuidString)
        
        StrongboxFilesManager.sharedInstance().createIfNecessary(uniqDir)
        
        
        
        guard SSZipArchive.unzipFile(atPath: url.path, toDestination: uniqDir.path) else {
            throw OnePassword1PuxImporterError.CouldNotUnzip
        }
        
        return uniqDir
    }
    
    func processUnzippedDirectory ( database: DatabaseModel, unzippedDir : URL ) throws -> [ImportMessage] {
        let jsonFile = unzippedDir.appendingPathComponent("export.data")
        let attachmentsDir = unzippedDir.appendingPathComponent("files")

        let jsonData = try Data(contentsOf: jsonFile)

        return try processExportDataJson( jsonData: jsonData, database: database, attachmentsDir: attachmentsDir )
    }
    
    func processExportDataJson ( jsonData : Data, database: DatabaseModel, attachmentsDir : URL ) throws -> [ImportMessage] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let container = try decoder.decode(OnePuxContainer.self, from: jsonData)
        
        guard let accounts = container.accounts, !accounts.isEmpty else {
            throw OnePassword1PuxImporterError.InvalidStructure(detail: "No accounts found!")
        }
        
        let multipleAccounts = accounts.count > 1
        
        var messages : [ImportMessage] = []
        
        for account in accounts {
            let tmp = try processAccount(database: database, account: account, multipleAccounts: multipleAccounts, attachmentsDir: attachmentsDir)
            
            messages.append(contentsOf: tmp)
        }
        
        return messages
    }
    
    func processAccount (database: DatabaseModel, account : OnePuxAccount, multipleAccounts : Bool, attachmentsDir : URL ) throws -> [ImportMessage] {
        var accountGroup = database.effectiveRootGroup
        
        if multipleAccounts {
            accountGroup = Node(asGroup: account.attrs?.name ?? "Unknown Account", parent: database.effectiveRootGroup, keePassGroupTitleRules: true, uuid: nil)!
            database.effectiveRootGroup.addChild(accountGroup, keePassGroupTitleRules: true)
        }
        
        guard let vaults = account.vaults else {
            let msg = String(format: "⚠️ No vaults found for account = [%@]", String ( describing: account.attrs?.name))
            NSLog(msg)
            return [ImportMessage(msg, .warning)]
        }
        
        let multipleVaults = vaults.count > 1
        
        var collected : [ImportMessage] = []
        for vault in vaults {
            let msgs = try processVault(database: database, vault: vault, accountGroup : accountGroup, multipleVaults: multipleVaults, attachmentsDir: attachmentsDir )
            
            collected.append(contentsOf: msgs)
        }
        
        return collected
    }
    
    func processVault ( database: DatabaseModel, vault : OnePuxVault, accountGroup : Node, multipleVaults : Bool, attachmentsDir : URL ) throws -> [ImportMessage] {
        var vaultGroup = accountGroup
        
        if multipleVaults {
            vaultGroup = Node(asGroup: vault.attrs?.name ?? "Unknown Vault", parent: accountGroup, keePassGroupTitleRules: true, uuid: nil)!
            accountGroup.addChild(vaultGroup, keePassGroupTitleRules: true)
        }
        
        guard let items = vault.items else {
            let msg = String(format: "⚠️ No items found for vault = [%@]", String(describing: vault.attrs?.name))
            NSLog(msg)
            return [ImportMessage(msg, .warning)]
        }
        
        var collected : [ImportMessage] = []
        
        for item in items {
            let msgs = try processItem ( database: database, item: item, vaultGroup: vaultGroup, attachmentsDir: attachmentsDir )
            collected.append(contentsOf: msgs)
        }
        
        return collected
    }
    
    func processItem ( database: DatabaseModel, item : OnePuxVaultItem, vaultGroup : Node, attachmentsDir : URL ) throws -> [ImportMessage] {
        var messages : [ImportMessage] = []
        
        let parentGroup : Node
        if let categoryId = item.categoryUuid {
            let (pg, msgs) = createOrGetCategoryGroup(categoryId: categoryId, vaultGroup : vaultGroup, item: item)
            
            parentGroup = pg
            messages.append(contentsOf: msgs)
        }
        else {
            messages.append(ImportMessage("CategoryUuid not found for item", .error))
            parentGroup = vaultGroup
        }
        
        let node = Node(asRecord: "Unknown", parent: parentGroup)
        node.icon = parentGroup.icon
        parentGroup.addChild(node, keePassGroupTitleRules: true)
        
        if let state = item.state, state == "archived" {
            database.recycleItems([node])
        }
        
        if let trashed = item.trashed, trashed {
            database.recycleItems([node])
        }
        
        if let favourite = item.favIndex, favourite != 0 {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        if let createdAt = item.createdAt, createdAt != 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(createdAt))
            node.fields.setTouchPropertiesWithCreated(date, accessed: nil, modified: nil, locationChanged: nil, usageCount: nil)
        }
        
        if let updatedAt = item.updatedAt, updatedAt != 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(updatedAt))
            node.fields.setModifiedDateExplicit(date)
        }
        
        if let overview = item.overview {
            processOverview(overview, node)
        }

        if let details = item.details {
            let msgs = try processItemDetails ( node : node, details : details, categoryId: item.categoryUuid, attachmentsDir: attachmentsDir )
            messages.append(contentsOf: msgs)
        }

        return messages
    }
    
    func processOverview(_ overview: OnePuxItemOverview, _ node: Node) {
        if let title = overview.title {
            node.setTitle(title, keePassGroupTitleRules: true)
        }
        
        if let primaryUrl = overview.url {
            node.fields.url = primaryUrl
        }
        
        if let secondaryUrls = overview.urls {
            for secondaryUrl in secondaryUrls {
                if let url = secondaryUrl.url {
                    addUrl(node, url, secondaryUrl.label )
                }
            }
        }
        
        if let tags = overview.tags {
            for tag in tags {
                node.fields.tags.add(tag)
            }
        }
    }
    
    func processItemDetails ( node : Node, details : OnePuxItemDetails, categoryId: String?, attachmentsDir : URL ) throws -> [ImportMessage] {
        if let notes = details.notesPlain, !notes.isEmpty {
            node.fields.notes = notes
        }
        
        var collected : [ImportMessage] = []
        
        if let attachment = details.documentAttributes {
            let msgs = try processAttachment ( node: node, attachment: attachment, attachmentsDir: attachmentsDir)
            collected.append(contentsOf: msgs)
        }
        
        if let loginFields = details.loginFields {
            for loginField in loginFields {
                processLoginField( node: node, field: loginField )
            }
        }
        
        if let sections = details.sections {
            for section in sections {
                let msgs = try processSection(node: node, section: section, categoryId: categoryId, attachmentsDir: attachmentsDir )
                collected.append(contentsOf: msgs)
            }
        }
        
        if let password = details.password {
            if node.fields.password.isEmpty {
                node.fields.password = password
            }
            else {
                addCustomField(node: node, name: "password", value: password, protected: true)
            }
        }
        
        return collected
    }
    
    func processLoginField ( node : Node, field : OnePuxLoginField ) {
        if let designation = field.designation {
            guard let value = field.value, !value.isEmpty else {
                return
            }
            
            if designation == "username" {
                node.fields.username = value
                return
            }
            else if designation == "password" {
                node.fields.password = value
                return
            }
        }

        
        
        var key = field.name

        if let name = field.name, !name.isEmpty {
            key = name
        }
        else {
            key = UUID().uuidString
        }

        var val = field.value
        
        var protected : Bool = false
        if let fieldType = field.fieldType, let knownType = OnePuxLoginFieldType(rawValue: fieldType) {
            if knownType == .Password {
                protected = true
            }
            else if knownType == .CheckBox {
                val = (field.value != nil && !field.value!.isEmpty) ? "true" : "false"
            }
        }
        
        if let val, let key, !key.isEmpty, !val.isEmpty {
            addCustomField(node: node, name: key, value: val, protected: protected)
        }
    }
    
    func processSection ( node: Node, section : OnePuxSection, categoryId: String?, attachmentsDir : URL ) throws -> [ImportMessage] {
        let sectionTitle = section.title ?? UUID().uuidString

        var collected : [ImportMessage] = []
        
        if let fields = section.fields {
            for field in fields {
                let msgs = try processSectionField ( node: node, sectionTitle : sectionTitle, field : field, categoryId: categoryId, attachmentsDir: attachmentsDir)
                
                collected.append(contentsOf: msgs)
            }
        }
        
        return collected
    }
        
    func processSectionField ( node: Node, sectionTitle : String, field : OnePuxSectionField, categoryId: String?, attachmentsDir : URL ) throws -> [ImportMessage] {
        var collected : [ImportMessage] = []
        
        if let file = field.file {
            let msgs = try processAttachment( node: node, attachment: file, attachmentsDir: attachmentsDir )
            collected.append(contentsOf: msgs)
            return collected
        }

        guard let fieldValue = field.value, let key = fieldValue.keys.first, let value = fieldValue[key] else {
            let msg = String(format: "🔴 No value or key found for Section Field!", String(describing: field.value))
            NSLog(msg)
            collected.append(ImportMessage(msg, .error))
            return collected
        }
        
        
        
        let fieldN = (field.title == nil || field.title!.isEmpty) ? field.id : field.title
        var fieldName = (fieldN == nil || fieldN!.isEmpty) ? UUID().uuidString : fieldN!
        
        if node.fields.customFields.containsKey(fieldName as NSString) {
            if !sectionTitle.isEmpty {
                fieldName = String(format: "%@-%@", sectionTitle, fieldName)
            }
            else {
                fieldName = String(format: "%@-%@", UUID().uuidString, fieldName)
            }
        }
        
        
        
        let isUsername = key == "username" || field.title == "username" || field.id == "username"
        if isUsername, node.fields.username.isEmpty, let str = value.value as? String {
            node.fields.username = str
            return collected
        }

        
        
        let isPassword = key == "password" || field.title == "password" || field.id == "password"
        if isPassword, let str = value.value as? String {
            if node.fields.password.isEmpty {
                node.fields.password = str
            }
            else {
                addCustomField(node: node, name: fieldName, value: str, protected: true)
            }
            return collected
        }
        
        
        
        if key == "totp", let str = value.value as? String {
            if let token = NodeFields.getOtpToken(from: str, forceSteam: false, issuer: "", username: "") {
                if node.fields.otpToken == nil {
                    let prefs = CrossPlatformDependencies.defaults().applicationPreferences
                    
                    node.fields.setTotp(token,
                                        appendUrlToNotes: false,
                                        addLegacyFields:  prefs.addLegacySupplementaryTotpCustomFields,
                                        addOtpAuthUrl: prefs.addOtpAuthUrl)
                    return collected
                }
                else if let otpUrl = token.url(true) {
                    node.fields.addSecondaryUrl(otpUrl.absoluteString, optionalCustomFieldSuffixLabel: fieldName)
                    return collected
                }
            }
            else{
                
            }
        }
        
        
        
        if let categoryId, let category = OnePuxCategory(rawValue: categoryId) {
            if category == .Server, let fieldId = field.id, fieldId == "url", let str = value.value as? String {
                addUrl(node, str, fieldName)
                return collected
            }

            if category == .API_Credential, let fieldId = field.id, fieldId == "credential", node.fields.password.isEmpty, let str = value.value as? String {
                node.fields.password = str
                return collected
            }
            
            if category == .SshKey {
                if let dict = value.value as? [String : Any],
                   let privateKey = dict["privateKey"] as? String,
                   let metadata = dict["metadata"] as? [String : Any],
                   let publicKey = metadata["publicKey"] as? String,
                   let fingerprint = metadata["fingerprint"] as? String {
                    addCustomField(node: node, name: "privateKey", value: privateKey, protected: true)
                    addCustomField(node: node, name: "publicKey", value: publicKey)
                    addCustomField(node: node, name: "fingerprint", value: fingerprint, protected: false, detectUrl: false)
                    
                    
                    
                    
                    
                    
                    
                    
                    return collected
                }
                else {
                    let msg = String(format: "Could not properly parse SSH Key: [%@] - [%@] - [%@]", String(describing: value.value), node.title, String(describing: node.uuid))
                    NSLog(msg)
                    collected.append(ImportMessage(msg, .warning))
                    
                    addCustomField(node: node, name: "UNK-SSH-KEY", value: String(describing: value.value), protected: false )
                    
                    return collected
                }
            }
        }
    
        
        
        if key == "address", let addressDict = value.value as? [String : Any] {
            processSectionAddressField(addressDict, node, fieldName)
            return collected
        }
        
        
        
        if key == "email", let emailDict = value.value as? [String : Any] {
            if let addy = emailDict["email_address"] as? String, !addy.isEmpty {
                if node.fields.email.isEmpty {
                    node.fields.email = addy
                }
                else {
                    addCustomField(node: node, name: fieldName, value: addy)
                }
            }

            if let provider = emailDict["provider"] as? String, !provider.isEmpty {
                addCustomField(node: node, name: "provider", value: provider)
            }

            return collected
        }
        
        
        
        if key == "date", let epoch = value.value as? Int64, epoch != 0 {
            let date = Date(timeIntervalSince1970: TimeInterval(epoch))
            let mydf = DateFormatter()
            mydf.dateStyle = .long 
            let dateFmt = mydf.string(from: date)

            addCustomField(node: node, name: fieldName, value: dateFmt)
            
            return collected
        }

        
        
        if key == "monthYear", let u = value.value as? Int64, u != 0 {
            let year = u / 100
            let month = u % 100

            let str = String(format: "%0.2d/%0.4d", month, year)
            addCustomField(node: node, name: fieldName, value: str)
            
            return collected
        }

        if key == "file", 
           let fileDict = value.value as? [String: Any],
            let filename = fileDict["fileName"] as? String,
            let documentId = fileDict["documentId"] as? String {

            try processAttachment(node: node, documentId: documentId, filename: filename, attachmentsDir: attachmentsDir)
            
            return collected
        }
        
        
        
        if let str = value.value as? String {
            if !str.isEmpty {
                addCustomField(node: node, name: fieldName, value: str, protected: field.guarded ?? false )
            }
        }
        else if let _ = value.value as? JSONNull {
            
        }
        else if let num = value.value as? Int64 {
            addCustomField(node: node, name: fieldName, value: String(num), protected: field.guarded ?? false )
        }
        else {
            let msg = String(format: "Could not properly import structured field: [%@] - [%@] - [%@]", String(describing: value.value), node.title, String(describing: node.uuid))
            NSLog(msg)
            collected.append(ImportMessage(msg, .warning))
            
            addCustomField(node: node, name: "UNK", value: String(describing: value.value), protected: false )
        }
        
        return collected
    }

    func processSectionAddressField(_ addressDict: [String : Any], _ node: Node, _ fieldName: String) {
        var addressString = ""
        
        if let street = addressDict["street"] as? String, !street.isEmpty {
            addressString.append(street)
            addressString.append("\n")
        }
        
        if let zip = addressDict["zip"] as? String, !zip.isEmpty {
            addressString.append(zip)
            addressString.append("\n")
        }
        if let city = addressDict["city"] as? String, !city.isEmpty {
            addressString.append(city)
            addressString.append("\n")
        }
        if let state = addressDict["state"] as? String, !state.isEmpty {
            addressString.append(state)
            addressString.append("\n")
        }
        if let country = addressDict["country"] as? String, !country.isEmpty {
            addressString.append(country)
            addressString.append("\n")
        }
        
        if !addressString.isEmpty {
            addCustomField(node: node, name: "address", value: addressString)
        }
        else {

        }
    }

    func processAttachment ( node : Node, attachment : OnePuxFileAttachment, attachmentsDir : URL ) throws -> [ImportMessage] {
        guard let documentId = attachment.documentId,
              let filename = attachment.fileName else {
            NSLog("🔴 No Document ID or Filename for file Attachment!")
            return [ImportMessage("No Document ID or Filename for file Attachment!", .error)]
        }
        
        try processAttachment(node: node, documentId: documentId, filename: filename, attachmentsDir: attachmentsDir)
        
        return []
    }
    
    func processAttachment ( node : Node, documentId : String, filename : String , attachmentsDir : URL ) throws {
        let filePath = String(format: "%@__%@", documentId, filename )
        let fileUrl = attachmentsDir.appendingPathComponent(filePath)
        
        let data = try Data(contentsOf: fileUrl)

        var uniqueFilename = filename
        if ( node.fields.attachments[filename] != nil ) {
            uniqueFilename = String(format: "%@-%@", documentId, filename)
        }
        
        node.fields.attachments[uniqueFilename] = KeePassAttachmentAbstractionLayer(nonPerformantWith: data, compressed: true, protectedInMemory: true)
    }
    
    

    func addUrl(_ node: Node, _ url: String, _ label : String?) {
        BaseImporter.addUrl(node, url, label)
    }
    
    func addCustomField ( node: Node, name : String, value : String, protected : Bool = false, detectUrl : Bool = true ) {
        BaseImporter.addCustomField(node: node, name: name, value: value, protected: protected, detectUrl: detectUrl)
    }
    
    func createOrGetCategoryGroup(categoryId: String, vaultGroup : Node, item : OnePuxVaultItem ) -> (Node, [ImportMessage]) {
        guard let category = OnePuxCategory(rawValue: categoryId) else {
            let msg = String(format: "Couldn't get category for item: [%@] - Moved to root group", categoryId)
            NSLog(msg)
            return ( vaultGroup, [ImportMessage(msg, .warning)] )
        }
        
        let node = createOrGetGroup(parentGroup : vaultGroup, title: category.displayName, icon: category.icon)
        
        return ( node, [] )
    }
    
    func createOrGetGroup ( parentGroup : Node, title : String, icon : KeePassIconNames ) -> Node {
        if let existing = parentGroup.childGroups.first ( where: { group in
            return group.title == title
        }) {
            return existing
        }
        
        let ret = Node(asGroup: title, parent: parentGroup, keePassGroupTitleRules: true, uuid: nil)!
        ret.icon = NodeIcon.withPreset(icon.rawValue)
        
        parentGroup.addChild(ret, keePassGroupTitleRules: true)
        
        return ret
    }
}
