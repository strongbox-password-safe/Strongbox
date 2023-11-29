//
//  BooleanAutoFillResponse.swift
//  MacBox
//
//  Created by Strongbox on 22/09/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

class BooleanAutoFillResponse: NSObject, Codable {
    var success: Bool

    init(success: Bool) {
        self.success = success
    }
}
