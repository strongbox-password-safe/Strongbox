import Foundation
import Cocoa


final class CreateEditCreditCardViewModel: ObservableObject {
    private enum CreditCardFieldKey {
        static let name = "CreditCardName"
        static let cardholderName = "CardholderName"
        static let cardType = "CardType"
        static let cardNumber = "CardNumber"
        static let expiryDate = "ExpiryDate"
        static let validFrom = "ValidFrom"
        static let cvv = "CVV"
        static let pin = "PIN"
        static let creditLimit = "CreditLimit"
        static let cashWithdrawalLimit = "CashWithdrawalLimit"
        static let interestRate = "InterestRate"
        static let issueNumber = "IssueNumber"
    }

    enum CreditCardReservedFieldKeys {
        static let primaryFieldKeys: [String] = [
            CreditCardFieldKey.name,
            CreditCardFieldKey.cardholderName,
            CreditCardFieldKey.cardType,
            CreditCardFieldKey.cardNumber,
            CreditCardFieldKey.expiryDate,
            CreditCardFieldKey.validFrom,
            CreditCardFieldKey.cvv,
            CreditCardFieldKey.pin,
            CreditCardFieldKey.creditLimit,
            CreditCardFieldKey.cashWithdrawalLimit,
            CreditCardFieldKey.interestRate,
            CreditCardFieldKey.issueNumber
        ]
        static let legacyFieldAliases: [String: [String]] = [
            CreditCardFieldKey.cardholderName: ["Card Holder", "Cardholder Name"],
            CreditCardFieldKey.cardType: ["Card Type"],
            CreditCardFieldKey.cardNumber: ["Card Number"],
            CreditCardFieldKey.expiryDate: ["Expiry Date"],
            CreditCardFieldKey.creditLimit: ["Credit Limit"],
            CreditCardFieldKey.cashWithdrawalLimit: ["Cash Withdrawal Limit"],
            CreditCardFieldKey.interestRate: ["Interest Rate"],
            CreditCardFieldKey.issueNumber: ["Issue Number"],
            CreditCardFieldKey.validFrom: ["Valid From"],
            CreditCardFieldKey.name: ["Credit Card Name"]
        ]
    }

    private static let reservedFieldKeys: Set<String> = {
        var keys = Set(CreditCardReservedFieldKeys.primaryFieldKeys)
        CreditCardReservedFieldKeys.legacyFieldAliases.values.forEach { keys.formUnion($0) }
        return keys
    }()

    @Published var title: String = "Credit Card"
    @Published var cardholderName: String = ""
    @Published var cardNumber: String = ""
    @Published var cvv: String = ""
    @Published var pin: String = ""
    @Published var creditLimit: String = ""
    @Published var cashWithdrawalLimit: String = ""
    @Published var interestRate: String = ""
    @Published var issueNumber: String = ""
    @Published var cardType: String = "Other"
    @Published var notes: String = ""

    @Published var expiryDateString: String = ""
    @Published var validFromString: String = ""

    @Published var expiryDate: Date? {
        didSet {
            guard !isLoadingFromNode else { return }
            expiryDateString = expiryDate.map { formatExpiryDateString($0) } ?? ""
        }
    }

    @Published var validFromDate: Date? {
        didSet {
            guard !isLoadingFromNode else { return }
            validFromString = validFromDate.map { formatExpiryDateString($0) } ?? ""
        }
    }

    @Published var icon: NodeIcon
    @Published var iconExplicitlyChanged: Bool = false

    @Published var customFields: [(key: String, value: String, protected: Bool)] = []

    private var customFieldsMarkedForRemoval: Set<String> = []

    var database: ViewModel
    var model: EntryViewModel?
    private var initialNodeId: UUID?
    private var isLoadingFromNode = false
    
    init(database: ViewModel, initialNodeId: UUID? = nil) {
        self.database = database
        self.initialNodeId = initialNodeId
        self.icon = Self.getDefaultCreditCardIcon()
        
        if initialNodeId == nil {
            self.iconExplicitlyChanged = true
        }
        
        loadModel()
    }
    
    private func loadModel() {
        if let nodeId = initialNodeId,
           let existingNode = database.getItemBy(nodeId) {
            guard let dbModel = database.commonModel else {
                swlog("🔴 Could not load common model!")
                return
            }
            model = EntryViewModel.fromNode(existingNode, model: dbModel)
            loadFromNode(existingNode)
        } else {
            createNewModel()
        }
        syncCustomFieldsFromModel()
    }

    private func createNewModel() {
        guard let dbModel = database.commonModel else {
            swlog("🔴 Could not load common model!")
            return
        }

        let resolvedTitle = title.isEmpty ? "Credit Card" : title
        let node = Node(asRecord: resolvedTitle, parent: database.rootGroup)
        node.icon = icon
        model = EntryViewModel.fromNode(node, model: dbModel)
        model?.parentGroupUuid = database.rootGroup.uuid
        resetFormForNewEntry()
    }

