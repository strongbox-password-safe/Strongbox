//
//  BoxKeyPair.swift
//  MacBox
//
//  Created by Strongbox on 25/08/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

@objc
class BoxKeyPair: NSObject {
    var publicKey: String
    var privateKey: String

    @objc
    public init(publicKey: String, privateKey: String) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}
