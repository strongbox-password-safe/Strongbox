import AuthenticationServices
import CryptoKit
import Foundation

@available(iOS 26.0, *)
class ApplePasswordsImporter {

    enum ImporterError: Error {
        case passKey(String)
        case invalidActivityType
        case missingToken
        case noAccounts
    }

    
    
    func importFromUserActivity(_ userActivity: NSUserActivity) async throws -> ImportResult {
        guard userActivity.activityType == ASCredentialExchangeActivity else {
            throw ImporterError.invalidActivityType
        }

        guard let token = userActivity.userInfo?[ASCredentialImportToken] as? NSUUID else {
            throw ImporterError.missingToken
        }

        let manager = ASCredentialImportManager()
        let exportedData = try await manager.importCredentials(token: token as UUID)

        return convertToDatabase(exportedData)
    }
}



@available(iOS 26.0, *)
private extension ApplePasswordsImporter {
    func convertToDatabase(_ exported: ASExportedCredentialData) -> ImportResult {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        guard !exported.accounts.isEmpty else {
            return ImportResult(database: database, messages: [ImportMessage("No accounts found to import.", .warning)])
        }

        var messages: [ImportMessage] = []

        for account in exported.accounts {
            let accountMessages = processAccount(account, database: database)
            messages.append(contentsOf: accountMessages)
        }

        return ImportResult(database: database, messages: messages)
    }

    func processAccount(_ account: ASImportableAccount, database: DatabaseModel) -> [ImportMessage] {
        var messages: [ImportMessage] = []

        let accountTitle = account.fullName ?? (!account.email.isEmpty ? account.email : account.userName)
        let topGroupName = accountTitle.isEmpty ? NSLocalizedString("generic_unknown", comment: "Unknown") : accountTitle
        let accountGroup = BaseImporter.getOrCreateGroup(database, [topGroupName], nil) ?? database.effectiveRootGroup

        var collectionGroups: [Data: Node] = [:]
        for collection in account.collections {
            let group = buildCollection(collection, parent: accountGroup, database: database, messages: &messages, map: &collectionGroups)
            collectionGroups[collection.id] = group
        }

        var itemsById: [Data: ASImportableItem] = [:]
        for item in account.items {
            itemsById[item.id] = item
        }

        var placed: Set<Data> = []

        for collection in account.collections {
            guard let targetGroup = collectionGroups[collection.id] else { continue }
            for linked in collection.items {
                if let item = itemsById[linked.item] {
                    let msgs = processItem(item, parentGroup: targetGroup)
                    messages.append(contentsOf: msgs)
                    placed.insert(item.id)
                }
            }
        }

        for item in account.items where !placed.contains(item.id) {
            let msgs = processItem(item, parentGroup: accountGroup)
            messages.append(contentsOf: msgs)
        }

        return messages
    }

    @discardableResult
    func buildCollection(_ collection: ASImportableCollection,
                         parent: Node,
                         database: DatabaseModel,
                         messages: inout [ImportMessage],
                         map: inout [Data: Node]) -> Node {
        let title = collection.title
        let group = Node(asGroup: title,
                         parent: parent,
                         keePassGroupTitleRules: true,
                         uuid: nil) ?? parent

        if group !== parent {
            database.addChildren([group], destination: parent)
        }

        for sub in collection.subcollections {
            let child = buildCollection(sub, parent: group, database: database, messages: &messages, map: &map)
            map[sub.id] = child
        }

        map[collection.id] = group
        return group
    }

