//
//  DBManagerPanel.swift
//  MacBox
//
//  Created by Strongbox on 23/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class DBManagerPanel: NSWindowController {
    @objc
    static let sharedInstance: DBManagerPanel = .instantiateFromStoryboard()

    private class func instantiateFromStoryboard() -> DBManagerPanel {
        let storyboard = NSStoryboard(name: "DatabasesManager", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! DBManagerPanel
        return wc
    }

    @objc
    public func show() {
        

        showWindow(nil)
    }

    @objc
    public func showAndBeginAddDatabaseSequence(createMode: Bool, newModel: DatabaseModel? = nil) {
        

        showWindow(nil)

        guard let vc = contentViewController as? DatabasesManagerVC else {
            swlog("🔴 Could not get contentviewcontroller?! for DBManager")
            return
        }

        vc.beginAddDatabaseSequence(createMode, newModel: newModel, existingDatabaseToCopy: nil)
    }

    @objc
    public func hide() {
        

        window?.orderOut(nil)
    }
}
