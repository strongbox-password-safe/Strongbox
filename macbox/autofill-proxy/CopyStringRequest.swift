//
//  CopyStringRequest.swift
//  MacBox
//
//  Created by Strongbox on 23/11/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Cocoa

class CopyStringRequest: NSObject, Codable {
    var value: String

    init(value: String) {
        self.value = value
    }
}
