//
//  GroupPropertiesViewController.swift
//  MacBox
//
//  Created by Strongbox on 29/01/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

class GroupPropertiesViewController: NSViewController, NSTextViewDelegate {
    @IBOutlet var textViewNotes: NSTextView!
    @IBOutlet var labelTitle: NSTextField!
    @IBOutlet var segmentSearchable: NSSegmentedControl!
    @IBOutlet var inheritedStateLabel: NSTextField!
    @IBOutlet var inheritedState: NSTextField!
    @IBOutlet var stackViewNotes: NSStackView!
    @IBOutlet var stackViewSearchable: NSStackView!

    @IBOutlet var labelLocationChanged: NSTextField!
    @IBOutlet var labelModified: NSTextField!
    @IBOutlet var labelCreated: NSTextField!
    @IBOutlet var labelId: NSTextField!
    @IBOutlet var labelChildGroups: NSTextField!
    @IBOutlet var labelChildEntries: NSTextField!

    @IBOutlet var buttonDiscardNotesChanges: NSButton!
    @IBOutlet var buttonEditNotes: NSButton!

    @objc var group: Node!
    @objc var viewModel: ViewModel!

    @objc class func fromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("GroupPropertiesViewController"), bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        textViewNotes.delegate = self

        textViewNotes.enabledTextCheckingTypes = 0
        textViewNotes.isAutomaticQuoteSubstitutionEnabled = false
        textViewNotes.isAutomaticTextReplacementEnabled = false
        textViewNotes.isAutomaticDashSubstitutionEnabled = false
        textViewNotes.isAutomaticLinkDetectionEnabled = false

        bindUI()
    }

    func bindUI() {
        let derefedTitle = viewModel.dereference(group.title, node: group)

        labelTitle.stringValue = derefedTitle

        bindSearchable()
        bindNotes()
        bindMetaDataAndDates()
    }

    @IBAction func onSearchableChanged(_: Any) {
        if segmentSearchable.selectedSegment == 0 {
            viewModel.setSearchableState(group, searchable: false)
        } else if segmentSearchable.selectedSegment == 1 {
            viewModel.setSearchableState(group, searchable: nil)
        } else if segmentSearchable.selectedSegment == 2 {
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

        segmentSearchable.selectedSegment = group.fields.enableSearching == nil ? 1 : (group.fields.enableSearching!.boolValue ? 2 : 0)

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

    func notesHaveBeenChanged() -> Bool {
        guard let newNotes = textViewNotes.textStorage?.string else {
            swlog("🔴 Problem getting text from textViewNotes")
            return false
        }

        return newNotes != group.fields.notes
    }

    func textDidChange(_ notification: Notification) {
        if notification.object is NSTextView {
            bindEditNotesButton()
        }
    }

    func bindEditNotesButton() {
        if textViewNotes.isEditable {
            if notesHaveBeenChanged() {
                buttonEditNotes.title = NSLocalizedString("mac_save_action", comment: "Save")
                buttonEditNotes.keyEquivalent = "\r"
                buttonDiscardNotesChanges.title = NSLocalizedString("discard_changes", comment: "Discard Changes")
                buttonDiscardNotesChanges.isHidden = false
            } else {
                buttonEditNotes.title = NSLocalizedString("generic_cancel", comment: "Cancel")
                buttonDiscardNotesChanges.isHidden = true
            }
        } else {
            buttonEditNotes.title = NSLocalizedString("browse_vc_action_edit", comment: "Edit")
            buttonDiscardNotesChanges.isHidden = true
        }
    }

    func bindNotes() {
        if textViewNotes.isEditable {
            textViewNotes.string = group.fields.notes
        } else {
            let markdown = Settings.sharedInstance().markdownNotes

            textViewNotes.string = group.fields.notes

            if !markdown {
                

                textViewNotes.isEditable = true
                textViewNotes.checkTextInDocument(nil)
                textViewNotes.isEditable = false
            }
        }

        bindEditNotesButton()
    }

    @IBAction func onDiscardNotes(_: Any) {
        textViewNotes.isEditable = false

        bindNotes()
    }

    @IBAction func onEditOrSaveNotes(_: Any) {
        if textViewNotes.isEditable {
            if notesHaveBeenChanged() {
                guard let newNotes = textViewNotes.textStorage?.string else {
                    swlog("🔴 Problem getting text from textViewNotes")
                    return
                }

                viewModel.setItemNotes(group, notes: newNotes)

                

                if Settings.sharedInstance().autoSave { 
                    viewModel.document?.save(nil)
                }
            }
        } else {
            
        }

        textViewNotes.isEditable = !textViewNotes.isEditable
        bindNotes()
    }

    @IBAction func onDiscardAndClose(_: Any) {
        dismiss(nil) 
    }
}
