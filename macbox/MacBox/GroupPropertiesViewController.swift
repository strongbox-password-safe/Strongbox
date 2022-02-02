//
//  GroupPropertiesViewController.swift
//  MacBox
//
//  Created by Strongbox on 29/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class GroupPropertiesViewController: NSViewController {
    @IBOutlet var textViewNotes: SBDownTextView!

    @objc var group: Node!

    @objc class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("GroupPropertiesViewController"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindUI()
    }

    func bindUI() {
        let markdown = Settings.sharedInstance().markdownNotes
        textViewNotes.markdownEnabled = markdown
        textViewNotes.string = group.fields.notes

        if !markdown {
            

            textViewNotes.isEditable = true
            textViewNotes.checkTextInDocument(nil)
            textViewNotes.isEditable = false
        }
    }

    @IBAction func onOK(_: Any) {
        dismiss(nil)
    }
}
