//
//  CreateEditViewController.swift
//  MacBox
//
//  Created by Strongbox on 19/12/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import AppKit
import Cocoa
import CoreMedia
import QuickLookUI
import UniformTypeIdentifiers

class CreateEditViewController: NSViewController, NSWindowDelegate, NSToolbarDelegate, NSTextFieldDelegate, NSMenuDelegate, NSTextViewDelegate, NSTokenFieldDelegate {
    enum CreateEditError: Error {
        case attachmentDragAndDropError
    }

    enum FilePromiseProviderUserInfoKeys {
        static let filename = "filename"
    }

    var dragAndDropDestinationURL: URL {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DropAndDrops")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        return destinationURL
    }

    

    var dragAndDropPromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        return queue
    }()

    var iconExplicitlyChanged: Bool = false
    let autosave: String = "createOrEditSheetAutoSave"
    var initialNodeId: UUID? 
    var initialParentNodeId: UUID? 
    var database: ViewModel!
    var model: EntryViewModel!
    private var preEditModelClone: EntryViewModel!

    @IBOutlet var buttonCancel: NSButton!
    @IBOutlet var buttonDone: NSButton!
    @IBOutlet weak var buttonSave: NSButton!
    
    @IBOutlet var imageViewIcon: ClickableImageView!
    @IBOutlet var textFieldTitle: MMcGACTextField!
    @IBOutlet var textFieldUsername: MMcGACTextField!
    @IBOutlet var textFieldUrl: MMcGACTextField!
    @IBOutlet var textFieldEmail: MMcGACTextField!
    @IBOutlet var passwordField: MMcGSecureTextField!
    @IBOutlet var progressStrength: NSProgressIndicator!
    @IBOutlet var labelStrength: NSTextField!
    @IBOutlet var buttonGeneratePassword: NSButton!
    @IBOutlet var buttonPasswordPreferences: NSButton!
    @IBOutlet var popupButtonAlternativeSuggestions: NSPopUpButton!
    @IBOutlet var popupButtonUsernameSuggestions: NSPopUpButton!
    @IBOutlet var popupButtonEmailSuggestions: NSPopUpButton!
    @IBOutlet var popupButtonNotesSuggestions: NSPopUpButton!
    @IBOutlet var popupButtonTagsSuggestions: NSPopUpButton!

    @IBOutlet var tableViewAttachments: TableViewWithKeyDownEvents!
    @IBOutlet var tableViewCustomFields: TableViewWithKeyDownEvents!
    @IBOutlet var buttonDeleteAttachment: NSButton!
    @IBOutlet var buttonAddAttachment: NSButton!
    @IBOutlet var buttonSaveAs: NSButton!
    @IBOutlet var buttonPreview: NSButton!
    @IBOutlet var buttonAddField: NSButton!
    @IBOutlet var buttonEditField: NSButton!
    @IBOutlet var buttonRemoveField: NSButton!
    @IBOutlet var stackViewAttachmentButtons: NSStackView!
    @IBOutlet var textViewNotes: NSTextView!
    @IBOutlet var stackViewTOTP: NSStackView!
    @IBOutlet var buttonRemoveTOTP: NSButton!
    @IBOutlet var stackViewTOTPDisplay: NSStackView!
    @IBOutlet var popupAddTotp: NSPopUpButton!
    @IBOutlet var labelTotp: NSTextField!
    @IBOutlet var borderScrollNotes: NSScrollView!
    @IBOutlet var borderScrollAttachments: NSScrollView!
    @IBOutlet var borderScrollCustomFields: NSScrollView!
    @IBOutlet var stackViewExpiry: NSStackView!
    @IBOutlet var buttonSetExpiry: NSButton!
    @IBOutlet var stackViewAdjustExpiry: NSStackView!
    @IBOutlet var buttonClearExpiry: NSButton!
    @IBOutlet var tagsField: AutoResizingTokenField!
    @IBOutlet var progressTotp: NSProgressIndicator!
    @IBOutlet var popupLocation: NSPopUpButton!

    @IBOutlet var buttonHistory: NSPopUpButton!
    







    
    

    @IBOutlet var dummyKludge: NSSecureTextField!
    @IBOutlet var dummyKludgeWidthConstraint: NSLayoutConstraint!

    class func instantiateFromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "CreateEditViewController", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }

    deinit {
        NSLog("😎 DEINIT [CreateEditViewController]")
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let window = view.window else {
            return
        }

        if model == nil { 
            dismiss(nil)
            return
        }

        window.delegate = self
        window.setFrameUsingName(NSWindow.FrameAutosaveName(autosave))

        

        window.initialFirstResponder = textFieldTitle
        
        bindScreenCaptureBlock()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let node = getExistingOrNewEntry(newEntryParentGroupId: initialParentNodeId),
              let dbModel = database.commonModel else
        {
            NSLog("🔴 Could not load initial node!")
            return
        }

        model = EntryViewModel.fromNode(node, format: database.format, model: dbModel, sortCustomFields: !database.customSortOrderForFields)
        preEditModelClone = model.clone()

        setupUI()

        bindUiToModel()
        
        bindDoneButtonState()
    }

    func bindScreenCaptureBlock() {
        if let window = view.window {
            window.sharingType = Settings.sharedInstance().screenCaptureBlocked ? .none : .readOnly
        }
    }
    
    var sortedGroups: [Node]!
    
    func setupLocationUI() {
        let groups = database.allActiveGroups

        sortedGroups = groups.sorted { n1, n2 in
            let p1 = database.getGroupPathDisplayString(n1)
            let p2 = database.getGroupPathDisplayString(n2)
            return finderStringCompare(p1, p2) == .orderedAscending
        }
        popupLocation.menu?.removeAllItems()

        for group in sortedGroups {
            var title = database.getGroupPathDisplayString(group, rootGroupNameInsteadOfSlash: false)

            
            
            
            let clipLength = 72;
            if title.count > clipLength {
                let tail = title.suffix(clipLength - 3)
                title = String(format: "...%@", String(tail))
            }
            
            let item = NSMenuItem(title: title, action: #selector(onChangeLocation(sender:)), keyEquivalent: "")

            var icon = NodeIconHelper.getIconFor(group, predefinedIconSet: database.iconSet, format: database.format)
            
            let isCustom = group.icon?.isCustom ?? false
            
            if isCustom || database.iconSet != .sfSymbols {
                icon = scaleImage(icon, CGSize(width: 16, height: 16))
            }
            item.image = icon

            popupLocation.menu?.addItem(item)
        }

        

        if database.rootGroup.childRecordsAllowed {
            

            let title = database.getGroupPathDisplayString(database.rootGroup, rootGroupNameInsteadOfSlash: true)
            let attributes: [NSAttributedString.Key: Any] = [.font: FontManager.shared.italicBodyFont]
            let attributedString = NSAttributedString(string: title, attributes: attributes)

            let item = NSMenuItem(title: title, action: #selector(onChangeLocation(sender:)), keyEquivalent: "")
            item.attributedTitle = attributedString

            

            var icon = database.rootGroup.isUsingKeePassDefaultIcon ? Icon.house.image() : NodeIconHelper.getIconFor(database.rootGroup, predefinedIconSet: database.iconSet, format: database.format)
            
            let isCustom = database.rootGroup.icon?.isCustom ?? false
            
            if isCustom || database.iconSet != .sfSymbols {
                icon = scaleImage(icon, CGSize(width: 16, height: 16))
            }

            item.image = icon

            popupLocation.menu?.insertItem(item, at: 0)
            sortedGroups.insert(database.rootGroup, at: 0)
        }
    }

    func setupIcon() {
        imageViewIcon.clickable = true
        imageViewIcon.showClickableBorder = true
        imageViewIcon.onClick = { [weak self] in
            guard let self = self else { return }
            self.onIconClicked()
        }
    }

    func setupTitle() {
        textFieldTitle.onTextDidChange = { [weak self] in
            guard let self = self else { return }
            self.model.title = trim(self.textFieldTitle.stringValue)
            self.onModelEdited()
        }
        textFieldTitle.onImagePasted = { [weak self] in
            guard let self = self else { return }
            self.handlePasteImageIntoField()
        }
    }

    func setupUsername() {
        textFieldUsername.completions = Array(database.usernameSet)
        textFieldUsername.completionEnabled = database.showAutoCompleteSuggestions
        textFieldUsername.onTextDidChange = { [weak self] in
            guard let self = self else { return }
            self.model.username = trim(self.textFieldUsername.stringValue)
            self.onModelEdited()
        }
        textFieldUsername.onEndEditing = { [weak self] in
            guard let self = self else { return }
            self.checkForAndSkipDummyKludgeAutoFillAvoidanceField(self.textFieldUsername)
        }
        textFieldUsername.onImagePasted = { [weak self] in
            guard let self = self else { return }
            self.handlePasteImageIntoField()
        }

        popupButtonUsernameSuggestions.menu?.delegate = self
    }

    func setupUrl() {
        textFieldUrl.completions = Array(database.urlSet)
        textFieldUrl.completionEnabled = database.showAutoCompleteSuggestions
        textFieldUrl.onTextDidChange = { [weak self] in
            guard let self = self else { return }
            self.model.url = trim(self.textFieldUrl.stringValue)
            self.onModelEdited()
        }
        textFieldUrl.onImagePasted = { [weak self] in
            guard let self = self else { return }
            self.handlePasteImageIntoField()
        }
    }

    func setupEmail() {
        textFieldEmail.completions = Array(database.emailSet)
        textFieldEmail.completionEnabled = database.showAutoCompleteSuggestions
        textFieldEmail.onTextDidChange = { [weak self] in
            guard let self = self else { return }
            self.model.email = trim(self.textFieldEmail.stringValue)
            self.onModelEdited()
        }
        popupButtonEmailSuggestions.menu?.delegate = self
        textFieldEmail.onImagePasted = { [weak self] in
            guard let self = self else { return }
            self.handlePasteImageIntoField()
        }
    }

    func setupPassword() {
        if #available(macOS 11.0, *) {
            buttonPasswordPreferences.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
            buttonPasswordPreferences.symbolConfiguration = .init(scale: .large)

            buttonGeneratePassword.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
            buttonGeneratePassword.symbolConfiguration = .init(scale: .large)
        }
        passwordField.delegate = self
        passwordField.concealed = !Settings.sharedInstance().revealPasswordsImmediately
        popupButtonAlternativeSuggestions.menu?.delegate = self

        if #available(macOS 11.0, *) {
            dummyKludge.contentType = .oneTimeCode
            dummyKludgeWidthConstraint.constant = 0.0
        } else {
            dummyKludge.isHidden = true 
        }
    }

    func setupNotes() {
        textViewNotes.delegate = self
        
        textViewNotes.enabledTextCheckingTypes = 0
        textViewNotes.isAutomaticQuoteSubstitutionEnabled = false
        textViewNotes.isAutomaticTextReplacementEnabled = false
        textViewNotes.isAutomaticDashSubstitutionEnabled = false
        textViewNotes.isAutomaticLinkDetectionEnabled = false
        
        popupButtonNotesSuggestions.menu?.delegate = self

        borderScrollNotes.wantsLayer = true
        borderScrollNotes.layer?.cornerRadius = 5
    }

    func setupTOTP() {
        if #available(macOS 11.0, *) {
            buttonRemoveTOTP.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            buttonRemoveTOTP.contentTintColor = .systemOrange
        }

        NotificationCenter.default.addObserver(forName: .totpUpdate, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.bindTOTP()
        }
    }
    
    func setupUI() {
        setupLocationUI()
        setupIcon()
        setupTitle()
        setupUsername()
        setupUrl()
        setupEmail()
        setupPassword()
        setupNotes()
        setupAttachments()
        setupCustomFieldsTable()
        setupTOTP()
        setupExpiry()
        setupTags()

        disableFieldsBasedOnFormat()
    }

    func disableFieldsBasedOnFormat() {
        if database.format == .keePass1 {
            tableViewCustomFields.isEnabled = false
            buttonAddField.isEnabled = false
            tagsField.isEnabled = false
            tagsField.placeholderString = NSLocalizedString("unsupported_by_database_format", comment: "Unsupported by Database Format")

            textFieldEmail.isEnabled = false
            textFieldEmail.placeholderString = NSLocalizedString("unsupported_by_database_format", comment: "Unsupported by Database Format")

            tableViewCustomFields.emptyMessageProvider = { [weak self] in
                self?.noneSingleSelectionMessageProvider()
            }
        } else if database.format == .passwordSafe {
            tableViewAttachments.isEnabled = false
            tableViewCustomFields.isEnabled = false
            buttonAddField.isEnabled = false
            tagsField.isEnabled = false
            tagsField.placeholderString = NSLocalizedString("unsupported_by_database_format", comment: "Unsupported by Database Format")

            tableViewCustomFields.emptyMessageProvider = { [weak self] in
                self?.noneSingleSelectionMessageProvider()
            }
            tableViewAttachments.emptyMessageProvider = { [weak self] in
                self?.noneSingleSelectionMessageProvider()
            }
        }
    }

    func noneSingleSelectionMessageProvider() -> NSAttributedString {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraphStyle,
                                                         .font: FontManager.shared.bodyFont,
                                                         .foregroundColor: NSColor.secondaryLabelColor]

        let final = NSLocalizedString("unsupported_by_database_format", comment: "Unsupported by Database Format")

        let foo = NSMutableAttributedString(string: final, attributes: attributes)




        return foo
    }

    @objc func onChangeLocation(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupLocation.menu?.index(of: sender) else {
            NSLog("🔴 Could not find this menu item in the menu?!")
            return
        }

        let node = sortedGroups[idx]



        model.parentGroupUuid = node.uuid

        onModelEdited()

        bindLocation()
    }

    func bindLocation() {
        guard let idx = sortedGroups.firstIndex(where: { group in
            if model.parentGroupUuid == nil {
                return group == database.rootGroup
            } else {
                return group.uuid == model.parentGroupUuid
            }
        })
        else {
            NSLog("🔴 Could not find this items parent group in the sorted groups list!")
            return
        }

        popupLocation.selectItem(at: idx)
    }

    func bindUiToModel() {
        textFieldTitle.stringValue = model.title
        imageViewIcon.image = NodeIconHelper.getNodeIcon(model.icon, predefinedIconSet: database.iconSet)
        textFieldUsername.stringValue = model.username
        textFieldUrl.stringValue = model.url
        textFieldEmail.stringValue = model.email
        passwordField.stringValue = model.password
        textViewNotes.string = model.notes
        bindTOTP()
        bindExpiry()
        bindTags()
        bindLocation()
        bindPasswordUI()
    }

    

    func windowDidEndLiveResize(_: Notification) {
        view.window?.saveFrame(usingName: autosave)
    }

    func getExistingOrNewEntry(newEntryParentGroupId: UUID?) -> Node? {
        let node: Node

        if initialNodeId != nil {
            guard let found = database.getItemBy(initialNodeId!) else {
                NSLog("🔴 Could not load node")
                return nil
            }

            node = found
        } else {
            var parentGroup: Node?

            if let newEntryParentGroupId = newEntryParentGroupId {
                parentGroup = database.getItemBy(newEntryParentGroupId)
            }

            if parentGroup == nil {
                NSLog("🔴 Could not load parent node! Trying Root Group")

                if database.format == .keePass1 {
                    parentGroup = database.rootGroup.childGroups.first
                }
                else {
                    parentGroup = database.rootGroup
                }
            }

            if let parentGroup = parentGroup {
                node = createNewEntryNode(parentGroup)
            }
            else {
                NSLog("🔴 Could not load parent node!")
                return nil
            }
        }

        return node
    }

    let CustomFieldDragAndDropId: String = "com.markmcguill.strongbox.drag.and.drop.Custom-Field-Edit-Reorder"

    fileprivate func setupCustomFieldsTable() {
        borderScrollCustomFields.wantsLayer = true
        borderScrollCustomFields.layer?.cornerRadius = 5

        tableViewCustomFields.register(NSNib(nibNamed: NSNib.Name(GenericAutoLayoutTableViewCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier)
        tableViewCustomFields.register(NSNib(nibNamed: NSNib.Name("CustomFieldTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("CustomFieldValueCellIdentifier"))

        if #available(macOS 11.0, *) {
            buttonRemoveField.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            buttonEditField.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
            buttonAddField.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        }

        tableViewCustomFields.doubleAction = #selector(onEditField(_:))
        tableViewCustomFields.onEnterKey = { [weak self] in
            self?.onEditField(nil)
        }
        tableViewCustomFields.onDeleteKey = { [weak self] in
            self?.onRemoveField(nil)
        }

        

        tableViewCustomFields.registerForDraggedTypes([NSPasteboard.PasteboardType(CustomFieldDragAndDropId)])

        tableViewCustomFields.delegate = self
        tableViewCustomFields.dataSource = self

        bindCustomFieldsButtons()
    }

    func bindCustomFieldsButtons() {
        buttonRemoveField.isEnabled = tableViewCustomFields.selectedRowIndexes.count != 0
        buttonEditField.isEnabled = tableViewCustomFields.selectedRowIndexes.count == 1
        buttonRemoveField.contentTintColor = tableViewCustomFields.selectedRowIndexes.count != 0 ? NSColor.systemOrange : nil
        buttonEditField.contentTintColor = tableViewCustomFields.selectedRowIndexes.count == 1 ? NSColor.linkColor : nil
    }

    func refreshCustomFields() {
        tableViewCustomFields.reloadData()
        bindCustomFieldsButtons()
    }

    private func createNewEntryNode(_ parentGroup: Node) -> Node {
        return database.getDefaultNewEntryNode(parentGroup)
    }

    @IBAction func onDiscard(_: Any) {
        let isDifferent = model.isDifferent(from: preEditModelClone)

        if isDifferent {
            MacAlerts.yesNo(NSLocalizedString("item_details_vc_discard_changes", comment: "Discard Changes?"),
                            informativeText: NSLocalizedString("item_details_vc_are_you_sure_discard_changes", comment: "Are you sure you want to discard all your changes?"),
                            window: view.window, completion: { [weak self] response in
                                if response {
                                    guard let self = self else { return }
                                    self.dismiss(nil)
                                }
                            })
        } else {
            dismiss(nil)
        }
    }

    func messageProblemSaving() {
        MacAlerts.info(NSLocalizedString("item_details_problem_saving", comment: "Problem Saving"),
                       informativeText: NSLocalizedString("item_details_problem_saving", comment: "Problem Saving"),
                       window: view.window,
                       completion: nil)
    }

    @IBAction func onSaveAndDismiss(_: Any) {
        let isDifferent = model.isDifferent(from: preEditModelClone)
        let isSaveable = (isDifferent || initialNodeId == nil)

        if isSaveable {
            save(dismissAfterSave: true)
        }
        else if !isDifferent { 
            dismiss(nil)
        }
    }

    @IBAction func onSave(_: Any) {
        save(dismissAfterSave: false)
    }

    func save(dismissAfterSave: Bool) {
        let value = model.password

        if trim(value) != value {
            MacAlerts.twoOptions(withCancel: NSLocalizedString("field_tidy_title_tidy_up_field", comment: "Tidy Up Field?"),
                                 informativeText: NSLocalizedString("field_tidy_message_tidy_up_password", comment: "There are some blank characters (e.g. spaces, tabs) at the start or end of your password.\n\nShould Strongbox tidy up these extraneous characters?"),
                                 option1AndDefault: NSLocalizedString("field_tidy_choice_tidy_up_field", comment: "Tidy Up"),
                                 option2: NSLocalizedString("field_tidy_choice_dont_tidy", comment: "Don't Tidy"),
                                 window: view.window) { [weak self] response in
                if response == 0 {
                    self?.model.password = trim(value)
                    self?.postValidationSave(dismissAfterSave: dismissAfterSave)
                } else if response == 1 {
                    self?.postValidationSave(dismissAfterSave: dismissAfterSave)
                }
            }
        } else {
            postValidationSave(dismissAfterSave: dismissAfterSave)
        }
    }

    func postValidationSave(dismissAfterSave: Bool) {
        let nodeId: UUID

        if initialNodeId == nil {
            guard let node = getExistingOrNewEntry(newEntryParentGroupId: model.parentGroupUuid) else {
                NSLog("🔴 Could not load node for save!")
                messageProblemSaving()
                return
            }

            let success = model.apply(to: node,
                                      databaseFormat: database.format,
                                      legacySupplementaryTotp: Settings.sharedInstance().addLegacySupplementaryTotpCustomFields,
                                      addOtpAuthUrl: Settings.sharedInstance().addOtpAuthUrl)

            if !success {
                NSLog("🔴 Could not apply model changes")
                messageProblemSaving()
                return
            }

            guard let parent = node.parent else {
                NSLog("🔴 Could not apply model changes")
                messageProblemSaving()
                return
            }

            let added = database.addItem(node, parent: parent)

            if !added {
                NSLog("🔴 Could not add child")
                messageProblemSaving()
                return
            }

            nodeId = node.uuid
        } else {
            if !database.applyEditsAndMoves(model, toNode: initialNodeId!) {
                NSLog("🔴 Could not apply model changes")
                messageProblemSaving()
                return
            }

            nodeId = initialNodeId!
        }

        

        setIconAndSave(nodeId, dismissAfterSave: dismissAfterSave)
    }

    func setIconAndSave(_ nodeId: UUID, dismissAfterSave: Bool) {
        guard let node = database.getItemBy(nodeId) else {
            NSLog("🔴 Could not load node for setIconAndExit")
            messageProblemSaving()
            return
        }

        if iconExplicitlyChanged {
            iconExplicitlyChanged = false
            database.setItemIcon(node, icon: model.icon)
            onSaveDone(node, dismissAfterSave: dismissAfterSave)
        } else {
            let urlChanged = model.url.compare(preEditModelClone.url) != .orderedSame

            if initialNodeId == nil || urlChanged {
                
                

                let formatGood = database.format == .keePass || database.format == .keePass4
                let featureAvailable = Settings.sharedInstance().isPro

                if featureAvailable, formatGood, model.url.count > 0, let _ = model.url.urlExtendedParse {
                    if !database.promptedForAutoFetchFavIcon {
                        MacAlerts.yesNo(NSLocalizedString("item_details_prompt_auto_fetch_favicon_title", comment: "Auto Fetch FavIcon?"),
                                        informativeText: NSLocalizedString("item_details_prompt_auto_fetch_favicon_message", comment: "Strongbox can automatically fetch FavIcons when an new entry is created or updated.\n\nWould you like to Strongbox to do this?"),
                                        window: view.window,
                                        completion: { [weak self] yesNo in
                                            guard let self = self else { return }

                                            self.database.promptedForAutoFetchFavIcon = true
                                            self.database.downloadFavIconOnChange = yesNo

                                            self.maybeDownloadFavIconAndExit(node, dismissAfterSave: dismissAfterSave)
                                        })
                    } else {
                        maybeDownloadFavIconAndExit(node, dismissAfterSave: dismissAfterSave)
                    }
                } else {
                    onSaveDone(node, dismissAfterSave: dismissAfterSave)
                }
            } else {
                onSaveDone(node, dismissAfterSave: dismissAfterSave)
            }
        }
    }

    func maybeDownloadFavIconAndExit(_ node: Node, dismissAfterSave: Bool) {
#if NO_FAVICON_LIBRARY 
        onSaveDone(node, dismissAfterSave: dismissAfterSave)
#else
        if database.downloadFavIconOnChange { 
            let url = node.fields.url.urlExtendedParse
            if url == nil {
                onSaveDone(node, dismissAfterSave: dismissAfterSave)
                return
            }

            macOSSpinnerUI.sharedInstance().show(NSLocalizedString("set_icon_vc_progress_downloading_favicon", comment: "Downloading FavIcon"), viewController: self)

            DispatchQueue.global().async {
                FavIconManager.sharedInstance().downloadPreferred(url!, options: .express()) { maybeImage in
                    DispatchQueue.main.async { [weak self] in
                        macOSSpinnerUI.sharedInstance().dismiss()

                        guard let self = self else { return }

                        if maybeImage != nil {
                            self.database.setItemIcon(node, icon: NodeIcon.withCustomImage(maybeImage!))
                        }

                        self.onSaveDone(node, dismissAfterSave: dismissAfterSave)
                    }
                }
            }
        } else {
            onSaveDone(node, dismissAfterSave: dismissAfterSave)
        }
#endif
    }

    func onSaveDone(_ node: Node, dismissAfterSave: Bool) {
        NSLog("✅ onSaveDone")

        
        
        
        database.document?.save(nil)
                
        if dismissAfterSave {
            database.nextGenSelectedItems = [node.uuid]
            dismiss(nil)
        }
        else {
            guard let dbModel = database.commonModel else {
                NSLog("🔴 Could not load common model!")
                messageProblemSaving()
                return
            }

            model = EntryViewModel.fromNode(node, format: database.format, model: dbModel, sortCustomFields: !database.customSortOrderForFields)
            preEditModelClone = model.clone()
            
            initialNodeId = node.uuid 
            
            bindUiToModel()

            bindDoneButtonState()
        }
    }

    func onModelEdited() {
        bindDoneButtonState()
    }

    @objc
    var isEditsInProgress: Bool {
        return model.isDifferent(from: preEditModelClone)
    }

    func bindDoneButtonState() {
        let isDifferent = model.isDifferent(from: preEditModelClone)
        let isSaveable = isDifferent || initialNodeId == nil

        buttonDone.isEnabled = isSaveable || !isDifferent
        
        buttonDone.title = isSaveable ?  NSLocalizedString("mac_create_or_edit_commit_changes_and_close", comment: "Commit & Close (⌘⏎)") :
        NSLocalizedString("mac_create_or_edit_commit_close", comment: "Close (⌘⏎)");
        
        buttonSave.isEnabled = isSaveable
        
        buttonCancel.title = isDifferent ? NSLocalizedString("discard_changes", comment: "Discard Changes") : NSLocalizedString("generic_cancel", comment: "Cancel")

        if #available(macOS 10.12.2, *) {
            buttonCancel.bezelColor = isDifferent ? .systemRed : nil
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        if textField == passwordField {
            model.password = passwordField.stringValue 
            onModelEdited()
            bindPasswordUI()
        } else if textField == tagsField {
            onTagsFieldEdited()
        } else {

        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            checkForAndSkipDummyKludgeAutoFillAvoidanceField(textField)

            if textField == tagsField {
                onTagsFieldEndEditing()
            }
        }
    }

    var selectPredefinedIconController: SelectPredefinedIconController? 
    func onIconClicked() {
        if database.format == .passwordSafe {
            return
        }

        selectPredefinedIconController = SelectPredefinedIconController(windowNibName: NSNib.Name("SelectPredefinedIconController"))
        guard let selectPredefinedIconController = selectPredefinedIconController else {
            return
        }

        selectPredefinedIconController.iconPool = Array(database.customIcons)
        selectPredefinedIconController.hideSelectFile = !database.formatSupportsCustomIcons
        selectPredefinedIconController.hideFavIconButton = !database.formatSupportsCustomIcons || !StrongboxProductBundle.supportsFavIconDownloader
        
        selectPredefinedIconController.onSelectedItem = { [weak self] (icon: NodeIcon?, showFindFavIcons: Bool) in
            guard let self = self else { return }
            self.onIconSelected(icon: icon, showFindFavIcons: showFindFavIcons)
        }
        selectPredefinedIconController.iconSet = database.iconSet

        view.window?.beginSheet(selectPredefinedIconController.window!, completionHandler: nil)
    }

    func onIconSelected(icon: NodeIcon?, showFindFavIcons: Bool) {
        if showFindFavIcons {
            showFavIconDownloader()
        } else {
            explicitSetIconAndUpdateUI(icon)
        }
    }

    func showFavIconDownloader() {
        #if !NO_FAVICON_LIBRARY
        let vc = FavIconDownloader.newVC()

        

        let dummyNode = createNewEntryNode(database.rootGroup)
        model.apply(to: dummyNode, databaseFormat: database.format, legacySupplementaryTotp: false, addOtpAuthUrl: true)

        vc.nodes = [dummyNode]
        vc.viewModel = database

        vc.onDone = { [weak self] (go: Bool, selectedFavIcons: [UUID: NSImage]?) in
            guard let self = self else {
                return
            }

            if go {
                guard let selectedFavIcons = selectedFavIcons else {
                    NSLog("🔴 Select FavIcons null!")
                    return
                }

                guard let single = selectedFavIcons.first else {
                    NSLog("🔴 More than 1 FavIcons returned!")
                    return
                }

                if single.key != dummyNode.uuid {
                    NSLog("🔴 single.key != dummyNode.uuid")
                    return
                }

                self.explicitSetIconAndUpdateUI(NodeIcon.withCustomImage(single.value))
            }
        }

        presentAsSheet(vc)
        #endif
    }

    func explicitSetIconAndUpdateUI(_ icon: NodeIcon?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.model.icon = icon
            self.imageViewIcon.image = NodeIconHelper.getNodeIcon(self.model.icon, predefinedIconSet: self.database.iconSet)
            self.iconExplicitlyChanged = true
            self.onModelEdited()
        }
    }

    @IBAction func onButtonGenerate(_: Any) {
        onGeneratePassword(database.generatePassword())
    }

    func onGeneratePassword(_ password: String) {
        model.password = trim(password)
        passwordField.stringValue = model.password
        onModelEdited()
        bindPasswordUI()
    }

    func onGenerateUsername(_ username: String) {
        model.username = trim(username)
        textFieldUsername.stringValue = model.username
        onModelEdited()
    }

    func onInsertSuggestionIntoNotes(_ suggestion: String) {
        textViewNotes.insertText(suggestion, replacementRange: textViewNotes.selectedRange())
    }

    func onGenerateEmail(_ email: String) {
        model.email = trim(email)
        textFieldEmail.stringValue = model.email
        onModelEdited()
    }

    func bindPasswordUI() {
        PasswordStrengthUIHelper.bindPasswordStrength(model.password, labelStrength: labelStrength, progress: progressStrength)
        
        let history = getPasswordHistoryMenu()
        buttonHistory.menu = history
        buttonHistory.isHidden = history == nil
    }
    
    func getPasswordHistoryMenu( ) -> NSMenu? {
        guard (database.format == .keePass4 || database.format == .keePass),
              let initialNodeId,
              let item = database.getItemBy(initialNodeId) else {
            return nil
        }
        
        return PasswordHistoryHelper.getPasswordHistoryMenu( item: item )
    }

    @IBAction func onGenerationSettings(_: Any) {
        let vc = PasswordGenerationPreferences.fromStoryboard()

        vc.onClickSampleOverride = { [weak self] samplePassword in
            guard let self = self else { return }

            self.onGeneratePassword(samplePassword)
            vc.dismiss(nil)
        }

        present(vc, asPopoverRelativeTo: NSZeroRect, of: buttonPasswordPreferences, preferredEdge: .minY, behavior: .transient)
    }

    fileprivate func refreshSuggestionsMenu(_ menu: NSMenu, suggestions: [String], colorize: Bool, easyReadFont: Bool, image: NSImage? = nil) {
        while menu.items.count > 1 {
            menu.items.removeLast()
        }

        let colorize = Settings.sharedInstance().colorizePasswords && colorize
        let colorBlind = Settings.sharedInstance().colorizeUseColorBlindPalette
        let dark = DarkMode.isOn

        for suggestion in suggestions {
            if suggestion == "_GENERATED_" {
                menu.addItem(NSMenuItem.separator())
                let item = NSMenuItem(title: NSLocalizedString("menu_item_header_randomly_generated_suggestions", comment: "Randomly Generated"), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else if suggestion == "_POPULAR_" {
                let item = NSMenuItem(title: NSLocalizedString("menu_item_header_most_used_suggestions", comment: "Most Used"), action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                let font = easyReadFont ? FontManager.shared.easyReadFont : FontManager.shared.bodyFont

                let colored = ColoredStringHelper.getColorizedAttributedString(suggestion, colorize: colorize, darkMode: dark, colorBlind: colorBlind, font: font)

                let item = NSMenuItem(title: "", action: #selector(onAlternativeSelection), keyEquivalent: "")
                item.attributedTitle = colored

                if let image = image {
                    item.image = image
                }

                menu.addItem(item)
            }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        var altSuggestions: [String] = []
        var colorize = true
        var easyReadFont = true
        var image: NSImage?

        if menu == popupButtonAlternativeSuggestions.menu || menu == popupButtonNotesSuggestions.menu {
            altSuggestions.append("_GENERATED_")

            altSuggestions.append(PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig))
            altSuggestions.append(PasswordMaker.sharedInstance().generateAlternate(for: Settings.sharedInstance().passwordGenerationConfig))
            altSuggestions.append(database.generatePassword())
            altSuggestions.append(database.generatePassword())
            altSuggestions.append(PasswordMaker.sharedInstance().generateUsername().lowercased())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateRandomWord())
            altSuggestions.append(PasswordMaker.sharedInstance().generateRandomWord())
            altSuggestions.append(String(arc4random()))
            altSuggestions.append(String(format: "0x%0.8X", arc4random()))
            altSuggestions.append(String(arc4random(), radix: 2))

            let futureDate = Date.randomDate(range: 365 * 6) as NSDate
            altSuggestions.append(futureDate.friendlyDateStringVeryShortDateOnly)
        } else if menu == popupButtonUsernameSuggestions.menu {
            if database.mostPopularUsernames.count > 0 {
                altSuggestions.append("_POPULAR_")

                for popular in database.mostPopularUsernames.prefix(4) {
                    if popular.count != 0 {
                        altSuggestions.append(popular)
                    }
                }
            }

            altSuggestions.append("_GENERATED_")
            altSuggestions.append(PasswordMaker.sharedInstance().generateUsername().lowercased())
            altSuggestions.append(PasswordMaker.sharedInstance().generateUsername().lowercased())
            altSuggestions.append(PasswordMaker.sharedInstance().generateUsername().lowercased())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateRandomWord())
        } else if menu == popupButtonEmailSuggestions.menu {
            if database.mostPopularEmails.count > 0 {
                altSuggestions.append("_POPULAR_")

                for popular in database.mostPopularEmails.prefix(4) {
                    if popular.count != 0 {
                        altSuggestions.append(popular)
                    }
                }
            }

            altSuggestions.append("_GENERATED_")

            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
            altSuggestions.append(PasswordMaker.sharedInstance().generateEmail())
        } else if menu == popupButtonTagsSuggestions.menu {
            var popular = database.mostPopularTags
            popular.removeAll { tag in
                model.tags.contains(tag)
            }

            if popular.count > 0 {
                altSuggestions.append("_POPULAR_")

                for popular in popular.prefix(10) {
                    if popular.count != 0 {
                        altSuggestions.append(popular)
                    }
                }
            } else {
                
                if let cell = popupButtonTagsSuggestions.cell as? NSPopUpButtonCell {
                    cell.arrowPosition = .noArrow
                }
            }

            colorize = false
            easyReadFont = false

            if #available(macOS 11.0, *) {
                image = NSImage(systemSymbolName: "tag", accessibilityDescription: nil)
            }
        }

        refreshSuggestionsMenu(menu, suggestions: altSuggestions, colorize: colorize, easyReadFont: easyReadFont, image: image)
    }

    @objc
    func onAlternativeSelection(_ sender: Any) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }

        if menuItem.menu == popupButtonAlternativeSuggestions.menu {
            onGeneratePassword(menuItem.title)
        } else if menuItem.menu == popupButtonEmailSuggestions.menu {
            onGenerateEmail(menuItem.title)
        } else if menuItem.menu == popupButtonUsernameSuggestions.menu {
            onGenerateUsername(menuItem.title)
        } else if menuItem.menu == popupButtonNotesSuggestions.menu {
            onInsertSuggestionIntoNotes(menuItem.title)
        } else if menuItem.menu == popupButtonTagsSuggestions.menu {
            model.addTag(trim(menuItem.title))
            bindTags()
            onModelEdited()
        }
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {


        if textView == textViewNotes {
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                textView.window?.selectNextKeyView(nil)
                return true
            } else if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                textView.window?.selectPreviousKeyView(nil)
                return true
            }
        }

        return false
    }

    func textDidChange(_ notification: Notification) {
        if let textView = notification.object as? NSTextView {


            guard let newNotes = textView.textStorage?.string else {
                NSLog("🔴 Problem getting text from textViewNotes")
                return
            }

            model.notes = newNotes
            onModelEdited()
        }
    }

    func checkForAndSkipDummyKludgeAutoFillAvoidanceField(_ textField: NSTextField) {
        performSelector(onMainThread: #selector(skipDummyKludgeAutoFillAvoidanceField), with: textField, waitUntilDone: false)
    }

    @objc func skipDummyKludgeAutoFillAvoidanceField(_ sender: Any?) {
        guard let event = view.window?.currentEvent, event.type == .keyDown else { 

            return
        }

        if let textViewFound = view.window?.firstResponder as? NSTextView,
            let dummyView = view.window?.fieldEditor(false, for: dummyKludge) {
            if textViewFound == dummyView {
                if let textFieldFrom = sender as? NSTextField {

                    if textFieldFrom == textFieldUsername {
                        view.window?.makeFirstResponder(passwordField)
                    } else if textFieldFrom == passwordField {
                        view.window?.makeFirstResponder(textFieldUsername)
                    }
                }
            }
        }
    }

    @objc func paste(_: Any?) -> Any? {
        handlePasteImageIntoField()
    }

    

    fileprivate func setupAttachments() {
        borderScrollAttachments.wantsLayer = true
        borderScrollAttachments.layer?.cornerRadius = 5

        tableViewAttachments.register(NSNib(nibNamed: NSNib.Name(TitleAndIconCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: TitleAndIconCell.NibIdentifier)

        tableViewAttachments.register(NSNib(nibNamed: NSNib.Name(GenericAutoLayoutTableViewCell.NibIdentifier.rawValue), bundle: nil), forIdentifier: GenericAutoLayoutTableViewCell.NibIdentifier)

        if #available(macOS 10.13, *) {
            tableViewAttachments.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
            tableViewAttachments.registerForDraggedTypes([.fileURL])
        }

        tableViewAttachments.setDraggingSourceOperationMask(.copy, forLocal: false)
        tableViewAttachments.onDeleteKey = { [weak self] in
            self?.onDeleteAttachments(nil)
        }
        tableViewAttachments.onEnterKey = { [weak self] in
            self?.previewSelectedItem()
        }
        tableViewAttachments.onSpaceBar = { [weak self] in
            self?.previewSelectedItem()
        }

        if #available(macOS 11.0, *) {
            buttonDeleteAttachment.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            buttonAddAttachment.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            buttonSaveAs.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
            buttonPreview.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        }

        tableViewAttachments.doubleAction = #selector(onPreview(_:))

        
        

        tableViewAttachments.delegate = self
        tableViewAttachments.dataSource = self

        

        bindAttachmentButtons()
    }

    func bindAttachmentButtons() {
        buttonAddAttachment.isEnabled = canAddAttachment
        buttonDeleteAttachment.isEnabled = tableViewAttachments.selectedRowIndexes.count != 0
        buttonSaveAs.isEnabled = tableViewAttachments.selectedRowIndexes.count == 1
        buttonPreview.isEnabled = tableViewAttachments.selectedRowIndexes.count != 0
        buttonDeleteAttachment.contentTintColor = tableViewAttachments.selectedRowIndexes.count != 0 ? NSColor.systemOrange : nil
        buttonSaveAs.contentTintColor = tableViewAttachments.selectedRowIndexes.count == 1 ? NSColor.linkColor : nil
        buttonPreview.contentTintColor = tableViewAttachments.selectedRowIndexes.count != 0 ? NSColor.linkColor : nil
    }

    var canAddAttachment: Bool {
        if database.format == .keePass1 {
            return model.attachments.count == 0
        }

        return database.format != .passwordSafe
    }

    func handlePasteImageIntoField() {
        if canAddAttachment {
            guard let image = NSImage(pasteboard: NSPasteboard.general) else {
                NSLog("🔴 Could not get clipboard image")
                return
            }

            askToAddClipboardImageAsAttachment(image)
        }
    }

    func askToAddClipboardImageAsAttachment(_ image: NSImage) {
        let vc = PastedImagePreviewer.fromStoryboard()
        vc.image = image
        vc.onGo = {
            self.addClipboardImageAsAttachment(image)
        }

        presentAsSheet(vc)
    }

    func addClipboardImageAsAttachment(_ image: NSImage) {
        guard let imageData = image.tiffRepresentation,
              let bmpRep = NSBitmapImageRep(data: imageData),
              let pngData = bmpRep.representation(using: .png, properties: [:])
        else {
            NSLog("🔴 Could not get PNG representation of image")
            MacAlerts.info(NSLocalizedString("generic_error", comment: "Error"), window: view.window)
            return
        }

        let databaseAttachment = DatabaseAttachment(nonPerformantWith: pngData, compressed: true, protectedInMemory: true)

        let filename = String(format: NSLocalizedString("pasted_image_attachment_at_time_filename_png_fmt", comment: "paste-at-%@.png"), NSDate().fileNameCompatibleDateTimePrecise)

        addAttachment(filename, databaseAttachment)
    }

    func addAttachment(_ filename: String, _ databaseAttachment: DatabaseAttachment) {
        var uniqueFilename = filename

        if model.attachments.allKeys().contains(filename as NSString) {
            let foo = filename as NSString
            uniqueFilename = String(format: "%@-%@.%@", foo.deletingPathExtension, NSDate().fileNameCompatibleDateTimePrecise, foo.pathExtension)
        }

        model.insertAttachment(uniqueFilename, attachment: databaseAttachment)

        refreshAttachments()
        onModelEdited()

        selectAttachmentWithName(uniqueFilename)
    }

    func deleteAttachment(_ filename: String) {
        model.attachments.remove(filename as NSString)
        refreshAttachments()
        onModelEdited()
    }

    func selectAttachmentWithName(_ name: String) {
        guard let idx = model.attachments.allKeys().firstIndex(of: name as NSString) else {
            return
        }

        tableViewAttachments.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        tableViewAttachments.scrollToVisible(tableViewAttachments.rect(ofRow: idx))
    }

    func refreshAttachments() {
        tableViewAttachments.reloadData()
        bindAttachmentButtons()
    }

    

    override func dismiss(_ sender: Any?) {
        super.dismiss(sender)

        NotificationCenter.default.removeObserver(self)
    }

    @IBOutlet var stackViewTotpOptions: NSStackView!
    @objc func bindTOTP() {
        stackViewTOTPDisplay.isHidden = model.totp == nil
        stackViewTotpOptions.isHidden = model.totp != nil

        if let totp = model.totp {
            let current = NSDate().timeIntervalSince1970
            let period = totp.period

            let remainingSeconds = period - (current.truncatingRemainder(dividingBy: period))

            labelTotp.stringValue = totp.password
            labelTotp.textColor = (remainingSeconds < 5) ? .systemRed : (remainingSeconds < 9) ? .systemOrange : .controlTextColor

            progressTotp.minValue = 0
            progressTotp.maxValue = totp.period
            progressTotp.doubleValue = remainingSeconds
        }
    }

    @IBAction func onAddTOTP(_: Any) {
        let alert = MacAlerts()

        if let str = alert.input(NSLocalizedString("item_details_setup_totp_secret_message", comment: "Please enter the secret or an OTPAuth URL"),
                                 defaultValue: "",
                                 allowEmpty: false)
        {
            setTotpWithString(string: str, steam: false)
        }
    }

    @IBAction func onAddSteamTOTP(_: Any) {
        let alert = MacAlerts()

        if let str = alert.input(NSLocalizedString("item_details_setup_totp_secret_message", comment: "Please enter the secret or an OTPAuth URL"),
                                 defaultValue: "",
                                 allowEmpty: false)
        {
            setTotpWithString(string: str, steam: true)
        }
    }
    
    func setTotpFromQrCodeScanner ( _ totpString : String ) {
        setTotpWithString(string: totpString, steam: false)
        
        if Settings.sharedInstance().autoCommitScannedTotp {
            save(dismissAfterSave: false)
        }
    }

    func setTotpWithString(string: String, steam: Bool) {
        if let token = NodeFields.getOtpToken(from: string, forceSteam: steam, issuer: model.title, username: model.username) {
            model.totp = token

            bindTOTP()

            onModelEdited()
        } else {
            MacAlerts.info(NSLocalizedString("item_details_setup_totp_failed_title", comment: "Failed to Set TOTP"),
                           informativeText: NSLocalizedString("item_details_setup_totp_failed_message", comment: "Could not set TOTP because it could not be initialized."),
                           window: view.window,
                           completion: nil)
        }
    }

    @IBAction func onScanForTotpQRCode(_ sender: Any) {
        performSegue(withIdentifier: NSStoryboardSegue.Identifier("segueToQrCodeScanner"), sender: nil)
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == "segueToQrCodeScanner" {
            if let vc = segue.destinationController as? QRCodeScanner {
                vc.onSetTotp = { [weak self] totpString in
                    self?.setTotpFromQrCodeScanner(totpString)
                }
            }
        }
    }
    
    func scanPhotoLibraryImageForQRCode() {}

    @IBAction func onRemoveTOTP(_: Any) {
        MacAlerts.areYouSure(NSLocalizedString("are_you_sure_clear_totp", comment: "Are you sure you want to clear the TOTP for this entry?"), window: view.window) { [weak self] response in
            if response {
                self?.model.totp = nil
                self?.bindTOTP()
                self?.onModelEdited()
            }
        }
    }

    

    func setupExpiry() {
        if #available(macOS 11.0, *) {
            buttonClearExpiry.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            buttonClearExpiry.contentTintColor = .systemOrange
        }
    }

    @IBOutlet var datePickerExpiry: NSDatePicker!
    func bindExpiry() {
        buttonSetExpiry.isHidden = model.expires != nil
        stackViewAdjustExpiry.isHidden = model.expires == nil
        datePickerExpiry.dateValue = model.expires ?? Date()
    }

    @IBAction func onSetExpiry(_: Any) {
        let now = Date()

        model.expires = now.addMonth(n: 3)

        onModelEdited()
        bindExpiry()
    }

    @IBAction func onClearExpiry(_: Any) {
        MacAlerts.areYouSure(NSLocalizedString("are_you_sure_clear_expiry", comment: "Are you sure you want to clear the expiry for this entry?"), window: view.window) { [weak self] response in
            if response {
                self?.model.expires = nil

                self?.onModelEdited()

                self?.bindExpiry()
            }
        }
    }

    @IBAction func onChangeExpiry(_: Any) {
        model.expires = datePickerExpiry.dateValue

        onModelEdited()

        bindExpiry()
    }

    

    func setupTags() {





        popupButtonTagsSuggestions.menu?.delegate = self
        tagsField.delegate = self
    }

    func bindTags() {
        tagsField.objectValue = model.tags

        var popular = database.mostPopularTags
        popular.removeAll { tag in
            model.tags.contains(tag)
        }

        if let cell = popupButtonTagsSuggestions.cell as? NSPopUpButtonCell {
            cell.arrowPosition = popular.count == 0 ? .noArrow : .arrowAtBottom
        }

        tagsField.explicitResizeToFitContent()
    }

    func tokenField(_: NSTokenField, completionsForSubstring substring: String, indexOfToken _: Int, indexOfSelectedItem _: UnsafeMutablePointer<Int>?) -> [Any]? {
        guard let existingTags = tagsField.objectValue as? [String] else {
            return []
        }

        let allTags = database.tagSet

        return allTags.filter { tag in
            tag.starts(with: substring) && !existingTags.contains(tag)
        }
    }

    func tokenField(_: NSTokenField, shouldAdd tokens: [Any], at _: Int) -> [Any] {
        guard let tokens = tokens as? [String] else {
            NSLog("🔴 Couldn't get tagsFields as array")
            return []
        }

        var allowed = tokens



        allowed.removeAll { tag in
            model.tags.contains(tag)
        }

        if !allowed.isEmpty {
            for newTag in allowed {
                model.addTag(newTag)
            }


            onModelEdited()
        }


        return allowed
    }

    func onTagsFieldEdited() {
        NSLog("onTagsFieldEdited: [%@]", String(describing: tagsField.objectValue))

        guard let existingTags = tagsField.objectValue as? [String] else {
            return
        }

        let modelTags = Set(model.tags)
        let fieldTags = Set(existingTags)

        let deleted = modelTags.subtracting(fieldTags)
        if !deleted.isEmpty {
            for deletedTag in deleted {
                model.removeTag(deletedTag)
            }



            onModelEdited()
        }
    }

    func onTagsFieldEndEditing() {
        guard let existingTags = tagsField.objectValue as? [String] else {
            return
        }
        
        let splitByDelimter = existingTags.flatMap { t in
            return Utils.getTagsFromTagString(t)
        }



        let fieldTags = Set(splitByDelimter)

        model.resetTags(fieldTags)
        onModelEdited()
        bindTags()
    }

    

    @objc func onAttachmentNameEdited(_ sender: Any?) {
        guard let textField = sender as? NSTextField else {
            return
        }

        let selectedIdx = tableViewAttachments.selectedRow
        if selectedIdx >= 0, selectedIdx < model.attachments.count {
            let key = model.attachments.allKeys()[selectedIdx]
            guard let attachment = model.attachments[key] else {
                return
            }
            let oldTitle = key as String
            let newTitle = trim(textField.stringValue)
            if newTitle == oldTitle {
                return
            }

            if newTitle.count == 0 {
                MacAlerts.info(NSLocalizedString("invalid_attachment_name", comment: "Invalid Attachment Name"),
                               informativeText: NSLocalizedString("attachment_name_must_not_be_empty", comment: "The attachment name must not be empty"),
                               window: view.window,
                               completion: nil)
                textField.stringValue = key as String
                return
            }

            if model.attachments.allKeys().contains(newTitle as NSString) {
                MacAlerts.info(NSLocalizedString("invalid_attachment_name", comment: "Invalid Attachment Name"),
                               informativeText: NSLocalizedString("attachment_name_already_exists", comment: "That attachment name is already used"),
                               window: view.window, completion: nil)
                textField.stringValue = key as String
                return
            }

            model.removeAttachment(key as String)
            model.insertAttachment(newTitle as String, attachment: attachment)

            refreshAttachments()
            onModelEdited()
        }
    }

    @IBAction func onAddAttachment(_: Any) {
        let panel = NSOpenPanel()

        panel.title = NSLocalizedString("item_details_add_attachment_button", comment: "Add Attachment...")
        panel.allowsMultipleSelection = true

        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.data]
        }

        if panel.runModal() == .OK {
            panel.urls.forEach { url in
                addAttachmentWithUrl(url)
            }
        }
    }

    func addAttachmentWithUrl(_ url: URL) {
        let filename = url.lastPathComponent
        do {
            let data = try Data(contentsOf: url)
            let attachment = DatabaseAttachment(nonPerformantWith: data, compressed: true, protectedInMemory: true)
            addAttachment(filename, attachment)
        } catch {
            MacAlerts.error(error, window: view.window)
        }
    }

    func tableViewSelectionDidChange(_: Notification) {
        bindAttachmentButtons()
        bindCustomFieldsButtons()
    }

    @IBAction func onSaveAttachmentAs(_: Any) {
        guard let idx = tableViewAttachments.selectedRowIndexes.first else {
            return
        }

        if idx >= 0, idx < model.attachments.count {
            let key = model.attachments.allKeys()[idx]
            guard let attachment = model.attachments[key] else {
                return
            }

            let panel = NSSavePanel()
            panel.nameFieldStringValue = key as String

            if panel.runModal() == .OK {
                guard let url = panel.url else {
                    return
                }

                let data = attachment.nonPerformantFullData
                do {
                    try data.write(to: url)
                } catch {
                    MacAlerts.error(error, window: view.window)
                }
            }
        }
    }

    @IBAction func onDeleteAttachments(_: Any?) {
        let keys = model.attachments.allKeys().enumerated().compactMap { index, b in
            tableViewAttachments.selectedRowIndexes.contains(index) ? b : nil
        }

        if keys.count == 0 {
            return
        }

        MacAlerts.areYouSure(NSLocalizedString("are_you_sure_delete_attachment_s", comment: "Are you sure you want to delete the selected attachment(s)?"),
                             window: view.window)
        { [weak self] go in
            if go {
                keys.forEach { key in
                    self?.deleteAttachment(key as String)
                }
            }
        }
    }

    

    func dragSourceIsFromAttachments(draggingInfo: NSDraggingInfo) -> Bool {
        if let draggingSource = draggingInfo.draggingSource as? NSTableView, draggingSource == tableViewAttachments {
            return true
        } else {
            return false
        }
    }

    @available(macOS 10.13, *)
    func handleDropOnToAttachmentsTable(_ tableView: NSTableView, draggingInfo: NSDraggingInfo, toRow: Int) -> Bool {
        var succeeded = handlePromisedDrops(draggingInfo: draggingInfo, toRow: toRow)

        if !succeeded {
            succeeded = handleNonePromisedDrops(tableView, draggingInfo: draggingInfo, toRow: toRow)
        }

        return succeeded
    }

    @available(macOS 10.13, *)
    func handleNonePromisedDrops(_ tableView: NSTableView, draggingInfo: NSDraggingInfo, toRow: Int) -> Bool {
        NSLog("handleNonePromisedDrops...")

        var failed = false

        draggingInfo.enumerateDraggingItems(options: .concurrent, for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:],
                                            using: { draggingItem, _, _ in
                                                if let pasteboardItem = draggingItem.item as? NSPasteboardItem {
                                                    if let itemType = pasteboardItem.availableType(from: [.fileURL]),
                                                       let filePath = pasteboardItem.string(forType: itemType),
                                                       let url = URL(string: filePath)
                                                    {
                                                        if !self.insertURLAsAttachment(url, toRow: toRow) {
                                                            failed = true
                                                        }
                                                    }
                                                }
                                            })

        return !failed
    }

    @available(macOS 10.13, *)
    func handlePromisedDrops(draggingInfo: NSDraggingInfo, toRow: Int) -> Bool {
        NSLog("handlePromisedDrops...")

        guard let promises = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil), !promises.isEmpty else {
            return false
        }

        var failed = false

        for promise in promises {
            if let promiseReceiver = promise as? NSFilePromiseReceiver {
                promiseReceiver.receivePromisedFiles(atDestination: dragAndDropDestinationURL, options: [:], operationQueue: dragAndDropPromiseQueue) { fileURL, error in
                    OperationQueue.main.addOperation {
                        if error != nil {
                            NSLog("🔴 Error Handling Promise: [%@]", String(describing: error))
                            failed = true
                        } else {
                            if !self.insertURLAsAttachment(fileURL, toRow: toRow) {
                                failed = true
                            }
                        }
                    }
                }
            }
        }

        return !failed
    }

    func insertURLAsAttachment(_ url: URL, toRow _: Int) -> Bool {
        guard let data = try? Data(contentsOf: url) else {
            return false
        }

        var filename = url.lastPathComponent

        if model.attachments.allKeys().contains(filename as NSString) {
            filename = String(format: "%@-%@.%@", url.deletingPathExtension().lastPathComponent, NSDate().fileNameCompatibleDateTimePrecise, url.pathExtension)
        }

        let attachment = DatabaseAttachment(nonPerformantWith: data, compressed: true, protectedInMemory: true)

        addAttachment(filename, attachment)

        return true
    }

    

    @IBAction func onRemoveField(_: Any?) {
        MacAlerts.areYouSure(NSLocalizedString("are_you_sure_delete_custom_field_s", comment: "Are you sure you want to delete the selected field(s)?"),
                             window: view.window) { [weak self] go in
            guard let self = self else { return }

            if go {
                var offsetIndex = 0
                self.tableViewCustomFields.selectedRowIndexes.forEach { row in
                    self.model.removeCustomField(at: UInt(row - offsetIndex))
                    offsetIndex += 1
                }

                self.refreshCustomFields()
                self.onModelEdited()
            }
        }
    }

    @IBAction func onAddField(_: Any) {
        let vc = EditCustomFieldController.fromStoryboard()

        vc.existingKeySet = Set(model.customFields.map { field in
            field.key
        })

        vc.customFieldKeySet = database.customFieldKeySet

        vc.onSetField = { [weak self] key, value, protected in
            guard let self = self else { return }

            let field = CustomFieldViewModel.customField(withKey: key, value: value, protected: protected)
            self.model.addCustomField(field)
            self.refreshCustomFields()
            self.onModelEdited()
        }

        presentAsSheet(vc)
    }

    @IBAction func onEditField(_: Any?) {
        guard let idx = tableViewCustomFields.selectedRowIndexes.first else { return }

        let field = model.customFields[idx]

        let vc = EditCustomFieldController.fromStoryboard()

        vc.existingKeySet = Set(model.customFields.map { field in
            field.key
        })

        vc.customFieldKeySet = database.customFieldKeySet

        vc.field = CustomField()
        vc.field.key = field.key
        vc.field.value = field.value
        vc.field.protected = field.protected

        vc.onSetField = { [weak self] key, value, protected in
            guard let self = self else { return }

            let field = CustomFieldViewModel.customField(withKey: key, value: value, protected: protected)

            self.model.removeCustomField(at: UInt(idx))
            
            if ( self.model.sortCustomFields ) {
                self.model.addCustomField(field)
            }
            else {
                self.model.addCustomField(field, at: UInt(idx))
            }

            self.refreshCustomFields()
            self.onModelEdited()
        }





        presentAsSheet(vc)
    }
}

