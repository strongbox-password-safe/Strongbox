//
//  CopyFieldRequest.swift
//  MacBox
//
//  Created by Strongbox on 22/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

class CopyFieldRequest: NSObject, Codable {
    enum WellKnownField: Int, Codable {
        case username
        case password
        case totp
    }

    var databaseId: String
    var nodeId: UUID
    var field: WellKnownField

    init(databaseId: String, nodeId: UUID, field: CopyFieldRequest.WellKnownField, customFieldName _: String, explicitTotp: Bool = false) {
        self.databaseId = databaseId
        self.nodeId = nodeId
        self.field = field
        _explicitTotp = explicitTotp
    }

    var explicitTotp: Bool { _explicitTotp ?? false }
    var _explicitTotp: Bool?

    enum CodingKeys: String, CodingKey {
        case databaseId
        case nodeId
        case field
        case _explicitTotp = "explicitTotp"
    }
}
