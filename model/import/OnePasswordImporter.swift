//
//  OnePasswordImporter.swift
//  MacBox
//
//  Created by Strongbox on 19/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

//

enum OnePasswordImporterError: Error {
    case CouldNotConvertStringToData
    case CouldNotDecodeSshKey
    case UnknownRecordType(typeString: String)
}

class OnePasswordImporter: NSObject, Importer {
    var allowedFileTypes: [String] = ["1pif"]

    static let magicSplitter: String = "***5642bee8-a5ff-11dc-8314-0800200c9a66***"

    func convert(url: URL) throws -> DatabaseModel {
        try OnePasswordImporter.convertToStrongboxNodes(url: url)
    }

    @objc
    class func convertToStrongboxNodes(url: URL) throws -> DatabaseModel { 
        let wrapper = try FileWrapper(url: url, options: .immediate)

        let data: Data?
        var attachments: [String: [String: Data]] = [:]

        if wrapper.isDirectory {
            guard let fileWrappers = wrapper.fileWrappers,
                  let nodesDataIdx = fileWrappers.keys.firstIndex(where: { key in
                      let str = key as NSString
                      return str.pathExtension == "1pif"
                  })
            else {
                throw OnePasswordImporterError.CouldNotConvertStringToData
            }

            attachments = findAttachments(fileWrappers)

            let file = fileWrappers[nodesDataIdx].value
            if file.isRegularFile {
                data = file.regularFileContents
            } else {
                throw OnePasswordImporterError.CouldNotConvertStringToData
            }
        } else {
            data = wrapper.regularFileContents
        }

        if let data {
            if let string = String(data: data, encoding: .utf8) {
                return try convertToStrongboxNodes(text: string, attachments: attachments)
            } else {
                throw OnePasswordImporterError.CouldNotConvertStringToData
            }
        } else {
            throw OnePasswordImporterError.CouldNotConvertStringToData
        }
    }

    @objc
    class func convertToStrongboxNodes(text: String, attachments: [String: [String: Data]] = [:]) throws -> DatabaseModel {
        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        let effectiveRootGroup = database.effectiveRootGroup

        let jsonRecords = text.components(separatedBy: OnePasswordImporter.magicSplitter)

        let records = try getRecords(jsonRecords)

        

        

        let uniqueRecordTypes = Array(Set(records.compactMap { recordTypeByTypeName[$0.typeName ?? ""] }))
        let uniqueCategories = uniqueRecordTypes.compactMap { $0.category() }

        var categoryToNodeMap: [ItemCategory: Node] = [:]
        for category in uniqueCategories {
            if category == .Unknown {
                continue
            }

            let categoryNode = Node(asGroup: category.rawValue, parent: effectiveRootGroup, keePassGroupTitleRules: true, uuid: nil)

            if categoryNode != nil {
                categoryNode!.icon = NodeIcon.withPreset(category.icon().rawValue)
                effectiveRootGroup.addChild(categoryNode!, keePassGroupTitleRules: true)
                categoryToNodeMap[category] = categoryNode!
            }
        }

        

        for record in records {
            let recordType = record.type

            if !recordTypeIsProcessable(recordType) {
                swlog("Unprocessable Record Type, Ignoring: \(String(describing: record.typeName))")
                continue
            }

            let category = recordType.category()
            let categoryNode = categoryToNodeMap[category]
            let parentNode = categoryNode ?? effectiveRootGroup

            let entry = Node(asRecord: "", parent: parentNode)

            record.fillStrongboxEntry(entry: entry)

            if let uuid = record.uuid, let attachments = attachments[uuid] {
                for attachment in attachments {
                    let dbA = KeePassAttachmentAbstractionLayer(nonPerformantWith: attachment.value, compressed: true, protectedInMemory: true)
                    entry.fields.attachments[attachment.key] = dbA
                }
            }

            parentNode.addChild(entry, keePassGroupTitleRules: true)

            if let trashed = record.trashed, trashed {
                database.recycleItems([entry])
            }
        }

        return database
    }

    fileprivate class func extractAttachment(_ attachment: Dictionary<String, FileWrapper>.Element) -> [String: Data] {
        let valWrapperDirectory = attachment.value

        var ret: [String: Data] = [:]

        guard valWrapperDirectory.isDirectory, let attachmentFileWrappers = valWrapperDirectory.fileWrappers else {
            return ret
        }

        for attachmentFileWrapper in attachmentFileWrappers {
            if attachmentFileWrapper.value.isRegularFile {
                if let data = attachmentFileWrapper.value.regularFileContents {
                    let filename = attachmentFileWrapper.key
                    ret[filename] = data

                    swlog("Found: [%@] => %@", filename, String(describing: data))
                }
            }
        }

        return ret
    }

    fileprivate class func findAttachments(_ fileWrappers: [String: FileWrapper]) -> [String: [String: Data]] {
        guard let attachmentsIdx = fileWrappers.keys.firstIndex(where: { key in
            key == "attachments"
        }), let attachments = fileWrappers[attachmentsIdx].value.fileWrappers else {
            return [:]
        }

        var ret: [String: [String: Data]] = [:]

        for attachment in attachments {
            let key = attachment.key
            let attachments = extractAttachment(attachment)
            ret[key] = attachments
        }

        return ret
    }

    class func recordTypeIsProcessable(_ recordType: RecordType) -> Bool {
        if recordType == .SavedSearch {
            return false
        } else if recordType == .RegularFolder {
            return false
        }

        return true
    }

    fileprivate class func getRecords(_ jsonRecords: [String]) throws -> [UnifiedRecord] {
        var records: [UnifiedRecord] = []

        for jsonRecord in jsonRecords {
            let trimmed: String = jsonRecord.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

            if trimmed.count == 0 {
                continue
            }

            let jsonData: Data? = trimmed.data(using: .utf8, allowLossyConversion: true)
            if jsonData == nil {
                throw OnePasswordImporterError.CouldNotConvertStringToData
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            let baseRecord = try decoder.decode(UnifiedRecord.self, from: jsonData!)

            records.append(baseRecord)
        }

        return records
    }
}
