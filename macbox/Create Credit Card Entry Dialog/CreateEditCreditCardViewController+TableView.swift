import Foundation
import Cocoa

extension CreateEditCreditCardViewController {
    
    func setupCustomFields() {
        tableViewCustomFields.register(NSNib(nibNamed: NSNib.Name("GenericAutoLayoutTableViewCell"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("GenericAutoLayoutTableViewCell"))
        
        buttonRemoveField.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        buttonEditField.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)
        buttonAddField.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
        
        tableViewCustomFields.doubleAction = #selector(onEditField(_:))
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
    
    @IBAction func onAddField(_ sender: Any) {
        let vc = EditCustomFieldController.fromStoryboard()

        if let model = model {
            vc.existingKeySet = model.existingCustomFieldsKeySet
        } else {
            vc.existingKeySet = Set(customFields.map { $0.key })
        }

        vc.customFieldKeySet = customFieldKeySet

        vc.onSetField = { [weak self] key, value, protected in
            guard let self else { return }

            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if self.viewModel?.isReservedCustomFieldKey(trimmedKey) == true {
                MacAlerts.info("Reserved Field", informativeText: "That field is managed automatically for credit cards.", window: self.view.window, completion: nil)
                return
            }

            if let model = self.model {
                let field = CustomFieldViewModel.customField(withKey: trimmedKey, value: value, protected: protected)
                model.addCustomField(field)
            } else {
                self.customFields.append((key: trimmedKey, value: value, protected: protected))
                self.viewModel?.addCustomField(key: trimmedKey, value: value, protected: protected)
            }
            self.onModelEdited()
            self.refreshCustomFields()
        }

        presentAsSheet(vc)
    }
    
    @IBAction func onEditField(_ sender: Any?) {
        guard let idx = tableViewCustomFields.selectedRowIndexes.first else { return }

        let vc = EditCustomFieldController.fromStoryboard()

        if let model = model, idx < filteredCustomFields.count {
            let field = filteredCustomFields[idx]
            
            vc.existingKeySet = model.existingCustomFieldsKeySet
            vc.customFieldKeySet = customFieldKeySet

            vc.field = CustomField()
            vc.field.key = field.key
            vc.field.value = field.value
            vc.field.protected = field.protected

            vc.onSetField = { [weak self] key, value, protected in
                guard let self else { return }

                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                if self.viewModel?.isReservedCustomFieldKey(trimmedKey) == true {
                    MacAlerts.info("Reserved Field", informativeText: "That field is managed automatically for credit cards.", window: self.view.window, completion: nil)
                    return
                }

                let newField = CustomFieldViewModel.customField(withKey: trimmedKey, value: value, protected: protected)

                if let originalModelIndex = self.originalModelIndex(for: idx) {
                    self.model?.removeCustomField(at: UInt(originalModelIndex))
                    self.model?.addCustomField(newField)
                } else {
                    self.customFields[idx] = (key: trimmedKey, value: value, protected: protected)
                }

                self.refreshCustomFields()
                self.onModelEdited()
            }
        } else {
            guard idx < customFields.count else { return }
            let field = customFields[idx]
            
            vc.existingKeySet = Set(customFields.map { $0.key })
            vc.customFieldKeySet = customFieldKeySet
            
            vc.field = CustomField()
            vc.field.key = field.key
            vc.field.value = field.value
            vc.field.protected = field.protected
            
            vc.onSetField = { [weak self] key, value, protected in
                guard let self else { return }
                let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                if self.viewModel?.isReservedCustomFieldKey(trimmedKey) == true {
                    MacAlerts.info("Reserved Field", informativeText: "That field is managed automatically for credit cards.", window: self.view.window, completion: nil)
                    return
                }
                self.customFields[idx] = (key: trimmedKey, value: value, protected: protected)
                self.viewModel?.updateCustomField(at: idx, key: trimmedKey, value: value, protected: protected)
                self.onModelEdited()
                self.refreshCustomFields()
            }
        }

        presentAsSheet(vc)
    }
    
    @IBAction func onRemoveField(_ sender: Any) {
        let selectedRows = tableViewCustomFields.selectedRowIndexes
        guard !selectedRows.isEmpty else { return }
        
        let alert = NSAlert()
        alert.messageText = "Remove Custom Field"
        alert.informativeText = "Are you sure you want to remove the selected field(s)?"
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let model = model {
                var offsetIndex = 0
                for row in selectedRows {
                    let filteredRow = row - offsetIndex
                    if let originalModelIndex = self.originalModelIndex(for: filteredRow) {
                        let field = self.filteredCustomFields[filteredRow]
                        self.viewModel?.removeCustomField(withKey: field.key)
                        model.removeCustomField(at: UInt(originalModelIndex))
                    }
                    offsetIndex += 1
                }
                onModelEdited()
            } else {
                for row in selectedRows.reversed() {
                    if row < customFields.count {
                        viewModel?.removeCustomField(at: row)
                        customFields.remove(at: row)
                    }
                }
                onModelEdited()
            }
            refreshCustomFields()
        }
    }
}

extension CreateEditCreditCardViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let model = model {
            return filteredCustomFields.count
        } else {
            return customFields.count
        }
    }
    
    private var filteredCustomFields: [CustomFieldViewModel] {
        guard let model = model else { return [] }
        
        let creditCardFields = Set([
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
            "IssueNumber",
            "Credit Card Name",
            "Cardholder Name",
            "Card Holder",
            "Card Type",
            "Card Number",
            "Expiry Date",
            "Credit Limit",
            "Cash Withdrawal Limit",
            "Interest Rate",
            "Issue Number",
            "Valid From"
        ])
        
        return model.customFieldsFiltered.filter { field in
            !creditCardFields.contains(field.key)
        }
    }
    
    private func originalModelIndex(for filteredIndex: Int) -> Int? {
        guard let model = model, filteredIndex < filteredCustomFields.count else { return nil }
        
        let targetField = filteredCustomFields[filteredIndex]
        
        return model.customFieldsFiltered.firstIndex { field in
            field.key == targetField.key && field.value == targetField.value && field.protected == targetField.protected
        }
    }
}

