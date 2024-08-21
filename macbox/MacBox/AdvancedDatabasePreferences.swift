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
    @IBOutlet var checkboxShowRecycleBinInSearch: NSButton!
    @IBOutlet var checkboxShowAutoCompleteSuggestions: NSButton!
    @IBOutlet var checkboxSortCustomFields: NSButton!
    @IBOutlet var checkboxAlwaysAutoMerge: NSButton!
    @IBOutlet var checkboxMarkDirtyOnExpandCollapseGroups: NSButton!

    @objc
    var model: ViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if model.format == .passwordSafe {
            checkboxShowRecycleBinInSearch.isHidden = true
            checkboxSortCustomFields.isHidden = true
        }

        bindUI()
    }

    func bindUI() {
        checkboxShowRecycleBinInSearch.state = model.showRecycleBinInSearchResults ? .on : .off
        checkboxShowAutoCompleteSuggestions.state = !model.showAutoCompleteSuggestions ? .off : .on
        checkboxTitleIsEditable.state = !model.outlineViewTitleIsReadonly ? .on : .off
        checkboxConcealEmptyProtected.state = model.concealEmptyProtectedFields ? .on : .off
        checkboxSortCustomFields.state = !model.customSortOrderForFields ? .on : .off
        checkboxAlwaysAutoMerge.state = model.conflictResolutionStrategy == .autoMerge ? .on : .off
        checkboxMarkDirtyOnExpandCollapseGroups.state = model.databaseMetadata.markDirtyOnExpandCollapseGroups ? .on : .off
    }

    @IBAction func onClose(_: Any) {
        view.window?.cancelOperation(nil)
    }

    @IBAction func onChanged(_: Any) {
        model.concealEmptyProtectedFields = checkboxConcealEmptyProtected.state == .on
        model.showRecycleBinInSearchResults = checkboxShowRecycleBinInSearch.state == .on
        model.showAutoCompleteSuggestions = checkboxShowAutoCompleteSuggestions.state == .on
        model.outlineViewTitleIsReadonly = checkboxTitleIsEditable.state == .off
        model.customSortOrderForFields = checkboxSortCustomFields.state == .off
        model.conflictResolutionStrategy = checkboxAlwaysAutoMerge.state == .on ? .autoMerge : .ask

        model.databaseMetadata.markDirtyOnExpandCollapseGroups = checkboxMarkDirtyOnExpandCollapseGroups.state == .on

        bindUI()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }
}
