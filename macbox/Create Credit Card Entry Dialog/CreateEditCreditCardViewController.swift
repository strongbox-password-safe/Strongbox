import Foundation
import Cocoa
import QuickLookUI

final class CreateEditCreditCardViewController: NSViewController, NSWindowDelegate, NSToolbarDelegate, NSTextFieldDelegate, NSMenuDelegate, NSTextViewDelegate, NSTokenFieldDelegate {
    
    var viewModel: CreateEditCreditCardViewModel!
    var selectPredefinedIconController: SelectPredefinedIconController?
    
    @IBOutlet weak var imageVIewIcon: ClickableImageView!
    @IBOutlet weak var creditCardTitle: MMcGACTextField!
    @IBOutlet weak var cardHolderNameTextField: MMcGACTextField!
    @IBOutlet weak var cardNumberTextField: MMcGSecureTextField!
    @IBOutlet weak var cvvTextField: MMcGSecureTextField!
    @IBOutlet weak var pinTextField: MMcGSecureTextField!
    @IBOutlet weak var creditLimitTextField: MMcGSecureTextField!
    @IBOutlet weak var cashWithdrawalLimitTextField: MMcGACTextField!
    @IBOutlet weak var notesTextField: NSScrollView!
    @IBOutlet weak var buttonSetExpiry: NSButton!
    @IBOutlet weak var buttonSetValidDate: NSButton!
    @IBOutlet weak var cardTypePopUpButton: NSPopUpButton!
    @IBOutlet weak var interestRateTextField: MMcGACTextField!
    @IBOutlet weak var issueNumberTextField: MMcGACTextField!
    
    
    @IBOutlet weak var popupLocation: NSPopUpButton!
    
    
    @IBOutlet weak var tableViewCustomFields: TableViewWithKeyDownEvents!
    @IBOutlet weak var buttonAddField: NSButton!
    @IBOutlet weak var buttonEditField: NSButton!
    @IBOutlet weak var buttonRemoveField: NSButton!
    
    
    @IBOutlet weak var datePickerValidFrom: NSDatePicker!
    @IBOutlet weak var datePickerExpiry: NSDatePicker!
    @IBOutlet weak var stackViewValidFromPicker: NSStackView!
    @IBOutlet weak var stackViewExpiryPicker: NSStackView!
    @IBOutlet weak var buttonClearValidFrom: NSButton!
    @IBOutlet weak var buttonClearExpiry: NSButton!
    
    
    @IBOutlet weak var buttonFavourite: NSButton!
    
    var database: ViewModel!
    var initialNodeId: UUID?
    
    var iconExplicitlyChanged: Bool = false
    var sortedGroups: [Node]!
    
    internal var customFields: [(key: String, value: String, protected: Bool)] = []
    
    var model: EntryViewModel? {
        return viewModel?.model
    }
    
    var customFieldKeySet: Set<String> {
        return viewModel?.customFieldSuggestions ?? Set()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let database = database else {
            swlog("🔴 CreateEditCreditCardViewController: Database is nil in viewDidLoad")
            return
        }
        
        viewModel = CreateEditCreditCardViewModel(database: database, initialNodeId: initialNodeId)
        
        setupUI()
        bindUiToViewModel()
        bindDatePickerVisibility()
        updateDateButtonText()
    }
   
    private func setupUI() {
        setupIcon()
        setupDatePickers()
        setupCustomFields()
        setupPopupMenus()
        setupTextFieldDelegates()
        refreshCustomFields()
    }
    
    private func setupIcon() {
        imageVIewIcon.clickable = true
        imageVIewIcon.showClickableBorder = true
        imageVIewIcon.onClick = { [weak self] in
            guard let self else { return }
            self.onIconClicked()
        }
    }
    
