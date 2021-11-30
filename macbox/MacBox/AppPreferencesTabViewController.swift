//
//  AppPreferencesTabViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AppPreferencesTabViewController: NSTabViewController, NSWindowDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        self.view.window?.delegate = self
    }
    
    override func cancelOperation(_ sender: Any?) {
        NSLog("cancelOperation!")

    }
}
