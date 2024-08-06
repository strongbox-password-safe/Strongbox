//
//  EnpassImporter.swift
//  MacBox
//
//  Created by Strongbox on 22/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class EnpassImporter: NSObject, Importer {
    enum EnpassImportError: Error {
        case generic(description: String)
    }

    var archiveGroup: Node? = nil
    var allowedFileTypes: [String] = ["json"]

    func convert(url: URL) throws -> DatabaseModel {
        let result = try convertEx(url: url)

        return result.database
    }

    func convertEx(url: URL) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let jsonData = try Data(contentsOf: url)

        let container = try decoder.decode(EnpassJsonFile.self, from: jsonData)

        let database = DatabaseModel(format: .keePass4,
                                     compositeKeyFactors: .password("a"),
                                     metadata: .withDefaultsFor(.keePass4),
                                     root: Node.rootWithDefaultKeePassEffectiveRootGroup())

        guard let items = container.items else {
            return ImportResult(database: database, messages: [ImportMessage("No Items Found!", .warning)])
        }

        var messages: [ImportMessage] = []

        var iconPool: [UUID: NodeIcon] = [:]
        if let icons = container.custom_icons {
            processCustomIcons(icons, &iconPool, &messages)
        }

        let folderMap = processTags(container, &messages)

        for item in items {
            try processItem(item, database, iconPool, folderMap, &messages)
        }

        return ImportResult(database: database, messages: messages)
    }

    func processBasicFields(_ item: EnpassItem, _ node: Node) {
        if let created = item.createdAt {
            node.fields.setTouchPropertiesWithCreated(created, accessed: nil, modified: nil, locationChanged: nil, usageCount: nil)
        }

        if let modified = item.updated_at {
            node.setModifiedDateExplicit(modified, setParents: false)
        }

        if let fav = item.favorite, fav != 0 {
            node.fields.tags.add(kCanonicalFavouriteTag)
        }

        if let notes = item.note {
            node.fields.notes = notes
        }

        if let subtitle = item.subtitle, subtitle.count > 0 {
            BaseImporter.addCustomField(node: node, name: "Subtitle", value: subtitle, protected: false, detectUrl: false)
        }
    }

    func processItem(_ item: EnpassItem, _ database: DatabaseModel, _ iconPool: [UUID: NodeIcon], _ folderMap: [UUID: String], _ messages: inout [ImportMessage]) throws {
        let title = item.title ?? NSLocalizedString("generic_unknown", comment: "Unknown")

        

        var categoryIcon: NodeIcon? = nil

        if let categoryStr = item.category, let cat = EnpassCategory(rawValue: categoryStr) {
            categoryIcon = NodeIcon.withPreset(cat.keePassIcon.rawValue)
        }

        

        let parentGroup = try getParentGroup(database, item, categoryIcon, &messages)
        let uuid = item.uuid != nil ? (UUID(uuidString: item.uuid!) ?? UUID()) : UUID()
        let node = Node(asRecord: title, parent: parentGroup, fields: NodeFields(), uuid: uuid)
        parentGroup.addChild(node, keePassGroupTitleRules: true) 

        

        if let trashed = item.trashed, trashed != 0 {
            database.recycleItems([node])
        }

        

        if let icon = item.icon {
            if let uuidStr = icon.uuid, let uuid = UUID(uuidString: uuidStr), let nodeIcon = iconPool[uuid] { 
                node.icon = nodeIcon
            } else if let categoryIcon {
                node.icon = categoryIcon
            }
        }

        processItemTags(item, folderMap, node, &messages)

        processBasicFields(item, node)

        if let fields = item.fields {
            processFields(fields, node)
        }

        

        if let attachments = item.attachments {
            processAttachments(attachments, node, &messages)
        }
    }

    func processItemTags(_ item: EnpassItem, _ folderMap: [UUID: String], _ node: Node, _ messages: inout [ImportMessage]) {
        

        if let folders = item.folders {
            for folderUuid in folders {
                if let uuid = UUID(uuidString: folderUuid), let tag = folderMap[uuid] {
                    node.fields.tags.add(tag)
                } else {
                    messages.append(ImportMessage(String(format: "Error getting Tag for item [%@]", node.title), .warning))
                }
            }
        }
    }

    func processFields(_ fields: [EnpassItemField], _ node: Node) {
        let sorted = fields.sorted { item1, item2 in
            let o1 = item1.order ?? .max
            let o2 = item2.order ?? .max

            return o1 < o2
        }

        for field in sorted {
            if let deleted = field.deleted, deleted != 0 {
                continue
            }

            

            if let fieldType = field.type {
                if fieldType == "username", let value = field.value, !value.isEmpty {
                    BaseImporter.addUsernameOrCustom(node: node, name: field.label, value: field.value)
                    continue
                } else if fieldType == "password" {
                    BaseImporter.addPasswordOrCustom(node: node, name: field.label, value: field.value)
                    continue
                } else if fieldType == "email", let value = field.value, !value.isEmpty {
                    BaseImporter.addEmailOrCustom(node: node, name: field.label, value: field.value)
                    continue
                } else if fieldType == "totp", let value = field.value, !value.isEmpty {
                    BaseImporter.addTotpOrCustom(node: node, name: field.label, value: field.value)
                    continue
                } else if fieldType == "section" { 
                    let concealed = field.sensitive == nil ? false : (field.sensitive! != 0)
                    BaseImporter.addCustomField(node: node, name: field.label, value: field.value, protected: concealed)
                    continue
                }
            }

            let concealed = field.sensitive == nil ? false : (field.sensitive! != 0)
            BaseImporter.addCustomField(node: node, name: field.label, value: field.value, protected: concealed)
        }
    }

    func processAttachments(_ attachments: [EnpassAttachment], _ node: Node, _ messages: inout [ImportMessage]) {
        for attachment in attachments {
            do {
                try BaseImporter.addAttachment(node: node, name: attachment.name, base64Data: attachment.data)
            } catch {
                swlog("🔴 [\(error)]")
                messages.append(ImportMessage("\(error)", .error))
            }
        }
    }

    func processCustomIcons(_ icons: [EnpassCustomIcon], _ iconPool: inout [UUID: NodeIcon], _ messages: inout [ImportMessage]) {
        for icon in icons {
            if let uuidStr = icon.uuid, let uuid = UUID(uuidString: uuidStr), let b64Data = icon.data, !b64Data.isEmpty, let data = (b64Data as NSString).dataFromHex {
                iconPool[uuid] = NodeIcon.withCustom(data, uuid: uuid, name: nil, modified: nil)
            } else {
                messages.append(ImportMessage(String(format: "Could not read custom icon [%@]", String(describing: icon.uuid)), .warning))
            }
        }
    }

    func processFolders(_ folders: [EnpassFolder], _ intermediateFolderMap: inout [UUID: EnpassFolder], _ messages: inout [ImportMessage]) {
        for folder in folders {
            if let uuidStr = folder.uuid, let uuid = UUID(uuidString: uuidStr) {
                intermediateFolderMap[uuid] = folder
            } else {
                messages.append(ImportMessage(String(format: "Could not read folder/tag [%@]", String(describing: folder.uuid)), .warning))
            }
        }
    }

    func processFolderTags(_ uuid: UUID, _ intermediateFolderMap: inout [UUID: EnpassFolder], _ folderMap: inout [UUID: String], _ messages: inout [ImportMessage]) {
        var components: [String] = []

        var hierarchicalUuid = uuid
        while true {
            if let folder = intermediateFolderMap[hierarchicalUuid], let tag = folder.title, !tag.isEmpty {
                components.append(tag)

                if let parentUuidStr = folder.parent_uuid, let parentUuid = UUID(uuidString: parentUuidStr) {
                    hierarchicalUuid = parentUuid
                } else {
                    folderMap[uuid] = components.reversed().joined(separator: "-")
                    break
                }
            } else {
                messages.append(ImportMessage(String(format: "Could not find folder/tag [%@]", String(describing: hierarchicalUuid)), .warning))
                break 
            }
        }
    }

    func processTags(_ container: EnpassJsonFile, _ messages: inout [ImportMessage]) -> [UUID: String] {
        var intermediateFolderMap: [UUID: EnpassFolder] = [:]
        if let folders = container.folders {
            processFolders(folders, &intermediateFolderMap, &messages)
        }

        var folderMap: [UUID: String] = [:]
        for uuid in intermediateFolderMap.keys {
            processFolderTags(uuid, &intermediateFolderMap, &folderMap, &messages)
        }

        return folderMap
    }

    func getParentGroup(_ database: DatabaseModel, _ item: EnpassItem, _ categoryIcon: NodeIcon?, _ messages: inout [ImportMessage]) throws -> Node {
        var parentGroup = database.effectiveRootGroup

        if let templateType = item.template_type, !templateType.isEmpty {
            var components = templateType
                .split(separator: ".")
                .map { String($0) }
                .filter { !$0.isEmpty }

            

            if !components.isEmpty, components.last == "default" {
                components.removeLast()
            }

            if !components.isEmpty, let subgroup = BaseImporter.getOrCreateGroup(database, components, categoryIcon) {
                parentGroup = subgroup
            } else {
                messages.append(ImportMessage(String(format: "Could not get or create group: [%@]", String(describing: components)), .warning))
                swlog(String(format: "Could not get or create group: [%@]"))
            }
        }

        if let archived = item.archived, archived != 0 {
            parentGroup = try getOrCreateArchiveGroup(database)
        }

        return parentGroup
    }

    func getOrCreateArchiveGroup(_ database: DatabaseModel) throws -> Node {
        if let archiveGroup {
            return archiveGroup
        } else {
            guard let group = Node(asGroup: "_archived",
                                   parent: database.effectiveRootGroup,
                                   keePassGroupTitleRules: true, uuid: nil),
                database.addChildren([group], destination: database.effectiveRootGroup)
            else {
                throw EnpassImportError.generic(description: "Could not create Archive group")
            }

            archiveGroup = group

            group.icon = NodeIcon.withPreset(KeePassIconNames.Tux.rawValue)

            group.fields.enableSearching = false
            group.fields.enableAutoType = false

            return group
        }
    }
}