    func onIconClicked() {
        guard let database = database else {
            swlog("🔴 Database not available for icon selection")
            return
        }
        
        if database.format == .passwordSafe {
            return
        }
        
        selectPredefinedIconController = SelectPredefinedIconController(windowNibName: NSNib.Name("SelectPredefinedIconController"))
        guard let selectPredefinedIconController else {
            return
        }
        
        selectPredefinedIconController.iconPool = Array(database.customIcons)
        selectPredefinedIconController.hideSelectFile = !database.formatSupportsCustomIcons
        selectPredefinedIconController.hideFavIconButton = !database.formatSupportsCustomIcons || !StrongboxProductBundle.supportsFavIconDownloader
        
        selectPredefinedIconController.onSelectedItem = { [weak self] (icon: NodeIcon?, showFindFavIcons: Bool) in
            guard let self else { return }
            self.onIconSelected(icon: icon, showFindFavIcons: showFindFavIcons)
        }
        selectPredefinedIconController.iconSet = database.keePassIconSet
        
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
        guard let database = database else {
            swlog("🔴 Database not available for FavIcon downloader")
            return
        }
        
        let vc = FavIconDownloader.newVC()
    
        guard let dbModel = database.commonModel else {
            swlog("🔴 Could not load common model!")
            return
        }
        
        let dummyNode = Node(asRecord: creditCardTitle.stringValue.isEmpty ? "Credit Card" : creditCardTitle.stringValue, parent: database.rootGroup)
        if let url = extractUrlFromModel() {
            dummyNode.fields.url = url
        }
        
        vc.nodes = [dummyNode]
        vc.viewModel = database
        
        vc.onDone = { [weak self] (go: Bool, selectedFavIcons: [UUID: NodeIcon]?) in
            guard let self else { return }
            
            if go {
                guard let selectedFavIcons else {
                    swlog("🔴 Select FavIcons null!")
                    return
                }
                
                guard let single = selectedFavIcons.first else {
                    swlog("🔴 More than 1 FavIcons returned!")
                    return
                }
                
                if single.key != dummyNode.uuid {
                    swlog("🔴 single.key != dummyNode.uuid")
                    return
                }
                
                self.explicitSetIconAndUpdateUI(single.value)
            }
        }
        
        presentAsSheet(vc)
        #endif
    }
    
