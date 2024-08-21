//
//  String+Lines.swift
//  MacBox
//
//  Created by Strongbox on 21/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

extension String {
    var lines: [String] {
        components(separatedBy: CharacterSet.newlines)
    }

    var htmlStringEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
