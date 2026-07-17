import Foundation
import SwiftUI

class CreditCardEditorViewModel: ObservableObject {
    
    @Published var creditCardData = CreditCardData()
    @Published var isLoading = false
    @Published var hasUnsavedChanges = false
    @Published var isEditing = false
    @Published var showingDiscardAlert = false
    @Published var showingErrorAlert = false
    @Published var errorMessage = ""
    
    
    private(set) var model: Model?
    private var itemUuid: UUID?
    private var parentGroupUuid: UUID?
    private var onCancel: (() -> Void)?
    private var saveCompletion: ((_ saved: Bool) -> Void)?
    
    
    private static let reservedCustomFieldKeys: Set<String> = [
        "CreditCardName",
        "CardholderName",
        "CardType",
        "CardNumber",
        "ExpiryDate",
        "ValidFrom",
        "CVV",
        "PIN",
        "CreditLimit",
        "CashWithdrawalLimit",
        "InterestRate",
        "IssueNumber"
    ]
    
    
    var navigationTitle: String {
        let name = creditCardData.name.isEmpty ? "Credit Card" : creditCardData.name
        return itemUuid != nil ? name : "New Credit Card"
    }
    
    var cancelButtonTitle: String {
        return hasUnsavedChanges ? "Cancel" : "Back"
    }
    
    var canSaveChanges: Bool {
        return canSave()
    }
    
    var justAutoCommittedTotp: Bool {
        return false 
    }
    
    
    init(
        model: Model?,
        itemId: NSUUID?,
        parentGroupId: UUID?,
        createNewItem: Bool,
        editImmediately: Bool,
        forcedReadOnly: Bool,
        completion: @escaping (_ saved: Bool) -> Void,
        onNavigateBack: @escaping () -> Void
    ) {
        self.model = model
        
        
        if let itemId = itemId {
            self.itemUuid = UUID(uuidString: itemId.uuidString)
        } else {
            self.itemUuid = nil
        }
        
        self.parentGroupUuid = parentGroupId
        self.isEditing = editImmediately
        
        
        self.saveCompletion = completion
        
        
        self.onCancel = onNavigateBack
        
        
        if let uuid = itemUuid {
            loadExistingItem(uuid: uuid)
            loadMetadata()
        }
    }
    
    
    private func loadExistingItem(uuid: UUID) {
        guard let model = model, let item = model.database.getItemBy(uuid) else { return }
        
        let cardTypeString = item.fields.customFields["CardType"]?.value ?? ""
        
        
        creditCardData.name = item.fields.customFields["CreditCardName"]?.value ?? ""
        creditCardData.cardholderName = item.fields.customFields["CardholderName"]?.value ?? ""
        creditCardData.cardType = CardType(rawValue: cardTypeString) ?? .other
        creditCardData.number = item.fields.customFields["CardNumber"]?.value ?? ""
        creditCardData.expiryDate = item.fields.customFields["ExpiryDate"]?.value ?? ""
        creditCardData.validFrom = item.fields.customFields["ValidFrom"]?.value ?? ""
        creditCardData.verificationNumber = item.fields.customFields["CVV"]?.value ?? ""
        creditCardData.pin = item.fields.customFields["PIN"]?.value ?? ""
        creditCardData.creditLimit = item.fields.customFields["CreditLimit"]?.value ?? ""
        creditCardData.cashWithdrawalLimit = item.fields.customFields["CashWithdrawalLimit"]?.value ?? ""
        creditCardData.interestRate = item.fields.customFields["InterestRate"]?.value ?? ""
        creditCardData.issueNumber = item.fields.customFields["IssueNumber"]?.value ?? ""
        creditCardData.notes = item.fields.notes
        creditCardData.tags = Set(item.fields.tags.allObjects as! [String])
        
        
        creditCardData.customFields.removeAll()
        creditCardData.customFieldsConceablable.removeAll()
        creditCardData.customFieldsConcealed.removeAll()
        let allKeys = item.fields.customFields.allKeys().compactMap { String($0) }
        for stringKey in allKeys {
            if !["CreditCardName",
                 "CardholderName",
                 "CardType",
                 "CardNumber",
                 "ExpiryDate",
                 "ValidFrom",
                 "CVV",
                 "PIN",
                 "CreditLimit",
                 "CashWithdrawalLimit",
                 "InterestRate",
                 "IssueNumber"].contains(stringKey) {
                let stringValue = item.fields.customFields[stringKey as NSString]
                let value = stringValue?.value ?? ""
                let isConceablable = stringValue?.protected ?? false
                creditCardData.customFields.append(["key": stringKey, "value": value])
                creditCardData.customFieldsConceablable.append(isConceablable)
                creditCardData.customFieldsConcealed.append(isConceablable)
            }
        }
        
        
        while creditCardData.customFieldsConcealed.count < creditCardData.customFields.count {
            creditCardData.customFieldsConcealed.append(false)
        }
        
        
        loadMetadata()
    }
    
