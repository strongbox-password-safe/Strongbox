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

struct PasswordStrengthData: Codable {
    var entropy: Double
    var category: String
    var summaryString: String
}

struct PasswordAndStrength: Codable {
    var password: String
    var strength: PasswordStrengthData
}

class GeneratePasswordV2Response: Codable {
    var password: PasswordAndStrength
    var alternatives: [PasswordAndStrength]

    init(password: PasswordAndStrength, alternatives: [PasswordAndStrength]) {
        self.password = password
        self.alternatives = alternatives
    }
}

class GetPasswordStrengthRequest: Codable {
    var password: String
}

class GetPasswordStrengthResponse: Codable {
    var strength: PasswordStrengthData

    init(strength: PasswordStrengthData) {
        self.strength = strength
    }
}
