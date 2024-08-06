//
//  LastPassImporter.swift
//  MacBox
//
//  Created by Strongbox on 03/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

private enum Fields: String {
    case url
    case username
    case password
    case totp
    case extra
    case name
    case grouping
    case fav
}

class LastPassImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["csv"]

    func convert(url: URL) throws -> DatabaseModel {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        guard let rows = NSArray(contentsOfCSVURL: url, options: [.sanitizesFields, .usesFirstLineAsKeys]) as? [CHCSVOrderedDictionary] else {
            swlog("🔴 Error parsing CSV file...")
            throw CsvGenericImporterError.errorParsing(details: "Could not read any rows from file")
        }

        guard rows.count > 0 else {
            throw CsvGenericImporterError.errorParsing(details: NSLocalizedString("mac_csv_file_contains_zero_rows", comment: "CSV File Contains Zero Rows. Cannot Import."))
        }

        guard let header = rows.first else {
            throw CsvGenericImporterError.errorParsing(details: "Could not read header row to validate")
        }

        guard header[Fields.url.rawValue] as? String != nil,
              header[Fields.username.rawValue] as? String != nil,
              header[Fields.password.rawValue] as? String != nil,
              header[Fields.totp.rawValue] as? String != nil,
              header[Fields.grouping.rawValue] as? String != nil,
              header[Fields.fav.rawValue] as? String != nil,
              header[Fields.extra.rawValue] as? String != nil,
              header[Fields.name.rawValue] as? String != nil
        else {
            throw CsvGenericImporterError.errorParsing(details: "Could not find required fields [url, username, password, totp, extra, name, grouping, fav]. Incorrect format.")
        }

        for row in rows {
            addRow(row: row, database: database)
        }

        return database
    }

    func addRow(row: CHCSVOrderedDictionary, database: DatabaseModel) {
        var parentGroup = database.effectiveRootGroup

        if let grouping = row[Fields.grouping.rawValue] as? String, !grouping.isEmpty {
            let pathComponents = grouping.components(separatedBy: "\\")

            if !pathComponents.isEmpty {
                parentGroup = createOrGetGroup(parentGroup: parentGroup, pathComponents: pathComponents)
            }
        }

        let node = Node(asRecord: "Unknown", parent: parentGroup)
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let name = row[Fields.name.rawValue] as? String {
            node.setTitle(name, keePassGroupTitleRules: true)
        }

        if let username = row[Fields.username.rawValue] as? String {
            node.fields.username = username
        }

        if let password = row[Fields.password.rawValue] as? String {
            node.fields.password = password
        }

        if let totp = row[Fields.totp.rawValue] as? String {
            let preferences = CrossPlatformDependencies.defaults().applicationPreferences

            node.setTotpWith(totp, appendUrlToNotes: false, forceSteam: false, addLegacyFields: preferences.addLegacySupplementaryTotpCustomFields, addOtpAuthUrl: preferences.addOtpAuthUrl)
        }

        if let fav = row[Fields.fav.rawValue] as? String, fav == "1" {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        var isSecureNote = false
        if let url = row[Fields.url.rawValue] as? String {
            if url != "http:
                node.fields.url = url
            } else {
                isSecureNote = true
            }
        }

        if let extra = row[Fields.extra.rawValue] as? String {
            if isSecureNote {
                processExtra(node, extra)
            } else {
                node.fields.notes = extra
            }
        }
    }

    func createOrGetGroup(parentGroup: Node, pathComponents: [String]) -> Node {
        var ret = parentGroup

        for component in pathComponents {
            guard !component.isEmpty else {
                swlog("⚠️ Empty Path Component?!")
                return ret
            }

            ret = createOrGetGroupImmediate(parentGroup: ret, title: component)
        }

        return ret
    }

    func createOrGetGroupImmediate(parentGroup: Node, title: String) -> Node {
        if let existing = parentGroup.childGroups.first(where: { group in
            group.title == title
        }) {
            return existing
        }

        let ret = Node(asGroup: title, parent: parentGroup, keePassGroupTitleRules: true, uuid: nil)!

        parentGroup.addChild(ret, keePassGroupTitleRules: true)

        return ret
    }

    func processExtra(_ node: Node, _ extra: String) {
        if !extra.hasPrefix("NoteType") {
            node.fields.notes = extra
            return
        }

        let lines = extra.split(whereSeparator: \.isNewline).map(String.init)
        for line in lines {
            guard !line.isEmpty else {
                continue
            }

            let kvp = line.split(separator: ":", maxSplits: 1).map(String.init)

            if kvp.count != 2 {
                BaseImporter.addCustomField(node: node, name: UUID().uuidString, value: line)
            } else {
                let key = kvp[0]
                let value = kvp[1]

                processExtraKvp(node, key, value)
            }
        }
    }

    func processExtraKvp(_ node: Node, _ key: String, _ value: String) {
        guard !value.isEmpty else {
            return 
        }

        if key == "NoteType" {
            if value == "Bank Account" {
                
                return
            }
            if value == "Address" {
                
                return
            }
            if value == "Credit Card" {
                
                return
            }
        }

        if key == "Language" {
            
            return
        }

        if key == "Notes", node.fields.notes.isEmpty {
            node.fields.notes = value
            return
        }

        BaseImporter.addCustomField(node: node, name: key, value: value)
    }
}