    func save() {
        guard let model = model else {
            showError(CreditCardSaveError.databaseUnavailable.localizedDescription)
            saveCompletion?(false)
            return
        }
        
        
        if creditCardData.name.isEmpty {
            showError(CreditCardSaveError.missingName.localizedDescription)
            saveCompletion?(false)
            return
        }
        
        if creditCardData.number.isEmpty {
            showError(CreditCardSaveError.missingCardNumber.localizedDescription)
            saveCompletion?(false)
            return
        }
        
        isLoading = true
        
        
        do {
            try performInMemoryChanges()
        } catch {
            isLoading = false
            showError(error.localizedDescription)
            saveCompletion?(false)
            return
        }
        
        
        model.asyncUpdate { result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.isLoading = false
                
                if result.userCancelled {
                    self.saveCompletion?(false)
                    return
                }
                
                if let error = result.error {
                    self.showError(error.localizedDescription)
                    self.saveCompletion?(false)
                    return
                }
                
                
                self.hasUnsavedChanges = false
                self.isEditing = false
                
                
                CreditCardToastMessages.showSlim(title: "Credit Card Saved")
                
                self.saveCompletion?(true)
            }
        }
    }
    
    private func performInMemoryChanges() throws {
        guard let model = model else {
            throw CreditCardSaveError.databaseUnavailable
        }
        
        let item: Node
        
        if let existingUuid = itemUuid {
            
            guard let existingItem = model.database.getItemBy(existingUuid) else {
                throw CreditCardSaveError.itemNotFound
            }
            
            item = existingItem
            
            
            let originalNodeForHistory = existingItem.cloneForHistory()
            item.fields.keePassHistory.add(originalNodeForHistory)
        } else {
            
            let title = creditCardData.name.isEmpty ? "Credit Card" : creditCardData.name
            let parentGroup: Node
            
            if let parentUuid = parentGroupUuid, let foundParent = model.database.getItemBy(parentUuid) {
                parentGroup = foundParent
            } else {
                parentGroup = model.database.effectiveRootGroup
            }
            
            item = Node(asRecord: title, parent: parentGroup)
            parentGroup.addChild(item, keePassGroupTitleRules: model.database.isUsingKeePassGroupTitleRules)
        }
        
        
        let _ = item.setTitle(creditCardData.name.isEmpty ? "Credit Card" : creditCardData.name, keePassGroupTitleRules: model.database.isUsingKeePassGroupTitleRules)
        item.fields.notes = creditCardData.notes
        
        
        if item.icon == nil || (item.icon?.isCustom == false && item.icon?.preset == 0) {
            item.icon = NodeIcon.withPreset(9) 
        }
        
        
        item.fields.setCustomField("CreditCardName", value: StringValue(string: creditCardData.name, protected: false))
        item.fields.setCustomField("CardholderName", value: StringValue(string: creditCardData.cardholderName, protected: false))
        item.fields.setCustomField("CardType", value: StringValue(string: creditCardData.cardType.rawValue, protected: false))
        item.fields.setCustomField("CardNumber", value: StringValue(string: creditCardData.number, protected: true))
        item.fields.setCustomField("ExpiryDate", value: StringValue(string: creditCardData.expiryDate, protected: false))
        item.fields.setCustomField("ValidFrom", value: StringValue(string: creditCardData.validFrom, protected: false))
        item.fields.setCustomField("CVV", value: StringValue(string: creditCardData.verificationNumber, protected: true))
        item.fields.setCustomField("PIN", value: StringValue(string: creditCardData.pin, protected: true))
        item.fields.setCustomField("CreditLimit", value: StringValue(string: creditCardData.creditLimit, protected: false))
        item.fields.setCustomField("CashWithdrawalLimit", value: StringValue(string: creditCardData.cashWithdrawalLimit, protected: false))
        item.fields.setCustomField("InterestRate", value: StringValue(string: creditCardData.interestRate, protected: false))
        item.fields.setCustomField("IssueNumber", value: StringValue(string: creditCardData.issueNumber, protected: false))
        
        item.fields.tags = NSMutableSet(set: creditCardData.tags)
        
        let desiredCustomFieldKeys = Set(
            creditCardData.customFields.compactMap { customField -> String? in
                guard let key = customField["key"], !key.isEmpty else { return nil }
                return key
            }
        )
        
        let existingCustomFieldKeys = item.fields.customFields.allKeys().compactMap { key -> String? in
            if let stringKey = key as? String {
                return stringKey
            }
            if let nsStringKey = key as? NSString {
                return String(nsStringKey)
            }
            return nil
        }
        
        var keysToRemove = existingCustomFieldKeys.filter {
            !Self.reservedCustomFieldKeys.contains($0) && !desiredCustomFieldKeys.contains($0)
        }
        keysToRemove.append(contentsOf: creditCardData.customFieldsForRemoval.filter {
            !desiredCustomFieldKeys.contains($0)
        })
        
        for key in Set(keysToRemove) {
            item.fields.removeCustomField(key)
        }
        creditCardData.customFieldsForRemoval.removeAll()
        
        
        for (index, customField) in creditCardData.customFields.enumerated() {
            if let key = customField["key"], let value = customField["value"] {
                let isConceablable = index < creditCardData.customFieldsConceablable.count ? creditCardData.customFieldsConceablable[index] : false
                item.fields.setCustomField(key, value: StringValue(string: value, protected: isConceablable))
            }
        }
        
        
        item.fields.touch(true)
        
        
        model.database.rebuildFastMaps()
        
        
        if itemUuid == nil {
            itemUuid = item.uuid
        }
    }
    
    func onTagsEdited(tags: Set<String>) {
        self.creditCardData.tags = tags
        markAsChanged()
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    
    func isValid() -> Bool {
        return !creditCardData.name.isEmpty && !creditCardData.number.isEmpty
    }
    
    func canSave() -> Bool {
        return isValid() && hasUnsavedChanges && !isLoading
    }
    
    
    func markAsChanged() {
        hasUnsavedChanges = true
    }
    
    func discardChanges() {
        if let uuid = itemUuid {
            loadExistingItem(uuid: uuid)
        } else {
            creditCardData = CreditCardData()
        }
        hasUnsavedChanges = false
        showingDiscardAlert = false
        
        
        onCancel?()
    }
    
    
    func handleCancelTapped() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            onCancel?()
        }
    }
    
    func handleEditToggle() {
        if isEditing {
            
            save()
        } else {
            
            isEditing = true
        }
    }
    
    func dismissDiscardAlert() {
        showingDiscardAlert = false
    }
    
    func focusFirstField() -> CreditCardFocusField {
        return .name
    }
    
    
    func addCustomField(key: String, value: String) {
        creditCardData.customFields.append(["key": key, "value": value])
        creditCardData.customFieldsConcealed.append(false) 
        creditCardData.customFieldsConceablable.append(false) 
        markAsChanged()
    }
    
    func addCustomField(key: String, value: String, isConceablable: Bool) {
        print("DEBUG: Adding custom field - Key: \(key), Value: \(value), Concealable: \(isConceablable)")
        print("DEBUG: Before add - custom fields count: \(creditCardData.customFields.count)")
        
        
        objectWillChange.send()
        
        creditCardData.customFields.append(["key": key, "value": value])
        creditCardData.customFieldsConcealed.append(isConceablable) 
        creditCardData.customFieldsConceablable.append(isConceablable) 
        
        print("DEBUG: After add - custom fields count: \(creditCardData.customFields.count)")
        print("DEBUG: Custom fields array: \(creditCardData.customFields)")
        
        markAsChanged()
    }
    
    func updateCustomField(at index: Int, key: String, value: String, isConceablable: Bool, originalKey: String?) {
        guard index < creditCardData.customFields.count else { return }
        
        objectWillChange.send()
        
        if let originalKey = originalKey, originalKey != key {
            if !creditCardData.customFieldsForRemoval.contains(originalKey) {
                creditCardData.customFieldsForRemoval.append(originalKey)
            }
        }
        
        creditCardData.customFields[index] = ["key": key, "value": value]
        
        let previousIsConceablable = index < creditCardData.customFieldsConceablable.count ? creditCardData.customFieldsConceablable[index] : false
        let hadConcealedEntry = index < creditCardData.customFieldsConcealed.count
        
        if index < creditCardData.customFieldsConceablable.count {
            creditCardData.customFieldsConceablable[index] = isConceablable
        } else {
            while creditCardData.customFieldsConceablable.count <= index {
                creditCardData.customFieldsConceablable.append(false)
            }
            creditCardData.customFieldsConceablable[index] = isConceablable
        }
        
        if index >= creditCardData.customFieldsConcealed.count {
            while creditCardData.customFieldsConcealed.count <= index {
                creditCardData.customFieldsConcealed.append(false)
            }
        }
        
        if !hadConcealedEntry || previousIsConceablable != isConceablable {
            creditCardData.customFieldsConcealed[index] = isConceablable
        }
        
        markAsChanged()
    }
    
    func removeCustomField(at index: Int) {
        guard index < creditCardData.customFields.count else { return }
        
        
        objectWillChange.send()
        
        if let key = creditCardData.customFields[index]["key"], !key.isEmpty {
            if !creditCardData.customFieldsForRemoval.contains(key) {
                creditCardData.customFieldsForRemoval.append(key)
            }
        }
        
        creditCardData.customFields.remove(at: index)
        
        
        if index < creditCardData.customFieldsConcealed.count {
            creditCardData.customFieldsConcealed.remove(at: index)
        }
        if index < creditCardData.customFieldsConceablable.count {
            creditCardData.customFieldsConceablable.remove(at: index)
        }
        
        markAsChanged()
    }
    
    
    func toggleNumberConcealed() {
        creditCardData.numberConcealed.toggle()
    }
    
    func toggleVerificationNumberConcealed() {
        creditCardData.verificationNumberConcealed.toggle()
    }
    
    func togglePinConcealed() {
        creditCardData.pinConcealed.toggle()
    }
    
    func toggleCustomFieldConcealed(at index: Int) {
        guard index < creditCardData.customFieldsConcealed.count else { return }
        creditCardData.customFieldsConcealed[index].toggle()
    }
    
    func isCustomFieldConceablable(at index: Int) -> Bool {
        guard index < creditCardData.customFieldsConceablable.count else { return false }
        return creditCardData.customFieldsConceablable[index]
    }
    
    
    private func loadMetadata() {
        guard let model = model, let uuid = itemUuid else { return }
        
        guard let item = model.database.getItemBy(uuid) else { return }
        
        
        let metadataArray = model.getMetadataFromItem(item)
        creditCardData.metadataEntries = metadataArray
    }
}


enum CreditCardSaveError: LocalizedError {
    case databaseUnavailable
    case readOnlyDatabase
    case missingName
    case missingCardholderName
    case missingCardNumber
    case itemNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return NSLocalizedString("save_error_database_unavailable", value: "Database is not available", comment: "Error when database is unavailable")
        case .readOnlyDatabase:
            return NSLocalizedString("save_error_readonly_database", value: "Database is read-only", comment: "Error when database is read-only")
        case .missingName:
            return NSLocalizedString("save_error_missing_name", value: "Credit card name is required", comment: "Error when credit card name is missing")
        case .missingCardholderName:
            return NSLocalizedString("save_error_missing_cardholder_name", value: "Cardholder name is required", comment: "Error when cardholder name is missing")
        case .missingCardNumber:
            return NSLocalizedString("save_error_missing_card_number", value: "Card number is required", comment: "Error when card number is missing")
        case .itemNotFound:
            return NSLocalizedString("save_error_item_not_found", value: "Item not found", comment: "Error when item is not found")
        case .saveFailed:
            return NSLocalizedString("save_error_save_failed", value: "Failed to save database to disk", comment: "Error when database save to disk fails")
        }
    }
}
