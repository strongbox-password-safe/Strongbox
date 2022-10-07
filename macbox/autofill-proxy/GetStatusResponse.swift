//
//  GetDatabasesResponse.swift
//  MacBox
//
//  Created by Strongbox on 16/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
class GetStatusResponse : NSObject, Codable {
    @objc var serverVersionInfo : String = ""
    @objc var databases : [DatabaseSummary] = []

    @objc
    func toJson () -> String? {
        return AutoFillJsonHelper.toJson(object: self)
    }
}
