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
    static let sharedInstance : DBManagerPanel = DBManagerPanel.instantiateFromStoryboard()

    private class func instantiateFromStoryboard () -> DBManagerPanel {
        let storyboard = NSStoryboard(name: "DatabasesManager", bundle: nil)
        let wc = storyboard.instantiateInitialController() as! DBManagerPanel
        return wc
    }
 
    @objc
    public func show( ) {
        NSLog("DBManagerPanel::show()");
        
        self.showWindow(nil)
    }
}