    private func resetFormForNewEntry() {
        isLoadingFromNode = true
        defer { isLoadingFromNode = false }

        title = "Credit Card"
        cardholderName = ""
        cardNumber = ""
        cvv = ""
        pin = ""
        creditLimit = ""
        cashWithdrawalLimit = ""
        interestRate = ""
        issueNumber = ""
        cardType = "Other"
        notes = ""
        expiryDate = nil
        validFromDate = nil
        expiryDateString = ""
        validFromString = ""
        customFields.removeAll()
        customFieldsMarkedForRemoval.removeAll()
        iconExplicitlyChanged = true
    }

    private func loadFromNode(_ node: Node) {
        guard let model = model else { return }

        isLoadingFromNode = true
        defer { isLoadingFromNode = false }

        let storedTitle = stringValue(for: CreditCardFieldKey.name, in: node)?.value ?? model.title
        if storedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = model.title.isEmpty ? "Credit Card" : model.title
        } else {
            title = storedTitle
        }

        if let cardholderValue = stringValue(for: CreditCardFieldKey.cardholderName, in: node)?.value,
           !cardholderValue.isEmpty {
            cardholderName = cardholderValue
        }

        if let cardNumberValue = stringValue(for: CreditCardFieldKey.cardNumber, in: node)?.value,
           !cardNumberValue.isEmpty {
            cardNumber = cardNumberValue
        }

        cvv = stringValue(for: CreditCardFieldKey.cvv, in: node)?.value ?? ""
        pin = stringValue(for: CreditCardFieldKey.pin, in: node)?.value ?? ""
        creditLimit = stringValue(for: CreditCardFieldKey.creditLimit, in: node)?.value ?? ""
        cashWithdrawalLimit = stringValue(for: CreditCardFieldKey.cashWithdrawalLimit, in: node)?.value ?? ""
        interestRate = stringValue(for: CreditCardFieldKey.interestRate, in: node)?.value ?? ""
        issueNumber = stringValue(for: CreditCardFieldKey.issueNumber, in: node)?.value ?? ""

        let storedCardType = stringValue(for: CreditCardFieldKey.cardType, in: node)?.value ?? cardType
        cardType = availableCardTypes.contains(storedCardType) ? storedCardType : "Other"

        let expiryString = stringValue(for: CreditCardFieldKey.expiryDate, in: node)?.value ?? ""
        expiryDate = parseDate(from: expiryString)
        expiryDateString = expiryString

        correctLegacyMonthShift(model)

        let validFromValue = stringValue(for: CreditCardFieldKey.validFrom, in: node)?.value ?? ""
        validFromDate = parseDate(from: validFromValue)
        validFromString = validFromValue

        notes = model.notes
        icon = model.icon ?? node.icon ?? Self.getDefaultCreditCardIcon()
        iconExplicitlyChanged = false

