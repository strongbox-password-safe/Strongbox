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

enum GenericImportError: Error {
    case error(details: String)
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

    class func addCustomField(node: Node, name: String?, value: String?, protected: Bool = false, detectUrl: Bool = true) {
        if detectUrl, let url = value?.urlExtendedParse, url.scheme != nil, url.absoluteString.count == (value?.count ?? 0), !protected { 
            addUrl(node, url.absoluteString, name)
            return
        }

        let base = (name != nil && !(name!.isEmpty)) ? name! : "Unknown Field"
        var uniqueName = base

        var i = 2

        while node.fields.customFields.containsKey(uniqueName as NSString) ||
            Constants.reservedCustomFieldKeys.contains(uniqueName)
        {
            uniqueName = String(format: "%@-%d", base, i)
            i = i + 1
        }

        node.fields.setCustomField(uniqueName, value: StringValue(string: value ?? "", protected: protected))
    }

    class func addUsernameOrCustom(node: Node, name: String?, value: String?) {
        if node.fields.username.count == 0, let value, value.count > 0 {
            node.fields.username = value
        } else {
            BaseImporter.addCustomField(node: node, name: name, value: value, protected: false, detectUrl: false)
        }
    }

    class func addPasswordOrCustom(node: Node, name: String?, value: String?) {
        if node.fields.password.count == 0, let value, value.count > 0 {
            node.fields.password = value
        } else {
            BaseImporter.addCustomField(node: node, name: name, value: value, protected: true, detectUrl: false)
        }
    }

    class func addEmailOrCustom(node: Node, name: String?, value: String?) {
        if node.fields.email.count == 0, let value, value.count > 0 {
            node.fields.email = value
        } else {
            BaseImporter.addCustomField(node: node, name: name, value: value, protected: false, detectUrl: false)
        }
    }

    class func addTotpOrCustom(node: Node, name: String?, value: String?) {
        if let value, !value.isEmpty {
            if let token = NodeFields.getOtpToken(from: value, forceSteam: false) {
                if node.fields.otpToken == nil {
                    let prefs = CrossPlatformDependencies.defaults().applicationPreferences

                    node.fields.setTotp(token,
                                        appendUrlToNotes: false,
                                        addLegacyFields: prefs.addLegacySupplementaryTotpCustomFields,
                                        addOtpAuthUrl: prefs.addOtpAuthUrl)
                    return
                } else if let otpUrl = token.url(true) {
                    addCustomField(node: node, name: name, value: otpUrl.absoluteString, protected: true)
                    return
                }
            }
        }

        BaseImporter.addCustomField(node: node, name: name, value: value)
    }

    class func addAttachment(node: Node, name: String?, base64Data: String?) throws {
        if let base64Data {
            guard let data = (base64Data as NSString).dataFromBase64 else {
                throw GenericImportError.error(details: String(format: "Could not convert base64 to Data for attachment: [%@ - %@]", node.title, String(describing: name)))
            }

            addAttachment(node: node, name: name, data: data)
        } else {
            addAttachment(node: node, name: name, data: Data())
        }
    }

    class func addAttachment(node: Node, name: String?, data: Data) {
        let base = (name != nil && !(name!.isEmpty)) ? name! : "attachment"
        var uniqueName = base

        var i = 2

        let arr = Array(node.fields.attachments.allKeys) as! [String]

        let attachmentNames = Set(arr)

        while attachmentNames.contains(uniqueName) {
            uniqueName = String(format: "%@-%d", base, i)
            i = i + 1
        }

        node.fields.attachments[uniqueName] = KeePassAttachmentAbstractionLayer(nonPerformantWith: data, compressed: true, protectedInMemory: true)
    }

    class func getOrCreateGroup(_ database: DatabaseModel, _ components: [String], _ icon: NodeIcon?) -> Node? {
        var current = database.effectiveRootGroup

        for title in components {
            if let found = current.childGroups.first(where: { $0.title == title }) {
                current = found
            } else {
                guard let group = Node(asGroup: title,
                                       parent: current,
                                       keePassGroupTitleRules: true,
                                       uuid: nil),
                    database.addChildren([group], destination: current)
                else {
                    return nil
                }

                group.icon = icon
                current = group
            }
        }

        return current
    }

    class func addHistoricalPasswordEntry(_ node: Node, _ password: String, _ mod: Date) {
        let cloneForHistory = node.cloneForHistory()

        cloneForHistory.fields.password = password
        cloneForHistory.fields.setModifiedDateExplicit(mod)

        node.fields.keePassHistory.add(cloneForHistory)
    }

    
    
    
    
    
    
}
