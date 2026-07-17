import Foundation
import Zip

class ProtonPassImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["zip", "json"]

    private let nestedContainerKeys = ["content", "data", "details", "value", "login", "properties", "metadata"]
    private var vaultGroups: [String: Node] = [:]

    func convert(url: URL) throws -> DatabaseModel {
        let result = try convertEx(url: url)
        return result.database
    }

    func convertEx(url: URL) throws -> ImportResult {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        vaultGroups = [:]
        var messages: [ImportMessage] = []

        if url.pathExtension.lowercased() == "zip" {
            let unzipRoot = try Zip.unzipUrlToUniqueDirectory(url: url)
            defer { try? FileManager.default.removeItem(at: unzipRoot) }

            let jsonFiles = collectJsonFiles(root: unzipRoot)

            if jsonFiles.isEmpty {
                messages.append(ImportMessage("No JSON files found in Proton Pass export", .warning))
            }

            for jsonUrl in jsonFiles {
                let data = try Data(contentsOf: jsonUrl)
                try processExport(data: data,
                                  sourceUrl: jsonUrl,
                                  exportRoot: unzipRoot,
                                  database: database,
                                  messages: &messages)
            }
        } else {
            let data = try Data(contentsOf: url)
            try processExport(data: data,
                              sourceUrl: url,
                              exportRoot: url.deletingLastPathComponent(),
                              database: database,
                              messages: &messages)
        }

        if database.effectiveRootGroup.childRecords.count == 0,
           database.effectiveRootGroup.childGroups.count == 0
        {
            messages.append(ImportMessage("No records imported", .warning))
        }

        return ImportResult(database: database, messages: messages)
    }

    private func collectJsonFiles(root: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root,
                                                               includingPropertiesForKeys: nil)
        else {
            return []
        }

        var urls: [URL] = []

        for case let url as URL in enumerator {
            if url.pathExtension.lowercased() == "json" {
                urls.append(url)
            }
        }

        return urls
    }

    private func processExport(data: Data,
                               sourceUrl: URL?,
                               exportRoot: URL?,
                               database: DatabaseModel,
                               messages: inout [ImportMessage]) throws
    {
        guard !data.isEmpty else {
            messages.append(ImportMessage("Encountered empty Proton Pass export file", .warning))
            return
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])

        if let dict = jsonObject as? [String: Any] {
            processRootDictionary(dict,
                                  parentGroup: database.effectiveRootGroup,
                                  database: database,
                                  sourceUrl: sourceUrl,
                                  exportRoot: exportRoot,
                                  messages: &messages)
        } else if let array = jsonObject as? [[String: Any]] {
            processItems(array,
                         parent: database.effectiveRootGroup,
                         vaultContext: nil,
                         database: database,
                         sourceUrl: sourceUrl,
                         exportRoot: exportRoot,
                         messages: &messages)
        } else {
            messages.append(ImportMessage("Unrecognized Proton Pass export structure", .warning))
        }
    }

    private func processRootDictionary(_ dict: [String: Any],
                                       parentGroup: Node,
                                       database: DatabaseModel,
                                       sourceUrl: URL?,
                                       exportRoot: URL?,
                                       messages: inout [ImportMessage])
    {
        var handled = false

        let vaultCandidates = extractDictionaryArrays(dict, keys: ["vaults", "Vaults", "shares", "Shares"])
        if !vaultCandidates.isEmpty {
            handled = true

            for vaultArray in vaultCandidates {
                for vaultDict in vaultArray {
                    processVault(vaultDict,
                                 parentGroup: parentGroup,
                                 database: database,
                                 sourceUrl: sourceUrl,
                                 exportRoot: exportRoot,
                                 messages: &messages)
                }
            }
        }
        
        if vaultCandidates.isEmpty {
            if let vaults = dict["vaults"] as? [String: Any], !vaults.isEmpty {
                handled = true

                for case let vault as [String: Any] in vaults.values {
                    processVault(vault,
                                 parentGroup: parentGroup,
                                 database: database,
                                 sourceUrl: sourceUrl,
                                 exportRoot: exportRoot,
                                 messages: &messages)
                }
            }
        }

        let directItems = extractDictionaryArrays(dict, keys: ["items", "Items", "entries", "Entries"])
        if !directItems.isEmpty {
            handled = true
            for items in directItems {
                processItems(items,
                             parent: parentGroup,
                             vaultContext: vaultContext(from: dict, database: database),
                             database: database,
                             sourceUrl: sourceUrl,
                             exportRoot: exportRoot,
                             messages: &messages)
            }
        }

        let nestedKeys = ["data", "export", "payload", "content", "result"]
        for key in nestedKeys {
            if let nested = dict[key] as? [String: Any] {
                handled = true
                processRootDictionary(nested,
                                      parentGroup: parentGroup,
                                      database: database,
                                      sourceUrl: sourceUrl,
                                      exportRoot: exportRoot,
                                      messages: &messages)
            }
        }

        if !handled, let items = dict["items"] as? [[String: Any]] {
            processItems(items,
                         parent: parentGroup,
                         vaultContext: vaultContext(from: dict, database: database),
                         database: database,
                         sourceUrl: sourceUrl,
                         exportRoot: exportRoot,
                         messages: &messages)
        }
    }

    private func processVault(_ vaultDict: [String: Any],
                              parentGroup: Node,
                              database: DatabaseModel,
                              sourceUrl: URL?,
                              exportRoot: URL?,
                              messages: inout [ImportMessage])
    {
        let vaultName = firstString(in: [vaultDict], keys: ["vaultName", "name", "displayName", "label", "vault", "title"]) ?? NSLocalizedString("generic_unknown", comment: "Unknown")

        let group = ensureVaultGroup(name: vaultName, database: database)

        let items = extractDictionaryArrays(vaultDict, keys: ["items", "Items", "entries", "Entries"])
        if items.isEmpty {
            messages.append(ImportMessage(String(format: "Vault '%@' contained no items", vaultName), .info))
            return
        }

        for item in items {
            processItems(item,
                         parent: group,
                         vaultContext: group,
                         database: database,
                         sourceUrl: sourceUrl,
                         exportRoot: exportRoot,
                         messages: &messages)
        }
    }

    private func processItems(_ items: [[String: Any]],
                              parent: Node,
                              vaultContext: Node?,
                              database: DatabaseModel,
                              sourceUrl: URL?,
                              exportRoot: URL?,
                              messages: inout [ImportMessage])
    {
        for item in items {
            processItem(item,
                        parent: parent,
                        vaultContext: vaultContext,
                        database: database,
                        sourceUrl: sourceUrl,
                        exportRoot: exportRoot,
                        messages: &messages)
        }
    }

    private func processItem(_ item: [String: Any],
                             parent: Node,
                             vaultContext: Node?,
                             database: DatabaseModel,
                             sourceUrl: URL?,
                             exportRoot: URL?,
                             messages: inout [ImportMessage])
    {
        let containers = collectContainers(from: item)

        let title = firstString(in: containers, keys: ["name", "title", "itemName", "displayName"]) ?? NSLocalizedString("generic_unknown", comment: "Unknown")
        let uuidString = firstString(in: containers, keys: ["itemUuid", "uuid", "id", "itemId"])
        let uuid = uuidString.flatMap { UUID(uuidString: $0) } ?? UUID()

        let parentGroup = determineParentGroup(for: item,
                                               containers: containers,
                                               baseGroup: vaultContext ?? parent,
                                               database: database)

        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: uuid)

        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let note = firstString(in: containers, keys: ["note", "notes", "description"]) {
            node.fields.notes = note
        }

        if let favorite = firstBool(in: containers, keys: ["favorite", "favourite", "starred", "isFavorite", "isStarred"]) , favorite {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        let tagValues = collectStrings(in: containers, keys: ["tags", "labels", "categories", "groups"])
        for tag in tagValues where !tag.isEmpty {
            node.fields.tags.add(tag)
        }

        if let created = firstDate(in: containers, keys: ["createdAt", "creationTime", "created", "ctime", "addedAt"]) {
            node.fields.setTouchPropertiesWithCreated(created,
                                                      accessed: nil,
                                                      modified: nil,
                                                      locationChanged: nil,
                                                      usageCount: nil)
        }

        if let modified = firstDate(in: containers, keys: ["updatedAt", "modifiedAt", "lastModified", "mtime", "revisionTime", "updated"]) {
            node.setModifiedDateExplicit(modified, setParents: false)
        }

        if let trashed = firstBool(in: containers, keys: ["trashed", "deleted", "isDeleted", "archived"]) , trashed {
            database.recycleItems([node])
        }

        let type = firstString(in: containers, keys: ["itemType", "type", "category", "kind"])?.lowercased()

        switch type {
        case .some(let value) where value.contains("login"):
            processLogin(node: node, containers: containers)
        case .some(let value) where value.contains("card"):
            processCard(node: node, containers: containers)
        case .some(let value) where value.contains("note"):
            processSecureNote(node: node, containers: containers)
        case .some(let value) where value.contains("alias"):
            processAlias(node: node, containers: containers)
        default:
            processGenericItem(node: node, containers: containers)
        }

        processFields(node: node, containers: containers)
        processAttachments(node: node,
                           containers: containers,
                           sourceUrl: sourceUrl,
                           exportRoot: exportRoot,
                           messages: &messages)
        processHistory(node: node, containers: containers)
    }

    private func processLogin(node: Node, containers: [[String: Any]]) {
        if let username = firstString(in: containers, keys: ["username", "userName", "login", "loginName", "email", "itemEmail", "itemUsername"]) {
            node.fields.username = username
        }

        if let email = firstString(in: containers, keys: ["itemEmail", "email"]) {
            BaseImporter.addEmailOrCustom(node: node, name: "Email", value: email)
        }

        if let password = firstString(in: containers, keys: ["password", "pass", "secret", "loginPassword"]) {
            node.fields.password = password
        }

        if let totp = firstString(in: containers, keys: ["totp", "totpUri", "otp", "otpUri", "twoFactor", "twoFactorUri"]) {
            BaseImporter.addTotpOrCustom(node: node, name: "TOTP", value: totp)
        }

        let urls = collectStrings(in: containers, keys: ["urls", "uris", "url", "domain", "domains", "websites", "website"])
        for url in urls {
            BaseImporter.addUrl(node, url)
        }
    }

    private func processCard(node: Node, containers: [[String: Any]]) {
        if let name = firstString(in: containers, keys: ["cardholderName", "holderName", "owner"]) {
            BaseImporter.addUsernameOrCustom(node: node, name: "Cardholder", value: name)
        }

        if let number = firstString(in: containers, keys: ["number", "cardNumber"]) {
            BaseImporter.addCustomField(node: node, name: "Card Number", value: number, protected: true)
        }

        if let verification = firstString(in: containers, keys: ["verificationNumber", "cvv", "cvc", "securityCode"]) {
            BaseImporter.addCustomField(node: node, name: "Security Code", value: verification, protected: true)
        }

        if let expMonth = firstString(in: containers, keys: ["expiryMonth", "expMonth"]) , let expYear = firstString(in: containers, keys: ["expiryYear", "expYear"]) {
            BaseImporter.addCustomField(node: node,
                                        name: "Expiry",
                                        value: String(format: "%@/%@", expMonth, expYear))
        }

        if let brand = firstString(in: containers, keys: ["brand", "network"]) {
            BaseImporter.addCustomField(node: node, name: "Brand", value: brand)
        }

        if let address = firstDictionary(in: containers, keys: ["billingAddress", "address"]) {
            let addressString = address.map { key, value in
                return "\(key.capitalized): \(stringFromAny(value) ?? "")"
            }
            .sorted()
            .joined(separator: "\n")

            if !addressString.isEmpty {
                BaseImporter.addCustomField(node: node, name: "Billing Address", value: addressString)
            }
        }
    }

    private func processSecureNote(node: Node, containers: [[String: Any]]) {
        if let text = firstString(in: containers, keys: ["text", "content", "body"]) {
            node.fields.notes = text
        }
    }

    private func processAlias(node: Node, containers: [[String: Any]]) {
        if let alias = firstString(in: containers, keys: ["alias", "aliasEmail", "email", "address"]) {
            BaseImporter.addEmailOrCustom(node: node, name: "Alias", value: alias)
        }

        processGenericItem(node: node, containers: containers)
    }

    private func processGenericItem(node: Node, containers: [[String: Any]]) {
        if let username = firstString(in: containers, keys: ["username", "user", "owner", "itemUsername"]) , node.fields.username.isEmpty {
            node.fields.username = username
        }

        if let password = firstString(in: containers, keys: ["password", "pass", "secret"]) , node.fields.password.isEmpty {
            node.fields.password = password
        }

        if let email = firstString(in: containers, keys: ["itemEmail", "email"]) {
            BaseImporter.addEmailOrCustom(node: node, name: "Email", value: email)
        }

        if let totp = firstString(in: containers, keys: ["totp", "totpUri", "otp", "otpUri"]) {
            BaseImporter.addTotpOrCustom(node: node, name: "TOTP", value: totp)
        }

        let urls = collectStrings(in: containers, keys: ["urls", "url", "link", "links"])
        for url in urls {
            BaseImporter.addUrl(node, url)
        }
    }

    private func processFields(node: Node, containers: [[String: Any]]) {
        let fieldKeys = ["fields", "customFields", "extraFields", "sections", "properties", "details", "attributes"]

        for container in containers {
            for key in fieldKeys {
                guard let array = container[key] else { continue }

                if let dict = array as? [String: Any] {
                    applyFieldDictionary(dict, to: node)
                } else if let list = array as? [Any] {
                    for element in list {
                        if let field = element as? [String: Any] {
                            applyFieldDictionary(field, to: node)
                        }
                    }
                }
            }
        }
    }

    private func applyFieldDictionary(_ field: [String: Any], to node: Node) {
        let type = firstString(in: [field], keys: ["type", "fieldType", "kind", "category"])?.lowercased()
        let label = firstString(in: [field], keys: ["label", "name", "fieldName", "title", "key"])
        let value = stringFromAny(field["value"] ?? field["text"] ?? field["content"] ?? field["string"] ?? field["data"])
        let isProtected = firstBool(in: [field], keys: ["protected", "isProtected", "secret", "concealed", "hidden"]) ?? (type?.contains("hidden") ?? false)

        guard let value else { return }

        let normalizedLabel = label?.lowercased()

        if type?.contains("username") == true || normalizedLabel?.contains("username") == true {
            BaseImporter.addUsernameOrCustom(node: node, name: label, value: value)
        } else if type?.contains("password") == true || normalizedLabel == "password" {
            BaseImporter.addPasswordOrCustom(node: node, name: label, value: value)
        } else if type?.contains("email") == true || normalizedLabel == "email" {
            BaseImporter.addEmailOrCustom(node: node, name: label, value: value)
        } else if type?.contains("otp") == true || type?.contains("totp") == true || normalizedLabel?.contains("otp") == true {
            BaseImporter.addTotpOrCustom(node: node, name: label ?? "TOTP", value: value)
        } else if type?.contains("url") == true || type?.contains("uri") == true || normalizedLabel?.contains("url") == true {
            BaseImporter.addUrl(node, value, label)
        } else {
            BaseImporter.addCustomField(node: node, name: label, value: value, protected: isProtected)
        }
    }

    private func processAttachments(node: Node,
                                    containers: [[String: Any]],
                                    sourceUrl: URL?,
                                    exportRoot: URL?,
                                    messages: inout [ImportMessage])
    {
        let attachmentKeys = ["attachments", "files", "documents"]

        for container in containers {
            for key in attachmentKeys {
                guard let attachmentsAny = container[key] else { continue }

                let attachments: [[String: Any]]
                if let dict = attachmentsAny as? [String: Any] {
                    attachments = [dict]
                } else if let list = attachmentsAny as? [Any] {
                    attachments = list.compactMap { $0 as? [String: Any] }
                } else {
                    continue
                }

                for attachment in attachments {
                    let name = firstString(in: [attachment], keys: ["name", "fileName", "filename", "title"])

                    if let base64 = firstString(in: [attachment], keys: ["data", "content", "base64", "payload"]) {
                        do {
                            try BaseImporter.addAttachment(node: node, name: name, base64Data: base64)
                        } catch {
                            messages.append(ImportMessage(String(format: "Failed to decode attachment for '%@'", node.title), .warning))
                        }
                        continue
                    }

                    if let pathString = firstString(in: [attachment], keys: ["path", "filePath", "relativePath", "location"]) {
                        let trimmed = pathString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        let candidateUrls = [sourceUrl?.deletingLastPathComponent().appendingPathComponent(trimmed),
                                             exportRoot?.appendingPathComponent(trimmed)]

                        var added = false
                        for candidate in candidateUrls.compactMap({ $0 }) {
                            if FileManager.default.fileExists(atPath: candidate.path) {
                                if let data = try? Data(contentsOf: candidate) {
                                    BaseImporter.addAttachment(node: node,
                                                               name: name ?? candidate.lastPathComponent,
                                                               data: data)
                                    added = true
                                    break
                                }
                            }
                        }

                        if !added {
                            messages.append(ImportMessage(String(format: "Attachment file not found for '%@'", node.title), .warning))
                        }
                    }
                }
            }
        }
    }

    private func processHistory(node: Node, containers: [[String: Any]]) {
        let historyKeys = ["history", "passwordHistory", "previousPasswords"]

        for container in containers {
            for key in historyKeys {
                guard let historyAny = container[key] else { continue }

                let entries: [[String: Any]]
                if let dict = historyAny as? [String: Any] {
                    entries = [dict]
                } else if let list = historyAny as? [Any] {
                    entries = list.compactMap { $0 as? [String: Any] }
                } else {
                    continue
                }

                for entry in entries {
                    guard let password = firstString(in: [entry], keys: ["password", "value", "secret"]) else {
                        continue
                    }

                    let modified = firstDate(in: [entry], keys: ["modifiedAt", "updatedAt", "timestamp", "time"]) ?? Date()
                    BaseImporter.addHistoricalPasswordEntry(node, password, modified)
                }
            }
        }
    }

    private func ensureVaultGroup(name: String, database: DatabaseModel) -> Node {
        if let existing = vaultGroups[name] {
            return existing
        }

        if let group = BaseImporter.getOrCreateGroup(database, [name], nil) {
            vaultGroups[name] = group
            return group
        }

        return database.effectiveRootGroup
    }

    private func vaultContext(from dict: [String: Any], database: DatabaseModel) -> Node? {
        if let name = firstString(in: [dict], keys: ["vaultName", "name", "title"]) {
            return ensureVaultGroup(name: name, database: database)
        }
        return nil
    }

    private func determineParentGroup(for item: [String: Any],
                                       containers: [[String: Any]],
                                       baseGroup: Node,
                                       database: DatabaseModel) -> Node {
        let folderCandidates = collectStrings(in: containers + [item], keys: ["folders", "folder", "folderPath", "collections", "collectionPath", "path"])

        guard let folderPath = folderCandidates.first else {
            return baseGroup
        }

        let sanitized = folderPath.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        guard !sanitized.isEmpty else {
            return baseGroup
        }

        var components: [String] = []
        components.append(baseGroup.title)
        components.append(contentsOf: sanitized)

        return BaseImporter.getOrCreateGroup(database, components, nil) ?? baseGroup
    }

    private func extractDictionaryArrays(_ dict: [String: Any], keys: [String]) -> [[[String: Any]]] {
        var result: [[[String: Any]]] = []

        for key in keys {
            if let array = dict[key] as? [[String: Any]] {
                result.append(array)
            } else if let list = dict[key] as? [Any] {
                let dictionaries = list.compactMap { $0 as? [String: Any] }
                if !dictionaries.isEmpty {
                    result.append(dictionaries)
                }
            }
        }

        return result
    }

    private func firstDictionary(in containers: [[String: Any]], keys: [String]) -> [String: Any]? {
        for container in containers {
            for key in keys {
                if let dict = container[key] as? [String: Any] {
                    return dict
                }
            }
        }
        return nil
    }

    private func firstString(in containers: [[String: Any]], keys: [String]) -> String? {
        for container in containers {
            for key in keys {
                if let value = container[key] as? String, !value.isEmpty {
                    return value
                }
                if let value = container[key] as? NSNumber {
                    return value.stringValue
                }
            }
        }
        return nil
    }

    private func firstBool(in containers: [[String: Any]], keys: [String]) -> Bool? {
        for container in containers {
            for key in keys {
                if let value = container[key] as? Bool {
                    return value
                }
                if let value = container[key] as? NSNumber {
                    return value.boolValue
                }
                if let value = container[key] as? String {
                    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if ["true", "yes", "1"].contains(normalized) {
                        return true
                    }
                    if ["false", "no", "0"].contains(normalized) {
                        return false
                    }
                }
            }
        }
        return nil
    }

    private func firstDate(in containers: [[String: Any]], keys: [String]) -> Date? {
        for container in containers {
            for key in keys {
                if let value = container[key] {
                    if let date = dateFromAny(value) {
                        return date
                    }
                }
            }
        }
        return nil
    }

    private func collectStrings(in containers: [[String: Any]], keys: [String]) -> [String] {
        var values: [String] = []

        for container in containers {
            for key in keys {
                if let str = container[key] as? String {
                    if !str.isEmpty {
                        values.append(str)
                    }
                } else if let arr = container[key] as? [String] {
                    values.append(contentsOf: arr.filter { !$0.isEmpty })
                } else if let arr = container[key] as? [Any] {
                    for element in arr {
                        if let str = element as? String, !str.isEmpty {
                            values.append(str)
                        }
                    }
                }
            }
        }

        return values
    }

    private func collectContainers(from item: [String: Any]) -> [[String: Any]] {
        var containers: [[String: Any]] = []
        var queue: [[String: Any]] = [item]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            containers.append(current)

            for key in nestedContainerKeys {
                if let dict = current[key] as? [String: Any] {
                    queue.append(dict)
                }
            }
        }

        return containers
    }

    private func dateFromAny(_ value: Any) -> Date? {
        if let date = value as? Date {
            return date
        }

        if let number = value as? NSNumber {
            let interval = number.doubleValue
            if interval > 9_999_999_999 { 
                return Date(timeIntervalSince1970: interval / 1000.0)
            }
            if interval > 0 {
                return Date(timeIntervalSince1970: interval)
            }
        }

        if let str = value as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return nil
            }

            if let number = Double(trimmed) {
                if number > 9_999_999_999 {
                    return Date(timeIntervalSince1970: number / 1000.0)
                }
                return Date(timeIntervalSince1970: number)
            }

            if let date = ProtonPassImporter.iso8601WithFractional.date(from: trimmed) {
                return date
            }

            if let date = ProtonPassImporter.iso8601.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private func stringFromAny(_ value: Any?) -> String? {
        guard let value else { return nil }

        if let str = value as? String {
            return str.isEmpty ? nil : str
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let dict = value as? [String: Any] {
            if let direct = dict["value"] ?? dict["text"] ?? dict["string"] ?? dict["data"] ?? dict["uri"] ?? dict["url"] {
                return stringFromAny(direct)
            }

            let flattened = dict
                .map { key, value -> String? in
                    guard let string = stringFromAny(value) else { return nil }
                    return "\(key.capitalized): \(string)"
                }
                .compactMap { $0 }
                .sorted()
                .joined(separator: "\n")

            return flattened.isEmpty ? nil : flattened
        }

        if let array = value as? [Any] {
            let strings = array.compactMap { stringFromAny($0) }
            if strings.isEmpty {
                return nil
            }
            return strings.joined(separator: ", ")
        }

        return nil
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
        return formatter
    }()

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withColonSeparatorInTime, .withColonSeparatorInTimeZone]
        return formatter
    }()
}
