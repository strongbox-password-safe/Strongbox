//
//  AppSettingsWindowController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

@objc
public class AppSettingsWindowController: NSWindowController {
    @objc
    static let sharedInstance: AppSettingsWindowController = .instantiateFromStoryboard()

    private class func instantiateFromStoryboard() -> AppSettingsWindowController {
        let storyboard = NSStoryboard(name: "AppPreferences", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! AppSettingsWindowController
        return wc
    }

    override public func windowDidLoad() {
        super.windowDidLoad()

        if !StrongboxProductBundle.supportsWiFiSync {
            guard let tabVc = contentViewController as? NSTabViewController else {
                return
            }

            if let wiFiSync = getChildVc(WiFiSyncSettings.self) {
                if let idx = tabVc.children.firstIndex(of: wiFiSync) {
                    tabVc.removeChild(at: idx)
                }
            }
        }
    }

    @objc
    public func showGeneralTab() {
        showTab(GeneralPreferencesViewController.self)
    }

    public func showTab(_ type: (some NSViewController).Type) {
        guard let tabVc = contentViewController as? NSTabViewController,
              let idx = getChildVcIndex(type)
        else {
            return
        }

        tabVc.selectedTabViewItemIndex = idx

        showWindow(nil)
    }

    func getChildVcIndex(_ myType: (some NSViewController).Type) -> Int? {
        guard let tabVc = contentViewController as? NSTabViewController,
              let obj = getChildVc(myType)
        else {
            return nil
        }

        return tabVc.children.firstIndex(of: obj)
    }

    func getChildVc<T: NSViewController>(_: T.Type) -> T? {
        guard let tabVc = contentViewController as? NSTabViewController else {
            return nil
        }

        for chi in tabVc.children {
            if let a = chi as? T {
                return a
            }
        }

        return nil
    }
}
