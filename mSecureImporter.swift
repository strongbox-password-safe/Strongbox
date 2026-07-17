import Foundation

private enum MSecureCategory {
    case login
    case card
    case note
}

@objcMembers
class MSecureImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["csv"]

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

        guard let rows = NSArray(contentsOfCSVURL: url, options: [.sanitizesFields]) as? [[String]] else {
            throw CsvGenericImporterError.errorParsing(details: "Could not read any rows from file")
        }

        guard !rows.isEmpty else {
            throw CsvGenericImporterError.errorParsing(details: NSLocalizedString("mac_csv_file_contains_zero_rows", comment: "CSV File Contains Zero Rows. Cannot Import."))
        }

        for row in rows {
            processRow(row, database: database)
        }

        if database.effectiveRootGroup.childRecords.isEmpty, database.effectiveRootGroup.childGroups.isEmpty {
            messages.append(ImportMessage("No records imported", .warning))
        }

        return ImportResult(database: database, messages: messages)
    }

    private func processRow(_ row: [String], database: DatabaseModel) {
        guard row.count >= 3 else {
            return
        }

        let category = trimmed(row[safe: 1]) ?? ""
        let entryType = classify(category: category)

        let baseTitle = trimmed(row[safe: 0]?.split(separator: "|").first.map(String.init)) ?? "--"
        var title = baseTitle

        if entryType == .note, !category.isEmpty {
            title = "\(category): \(baseTitle)"
        }

        let folderName = normalizedFolderName(row[safe: 2])
        let parentGroup = folderName.flatMap { BaseImporter.getOrCreateGroup(database, [$0], nil) } ?? database.effectiveRootGroup

        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: nil)

        parentGroup.addChild(node, keePassGroupTitleRules: true)

        switch entryType {
        case .login:
            processLogin(row: row, node: node)
        case .card:
            processCard(row: row, node: node)
        case .note:
            processNote(row: row, node: node)
        }
    }

    private func processLogin(row: [String], node: Node) {
        if let username = splitValueRetainingLastPart(row[safe: 5])?.nonEmpty {
            node.fields.username = username
        }

        if let url = splitValueRetainingLastPart(row[safe: 4])?.nonEmpty {
            BaseImporter.addUrl(node, url)
        }

        if let password = splitValueRetainingLastPart(row[safe: 6])?.nonEmpty {
            node.fields.password = password
        }

        if let notes = trimmed(row[safe: 3])?.replacingOccurrences(of: "\\n", with: "\n"), !notes.isEmpty {
            node.fields.notes = notes
        }
    }

    private func processCard(row: [String], node: Node) {
        if let number = splitValueRetainingLastPart(row[safe: 4])?.nonEmpty {
            BaseImporter.addCustomField(node: node, name: "Number", value: number)
        }

        if let expiry = splitValueRetainingLastPart(row[safe: 5])?.nonEmpty {
            let components = expiry.split(separator: "/", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if components.count == 2 {
                let month = components[0]
                let year = components[1]
                if !month.isEmpty || !year.isEmpty {
                    BaseImporter.addCustomField(node: node, name: "Expires", value: "\(month)/\(year)")
                }
            } else if let single = components.first, !single.isEmpty {
                BaseImporter.addCustomField(node: node, name: "Expires", value: single)
            }
        }

        if let code = splitValueRetainingLastPart(row[safe: 6])?.nonEmpty {
            BaseImporter.addCustomField(node: node, name: "Code", value: code, protected: true, detectUrl: false)
        }

        if let cardholder = splitValueRetainingLastPart(row[safe: 7])?.nonEmpty {
            BaseImporter.addUsernameOrCustom(node: node, name: "Cardholder Name", value: cardholder)
        }

        if let brand = splitValueRetainingLastPart(row[safe: 9])?.nonEmpty {
            BaseImporter.addCustomField(node: node, name: "Brand", value: brand)
        }

        let detailLines = [8, 10, 11].compactMap { index -> String? in
            guard let raw = row[safe: index], !raw.isEmpty else { return nil }
            let label = raw.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
            let value = splitValueRetainingLastPart(raw) ?? ""
            return "\(label): \(value)"
        }

        if !detailLines.isEmpty {
            node.fields.notes = detailLines.joined(separator: "\n")
        }
    }

    private func processNote(row: [String], node: Node) {
        var noteLines: [String] = []
        for index in 3..<row.count {
            if let line = trimmed(row[safe: index]), !line.isEmpty {
                noteLines.append(line)
            }
        }

        if !noteLines.isEmpty {
            node.fields.notes = noteLines.joined(separator: "\n")
        }
    }

    private func classify(category: String) -> MSecureCategory {
        if category == "Web Logins" || category == "Login" {
            return .login
        }

        if category == "Credit Card" {
            return .card
        }

        return .note
    }

    private func splitValueRetainingLastPart(_ value: String?) -> String? {
        guard let value else { return nil }
        let parts = value.components(separatedBy: "|")
        guard parts.count > 2 else { return parts.last }
        return parts.dropFirst(2).joined(separator: "|")
    }

    private func normalizedFolderName(_ value: String?) -> String? {
        guard let normalized = trimmed(value), !normalized.isEmpty else { return nil }
        return normalized == "Unassigned" ? nil : normalized
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
