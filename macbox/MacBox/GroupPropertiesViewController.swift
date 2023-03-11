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
    @IBOutlet weak var labelTitle: NSTextField!
    @IBOutlet weak var segmentSearchable: NSSegmentedControl!
    @IBOutlet weak var inheritedStateLabel: NSTextField!
    @IBOutlet weak var inheritedState: NSTextField!
    @IBOutlet weak var stackViewNotes: NSStackView!
    @IBOutlet weak var stackViewSearchable: NSStackView!
    
    @IBOutlet weak var labelLocationChanged: NSTextField!
    @IBOutlet weak var labelModified: NSTextField!
    @IBOutlet weak var labelCreated: NSTextField!
    @IBOutlet weak var labelId: NSTextField!
    @IBOutlet weak var labelChildGroups: NSTextField!
    @IBOutlet weak var labelChildEntries: NSTextField!
    
    @objc var group: Node!
    @objc var viewModel: ViewModel!

    @objc class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("GroupPropertiesViewController"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bindUI()
    }

    func bindUI() {
        let derefedTitle = viewModel.dereference(group.title, node: group)
        
        labelTitle.stringValue = derefedTitle
        
        bindSearchable()
        bindNotes()
        bindMetaDataAndDates()
    }
    
    @IBAction func onSearchableChanged(_ sender: Any) {
        if segmentSearchable.selectedSegment == 0 {
            viewModel.setSearchableState(group, searchable: false)
        }
        else if segmentSearchable.selectedSegment == 1 {
            viewModel.setSearchableState(group, searchable: nil)
        }
        else if segmentSearchable.selectedSegment == 2 {
            viewModel.setSearchableState(group, searchable: true)
        }
        
        bindUI()
    }
    
    func bindSearchable() {
        stackViewSearchable.isHidden = !viewModel.isKeePass2Format
        
        inheritedState.stringValue = localizedYesOrNoFromBool(group.isSearchable)
        
        segmentSearchable.setSelected(false, forSegment: 0)
        segmentSearchable.setSelected(false, forSegment: 1)
        segmentSearchable.setSelected(false, forSegment: 2)
        
        segmentSearchable.selectedSegment = group.fields.enableSearching == nil ? 1 : (group.fields.enableSearching!.boolValue ? 2 : 0);
        
        inheritedState.isHidden = group.fields.enableSearching != nil
        inheritedStateLabel.isHidden = group.fields.enableSearching != nil
        
        segmentSearchable.isEnabled = !viewModel.isEffectivelyReadOnly
    }
    
    func bindMetaDataAndDates() {
        labelId.stringValue = keePassStringIdFromUuid(group.uuid)
        labelCreated.stringValue = (group.fields.created as? NSDate)?.friendlyDateTimeString ?? ""
        labelModified.stringValue = (group.fields.modified as? NSDate)?.friendlyDateTimeString ?? ""
        labelLocationChanged.stringValue = (group.fields.locationChanged as? NSDate)?.friendlyDateTimeString ?? ""
        
        
        
        let childEntries = group.childRecords.count
        let childEntriesRec = group.allChildRecords.count
        let childGroups = group.childGroups.count
        let childGroupsRec = group.allChildGroups.count
        
        labelChildGroups.stringValue = String(format: NSLocalizedString("number_of_entries_or_groups_immediate_and_recursive_fmt", comment: "%d (%d Recursive)"), childGroups, childGroupsRec)
        
        labelChildEntries.stringValue = String(format: NSLocalizedString("number_of_entries_or_groups_immediate_and_recursive_fmt", comment: "%d (%d Recursive)"), childEntries, childEntriesRec)
    }
    
    func bindNotes() {
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
