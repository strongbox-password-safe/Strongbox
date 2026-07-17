import Foundation

class Secrets4Importer: NSObject, Importer {
    var allowedFileTypes: [String] = ["xml"]

    func convert(url: URL) throws -> DatabaseModel {
        let result = try convertEx(url: url)
        return result.database
    }

    func convertEx(url: URL) throws -> ImportResult {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        var messages: [ImportMessage] = []

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            messages.append(ImportMessage("Encountered empty Secrets 4 export file", .warning))
            return ImportResult(database: database, messages: messages)
        }

        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
            let items = extractItems(from: jsonObject)

            if items.isEmpty {
                messages.append(ImportMessage("Unrecognized Secrets 4 export structure", .warning))
            }

            for item in items {
                processItem(item, database: database, messages: &messages)
            }

            if let attachments = (jsonObject as? [String: Any])?["attachments"] as? [Any], !attachments.isEmpty {
                messages.append(ImportMessage("Secrets 4 export contained attachments which are not imported automatically.", .info))
            }
        } else if let xmlRoot = try? parseXml(data: data) as? [String: Any] {
            processXmlRoot(xmlRoot, database: database, messages: &messages)
        } else {
            messages.append(ImportMessage("Unable to parse Secrets 4 export", .warning))
        }

        if database.effectiveRootGroup.childGroups.isEmpty && database.effectiveRootGroup.childRecords.isEmpty {
            messages.append(ImportMessage("No records imported", .warning))
        }

        return ImportResult(database: database, messages: messages)
    }

    

    private func parseXml(data: Data) throws -> Any {
        class Element {
            let name: String
            var text = ""
            var children: [Element] = []

            init(name: String) {
                self.name = name
            }
        }

        final class ParserDelegate: NSObject, XMLParserDelegate {
            var stack: [Element] = []
            var result: Element?
            var error: Error?

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
                stack.append(Element(name: elementName))
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                stack.last?.text.append(string)
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                guard let current = stack.popLast() else { return }
                if let parent = stack.last {
                    parent.children.append(current)
                } else {
                    result = current
                }
            }

            func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
                error = parseError
            }
        }

        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()

        if let error = delegate.error { throw error }
        guard let root = delegate.result else {
            throw GenericImportError.error(details: "Could not parse Secrets 4 XML export")
        }

        func convert(_ element: Element) -> Any {
            let trimmed = element.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if element.children.isEmpty {
                return trimmed
            }

            var dictionary: [String: Any] = [:]
            for child in element.children {
                let converted = convert(child)
                if let existing = dictionary[child.name] {
                    if var arr = existing as? [Any] {
                        arr.append(converted)
                        dictionary[child.name] = arr
                    } else {
                        dictionary[child.name] = [existing, converted]
                    }
                } else {
                    dictionary[child.name] = converted
                }
            }

            if !trimmed.isEmpty {
                dictionary["_text"] = trimmed
            }

            return dictionary
        }

        return convert(root)
    }

    private func processXmlRoot(_ root: [String: Any], database: DatabaseModel, messages: inout [ImportMessage]) {
        let credentials = arrayOfDictionaries(from: root["credentials"], key: "credential")
        for credential in credentials {
            processCredential(credential, database: database, messages: &messages)
        }

        let creditCards = arrayOfDictionaries(from: root["creditCards"], key: "creditCard")
        for card in creditCards {
            processCreditCard(card, database: database, messages: &messages)
        }

        let bankAccounts = arrayOfDictionaries(from: root["bankAccounts"], key: "bankAccount")
        for account in bankAccounts {
            processBankAccount(account, database: database, messages: &messages)
        }

        let notes = arrayOfDictionaries(from: root["notes"], key: "note")
        for note in notes {
            processNote(note, database: database, messages: &messages)
        }
    }

    private func arrayOfDictionaries(from value: Any?, key: String) -> [[String: Any]] {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let dict = value as? [String: Any] {
            if let inner = dict[key] {
                return arrayOfDictionaries(from: inner, key: key)
            } else {
                return [dict]
            }
        }
        if let single = value as? [Any], let first = single.first as? [String: Any], single.count == 1 {
            return [first]
        }
        return []
    }

    private func processCredential(_ credential: [String: Any], database: DatabaseModel, messages: inout [ImportMessage]) {
        guard !isTrashed(credential["trashed"]) else {
            messages.append(ImportMessage("Skipped trashed credential", .info))
            return
        }

        let title = string(from: credential["name"]) ?? NSLocalizedString("generic_unknown", comment: "Unknown")
        let parentGroup = group(for: credential, database: database) ?? database.effectiveRootGroup
        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: nil)
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let username = string(from: credential["identifier"]) ?? string(from: credential["login"]) {
            node.fields.username = username
        }

        let secrets = arrayOfDictionaries(from: credential["secrets"], key: "secret")
        var passwordApplied = false
        for secret in secrets {
            guard let value = string(from: secret["secretValue"]) else { continue }
            let kind = (secret["kind"] as? NSString)?.integerValue ?? Int((secret["kind"] as? String) ?? "") ?? 0
            if kind == 0 && !passwordApplied {
                BaseImporter.addPasswordOrCustom(node: node, name: "Password", value: value)
                passwordApplied = true
            } else {
                let label = kind == 1 ? "PIN" : "Secret"
                BaseImporter.addCustomField(node: node, name: label, value: value, protected: true, detectUrl: false)
            }
        }

        if let notes = string(from: credential["notes"]) {
            node.fields.notes = notes
        }

        addServices(from: credential["services"], to: node)
        addTags(from: credential["tags"], to: node)

        if isFavorite(credential["favorite"]) {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        if let otpDict = credential["oneTimePassword"] as? [String: Any] {
            addTotp(from: otpDict, label: title, to: node)
        }

        let otps = arrayOfDictionaries(from: credential["oneTimePasswords"], key: "oneTimePassword")
        for otp in otps {
            addTotp(from: otp, label: title, to: node)
        }

        setDates(on: node, from: credential, createdKeys: ["creationDate"], modifiedKeys: ["modificationDate"])
    }

    private func processCreditCard(_ card: [String: Any], database: DatabaseModel, messages: inout [ImportMessage]) {
        guard !isTrashed(card["trashed"]) else {
            messages.append(ImportMessage("Skipped trashed credit card", .info))
            return
        }

        let title = string(from: card["name"]) ?? "Credit Card"
        let node = Node(asRecord: title, parent: database.effectiveRootGroup, fields: NodeFields(), uuid: nil)
        database.effectiveRootGroup.addChild(node, keePassGroupTitleRules: true)

        if let holder = string(from: card["cardholder"]) {
            BaseImporter.addUsernameOrCustom(node: node, name: "Cardholder", value: holder)
        }

        if let number = string(from: card["pan"]) {
            BaseImporter.addCustomField(node: node, name: "Number", value: number, protected: true, detectUrl: false)
        }

        if let expiry = string(from: card["expirationDate"]) {
            BaseImporter.addCustomField(node: node, name: "Expiration", value: expiry, protected: false, detectUrl: false)
        }

        if let brand = string(from: card["brand"]) {
            BaseImporter.addCustomField(node: node, name: "Brand", value: brand.capitalized, detectUrl: false)
        }

        if let security = string(from: card["securityCode"]) {
            BaseImporter.addCustomField(node: node, name: "Security Code", value: security, protected: true, detectUrl: false)
        }

        if let pin = string(from: card["pin"]) {
            BaseImporter.addCustomField(node: node, name: "PIN", value: pin, protected: true, detectUrl: false)
        }

        if let notes = string(from: card["notes"]) {
            node.fields.notes = notes
        }

        addTags(from: card["tags"], to: node)
        if isFavorite(card["favorite"]) {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        setDates(on: node, from: card, createdKeys: ["creationDate"], modifiedKeys: ["modificationDate"])
    }

    private func processBankAccount(_ account: [String: Any], database: DatabaseModel, messages: inout [ImportMessage]) {
        guard !isTrashed(account["trashed"]) else {
            messages.append(ImportMessage("Skipped trashed bank account", .info))
            return
        }

        let title = string(from: account["name"]) ?? "Bank Account"
        let node = Node(asRecord: title, parent: database.effectiveRootGroup, fields: NodeFields(), uuid: nil)
        database.effectiveRootGroup.addChild(node, keePassGroupTitleRules: true)

        if let holder = string(from: account["accountHolder"]) {
            BaseImporter.addCustomField(node: node, name: "Account Holder", value: holder, detectUrl: false)
        }

        if let bankName = string(from: account["bankName"]) {
            BaseImporter.addCustomField(node: node, name: "Bank", value: bankName, detectUrl: false)
        }

        if let number = string(from: account["number"]) {
            BaseImporter.addCustomField(node: node, name: "Number", value: number, protected: true, detectUrl: false)
        }

        if let iban = string(from: account["iban"]) {
            BaseImporter.addCustomField(node: node, name: "IBAN", value: iban, protected: true, detectUrl: false)
        }

        if let routing = string(from: account["routingNumber"]) {
            BaseImporter.addCustomField(node: node, name: "Routing Number", value: routing, detectUrl: false)
        }

        if let swift = string(from: account["swiftCode"]) {
            BaseImporter.addCustomField(node: node, name: "SWIFT", value: swift, detectUrl: false)
        }

        if let notes = string(from: account["notes"]) {
            node.fields.notes = notes
        }

        addTags(from: account["tags"], to: node)
        if isFavorite(account["favorite"]) {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        setDates(on: node, from: account, createdKeys: ["creationDate"], modifiedKeys: ["modificationDate"])
    }

    private func processNote(_ note: [String: Any], database: DatabaseModel, messages: inout [ImportMessage]) {
        guard !isTrashed(note["trashed"]) else {
            messages.append(ImportMessage("Skipped trashed note", .info))
            return
        }

        let title = string(from: note["title"]) ?? "Secure Note"
        let node = Node(asRecord: title, parent: database.effectiveRootGroup, fields: NodeFields(), uuid: nil)
        database.effectiveRootGroup.addChild(node, keePassGroupTitleRules: true)

        if let body = string(from: note["text"]) {
            node.fields.notes = body
        }

        addTags(from: note["tags"], to: node)
        if isFavorite(note["favorite"]) {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        setDates(on: node, from: note, createdKeys: ["creationDate"], modifiedKeys: ["modificationDate"])
    }

    private func addTotp(from dict: [String: Any], label: String, to node: Node) {
        guard let seed = string(from: dict["seed"]) else { return }
        let digits = (dict["digits"] as? NSString)?.integerValue ?? Int((dict["digits"] as? String) ?? "")
        let period = (dict["period"] as? NSString)?.integerValue ?? Int((dict["period"] as? String) ?? "")
        let algorithm = string(from: dict["algorithm"])?.uppercased()

        var components = URLComponents()
        components.scheme = "otpauth"
        components.host = "totp"
        components.path = "/" + (label.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? label)
        var queryItems = [URLQueryItem(name: "secret", value: seed)]
        if let digits = digits { queryItems.append(URLQueryItem(name: "digits", value: "\(digits)")) }
        if let period = period { queryItems.append(URLQueryItem(name: "period", value: "\(period)")) }
        if let algorithm = algorithm { queryItems.append(URLQueryItem(name: "algorithm", value: algorithm)) }
        components.queryItems = queryItems

        if let otpUrl = components.url?.absoluteString {
            BaseImporter.addTotpOrCustom(node: node, name: "TOTP", value: otpUrl)
        }
    }

    private func addServices(from value: Any?, to node: Node) {
        let services = arrayOfDictionaries(from: value, key: "service")
        for service in services {
            if let address = string(from: service["address"]) ?? string(from: service["url"]) {
                if let normalized = normalizedUrl(from: address) {
                    BaseImporter.addUrl(node, normalized)
                }
            }
        }
    }

    private func addTags(from value: Any?, to node: Node) {
        let tagDictionaries = arrayOfDictionaries(from: value, key: "tag")
        if tagDictionaries.isEmpty, let tagStrings = tags(from: value) {
            tagStrings.forEach { node.fields.tags.add($0) }
            return
        }

        for tag in tagDictionaries {
            if let name = string(from: tag["name"]) ?? string(from: tag["_text"]) {
                node.fields.tags.add(name)
            }
        }
    }

    private func isFavorite(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let str = string(from: value) { return str == "1" || str.caseInsensitiveCompare("true") == .orderedSame }
        return false
    }

    private func isTrashed(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let str = string(from: value) { return str == "1" || str.caseInsensitiveCompare("true") == .orderedSame }
        return false
    }

    private func extractItems(from json: Any) -> [[String: Any]] {
        if let list = json as? [[String: Any]] {
            return list
        }

        guard let dict = json as? [String: Any] else {
            return []
        }

        let candidateKeys = ["items", "entries", "secrets", "records", "logins", "objects"]

        for key in candidateKeys {
            if let items = dict[key] as? [[String: Any]] {
                return items
            }
        }

        
        if let vaults = dict["vaults"] as? [[String: Any]] {
            return vaults.flatMap { vault -> [[String: Any]] in
                guard let items = vault["items"] as? [[String: Any]] else { return [] as [[String: Any]] }
                return items.map { item in
                    var combined = item
                    if combined["vault"] == nil, let title = vault["title"] ?? vault["name"] {
                        combined["vault"] = title
                    }
                    return combined
                }
            }
        }

        return []
    }

    private func processItem(_ item: [String: Any],
                             database: DatabaseModel,
                             messages: inout [ImportMessage])
    {
        let title = string(from: item["title"])
            ?? string(from: item["name"])
            ?? string(from: item["label"])
            ?? NSLocalizedString("generic_unknown", comment: "Unknown")

        let parentGroup = group(for: item, database: database) ?? database.effectiveRootGroup
        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: nil)
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let username = firstString(in: item, keys: ["username", "user", "login", "account", "email"]) {
            node.fields.username = username
        }

        if let password = firstString(in: item, keys: ["password", "passcode", "secret"]) {
            node.fields.password = password
        }

        if let notes = firstString(in: item, keys: ["notes", "comment", "description", "remarks"]) {
            node.fields.notes = notes
        }

        addUrls(from: item, to: node)

        if let totp = firstString(in: item, keys: ["otpAuth", "otp", "otpURL", "otpAuthUrl", "totp", "totpUrl", "twoFactor", "twofa"]) {
            BaseImporter.addTotpOrCustom(node: node, name: "TOTP", value: totp)
        }

        if let tags = tags(from: item["tags"]) {
            tags.forEach { node.fields.tags.add($0) }
        }

        if let favorite = item["favorite"] as? Bool, favorite {
            node.fields.tags.add(kCanonicalFavouriteTag)
        } else if let favorite = item["isFavorite"] as? Bool, favorite {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        setDates(on: node, from: item)

        if let customFields = item["fields"] as? [[String: Any]] {
            processFields(customFields, node: node)
        }
    }

    private func addUrls(from item: [String: Any], to node: Node) {
        var urls: [String] = []

        if let url = firstString(in: item, keys: ["url", "website", "loginUrl", "webAddress"]) {
            urls.append(url)
        }

        if let list = item["urls"] as? [Any] {
            for value in list {
                if let urlString = string(from: value) {
                    urls.append(urlString)
                }
            }
        }

        if let domains = item["domains"] as? [Any] {
            for value in domains {
                if let domain = string(from: value) {
                    urls.append(domain)
                }
            }
        }

        for url in urls {
            if let normalized = normalizedUrl(from: url) {
                BaseImporter.addUrl(node, normalized)
            }
        }
    }

    private func processFields(_ fields: [[String: Any]], node: Node) {
        for field in fields {
            guard let rawValue = field["value"] ?? field["string"],
                  let value = string(from: rawValue),
                  !value.isEmpty
            else { continue }

            let label = string(from: field["label"]) ?? string(from: field["name"]) ?? string(from: field["fieldName"])
            let type = string(from: field["type"])?.lowercased() ?? string(from: field["kind"])?.lowercased()

            switch type {
            case let str? where str.contains("user"):
                BaseImporter.addUsernameOrCustom(node: node, name: label, value: value)
            case let str? where str.contains("pass"):
                BaseImporter.addPasswordOrCustom(node: node, name: label, value: value)
            case let str? where str.contains("url") || str.contains("web"):
                if let normalized = normalizedUrl(from: value) {
                    BaseImporter.addUrl(node, normalized, label)
                } else {
                    BaseImporter.addCustomField(node: node, name: label, value: value)
                }
            case let str? where str.contains("otp") || str.contains("totp"):
                BaseImporter.addTotpOrCustom(node: node, name: label, value: value)
            case let str? where str.contains("note"):
                node.fields.notes = node.fields.notes.appending(value.isEmpty ? "" : (node.fields.notes.isEmpty ? value : "\n\n" + value))
            default:
                if label?.localizedCaseInsensitiveContains("otp") == true {
                    BaseImporter.addTotpOrCustom(node: node, name: label, value: value)
                } else if label?.localizedCaseInsensitiveContains("url") == true, let normalized = normalizedUrl(from: value) {
                    BaseImporter.addUrl(node, normalized, label)
                } else {
                    BaseImporter.addCustomField(node: node, name: label, value: value)
                }
            }
        }
    }

    private func group(for item: [String: Any], database: DatabaseModel) -> Node? {
        var components: [String] = []

        if let vault = string(from: item["vault"]) {
            components.append(vault)
        }
        if let collection = string(from: item["collection"]) ?? string(from: item["folder"]) ?? string(from: item["group"]) ?? string(from: item["category"]) {
            components.append(collection)
        }

        guard !components.isEmpty else { return nil }
        return BaseImporter.getOrCreateGroup(database, components, nil)
    }

    private func setDates(on node: Node, from item: [String: Any], createdKeys: [String] = ["created", "createdAt", "created_at"], modifiedKeys: [String] = ["updated", "updatedAt", "modified", "modifiedAt"]) {
        let created = createdKeys.compactMap { date(from: item[$0]) }.first
        let modified = modifiedKeys.compactMap { date(from: item[$0]) }.first

        if created != nil || modified != nil {
            node.fields.setTouchPropertiesWithCreated(created,
                                                      accessed: nil,
                                                      modified: modified,
                                                      locationChanged: nil,
                                                      usageCount: nil)
        }
    }

    private func string(from value: Any?) -> String? {
        if let str = value as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let dict = value as? [String: Any] {
            return string(from: dict["_text"])
        }
        if let num = value as? NSNumber {
            return num.stringValue
        }
        return nil
    }

    private func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key], let str = string(from: value) {
                return str
            }
        }
        return nil
    }

    private func tags(from value: Any?) -> [String]? {
        if let list = value as? [String] {
            return list
        }
        if let list = value as? [Any] {
            return list.compactMap { string(from: $0) }
        }
        if let str = string(from: value) {
            return str.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return nil
    }

    private func normalizedUrl(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }

        if let url = URL(string: "https://" + trimmed) {
            return url.absoluteString
        }

        return nil
    }

    private func date(from value: Any?) -> Date? {
        guard let str = string(from: value) else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso.date(from: str) {
            return date
        }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: str) {
            return date
        }

        return nil
    }
}