extension CreateEditViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == tableViewAttachments {
            return Int(model.attachments.count)
        } else if tableView == tableViewCustomFields {
            return Int(model.customFields.count)
        }

        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == tableViewAttachments {
            let attachmentKey = model.attachments.allKeys()
            let key = attachmentKey[row]
            guard let attachment = model.attachments[key] else { return nil }

            if tableColumn?.identifier.rawValue == "Name" {
                let identifier = TitleAndIconCell.NibIdentifier

                let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as! TitleAndIconCell

                cell.setContent(NSAttributedString(string: key as String))

                cell.icon.image = AttachmentPreviewHelper.shared.getPreviewImage(key as String, attachment)
                cell.title.stringValue = key as String
                cell.title.isEditable = true
                cell.title.action = #selector(onAttachmentNameEdited)

                return cell
            } else {
                let identifier = GenericAutoLayoutTableViewCell.NibIdentifier
                let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as! GenericAutoLayoutTableViewCell

                cell.title.stringValue = friendlyFileSizeString(Int64(attachment.length))

                return cell
            }
        } else if tableView == tableViewCustomFields {
            let isKeyColumn = tableColumn?.identifier.rawValue == "CustomFieldKeyColumn"

            let field = model.customFields[row]

            if isKeyColumn {
                let identifier = GenericAutoLayoutTableViewCell.NibIdentifier
                let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as! GenericAutoLayoutTableViewCell
                cell.title.stringValue = field.key
                return cell
            } else {
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CustomFieldValueCellIdentifier"), owner: nil) as! CustomFieldTableCellView

                cell.value = field.value
                cell.protected = field.protected && !(field.value.count == 0 && !database.concealEmptyProtectedFields)
                cell.valueHidden = field.protected && !(field.value.count == 0 && !database.concealEmptyProtectedFields) 

                return cell
            }
        }

        return nil
    }
}

