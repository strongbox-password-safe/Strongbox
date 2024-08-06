//
//  SwiftEntryModel.swift
//  Strongbox
//
//  Created by Strongbox on 28/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import OrderedCollections

struct SwiftGroupModel: SwiftGroupModelInterface {
    let model: Model
    var id: UUID { uuid }
    let uuid: UUID

    static func < (lhs: SwiftGroupModel, rhs: SwiftGroupModel) -> Bool {
        lhs.title < rhs.title
    }

    var title: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.title, node: node)
    }

    var notes: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.notes, node: node)
    }

    init(node: Node, model: Model) {
        if !node.isGroup {
            swlog("🔴 entry passed to SwiftEntryModel")
        }

        uuid = node.uuid
        self.model = model
    }

    var node: Node? { model.getItemBy(uuid) }
    var isGroup: Bool { true }

    var searchFoundInPath: String {
        guard let node else {
            return "<Zombie Node>"
        }

        let rawPath = model.database.getSearchParentGroupPathDisplayString(node)
        return String(format: NSLocalizedString("browse_vc_group_path_string_fmt", comment: "(in %@)"), rawPath)
    }

    var image: IMAGE_TYPE_PTR {
        guard let node else {
            swlog("🔴 <Zombie Node>")
            return NodeIconHelper.defaultIcon
        }

        return NodeIconHelper.getIconFor(node, predefinedIconSet: model.metadata.keePassIconSet, format: model.metadata.likelyFormat, large: true)
    }
}

struct SwiftEntryModel: SwiftEntryModelInterface {
    let model: Model
    var id: UUID { uuid }
    let uuid: UUID

    static func < (lhs: SwiftEntryModel, rhs: SwiftEntryModel) -> Bool {
        lhs.title < rhs.title
    }

    var title: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.title, node: node)
    }

    var username: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.username, node: node)
    }

    var password: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.password, node: node)
    }

    var url: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.url, node: node)
    }

    var email: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.email, node: node)
    }

    var notes: String {
        guard let node else {
            return "<Zombie Node>"
        }

        return model.dereference(node.fields.notes, node: node)
    }

    var tags: [String] {
        guard let node else {
            return []
        }

        var set = Set(node.fields.tags.allObjects as! [String])

        set.remove(kCanonicalFavouriteTag)

        return set.sorted()
    }

    var totp: OTPToken? { node?.fields.otpToken ?? nil }

    init(node: Node, model: Model) {
        if node.isGroup {
            swlog("🔴 group passed to SwiftEntryModel")
        }

        uuid = node.uuid
        self.model = model
    }

    var node: Node? { model.getItemBy(uuid) }
    var isGroup: Bool { false }

    var searchFoundInPath: String {
        guard let node else {
            return "<Zombie Node>"
        }

        let rawPath = model.database.getSearchParentGroupPathDisplayString(node)
        return String(format: NSLocalizedString("browse_vc_group_path_string_fmt", comment: "(in %@)"), rawPath)
    }

    var image: IMAGE_TYPE_PTR {
        guard let node else {
            swlog("🔴 <Zombie Node>")
            return NodeIconHelper.defaultIcon
        }

        return NodeIconHelper.getIconFor(node, predefinedIconSet: model.metadata.keePassIconSet, format: model.metadata.likelyFormat, large: true)
    }

    func toggleFavourite() -> Bool {
        model.toggleFavourite(uuid)
    }

    var isFavourite: Bool { model.isFavourite(uuid) }

    var isFlaggedByAudit: Bool { model.isFlagged(byAudit: uuid) }

    var launchableUrl: URL? {
        guard !url.isEmpty else { return nil }

        return url.urlExtendedParseAddingDefaultScheme
    }

    var customFields: OrderedDictionary<String, StringValue> {
        guard let node else {
            swlog("🔴 <Zombie Node>")
            return .init()
        }

        let customFields = node.fields.customFieldsFiltered
        let keys = (customFields.keys as [String])

        let sorted = model.metadata.customSortOrderForFields ? keys : keys.sorted()
        let values = sorted.compactMap { customFields[$0 as NSString] }.map { StringValue(string: model.dereference($0.value, node: node), protected: $0.protected) }

        return OrderedDictionary(uniqueKeys: sorted, values: values)
    }
}
