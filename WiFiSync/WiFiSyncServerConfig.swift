//
//  WiFiSyncServerConfig.swift
//  Strongbox
//
//  Created by Strongbox on 28/12/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

import Network

@objc
class WiFiSyncServerConfig: NSObject, Identifiable {
    @objc var name: String
    @objc var passcode: String? 
    var endpoint: NWEndpoint

    var id: String {
        name
    }

    convenience init(name: String) {
        self.init(name: name, endpoint: NWEndpoint.service(name: "a", type: "b", domain: "c", interface: nil))
    }

    init(name: String, endpoint: NWEndpoint) {
        self.name = name
        self.endpoint = endpoint
    }
}