extension CreateEditViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow _: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation
    {
        if tableView == tableViewAttachments {
            var dragOperation: NSDragOperation = []

            guard dropOperation != .on,
                  !dragSourceIsFromAttachments(draggingInfo: info),
                  canAddAttachment,
                  let items = info.draggingPasteboard.pasteboardItems else { return dragOperation }

            if #available(macOS 10.13, *) { } else {
                return dragOperation
            }

            for item in items {
                var type: NSPasteboard.PasteboardType
                if #available(macOS 11.0, *) {
                    type = NSPasteboard.PasteboardType(UTType.image.identifier)
                } else {
                    type = (kUTTypeData as NSPasteboard.PasteboardType)
                }

                if item.availableType(from: [type]) != nil {
                    
                    dragOperation = [.copy]
                    return dragOperation
                }
            }

            if dragOperation == [] {
                let options = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true] as [NSPasteboard.ReadingOptionKey: Any]

                if let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) {
                    if !urls.isEmpty {
                        
                        dragOperation = [.copy]
                    }
                }
            }

            return dragOperation
        }
        else if tableView == tableViewCustomFields {
            if dropOperation == .above, !model.sortCustomFields {
                return [.move]
            }
        }

        return []
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation _: NSTableView.DropOperation) -> Bool
    {
        if tableView == tableViewAttachments {
            guard canAddAttachment else { return false }

            if #available(macOS 10.13, *) {
                let ret = handleDropOnToAttachmentsTable(tableView, draggingInfo: info, toRow: row)

                if !ret {
                    MacAlerts.info(NSLocalizedString("edit_item_could_not_add_item_as_attachment", comment: "There was an error adding this item as an Attachment"), window: view.window)
                }

                return ret
            }
            else {
                return false
            }
        }
        else if tableView == tableViewCustomFields {
            if let str = info.draggingPasteboard.string(forType: NSPasteboard.PasteboardType(CustomFieldDragAndDropId)),
               let sourceRow = UInt(str)
            {
                var insertAtIndex = UInt(row)

                if sourceRow < row {
                    insertAtIndex = insertAtIndex - 1
                }

                if sourceRow != insertAtIndex {
                    NSLog("Custom Field Drop: [%d insert at %d]", sourceRow, insertAtIndex)

                    model.moveCustomField(at: sourceRow, to: insertAtIndex)

                    refreshCustomFields()

                    onModelEdited()

                    return true
                }
            }
        }

        return false
    }

    

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if tableView == tableViewAttachments {
            if #available(macOS 10.13, *) {
                return pasteboardWriterForRow(tableView, row: row)
            }
        }
        else if tableView == tableViewCustomFields, !model.sortCustomFields {
            let item = NSPasteboardItem()
            item.setString(String(row), forType: NSPasteboard.PasteboardType(CustomFieldDragAndDropId))
            return item
        }

        return nil
    }

    @available(macOS 10.13, *)
    func pasteboardWriterForRow(_: NSTableView, row: Int) -> NSPasteboardWriting? {
        let attachmentKey = model.attachments.allKeys()
        let key = attachmentKey[row]

        let filename = key as String
        let filenameExtension = key.pathExtension

        var provider: NSFilePromiseProvider
        
        if #available(macOS 11.0, *) {
            let typeIdentifier = UTType(filenameExtension: filenameExtension) ?? UTType.data
            provider = NSFilePromiseProvider(fileType: typeIdentifier.identifier, delegate: self)
        }
        else {
            guard let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, filenameExtension as CFString, nil) else {
                NSLog("🔴 Could not determine typeIdentifier for filename [%@]", key)
                return nil
            }
            
            provider = NSFilePromiseProvider(fileType: typeIdentifier.takeRetainedValue() as String, delegate: self)
        }
        
        provider.userInfo = [FilePromiseProviderUserInfoKeys.filename: filename]

        return provider
    }
}

