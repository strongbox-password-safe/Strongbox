//
//  SwiftStringColourifier.swift
//  Strongbox
//
//  Created by Strongbox on 15/12/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import SwiftUI

private extension String {
    func getCharacterColor(darkMode: Bool, colorBlind: Bool) -> Color {
        let t = StringColourifierCharacterType.getTypeForCharacter(self)

        if colorBlind {
            return darkMode ? t.darkColorBlindColor : t.lightColorBlindColor
        } else {
            return t.color
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: 
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: 
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: 
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum StringColourifierCharacterType {
    case lower
    case upper
    case number
    case symbol

    var color: Color {
        switch self {
        case .lower:
            .primary
        case .upper:
            .green
        case .number:
            .blue
        case .symbol:
            .yellow
        }
    }

    var lightColorBlindColor: Color {





        switch self {
        case .lower:
            Color(hex: "000000")
        case .upper:
            Color(hex: "009E63")
        case .number:
            Color(hex: "CC79A7")
        case .symbol:
            Color(hex: "0072B2")
        }
    }

    var darkColorBlindColor: Color {





        switch self {
        case .lower:
            Color(hex: "009E63")
        case .upper:
            Color(hex: "F0E442")
        case .number:
            Color(hex: "D55E00")
        case .symbol:
            Color(hex: "56B4E9")
        }
    }

    static func getTypeForCharacter(_ character: String) -> Self {
        let inStringSet = CharacterSet(charactersIn: character)

        if CharacterSet.decimalDigits.isSuperset(of: inStringSet) {
            return .number
        } else if CharacterSet.lowercaseLetters.isSuperset(of: inStringSet) {
            return .lower
        } else if CharacterSet.uppercaseLetters.isSuperset(of: inStringSet) {
            return .upper
        } else {
            return .symbol
        }
    }
}

enum SwiftStringColourifier {
    static func getSwiftUIColor(for character: String, darkMode: Bool, colorBlind: Bool) -> Color {
        character.getCharacterColor(darkMode: darkMode, colorBlind: colorBlind)
    }

    static func getSwiftUIColoredString(_ string: String, darkMode: Bool, colorBlind: Bool) -> AttributedString {
        let ret = NSMutableAttributedString()

        let characters = Array(string) 

        for character in characters {
            let thisChar = String(character)

            let attributes = [NSAttributedString.Key.foregroundColor: UIColor(thisChar.getCharacterColor(darkMode: darkMode, colorBlind: colorBlind))]

            let attr = NSAttributedString(string: thisChar, attributes: attributes)

            ret.append(attr)
        }

        return AttributedString(ret)
    }

    static func getColor(for character: String, darkMode: Bool = true, colorBlind: Bool = false) -> UIColor {
        ColoredStringHelper.getColorForCharacter(character, darkMode: darkMode, colorBlind: colorBlind)
    }

    static func getAttributedString(for string: String, darkMode: Bool = true, colorBlind: Bool = false) -> AttributedString {
        AttributedString(ColoredStringHelper.getColorizedAttributedString(string, colorize: true, darkMode: darkMode, colorBlind: colorBlind, font: nil))
    }
}
