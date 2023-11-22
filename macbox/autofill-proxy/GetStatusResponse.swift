//
//  GetStatusResponse.swift
//  MacBox
//
//  Created by Strongbox on 16/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
public class ServerSettings: NSObject, Codable {
    @objc var supportsCreateNew: Bool = false
    @objc var markdownNotes: Bool = false
}

@objc
public class GetStatusResponse: NSObject, Codable {
    @objc var serverVersionInfo: String = ""
    @objc var databases: [DatabaseSummary] = []
    @objc var serverSettings: ServerSettings? = nil

    @objc
    func toJson() -> String? {
        AutoFillJsonHelper.toJson(object: self)
    }
}