    func processItem(_ item: ASImportableItem, parentGroup: Node) -> [ImportMessage] {
        var messages: [ImportMessage] = []

        let title = item.title.isEmpty ? NSLocalizedString("generic_unknown", comment: "Unknown") : item.title
        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: UUID())
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let subtitle = item.subtitle, !subtitle.isEmpty {
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("subtitle", comment: "Subtitle"), value: subtitle, protected: false, detectUrl: false)
        }

        if let created = item.created {
            node.fields.setTouchPropertiesWithCreated(created, accessed: nil, modified: nil, locationChanged: nil, usageCount: nil)
        }

        if let modified = item.lastModified {
            node.setModifiedDateExplicit(modified, setParents: false)
        }

        if let scope = item.scope {
            for url in scope.urls {
                BaseImporter.addUrl(node, url.absoluteString)
            }
            if !scope.androidApps.isEmpty {
                messages.append(ImportMessage("Android app scope not imported for item \(title).", .info))
            }
        }
        
        for tag in item.tags {
            node.fields.tags.add(tag)
        }

        if item.favorite {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        for credential in item.credentials {
            let credentialMessages = processCredential(credential, node: node, itemTitle: title)
            messages.append(contentsOf: credentialMessages)
        }

        return messages
    }

    func processCredential(_ credential: ASImportableCredential, node: Node, itemTitle: String) -> [ImportMessage] {
        var messages: [ImportMessage] = []

        switch credential {
        case let .basicAuthentication(auth):
            BaseImporter.addUsernameOrCustom(node: node, name: NSLocalizedString("username", comment: "Username"), value: auth.userName?.value)
            BaseImporter.addPasswordOrCustom(node: node, name: NSLocalizedString("password", comment: "Password"), value: auth.password?.value)

        case let .generatedPassword(generated):
            BaseImporter.addPasswordOrCustom(node: node, name: NSLocalizedString("password", comment: "Password"), value: generated.password)

        case let .totp(totp):
            if let otpUrl = buildOtpUrl(totp: totp, title: itemTitle) {
                BaseImporter.addTotpOrCustom(node: node, name: "TOTP", value: otpUrl.absoluteString)
            } else {
                messages.append(ImportMessage("Could not import TOTP for \(itemTitle).", .warning))
            }

        case let .note(note):
            node.fields.notes = note.content.value

        case let .apiKey(apiKey):
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("API Key", comment: "API Key"), value: apiKey.key?.value, protected: true, detectUrl: false)
            BaseImporter.addUsernameOrCustom(node: node, name: NSLocalizedString("Username", comment: "Username"), value: apiKey.userName?.value)
            if let label = apiKey.url?.label, let value = apiKey.url?.value {
                BaseImporter.addCustomField(node: node, name: label, value: value, protected: false)
            }

        case let .wifi(wifi):
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Wi-Fi SSID", comment: "Wi-Fi SSID"), value: wifi.ssid?.value, protected: false)
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Wi-Fi Passphrase", comment: "Wi-Fi Passphrase"), value: wifi.passphrase?.value, protected: true, detectUrl: false)

        case let .customFields(custom):
            for field in custom.fields {
                BaseImporter.addCustomField(node: node, name: field.label, value: field.value, protected: field.fieldType == .concealedString)
            }

        case let .address(address):
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Address", comment: "Address"), value: address.streetAddress?.value, protected: false, detectUrl: false)
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("City", comment: "City"), value: address.city?.value, protected: false, detectUrl: false)
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Country", comment: "Country"), value: address.country?.value, protected: false, detectUrl: false)

        case let .creditCard(card):
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Card Number", comment: "Card Number"), value: card.number?.value, protected: true, detectUrl: false)
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Cardholder Name", comment: "Cardholder Name"), value: card.fullName?.value, protected: false, detectUrl: false)
            BaseImporter.addCustomField(node: node, name: NSLocalizedString("Expiry Date", comment: "Expiry Date"), value: card.expiryDate?.value, protected: false, detectUrl: false)

        case .passkey(let passkey):
            applyPasskeyMetadata(passkey, with: credential, to: node)

            if let sbPasskey = try? makeStrongboxPasskey(from: passkey) {
                node.passkey = sbPasskey
            } else {
                BaseImporter.addCustomField(node: node,
                                            name: "Passkey RPID",
                                            value: passkey.relyingPartyIdentifier,
                                            protected: false,
                                            detectUrl: false)
                BaseImporter.addCustomField(node: node,
                                            name: "Passkey Username",
                                            value: passkey.userName,
                                            protected: false,
                                            detectUrl: false)
                BaseImporter.addCustomField(node: node,
                                            name: "Passkey User Handle",
                                            value: passkey.userHandle.base64EncodedString(),
                                            protected: true,
                                            detectUrl: false)
                BaseImporter.addCustomField(node: node,
                                            name: "Passkey Credential ID",
                                            value: passkey.credentialID.base64EncodedString(),
                                            protected: true,
                                            detectUrl: false)
                BaseImporter.addCustomField(node: node,
                                            name: "Passkey Key (raw)",
                                            value: passkey.key.base64EncodedString(),
                                            protected: true,
                                            detectUrl: false)
                messages.append(ImportMessage("Passkey for \(itemTitle) stored as custom fields; manual migration recommended.", .warning))
            }

        default:
            messages.append(ImportMessage("Unsupported credential type for \(itemTitle); stored minimal data.", .info))
        }

        return messages
    }

    func buildOtpUrl(totp: ASImportableCredential.TOTP, title: String) -> URL? {
        let secretData = totp.secret
        let secretBase32 = (secretData as NSData).mmcg_base32StringNoPadding()

        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        components.path = "/" + encodedTitle

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "secret", value: secretBase32),
            URLQueryItem(name: "period", value: String(totp.period)),
            URLQueryItem(name: "digits", value: String(totp.digits))
        ]

        let algorithm = totp.algorithm
        queryItems.append(URLQueryItem(name: "algorithm", value: algorithm.rawValue.uppercased()))

        if let issuer = totp.issuer {
            queryItems.append(URLQueryItem(name: "issuer", value: issuer))
        }

        if let userName = totp.userName {
            queryItems.append(URLQueryItem(name: "account", value: userName))
        }

        components.queryItems = queryItems

        return components.url
    }
}

