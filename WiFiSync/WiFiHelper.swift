//
//  WiFiHelper.swift
//  MacBox
//
//  Created by Strongbox on 03/02/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import CoreWLAN

@objc
class WiFiHelper: NSObject {
    @objc class var ssid: String? {
        CWWiFiClient.shared().interface(withName: nil)?.ssid()
    }
}
