//
//  FavIconsPreferences.swift
//  MacBox
//
//  Created by Strongbox on 20/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class FavIconsPreferences: NSViewController {
    @IBOutlet weak var duckDuckGo: NSButton!
    @IBOutlet weak var scanCommon: NSButton!
    @IBOutlet weak var ignoreSsl: NSButton!
    @IBOutlet weak var scanHtml: NSButton!
    @IBOutlet weak var google: NSButton!
    @IBOutlet weak var domainOnly: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    func bindUI() {
        let options = Settings.sharedInstance().favIconDownloadOptions
        
        duckDuckGo.state = options.duckDuckGo ? .on : .off
        scanCommon.state = options.checkCommonFavIconFiles ? .on : .off
        ignoreSsl.state = options.ignoreInvalidSSLCerts ? .on : .off
        scanHtml.state = options.scanHtml ? .on : .off
        google.state = options.google ? .on : .off
        domainOnly.state = options.domainOnly ? .on : .off
    }
    
    @IBAction func onChanged(_ sender: Any) {
        let options = Settings.sharedInstance().favIconDownloadOptions
        
        options.duckDuckGo = duckDuckGo.state == .on
        options.checkCommonFavIconFiles = scanCommon.state == .on
        options.ignoreInvalidSSLCerts = ignoreSsl.state == .on
        options.scanHtml = scanHtml.state == .on
        options.google = google.state == .on
        options.domainOnly = domainOnly.state == .on
        
        if(options.isValid) {
            Settings.sharedInstance().favIconDownloadOptions = options;
        }

        bindUI()
    }
}
