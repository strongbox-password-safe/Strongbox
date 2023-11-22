//
//  SecureContents.swift
//  MacBox
//
//  Created by Strongbox on 22/10/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

// import Cocoa

class SecureContents: Decodable {
    var notesPlain: String? = nil
    var sections: [OnePifSection]? = nil
    var URLs: [[String: String]]? = nil
    var fields: [OnePifField]? = nil
    var password: String? = nil
}
