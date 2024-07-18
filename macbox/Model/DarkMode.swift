//
//  DarkMode.swift
//  MacBox
//
//  Created by Strongbox on 17/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

enum DarkMode {
    static var isOn: Bool {
        if Settings.sharedInstance().appAppearance == kAppAppearanceDark {
            return true
        } else if Settings.sharedInstance().appAppearance == kAppAppearanceLight {
            return false
        }

        let osxMode: String? = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")

        return osxMode != nil && osxMode == "Dark"
    }
}