        syncCustomFieldsFromModel()
        customFieldsMarkedForRemoval.removeAll()
    }

    func updateModel() {
        guard let model = model else { return }

        model.title = normalizedTitle()
        model.username = cardholderName
        model.password = cardNumber
        model.notes = notes
        model.expires = expiryDate

        if initialNodeId == nil || iconExplicitlyChanged {
            model.icon = icon
        }

        updateCustomFieldsInModel()
    }

    private func updateCustomFieldsInModel() {
        guard let model = model else { return }

        clearExistingCustomFields(from: model)

        setCustomField(CreditCardFieldKey.name, value: title, protected: false)
        setCustomField(CreditCardFieldKey.cardholderName, value: cardholderName, protected: false)
        setCustomField(CreditCardFieldKey.cardType, value: cardTypeValueForStorage(), protected: false)
        setCustomField(CreditCardFieldKey.cardNumber, value: cardNumber, protected: true)
        setCustomField(CreditCardFieldKey.expiryDate, value: expiryDateString, protected: false)
        setCustomField(CreditCardFieldKey.validFrom, value: validFromString, protected: false)
        setCustomField(CreditCardFieldKey.cvv, value: cvv, protected: true)
        setCustomField(CreditCardFieldKey.pin, value: pin, protected: true)
        setCustomField(CreditCardFieldKey.creditLimit, value: creditLimit, protected: false)
        setCustomField(CreditCardFieldKey.cashWithdrawalLimit, value: cashWithdrawalLimit, protected: false)
        setCustomField(CreditCardFieldKey.interestRate, value: interestRate, protected: false)
        setCustomField(CreditCardFieldKey.issueNumber, value: issueNumber, protected: false)

        for customField in customFields where !Self.reservedFieldKeys.contains(customField.key) {
            guard !customField.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let field = CustomFieldViewModel.customField(withKey: customField.key, value: customField.value, protected: customField.protected)
            model.addCustomField(field)
        }

        customFieldsMarkedForRemoval.removeAll()
    }

    private func clearExistingCustomFields(from model: EntryViewModel) {
        let keysToRemove = model.customFieldsFiltered.map { $0.key } + Array(customFieldsMarkedForRemoval)

        let uniqueKeys = Set(keysToRemove)
        for key in uniqueKeys {
            while let index = model.customFieldsFiltered.firstIndex(where: { $0.key == key }) {
                model.removeCustomField(at: UInt(index))
            }
        }
    }

    private func setCustomField(_ key: String, value: String, protected: Bool) {
        guard let model = model else { return }
        let field = CustomFieldViewModel.customField(withKey: key, value: value, protected: protected)
        model.addCustomField(field)
    }
    
    func save() -> UUID? {
        updateModel()
        
        guard let model = model else {
            swlog("🔴 Model not available for saving")
            return nil
        }
        
        if let nodeId = initialNodeId {
            if database.applyEditsAndMoves(model, toNode: nodeId) {
                if let updatedNode = database.getItemBy(nodeId) {
                    applyCreditCardFields(to: updatedNode)
                    database.database.rebuildFastMaps()
                }
                return nodeId
            }
        } else {
            guard let dbModel = database.commonModel else {
                swlog("🔴 Could not load common model!")
                return nil
            }
            
            let parentGroup: Node
            if let parentGroupUuid = model.parentGroupUuid,
               let foundParent = database.getItemBy(parentGroupUuid) {
                parentGroup = foundParent
            } else {
                parentGroup = database.rootGroup
            }
            
            let node = Node(asRecord: model.title, parent: parentGroup)
            model.apply(to: node, model: dbModel, legacySupplementaryTotp: false, addOtpAuthUrl: true)
            applyCreditCardFields(to: node)
            
            node.icon = icon
            
            if database.addChildren([node], parent: parentGroup) {
                database.database.rebuildFastMaps()
                database.nextGenSelectedItems = [node.uuid]
                
                initialNodeId = node.uuid
                
                if Settings.sharedInstance().autoSave {
                    DispatchQueue.main.async { [weak self] in
                        self?.database.document?.save(nil)
                    }
                }
                
                return node.uuid
            }
        }
        
        return nil
    }
    
    func addCustomField(key: String, value: String, protected: Bool) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        guard !Self.reservedFieldKeys.contains(trimmedKey) else {
            swlog("🔴 Attempted to add reserved credit card field key: \(trimmedKey)")
            return
        }
        customFieldsMarkedForRemoval.remove(trimmedKey)
        customFields.append((key: trimmedKey, value: value, protected: protected))
    }

    func removeCustomField(at index: Int) {
        guard index < customFields.count else { return }
        let key = customFields[index].key
        if !key.isEmpty {
            customFieldsMarkedForRemoval.insert(key)
        }
        customFields.remove(at: index)
    }
    
    func updateCustomField(at index: Int, key: String, value: String, protected: Bool) {
        guard index < customFields.count else { return }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        guard !Self.reservedFieldKeys.contains(trimmedKey) else {
            swlog("🔴 Attempted to rename custom field to reserved key: \(trimmedKey)")
            return
        }
        customFields[index] = (key: trimmedKey, value: value, protected: protected)
    }

    func removeCustomField(withKey key: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        customFieldsMarkedForRemoval.insert(trimmedKey)
        if let index = customFields.firstIndex(where: { $0.key == trimmedKey }) {
            customFields.remove(at: index)
        }
    }

    func syncCustomFieldsFromModel() {
        guard let model else {
            customFields = []
            customFieldsMarkedForRemoval.removeAll()
            return
        }

        customFields = model.customFieldsFiltered.map { field in
            (key: field.key, value: field.value, protected: field.protected)
        }

        customFieldsMarkedForRemoval = Set(customFieldsMarkedForRemoval.filter { key in
            customFields.contains { $0.key == key } == false
        })
    }
    
    func setValidFromDate() {
        validFromDate = Date()
    }
    
    func setExpiryDate() {
        let now = Date()
        expiryDate = now.addMonth(n: 3)
    }
    
    func clearValidFromDate() {
        validFromDate = nil
    }
    
    func clearExpiryDate() {
        expiryDate = nil
    }
    
    func setIcon(_ newIcon: NodeIcon?) {
        if let newIcon = newIcon {
            icon = newIcon
            iconExplicitlyChanged = true
        }
    }
    
    var parentGroupUuid: UUID? {
        return model?.parentGroupUuid
    }
    
    func setParentGroup(_ groupUuid: UUID) {
        model?.parentGroupUuid = groupUuid
    }
    
    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && !trimmedNumber.isEmpty
    }

    var hasChanges: Bool {
        return true
    }

    private func normalizedTitle() -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Credit Card" : trimmed
    }

    private func cardTypeValueForStorage() -> String {
        availableCardTypes.contains(cardType) ? cardType : "Other"
    }

    private func parseDate(from string: String) -> Date? {
        CreditCardExpiryDateFormatting.parseDate(from: string)
    }

    private func correctLegacyMonthShift(_ model: EntryViewModel) {
        if let corrected = CreditCardExpiryDateFormatting.legacyMonthShiftCorrection(parsedExpiry: expiryDate, entryExpires: model.expires) {
            expiryDate = corrected
            expiryDateString = formatExpiryDateString(corrected)
        }
    }

    private func formatExpiryDateString(_ date: Date) -> String {
        CreditCardExpiryDateFormatting.format(date)
    }

    private func stringValue(for key: String, in node: Node) -> (value: String, protected: Bool)? {
        let customFields = node.fields.customFields

        if let stringValue = customFields[key as NSString] {
            return (stringValue.value, stringValue.protected)
        }

        if let aliases = CreditCardReservedFieldKeys.legacyFieldAliases[key] {
            for alias in aliases {
                if let stringValue = customFields[alias as NSString] {
                    return (stringValue.value, stringValue.protected)
                }
            }
        }

        return nil
    }

    func isReservedCustomFieldKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.reservedFieldKeys.contains(trimmed)
    }

    private func applyCreditCardFields(to node: Node) {
        let resolvedTitle = normalizedTitle()
        _ = node.setTitle(resolvedTitle, keePassGroupTitleRules: false)
        node.fields.notes = notes

        ensureDefaultIcon(for: node)

        let desiredCustomFieldKeys = Set(customFields.map { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        let existingKeys: [String] = node.fields.customFields.allKeys().compactMap { key in
            if let str = key as? String {
                return str
            } else if let nsStr = key as? NSString {
                return String(nsStr)
            }
            return nil
        }

        for key in existingKeys where !Self.reservedFieldKeys.contains(key) && !desiredCustomFieldKeys.contains(key) {
            node.fields.removeCustomField(key)
        }

        for key in Self.reservedFieldKeys {
            node.fields.removeCustomField(key)
        }

        node.fields.setCustomField(CreditCardFieldKey.name, value: StringValue(string: title, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.cardholderName, value: StringValue(string: cardholderName, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.cardType, value: StringValue(string: cardTypeValueForStorage(), protected: false))
        node.fields.setCustomField(CreditCardFieldKey.cardNumber, value: StringValue(string: cardNumber, protected: true))
        node.fields.setCustomField(CreditCardFieldKey.expiryDate, value: StringValue(string: expiryDateString, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.validFrom, value: StringValue(string: validFromString, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.cvv, value: StringValue(string: cvv, protected: true))
        node.fields.setCustomField(CreditCardFieldKey.pin, value: StringValue(string: pin, protected: true))
        node.fields.setCustomField(CreditCardFieldKey.creditLimit, value: StringValue(string: creditLimit, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.cashWithdrawalLimit, value: StringValue(string: cashWithdrawalLimit, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.interestRate, value: StringValue(string: interestRate, protected: false))
        node.fields.setCustomField(CreditCardFieldKey.issueNumber, value: StringValue(string: issueNumber, protected: false))

        for field in customFields where !Self.reservedFieldKeys.contains(field.key) {
            let value = StringValue(string: field.value, protected: field.protected)
            node.fields.setCustomField(field.key, value: value)
        }

        node.fields.touch(true)
    }

    private func ensureDefaultIcon(for node: Node) {
        if node.icon == nil || (node.icon?.isCustom == false && node.icon?.preset == 0) {
            node.icon = Self.getDefaultCreditCardIcon()
        }
    }

    static func getDefaultCreditCardIcon() -> NodeIcon {
        return NodeIcon.withPreset(9)
    }

    var customFieldSuggestions: Set<String> {
        return Set([
            "Bank Name",
            "Account Number",
            "Customer Service",
            "Annual Fee",
            "Reward Program",
            "Statement Date",
            "Payment Due Date",
            "Minimum Payment",
            "Billing Cycle",
            "Support Phone"
        ])
    }

    var availableCardTypes: [String] {
        return [
            "Visa",
            "MasterCard",
            "American Express",
            "Discover",
            "Diners Club",
            "JCB",
            "Other"
        ]
    }

    var favourite: Bool {
        get { model?.favourite ?? false }
        set { model?.favourite = newValue }
    }
}
