//
//  AppPreferencesWindowController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
public class AppPreferencesWindowController: NSWindowController {
    @objc
    public enum AppPreferencesTab: Int {
        case general
        case passwordGeneration
        case favIcon
        case newEntryDefaults
        case advanced
    }

    @objc
    static let sharedInstance: AppPreferencesWindowController = .instantiateFromStoryboard()

    private class func instantiateFromStoryboard() -> AppPreferencesWindowController {
        let storyboard = NSStoryboard(name: "AppPreferences", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! AppPreferencesWindowController
        return wc
    }

    @objc
    public func show(tab: AppPreferencesTab = .general) {
        let vc = contentViewController as! NSTabViewController
        vc.selectedTabViewItemIndex = tab.rawValue
        showWindow(nil)
    }
}
