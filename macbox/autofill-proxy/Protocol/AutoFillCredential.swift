//
//  AutoFillCredential.swift
//  MacBox
//
//  Created by Strongbox on 26/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class AutoFillCredential : Codable {
    // TODO: Indicate if entry is a favourite - might be good to indicate in UI
    // TODO: Tags?
    
    var uuid : UUID
    var databaseId : String
    var title : String
    var icon : String
    var username : String
    var password : String
    var url : String
    var totp : String
    var customFields : [String:String] 
    
    
    init(uuid : UUID, databaseId : String, title : String, username : String, password : String, url : String, totp: String, icon : String, customFields : [String : String] = [:]) {
        self.uuid = uuid
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.totp = totp
        self.icon = icon
        self.customFields = customFields
        self.databaseId = databaseId
    }
}
