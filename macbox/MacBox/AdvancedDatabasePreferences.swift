//
//  AdvancedDatabasePreferences.swift
//  MacBox
//
//  Created by Strongbox on 22/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AdvancedDatabasePreferences: NSViewController {
    @IBOutlet weak var checkboxConcealEmptyProtected: NSButton!
    @IBOutlet weak var checkboxTitleIsEditable: NSButton!
    @IBOutlet weak var checkboxOtherFieldsAreEditable: NSButton!
    @IBOutlet weak var checkboxShowRecycleBinInBrowse: NSButton!
    @IBOutlet weak var checkboxShowRecycleBinInSearch: NSButton!
    @IBOutlet weak var checkboxKeePassNoSort: NSButton!
    @IBOutlet weak var checkboxShowAutoCompleteSuggestions: NSButton!
    
    @objc
    var model : ViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bindUI()
    }
    
    func bindUI() {
        checkboxKeePassNoSort.state = !model.sortKeePassNodes ? .on : .off
        checkboxShowRecycleBinInBrowse.state = !model.showRecycleBinInBrowse ? .off : .on
        checkboxShowRecycleBinInSearch.state = model.showRecycleBinInSearchResults ? .on : .off
        checkboxShowAutoCompleteSuggestions.state = !model.showAutoCompleteSuggestions ? .off : .on
        checkboxTitleIsEditable.state = !model.outlineViewTitleIsReadonly ? .on : .off
        checkboxOtherFieldsAreEditable.state = model.outlineViewEditableFieldsAreReadonly ? .off : .on
        checkboxConcealEmptyProtected.state = model.concealEmptyProtectedFields ? .on : .off
    }
    
    @IBAction func onClose(_ sender: Any) {
        view.window?.cancelOperation(nil)
    }
    
    @IBAction func onChanged(_ sender: Any) {
        model.concealEmptyProtectedFields = checkboxConcealEmptyProtected.state == .on
        model.sortKeePassNodes = checkboxKeePassNoSort.state != .on
        model.showRecycleBinInBrowse = checkboxShowRecycleBinInBrowse.state == .on
        model.showRecycleBinInSearchResults = checkboxShowRecycleBinInSearch.state == .on
        model.showAutoCompleteSuggestions = checkboxShowAutoCompleteSuggestions.state == .on
        model.outlineViewTitleIsReadonly = checkboxTitleIsEditable.state == .off
        model.outlineViewEditableFieldsAreReadonly = checkboxOtherFieldsAreEditable.state == .off
    }
}
