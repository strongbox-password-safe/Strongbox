//
//  GeneratePassword.swift
//  MacBox
//
//  Created by Strongbox on 23/02/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Foundation

class GeneratePasswordRequest: Codable {}

class GeneratePasswordResponse: Codable {
    var password: String
    var alternatives: [String]

    init(password: String, alternatives: [String]) {
        self.password = password
        self.alternatives = alternatives
    }
}
