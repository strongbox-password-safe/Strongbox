//
//  iCloudImporter.swift
//  MacBox
//
//  Created by Strongbox on 03/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

private enum Fields: String {
    case Title
    case URL
    case Username
    case Password
    case Notes
    case OTPAuth
}

class iCloudImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["csv"]

    func convert(url: URL) throws -> DatabaseModel {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        let rows = NSArray(contentsOfCSVURL: url, options: [.sanitizesFields, .usesFirstLineAsKeys])

        guard let rows else {
            swlog("🔴 Error parsing CSV file...")
            throw CsvGenericImporterError.errorParsing(details: "Could not read any rows from file")
        }

        guard rows.count > 0 else {
            throw CsvGenericImporterError.errorParsing(details: NSLocalizedString("mac_csv_file_contains_zero_rows", comment: "CSV File Contains Zero Rows. Cannot Import."))
        }

        guard let headerRow = rows.firstObject else {
            throw CsvGenericImporterError.errorParsing(details: "Could not read header row to validate")
        }

        guard let header = headerRow as? CHCSVOrderedDictionary else {
            throw CsvGenericImporterError.errorParsing(details: "Could not read header row to validate")
        }

        guard header[Fields.Title.rawValue] as? String != nil,
              header[Fields.Username.rawValue] as? String != nil,
              header[Fields.Password.rawValue] as? String != nil,
              header[Fields.URL.rawValue] as? String != nil,
              header[Fields.Notes.rawValue] as? String != nil
        else {
            throw CsvGenericImporterError.errorParsing(details: "Could not find required fields [Title, Username, Password, URL, Notes]. Incorrect format.")
        }

        for rowAny in rows {
            guard let row = rowAny as? CHCSVOrderedDictionary else {
                throw CsvGenericImporterError.errorParsing(details: "Could not read row to validate")
            }

            addRow(row: row, database: database)
        }

        return database
    }

    func addRow(row: CHCSVOrderedDictionary, database: DatabaseModel) {
        let parentGroup = database.effectiveRootGroup
        let node = Node(asRecord: "Unknown", parent: parentGroup)
        parentGroup.addChild(node, keePassGroupTitleRules: true)

        if let title = row[Fields.Title.rawValue] as? String {
            node.setTitle(title, keePassGroupTitleRules: true)
        }
        if let url = row[Fields.URL.rawValue] as? String {
            node.fields.url = url
        }
        if let username = row[Fields.Username.rawValue] as? String {
            node.fields.username = username
        }
        if let password = row[Fields.Password.rawValue] as? String {
            node.fields.password = password
        }
        if let notes = row[Fields.Notes.rawValue] as? String {
            node.fields.notes = notes
        }
        if let otpAuth = row[Fields.OTPAuth.rawValue] as? String {
            let preferences = CrossPlatformDependencies.defaults().applicationPreferences

            node.setTotpWith(otpAuth, appendUrlToNotes: false, forceSteam: false, addLegacyFields: preferences.addLegacySupplementaryTotpCustomFields, addOtpAuthUrl: preferences.addOtpAuthUrl)
        }
    }
}