extension CreateEditCreditCardViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let isKeyColumn = tableColumn?.identifier.rawValue == "CustomFieldKeyColumn"
        
        if let model = model {
            let fields = filteredCustomFields
            guard row < fields.count else { return nil }
            let field = fields[row]
            
            if isKeyColumn {
                let identifier = NSUserInterfaceItemIdentifier("GenericAutoLayoutTableViewCell")
                let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
                
                if cell == nil {
                    let newCell = NSTableCellView()
                    let textField = NSTextField()
                    textField.isBordered = false
                    textField.isEditable = false
                    textField.backgroundColor = .clear
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    newCell.addSubview(textField)
                    newCell.textField = textField
                    
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 2),
                        textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -2),
                        textField.topAnchor.constraint(equalTo: newCell.topAnchor, constant: 2),
                        textField.bottomAnchor.constraint(equalTo: newCell.bottomAnchor, constant: -2)
                    ])
                    
                    newCell.identifier = identifier
                    return newCell
                }
                
                cell?.textField?.stringValue = field.key
                return cell
            } else {
                let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("CustomFieldValueCellIdentifier"), owner: nil) as? CustomFieldTableCellView
                
                if let cell = cell {
                    cell.value = field.value
                    cell.protected = field.protected
                    cell.valueHidden = field.protected
                    return cell
                } else {
                    let identifier = NSUserInterfaceItemIdentifier("GenericAutoLayoutTableViewCell")
                    let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
                    cell?.textField?.stringValue = field.protected ? "••••••••" : field.value
                    return cell
                }
            }
        } else {
            guard row < customFields.count else { return nil }
            
            let field = customFields[row]
            
            let identifier = NSUserInterfaceItemIdentifier("GenericAutoLayoutTableViewCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView
            
            if cell == nil {
                let newCell = NSTableCellView()
                let textField = NSTextField()
                textField.isBordered = false
                textField.isEditable = false
                textField.backgroundColor = .clear
                textField.translatesAutoresizingMaskIntoConstraints = false
                newCell.addSubview(textField)
                newCell.textField = textField
                
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 2),
                    textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -2),
                    textField.topAnchor.constraint(equalTo: newCell.topAnchor, constant: 2),
                    textField.bottomAnchor.constraint(equalTo: newCell.bottomAnchor, constant: -2)
                ])
                
                newCell.identifier = identifier
                return newCell
            }
            
            if isKeyColumn {
                cell?.textField?.stringValue = field.key
            } else {
                cell?.textField?.stringValue = field.protected ? "••••••••" : field.value
            }
            
            return cell
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        bindCustomFieldsButtons()
    }
} 
