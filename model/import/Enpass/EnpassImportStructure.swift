//
//  EnpassImportStructure.swift
//  MacBox
//
//  Created by Strongbox on 23/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

struct EnpassCustomIcon: Decodable {
    var data: String?
    var uuid: String?
}

struct EnpassFolder: Decodable { 
    var uuid: String?
    var icon: String?
    var parent_uuid: String?
    var title: String?
    var updated_at: Date?
}

struct EnpassItemField: Decodable {
    var deleted: Int?
    var label: String?
    var order: Int?
    var sensitive: Int?
    var type: String?
    var uid: Int?
    var updated_at: Date?
    var value: String?
    var value_updated_at: Date?
}

struct EnpassIconImage: Decodable {
    var file: String?
}

struct EnpassIcon: Decodable {
    var fav: String?
    var image: EnpassIconImage?

    var uuid: String?
}

struct EnpassAttachment: Decodable {
    var data: String? 
    var name: String?
}

struct EnpassItem: Decodable {
    var archived: Int?
    var attachments: [EnpassAttachment]?
    var auto_submit: Int?
    var category: String?
    var createdAt: Date?
    var favorite: Int?
    var fields: [EnpassItemField]?
    var folders: [String]?
    var icon: EnpassIcon?
    var note: String?
    var subtitle: String?
    var template_type: String?
    var title: String?
    var trashed: Int?
    var updated_at: Date?
    var uuid: String?
}

struct EnpassJsonFile: Decodable {
    var custom_icons: [EnpassCustomIcon]?
    var folders: [EnpassFolder]?
    var items: [EnpassItem]?
}

enum EnpassCategory: String {
    case creditcard
    case identity
    case note
    case password
    case finance
    case license
    case travel
    case computer

    var keePassIcon: KeePassIconNames {
        switch self {
        case .creditcard:
            return .Identity
        case .identity:
            return .PaperReady
        case .note:
            return .PaperNew
        case .password:
            return .Key
        case .finance:
            return .Money
        case .license:
            return .Certificate
        case .travel:
            return .World
        case .computer:
            return .Disk
        }
    }
}