extension CreateEditViewController: QLPreviewPanelDataSource {
    @IBAction func onPreview(_: Any) {
        previewSelectedItem()
    }

    func previewSelectedItem() {
        guard let idx = tableViewAttachments.selectedRowIndexes.first else {
            return
        }

        if idx >= 0 && idx < model.attachments.count {
            QLPreviewPanel.shared().makeKeyAndOrderFront(self)
        }
    }

    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        return tableViewAttachments.selectedRowIndexes.count
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let rows = Array(tableViewAttachments.selectedRowIndexes)
        guard let idx = rows[safe: index] else {
            return nil
        }

        if idx >= 0, idx < model.attachments.count {
            let key = model.attachments.allKeys()[idx]
            guard let attachment = model.attachments[key] else {
                return nil
            }

            









            let path = StrongboxFilesManager.sharedInstance().tmpAttachmentPreviewPath as NSString
            let tmp = path.appendingPathComponent(key as String)

            let inputStream = attachment.getPlainTextInputStream()!
            let outputStream = OutputStream(toFileAtPath: tmp, append: false)!

            StreamUtils.pipe(from: inputStream, to: outputStream)

            return NSURL(fileURLWithPath: tmp)
        }

        return nil
    }
}

extension CreateEditViewController: QLPreviewPanelDelegate {
    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }

    override func endPreviewPanelControl(_: QLPreviewPanel!) {
        StrongboxFilesManager.sharedInstance().deleteAllTmpAttachmentPreviewFiles()
    }
}

