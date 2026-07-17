import Foundation

class MinimalistImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["json"]

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
            messages.append(ImportMessage("Encountered empty Minimalist export file", .warning))
            return ImportResult(database: database, messages: messages)
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = jsonObject as? [String: Any] else {
            messages.append(ImportMessage("Unrecognized Minimalist export structure", .warning))
            return ImportResult(database: database, messages: messages)
        }

        if let attachments = dict["attachments"] as? [Any], !attachments.isEmpty {
            messages.append(ImportMessage("Minimalist export contained attachments which are not imported automatically.", .info))
        }

        guard let items = dict["items"] as? [[String: Any]], !items.isEmpty else {
            messages.append(ImportMessage("No records found in Minimalist export", .warning))
            return ImportResult(database: database, messages: messages)
        }

        for item in items {
            processItem(item, database: database, messages: &messages)
        }

        if database.effectiveRootGroup.childRecords.isEmpty,
           database.effectiveRootGroup.childGroups.isEmpty
        {
            messages.append(ImportMessage("No records imported", .warning))
        }

        return ImportResult(database: database, messages: messages)
    }

    private func processItem(_ item: [String: Any],
                             database: DatabaseModel,
                             messages: inout [ImportMessage])
    {
        let title = stringFromAny(item["title"]) ?? NSLocalizedString("generic_unknown", comment: "Unknown")
        let uuid = stringFromAny(item["id"]).flatMap { UUID(uuidString: $0) } ?? UUID()

        let group = database.effectiveRootGroup
        let node = Node(asRecord: title, parent: group, fields: NodeFields(), uuid: uuid)
        group.addChild(node, keePassGroupTitleRules: true)

        if let username = stringFromAny(item["username"]) {
            node.fields.username = username
        }

        if let password = stringFromAny(item["password"]) {
            node.fields.password = password
        }

        if let notes = stringFromAny(item["notes"]) {
            node.fields.notes = notes
        }

        if let website = stringFromAny(item["website"]),
           let url = normalizedUrl(from: website)
        {
            BaseImporter.addUrl(node, url)
        }

        if let services = item["serviceIdentifiers"] as? [[String: Any]] {
            addServiceIdentifiers(services, to: node)
        }

        if let favorite = item["isFavorite"] as? Bool, favorite {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        if let tagText = stringFromAny(item["tagText"]) {
            for tag in tags(from: tagText) {
                node.fields.tags.add(tag)
            }
        }

        if let created = dateFromAny(item["createdAt"]) {
            node.fields.setTouchPropertiesWithCreated(created,
                                                      accessed: nil,
                                                      modified: nil,
                                                      locationChanged: nil,
                                                      usageCount: nil)
        }

        if let modified = dateFromAny(item["modifiedAt"]) {
            node.setModifiedDateExplicit(modified, setParents: false)
        }

        if dateFromAny(item["archivedAt"]) != nil {
            database.recycleItems([node])
        }

        if let totp = stringFromAny(item["totpSecretKey"]) {
            addTotp(node: node, value: totp, label: "TOTP")
        }

        if let previousTotp = item["previousTOTPSecretKeys"] as? [Any] {
            for (index, value) in previousTotp.enumerated() {
                guard let totpValue = stringFromAny(value) else { continue }
                let label = String(format: NSLocalizedString("minimalist_previous_totp_format", comment: "Previous TOTP %d"), index + 1)
                addTotp(node: node, value: totpValue, label: label)
            }
        }

        let sections = sectionTitles(from: item["sections"] as? [[String: Any]] ?? [])
        processFields(item["fields"] as? [[String: Any]] ?? [],
                      sections: sections,
                      node: node)

        if let history = item["previousPasswords"] as? [[String: Any]] {
            addPasswordHistory(history, to: node)
        }
    }

    private func addServiceIdentifiers(_ list: [[String: Any]], to node: Node) {
        for entry in list {
            guard let identifier = stringFromAny(entry["identifier"]) else { continue }
            let label = stringFromAny(entry["label"])
            if let url = normalizedUrl(from: identifier) {
                BaseImporter.addUrl(node, url, label)
            } else {
                BaseImporter.addCustomField(node: node, name: label ?? "Service Identifier", value: identifier)
            }
        }
    }

    private func processFields(_ fields: [[String: Any]],
                               sections: [String: String],
                               node: Node)
    {
        for field in fields {
            guard let rawValue = field["value"], let value = stringFromAny(rawValue), !value.isEmpty else {
                continue
            }

            let category = stringFromAny(field["category"])?.lowercased() ?? ""
            let label = label(for: field, sections: sections)
            let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if category.contains("otp") || isTotpValue(normalizedValue) || (label?.localizedCaseInsensitiveContains("otp") ?? false) {
                addTotp(node: node, value: normalizedValue, label: label ?? "TOTP")
                continue
            }

            switch category {
            case "username":
                BaseImporter.addUsernameOrCustom(node: node, name: label, value: normalizedValue)
            case "password":
                BaseImporter.addPasswordOrCustom(node: node, name: label, value: normalizedValue)
            case "email":
                BaseImporter.addEmailOrCustom(node: node, name: label, value: normalizedValue)
            case "url":
                if let url = normalizedUrl(from: normalizedValue) {
                    BaseImporter.addUrl(node, url, label)
                } else {
                    BaseImporter.addCustomField(node: node, name: label, value: normalizedValue)
                }
            default:
                if category == "phone" || (label?.localizedCaseInsensitiveContains("phone") ?? false) {
                    BaseImporter.addCustomField(node: node, name: label ?? "Phone", value: normalizedValue)
                } else if category == "address" {
                    BaseImporter.addCustomField(node: node, name: label ?? "Address", value: normalizedValue)
                } else if label?.localizedCaseInsensitiveContains("username") == true {
                    BaseImporter.addUsernameOrCustom(node: node, name: label, value: normalizedValue)
                } else if label?.localizedCaseInsensitiveContains("password") == true {
                    BaseImporter.addPasswordOrCustom(node: node, name: label, value: normalizedValue)
                } else {
                    BaseImporter.addCustomField(node: node, name: label, value: normalizedValue)
                }
            }
        }
    }

    private func addPasswordHistory(_ entries: [[String: Any]], to node: Node) {
        for history in entries {
            guard let password = stringFromAny(history["password"]) else { continue }
            let timestamp = dateFromAny(history["replacedAt"]) ?? Date()
            BaseImporter.addHistoricalPasswordEntry(node, password, timestamp)
        }
    }

    private func sectionTitles(from sections: [[String: Any]]) -> [String: String] {
        var map: [String: String] = [:]

        for section in sections {
            guard let identifier = stringFromAny(section["id"]) else { continue }
            if let title = stringFromAny(section["title"]), !title.isEmpty {
                map[identifier] = title
            }
        }

        return map
    }

    private func label(for field: [String: Any], sections: [String: String]) -> String? {
        let fieldTitle = stringFromAny(field["title"])
        if let sectionID = stringFromAny(field["sectionID"]),
           let sectionTitle = sections[sectionID], !sectionTitle.isEmpty
        {
            if let fieldTitle, !fieldTitle.isEmpty {
                return "\(sectionTitle) - \(fieldTitle)"
            }
            return sectionTitle
        }

        return fieldTitle
    }

    private func addTotp(node: Node, value: String, label: String?) {
        guard !value.isEmpty else { return }
        let name = (label?.isEmpty == false) ? label! : "TOTP"
        BaseImporter.addTotpOrCustom(node: node, name: name, value: value)
    }

    private func normalizedUrl(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return trimmed
        }

        if let url = URL(string: "https://\(trimmed)"), url.host != nil {
            return url.absoluteString
        }

        return trimmed
    }

    private func dateFromAny(_ value: Any?) -> Date? {
        guard let value else { return nil }

        if let date = value as? Date {
            return date
        }

        if let number = value as? NSNumber {
            let interval = number.doubleValue
            if interval > 9_999_999_999 {
                return Date(timeIntervalSince1970: interval / 1000.0)
            }
            return Date(timeIntervalSince1970: interval)
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let numeric = Double(trimmed) {
                if numeric > 9_999_999_999 {
                    return Date(timeIntervalSince1970: numeric / 1000.0)
                }
                return Date(timeIntervalSince1970: numeric)
            }

            if let date = MinimalistImporter.iso8601WithFractional.date(from: trimmed) {
                return date
            }

            if let date = MinimalistImporter.iso8601.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private func stringFromAny(_ value: Any?) -> String? {
        guard let value else { return nil }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        if let dict = value as? [String: Any] {
            if let direct = dict["value"] ?? dict["text"] ?? dict["string"] ?? dict["data"] ?? dict["uri"] ?? dict["url"] {
                return stringFromAny(direct)
            }

            let flattened = dict.compactMap { key, value -> String? in
                guard let string = stringFromAny(value) else { return nil }
                return "\(key.capitalized): \(string)"
            }
            .sorted()
            .joined(separator: "\n")

            return flattened.isEmpty ? nil : flattened
        }

        if let array = value as? [Any] {
            let strings = array.compactMap { stringFromAny($0) }
            guard !strings.isEmpty else { return nil }
            return strings.joined(separator: ", ")
        }

        return nil
    }

    private func tags(from text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;")
        return text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static let minimumTotpSecretLength = 16

    private func isTotpValue(_ value: String) -> Bool {
        if value.lowercased().hasPrefix("otpauth://") {
            return true
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= Self.minimumTotpSecretLength else { return false }

        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567=")
        return trimmed.rangeOfCharacter(from: allowed.inverted) == nil
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
