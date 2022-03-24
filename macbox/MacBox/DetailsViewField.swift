//
//  DetailsViewField.swift
//  MacBox
//
//  Created by Strongbox on 19/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class DetailsViewField {
    enum FieldType {
        case header
        case customField
        case title
        case metadata
        case notes
        case attachment
        case totp
        case expiry
        case tags
        case url
        case auditIssue
    }

    var name: String = ""
    var value: String = ""
    var icon: NodeIcon?
    var concealed: Bool = false
    var concealable: Bool = false
    var fieldType: FieldType = .customField
    var object: Any?
    var showStrength: Bool = false

    init(name: String, value: String,
         fieldType: FieldType,
         concealed: Bool = false,
         concealable: Bool = false,
         icon: NodeIcon? = nil,
         object: Any? = nil,
         showStrength: Bool = false)
    {
        self.name = name
        self.value = value
        self.fieldType = fieldType
        self.concealed = concealed
        self.concealable = concealable
        self.icon = icon
        self.object = object
        self.showStrength = showStrength
    }
}