extension CreateEditViewController: NSFilePromiseProviderDelegate {
    @available(macOS 10.12, *)
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        NSLog("filePromiseProvider::fileNameForType called with [%@]", fileType)

        if let userInfo = filePromiseProvider.userInfo as? [String: Any],
           let filename = userInfo[FilePromiseProviderUserInfoKeys.filename] as? String
        {
            return filename
        }

        return "foo.png"
    }

    @available(macOS 10.12, *)
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        NSLog("filePromiseProvider - writePromiseTo: [%@]", String(describing: url))

        do {
            if let userInfo = filePromiseProvider.userInfo as? [String: Any],
               let filename = userInfo[FilePromiseProviderUserInfoKeys.filename] as? String,
               let attachment = model.attachments[filename as NSString]
            {
                try attachment.nonPerformantFullData.write(to: url)
            } else {
                throw CreateEditError.attachmentDragAndDropError
            }
            completionHandler(nil)
        } catch {
            NSLog("🔴 Error dragging and dropping to external: [%@]", String(describing: error))

            completionHandler(error)
        }
    }

    @available(macOS 10.12, *)
    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        return dragAndDropPromiseQueue
    }
}

extension CreateEditViewController: OEXTokenFieldDelegate {
    func tokenField(_: OEXTokenField!, attachmentCellForRepresentedObject representedObject: Any!) -> NSTextAttachmentCell! {
        guard let representedObject = representedObject as? String else { return SBTokenAttachmentCell() }

        let ret = SBTokenAttachmentCell(textCell: representedObject)
        ret.representedObject = representedObject

        return ret
    }
}
