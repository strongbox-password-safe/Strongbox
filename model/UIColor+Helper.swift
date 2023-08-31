//
//  UIColor+Helper.swift
//  Strongbox
//
//  Created by Strongbox on 12/07/2023.
//  Copyright © 2023 Mark McGuill. All rights reserved.
//

#if os(iOS)

    import UIKit

    extension UIColor {
        convenience init(hex: String, alpha: CGFloat = 1) {
            assert(hex[hex.startIndex] == "#", "Expected hex string of format #RRGGBB")

            let scanner = Scanner(string: hex)
            scanner.scanLocation = 1 

            var rgb: UInt32 = 0
            scanner.scanHexInt32(&rgb)

            self.init(
                red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0xFF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: alpha
            )
        }
    }

#else
    import Cocoa

    extension NSColor {
        convenience init(hex: String, alpha: CGFloat = 1) {
            assert(hex[hex.startIndex] == "#", "Expected hex string of format #RRGGBB")

            let scanner = Scanner(string: hex)
            scanner.scanLocation = 1 

            var rgb: UInt32 = 0
            scanner.scanHexInt32(&rgb)

            self.init(
                red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0xFF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: alpha
            )
        }
    }

#endif
