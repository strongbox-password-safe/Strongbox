//
//  Importer.swift
//  MacBox
//
//  Created by Strongbox on 01/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

@objc public enum ImportMessageSeverity: Int {
    case info
    case warning
    case error
}

@objc public class ImportMessage: NSObject, Identifiable {
    var message: String
    var severity: ImportMessageSeverity

    init(_ message: String, _ severity: ImportMessageSeverity) {
        self.message = message
        self.severity = severity
    }
}

@objc public class ImportResult: NSObject {
    @objc var database: DatabaseModel
    @objc var messages: [ImportMessage]

    init(database: DatabaseModel, messages: [ImportMessage]) {
        self.database = database
        self.messages = messages
    }
}

@objc public protocol Importer {
    var allowedFileTypes: [String] { get }
    func convert(url: URL) throws -> DatabaseModel
    @objc optional func convertEx(url: URL) throws -> ImportResult
}

enum CsvGenericImporterError: Error {
    case errorParsing(details: String)
}

extension CsvGenericImporterError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .errorParsing(details: details):
            return details
        }
    }
}

class BaseImporter {
    class func addUrl(_ node: Node, _ url: String, _ label: String? = nil) {
        if node.fields.url == url || node.fields.alternativeUrls.contains(url) {
            return
        }

        if node.fields.url.count == 0 {
            node.fields.url = url
        } else {
            node.fields.addSecondaryUrl(url, optionalCustomFieldSuffixLabel: label)
        }
    }

    class func addCustomField(node: Node, name: String?, value: String, protected: Bool = false, detectUrl: Bool = true) {
        if detectUrl, let url = value.urlExtendedParse, url.scheme != nil, url.absoluteString.count == value.count, !protected { 
            addUrl(node, url.absoluteString, name)
            return
        }

        let base = (name != nil && !(name!.isEmpty)) ? name! : "Unknown Field"
        var uniqueName = base

        var i = 2

        while node.fields.customFields.containsKey(uniqueName as NSString) || Constants.reservedCustomFieldKeys.contains(uniqueName) {
            uniqueName = String(format: "%@-%d", base, i)
            i = i + 1
        }

        node.fields.setCustomField(uniqueName, value: StringValue(string: value, protected: protected))
    }







}