    func explicitSetIconAndUpdateUI(_ icon: NodeIcon?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            self.iconExplicitlyChanged = true
            self.viewModel?.setIcon(icon)
            
            if let icon = icon ?? self.viewModel?.icon {
                self.imageVIewIcon.image = NodeIconHelper.getNodeIcon(icon, predefinedIconSet: self.database.keePassIconSet)
            }
            
            self.onModelEdited()
        }
    }
    
    private func extractUrlFromModel() -> String? {
        return nil
    }
    
    private func setupDatePickers() {
        datePickerValidFrom.dateValue = Date()
        datePickerExpiry.dateValue = Date()
        
        buttonClearValidFrom.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        buttonClearValidFrom.contentTintColor = .systemOrange
        
        buttonClearExpiry.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        buttonClearExpiry.contentTintColor = .systemOrange
    }
    
    private func setupPopupMenus() {
        setupLocationUI()
        setupCardTypeUI()
    }
    
    private func setupLocationUI() {
        let groups = database.allActiveGroups

        sortedGroups = groups.sorted { n1, n2 in
            let p1 = database.getGroupPathDisplayString(n1)
            let p2 = database.getGroupPathDisplayString(n2)
            return finderStringCompare(p1, p2) == .orderedAscending
        }
        popupLocation.menu?.removeAllItems()

        for group in sortedGroups {
            var title = database.getGroupPathDisplayString(group, rootGroupNameInsteadOfSlash: false)
            
            let clipLength = 72
            if title.count > clipLength {
                let tail = title.suffix(clipLength - 3)
                title = String(format: "...%@", String(tail))
            }

            let item = NSMenuItem(title: title, action: #selector(onChangeLocation(sender:)), keyEquivalent: "")

            var icon = NodeIconHelper.getIconFor(group, predefinedIconSet: database.keePassIconSet, format: database.format)

            let isCustom = group.icon?.isCustom ?? false

            if isCustom || database.keePassIconSet != .sfSymbols {
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

            var icon = database.rootGroup.isUsingKeePassDefaultIcon ? Icon.house.image() : NodeIconHelper.getIconFor(database.rootGroup, predefinedIconSet: database.keePassIconSet, format: database.format)

            let isCustom = database.rootGroup.icon?.isCustom ?? false

            if isCustom || database.keePassIconSet != .sfSymbols {
                icon = scaleImage(icon, CGSize(width: 16, height: 16))
            }

            item.image = icon

            popupLocation.menu?.insertItem(item, at: 0)
            sortedGroups.insert(database.rootGroup, at: 0)
        }
    }
    
    func setupCardTypeUI() {
        guard let viewModel = viewModel else { return }
        
        cardTypePopUpButton.removeAllItems()
        
        for cardType in viewModel.availableCardTypes {
            let item = NSMenuItem(title: cardType, action: #selector(onChangeCardType(sender:)), keyEquivalent: "")
             
            cardTypePopUpButton.menu?.addItem(item)
        }
        
        if let currentIndex = viewModel.availableCardTypes.firstIndex(of: viewModel.cardType) {
            cardTypePopUpButton.selectItem(at: currentIndex)
        }
    }
    
    @objc func onChangeCardType(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }
        
        guard let idx = cardTypePopUpButton.menu?.index(of: sender) else {
            swlog("🔴 Could not find this menu item in the card type menu?!")
            return
        }
        
        guard let viewModel = viewModel else {
            swlog("🔴 View model not available for card type change")
            return
        }
        
        let selectedCardType = viewModel.availableCardTypes[idx]
        viewModel.cardType = selectedCardType
        
        onModelEdited()
        setupCardTypeUI()
    }
    
    private func setupTextFieldDelegates() {
        cardNumberTextField.delegate = self
        creditLimitTextField.delegate = self
        cashWithdrawalLimitTextField.delegate = self
        
        cardNumberTextField.placeholderString = "1234-5678-9012-3456"
        creditLimitTextField.placeholderString = "10,000"
        cashWithdrawalLimitTextField.placeholderString = "1,000"
    }

    private func bindUiToViewModel() {
        guard let viewModel = viewModel else { return }
        
        creditCardTitle.stringValue = viewModel.title
        cardHolderNameTextField.stringValue = viewModel.cardholderName
        cardNumberTextField.stringValue = viewModel.cardNumber
        cvvTextField.stringValue = viewModel.cvv
        pinTextField.stringValue = viewModel.pin
        creditLimitTextField.stringValue = viewModel.creditLimit
        cashWithdrawalLimitTextField.stringValue = viewModel.cashWithdrawalLimit
        interestRateTextField.stringValue = viewModel.interestRate
        issueNumberTextField.stringValue = viewModel.issueNumber
        
        imageVIewIcon.image = NodeIconHelper.getNodeIcon(viewModel.icon, predefinedIconSet: database.keePassIconSet)
        iconExplicitlyChanged = viewModel.iconExplicitlyChanged
        
        if let index = viewModel.availableCardTypes.firstIndex(of: viewModel.cardType) {
            cardTypePopUpButton.selectItem(at: index)
        } else if let fallbackIndex = viewModel.availableCardTypes.firstIndex(of: "Other") {
            cardTypePopUpButton.selectItem(at: fallbackIndex)
        }
        
        if let expiryDate = viewModel.expiryDate {
            datePickerExpiry.dateValue = expiryDate
        }
        if let validFromDate = viewModel.validFromDate {
            datePickerValidFrom.dateValue = validFromDate
        }
        
        customFields = viewModel.customFields
        
        if let notesTextView = notesTextField.documentView as? NSTextView {
            notesTextView.string = viewModel.notes
        }
        
        bindFavourite()
        bindLocation()
    }
    
    private func bindDatePickerVisibility() {
        guard let viewModel = viewModel else { return }
        
        let validFromDate = viewModel.validFromDate
        buttonSetValidDate.isHidden = validFromDate != nil
        stackViewValidFromPicker.isHidden = validFromDate == nil
        
        if let validFromDate = validFromDate {
            datePickerValidFrom.dateValue = validFromDate
        }
        
        let expiryDate = viewModel.expiryDate
        buttonSetExpiry.isHidden = expiryDate != nil
        stackViewExpiryPicker.isHidden = expiryDate == nil
        
        if let expiryDate = expiryDate {
            datePickerExpiry.dateValue = expiryDate
        }
    }
    
    private func updateDateButtonText() {
        guard let viewModel = viewModel else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        if let validFromDate = viewModel.validFromDate {
            buttonSetValidDate.title = dateFormatter.string(from: validFromDate)
        } else {
            buttonSetValidDate.title = "Set Valid Date"
        }
        
        if let expiryDate = viewModel.expiryDate {
            buttonSetExpiry.title = dateFormatter.string(from: expiryDate)
        } else {
            buttonSetExpiry.title = "Set Expiry Date"
        }
    }

    private func syncFormToViewModel() {
        guard let viewModel = viewModel else { 
            swlog("🔴 syncFormToViewModel: viewModel is nil")
            return 
        }
        
        guard let creditCardTitle = creditCardTitle,
              let cardHolderNameTextField = cardHolderNameTextField,
              let cardNumberTextField = cardNumberTextField,
              let cvvTextField = cvvTextField,
              let pinTextField = pinTextField,
              let creditLimitTextField = creditLimitTextField,
              let cashWithdrawalLimitTextField = cashWithdrawalLimitTextField,
              let interestRateTextField = interestRateTextField,
              let issueNumberTextField = issueNumberTextField,
              let cardTypePopUpButton = cardTypePopUpButton else {
            swlog("🔴 syncFormToViewModel: One or more outlets are nil")
            return
        }
        
        viewModel.title = creditCardTitle.stringValue
        viewModel.cardholderName = cardHolderNameTextField.stringValue
        viewModel.cardNumber = cardNumberTextField.stringValue
        viewModel.cvv = cvvTextField.stringValue
        viewModel.pin = pinTextField.stringValue
        viewModel.creditLimit = creditLimitTextField.stringValue
        viewModel.cashWithdrawalLimit = cashWithdrawalLimitTextField.stringValue
        viewModel.interestRate = interestRateTextField.stringValue
        viewModel.issueNumber = issueNumberTextField.stringValue
        viewModel.cardType = cardTypePopUpButton.selectedItem?.title ?? "Other"
        
        if let notesTextView = notesTextField.documentView as? NSTextView {
            viewModel.notes = notesTextView.string
        }
    }
    
    func onModelEdited() {
        guard isViewLoaded else {
            swlog("🔴 onModelEdited: View not loaded yet, skipping")
            return
        }
        
        syncFormToViewModel()

        viewModel?.syncCustomFieldsFromModel()
        if let viewModel = viewModel {
            customFields = viewModel.customFields
        }
    }
    
    func onDiscard() {
        dismiss(nil)
    }
    
    func save(dismissAfterSave: Bool) {
        guard let viewModel = viewModel else {
            swlog("🔴 View model not available")
            return
        }
        
        syncFormToViewModel()
        
        if let nodeId = viewModel.save() {
            swlog("✅ Credit card entry saved successfully")
            handleIconAndFinishSave(nodeId: nodeId, dismissAfterSave: dismissAfterSave)
        } else {
            swlog("🔴 Failed to save credit card entry")
            MacAlerts.info("Error", informativeText: "Failed to save credit card entry", window: view.window, completion: nil)
        }
    }
    
    private func handleIconAndFinishSave(nodeId: UUID, dismissAfterSave: Bool) {
        guard let node = database.getItemBy(nodeId) else {
            swlog("🔴 Could not load node for handleIconAndFinishSave")
            if dismissAfterSave {
                dismiss(nil)
            }
            return
        }
        
        if iconExplicitlyChanged {
            iconExplicitlyChanged = false
            database.setItemIcon(node, icon: viewModel?.icon)
        }
        
        onSaveDone(node, dismissAfterSave: dismissAfterSave)
    }
    
    private func onSaveDone(_ node: Node, dismissAfterSave: Bool) {
        selectEditedItem(node)
        
        if dismissAfterSave {
            dismiss(nil)
        }
    }
    
    private func selectEditedItem(_ node: Node) {
        guard let parentNodeUuid = node.parent?.uuid else {
            return
        }

        let currentContext = getNavContextFromModel(database)

        if case .regularHierarchy = currentContext {
            setModelNavigationContextWithViewNode(database, .regularHierarchy(parentNodeUuid))
            database.nextGenSelectedItems = [node.uuid]
        } else {
            setModelNavigationContextWithViewNode(database, .special(.allEntries))
            database.nextGenSelectedItems = [node.uuid]
        }
    }
    
    @IBAction func commitCloseButtonAction(_ sender: Any) {
        save(dismissAfterSave: true)
    }
    
    @IBAction func commitButtonAction(_ sender: Any) {
        save(dismissAfterSave: false)
    }
    
    @IBAction func validDateButtonAction(_ sender: Any) {
        guard isViewLoaded, viewModel != nil else {
            swlog("🔴 validDateButtonAction: View not loaded or viewModel is nil")
            return
        }
        
        viewModel?.setValidFromDate()
        onModelEdited()
        bindDatePickerVisibility()
        updateDateButtonText()
    }
    
    @IBAction func expiryDateButtonAction(_ sender: Any) {
        guard isViewLoaded, viewModel != nil else {
            swlog("🔴 expiryDateButtonAction: View not loaded or viewModel is nil")
            return
        }
        
        viewModel?.setExpiryDate()
        onModelEdited()
        bindDatePickerVisibility()
        updateDateButtonText()
    }
    
    @IBAction func onChangeValidFromDate(_ sender: Any) {
        guard isViewLoaded, viewModel != nil else {
            swlog("🔴 onChangeValidFromDate: View not loaded or viewModel is nil")
            return
        }
        
        viewModel?.validFromDate = datePickerValidFrom.dateValue
        onModelEdited()
        bindDatePickerVisibility()
        updateDateButtonText()
    }
    
    @IBAction func onChangeExpiryDate(_ sender: Any) {
        guard isViewLoaded, viewModel != nil else {
            swlog("🔴 onChangeExpiryDate: View not loaded or viewModel is nil")
            return
        }
        
        viewModel?.expiryDate = datePickerExpiry.dateValue
        onModelEdited()
        bindDatePickerVisibility()
        updateDateButtonText()
    }
    
    @IBAction func onClearValidFromDate(_ sender: Any) {
        MacAlerts.areYouSure("Are you sure you want to clear the valid from date?", window: view.window) { [weak self] response in
            if response {
                self?.viewModel?.clearValidFromDate()
                self?.onModelEdited()
                self?.bindDatePickerVisibility()
                self?.updateDateButtonText()
            }
        }
    }
    
    @IBAction func onClearExpiryDate(_ sender: Any) {
        MacAlerts.areYouSure(NSLocalizedString("are_you_sure_clear_expiry", comment: "Are you sure you want to clear the expiry for this entry?"), window: view.window) { [weak self] response in
            if response {
                self?.viewModel?.clearExpiryDate()
                self?.onModelEdited()
                self?.bindDatePickerVisibility()
                self?.updateDateButtonText()
            }
        }
    }
    
    @IBAction func onToggleFavourite(_: Any) {
        guard let viewModel = viewModel else { return }
        viewModel.favourite = !viewModel.favourite
        onModelEdited()
        bindFavourite()
    }

    func bindFavourite() {
        guard let viewModel = viewModel, let buttonFavourite = buttonFavourite else { 
            return 
        }
        buttonFavourite.contentTintColor = viewModel.favourite ? .systemYellow : .systemGray
        buttonFavourite.image = NSImage(systemSymbolName: viewModel.favourite ? "star.fill" : "star", accessibilityDescription: nil)
    }
    
    @IBAction func cancelButtonAction(_ sender: Any) {
        onDiscard()
    }
    
    override func cancelOperation(_ sender: Any?) {
        onDiscard()
    }
    
    @objc func onChangeLocation(sender: Any?) {
        guard let sender = sender as? NSMenuItem else {
            return
        }

        guard let idx = popupLocation.menu?.index(of: sender) else {
            swlog("🔴 Could not find this menu item in the menu?!")
            return
        }

        let node = sortedGroups[idx]
        viewModel?.setParentGroup(node.uuid)

        onModelEdited()
        bindLocation()
    }

    func bindLocation() {
        guard let viewModel = viewModel else { return }
        
        let parentGroupUuid = viewModel.parentGroupUuid
        
        guard let idx = sortedGroups.firstIndex(where: { group in
            if parentGroupUuid == nil {
                return group == database.rootGroup
            } else {
                return group.uuid == parentGroupUuid
            }
        })
        else {
            swlog("🔴 Could not find this items parent group in the sorted groups list!")
            return
        }

        popupLocation.selectItem(at: idx)
    }
    
    private func calculateCardNumberCursorPosition(digitsBefore: Int, formattedString: String) -> Int {
        var position = 0
        var digitsFound = 0
        
        for char in formattedString {
            if char.isASCII && char.isWholeNumber {
                digitsFound += 1
                if digitsFound > digitsBefore {
                    break
                }
            }
            position += 1
        }
        
        return min(position, formattedString.count)
    }
    
    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else { return }
        
        let currentValue = textField.stringValue
        let formattedValue: String
        
        if textField == cardNumberTextField {
            let digits = currentValue.filter { $0.isASCII && $0.isWholeNumber }
            let isAmex = viewModel?.cardType == "American Express" || digits.hasPrefix("34") || digits.hasPrefix("37")
            formattedValue = currentValue.formattedAsCreditCardNumber(usingAmexFormat: isAmex)
        } else if textField == creditLimitTextField {
            formattedValue = currentValue.formattedAsMoney()
        } else if textField == cashWithdrawalLimitTextField {
            formattedValue = currentValue.formattedAsMoney()
        } else {
            return
        }
        
        if formattedValue != currentValue {
            let cursorPosition = textField.currentEditor()?.selectedRange.location ?? currentValue.count
            
            textField.stringValue = formattedValue
            
            if textField == cardNumberTextField {
                let digitsBefore = String(currentValue.prefix(cursorPosition)).filter { $0.isASCII && $0.isWholeNumber }.count
                let newPosition = calculateCardNumberCursorPosition(digitsBefore: digitsBefore, formattedString: formattedValue)
                textField.currentEditor()?.selectedRange = NSRange(location: newPosition, length: 0)
            } else {
                textField.currentEditor()?.selectedRange = NSRange(location: formattedValue.count, length: 0)
            }
        }
        
        onModelEdited()
    }
}

extension CreateEditCreditCardViewController {
    class func instantiateFromStoryboard() -> Self {
        let storyboard = NSStoryboard(name: "CreateEditCreditCardViewController", bundle: nil)
        return storyboard.instantiateInitialController() as! Self
    }
}
