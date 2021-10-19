//
//  DetailViewController.swift
//  MacBox
//
//  Created by Strongbox on 27/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class DetailViewController: NSViewController, DocumentViewController {
    private var document : Document?
    private var loadedDocument : Bool = false
    private var model : ViewModel? {
        return document?.viewModel
    }
    
    private var selectedItem : Node? {
        let uuid = model?.selectedItem;
        return uuid == nil ? nil : model?.database.getItemBy(uuid!)
    }
     
    @IBOutlet weak var labelTitle: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    func onDocumentLoaded() {
        Logging.log("SideBarViewController::onDocumentLoaded")

        loadDocument()
    }
    
    func loadDocument() {
        if ( loadedDocument ) {
            return
        }
        
        guard let doc = self.view.window?.windowController?.document as? Document else {
            Logging.warn("SideBarViewController::load Document not set!")
            return
        }
        document = doc
        loadedDocument = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.onSelectionChanged), name: NSNotification.Name(kModelUpdateNotificationSelectedItemChanged), object: nil)
        
        bindUI()
    }
    
    @objc func onSelectionChanged(_ notification: Notification) {
        let vm = notification.object as! ViewModel
        
        if ( vm == model ) {
            Logging.log("onSelectionChanged \(vm) == \(model!) - Selected Item = \(String(describing: model?.selectedItem))")

            bindUI()
        }
    }
    
    func bindUI () {
        labelTitle.stringValue = selectedItem?.title ?? "No Selection"
    }
}