@available(iOS 26.0, *)
private extension ApplePasswordsImporter {
    func applyPasskeyMetadata(_ passkey: ASImportableCredential.Passkey, with credential: ASImportableCredential, to node: Node) {
        
        let preferredUsername = passkey.userDisplayName.isEmpty ? passkey.userName : passkey.userDisplayName
        BaseImporter.addUsernameOrCustom(node: node,
                                         name: NSLocalizedString("username", comment: "Username"),
                                         value: preferredUsername)
        

        
        let rpid = passkey.relyingPartyIdentifier
        let urlString: String
        if rpid.lowercased().hasPrefix("http") {
            urlString = rpid
        } else {
            urlString = "https://\(rpid)"
        }

        if let url = URL(string: urlString)?.absoluteString {
            BaseImporter.addUrl(node, url)
        }
    }

    func makeStrongboxPasskey(from applePasskey: ASImportableCredential.Passkey) throws -> Passkey {
        guard let pem = passkeyPem(from: applePasskey.key) else {
            throw ImporterError.passKey("Could not decode passkey private key")
        }

        guard let sbPasskey = Passkey(relyingPartyId: applePasskey.relyingPartyIdentifier,
                                      username: applePasskey.userName,
                                      userHandleData: applePasskey.userHandle,
                                      credentialIdData: applePasskey.credentialID,
                                      privateKeyPem: pem) else {
            throw ImporterError.passKey("Could not initialize Strongbox passkey")
        }

        return sbPasskey
    }

    func passkeyPem(from keyData: Data) -> String? {
        
        if let maybePem = String(data: keyData, encoding: .utf8),
           maybePem.contains("BEGIN") {
            return maybePem
        }

        
        if keyData.count == 32, let key = try? P256.Signing.PrivateKey(rawRepresentation: keyData) {
            return key.pemRepresentation
        }

        
        if let key = try? P256.Signing.PrivateKey(derRepresentation: keyData) {
            return key.pemRepresentation
        }

        return nil
    }
}
