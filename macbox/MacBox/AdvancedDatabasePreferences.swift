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
    @IBOutlet var checkboxOtherFieldsAreEditable: NSButton!
    @IBOutlet var checkboxShowRecycleBinInBrowse: NSButton!
    @IBOutlet var checkboxShowRecycleBinInSearch: NSButton!
    @IBOutlet var checkboxKeePassNoSort: NSButton!
    @IBOutlet var checkboxShowAutoCompleteSuggestions: NSButton!
    @IBOutlet var checkboxAlwaysAutoMerge: NSButton!

    @objc
    var model: ViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if model.format == .passwordSafe {
            checkboxShowRecycleBinInBrowse.isHidden = true
            checkboxKeePassNoSort.isHidden = true
            checkboxShowRecycleBinInSearch.isHidden = true
        }

        if Settings.sharedInstance().nextGenUI {
            checkboxTitleIsEditable.isHidden = true
            checkboxOtherFieldsAreEditable.isHidden = true
        }

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
        checkboxAlwaysAutoMerge.state = model.databaseMetadata.conflictResolutionStrategy == .autoMerge ? .on : .off
    }

    @IBAction func onClose(_: Any) {
        view.window?.cancelOperation(nil)
    }

    @IBAction func onChanged(_: Any) {
        model.concealEmptyProtectedFields = checkboxConcealEmptyProtected.state == .on
        model.sortKeePassNodes = checkboxKeePassNoSort.state != .on
        model.showRecycleBinInBrowse = checkboxShowRecycleBinInBrowse.state == .on
        model.showRecycleBinInSearchResults = checkboxShowRecycleBinInSearch.state == .on
        model.showAutoCompleteSuggestions = checkboxShowAutoCompleteSuggestions.state == .on
        model.outlineViewTitleIsReadonly = checkboxTitleIsEditable.state == .off
        model.outlineViewEditableFieldsAreReadonly = checkboxOtherFieldsAreEditable.state == .off
        model.databaseMetadata.conflictResolutionStrategy = checkboxAlwaysAutoMerge.state == .on ? .autoMerge : .ask

        bindUI()

        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}
