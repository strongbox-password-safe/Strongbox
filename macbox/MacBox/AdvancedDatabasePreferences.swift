//
//  AdvancedDatabasePreferences.swift
//  MacBox
//
//  Created by Strongbox on 22/11/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa

class AdvancedDatabasePreferences: NSViewController {
    @IBOutlet var checkboxConcealEmptyProtected: NSButton!
    @IBOutlet var checkboxTitleIsEditable: NSButton!
    @IBOutlet var checkboxShowRecycleBinInBrowse: NSButton!
    @IBOutlet var checkboxShowRecycleBinInSearch: NSButton!
    @IBOutlet var checkboxKeePassSortItems: NSButton!
    @IBOutlet var checkboxShowAutoCompleteSuggestions: NSButton!
    @IBOutlet var checkboxSortCustomFields: NSButton!
    @IBOutlet var checkboxAlwaysAutoMerge: NSButton!

    @objc
    var model: ViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if model.format == .passwordSafe {
            checkboxShowRecycleBinInBrowse.isHidden = true
            checkboxKeePassSortItems.isHidden = true
            checkboxShowRecycleBinInSearch.isHidden = true
            checkboxSortCustomFields.isHidden = true
        }

        bindUI()
    }

    func bindUI() {
        checkboxKeePassSortItems.state = model.sortKeePassNodes ? .on : .off
        checkboxShowRecycleBinInBrowse.state = !model.showRecycleBinInBrowse ? .off : .on
        checkboxShowRecycleBinInSearch.state = model.showRecycleBinInSearchResults ? .on : .off
        checkboxShowAutoCompleteSuggestions.state = !model.showAutoCompleteSuggestions ? .off : .on
        checkboxTitleIsEditable.state = !model.outlineViewTitleIsReadonly ? .on : .off
        checkboxConcealEmptyProtected.state = model.concealEmptyProtectedFields ? .on : .off
        checkboxSortCustomFields.state = !model.customSortOrderForFields ? .on : .off
        checkboxAlwaysAutoMerge.state = model.conflictResolutionStrategy == .autoMerge ? .on : .off
    }

    @IBAction func onClose(_: Any) {
        view.window?.cancelOperation(nil)
    }

    @IBAction func onChanged(_: Any) {
        model.concealEmptyProtectedFields = checkboxConcealEmptyProtected.state == .on
        model.sortKeePassNodes = checkboxKeePassSortItems.state == .on
        model.showRecycleBinInBrowse = checkboxShowRecycleBinInBrowse.state == .on
        model.showRecycleBinInSearchResults = checkboxShowRecycleBinInSearch.state == .on
        model.showAutoCompleteSuggestions = checkboxShowAutoCompleteSuggestions.state == .on
        model.outlineViewTitleIsReadonly = checkboxTitleIsEditable.state == .off
        model.customSortOrderForFields = checkboxSortCustomFields.state == .off
        model.conflictResolutionStrategy = checkboxAlwaysAutoMerge.state == .on ? .autoMerge : .ask

        bindUI()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        }
    }
}
