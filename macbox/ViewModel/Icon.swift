//
//  Images.swift
//  MacBox
//
//  Created by Strongbox on 15/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Foundation

enum Icon {
    case folder
    case tag
    case house
    
    func image() -> NSImage {
        switch self {
        case .folder:
            if #available(macOS 11.0, *) {
                return NSImage( systemSymbolName: "folder", accessibilityDescription: nil )!
            }
            else {
                return NSImage(named: "folder")!
            }
        case .tag:
            if #available(macOS 11.0, *) {
                return NSImage( systemSymbolName: "tag", accessibilityDescription: nil )!
            }
            else {
                return NSImage(named: "tag")! 
            }
        case .house:
            if #available(macOS 11.0, *) {
                return NSImage( systemSymbolName: "house", accessibilityDescription: nil )!
            }
            else {
                return NSImage(named: "house")! 
            }
        }
    }
}
