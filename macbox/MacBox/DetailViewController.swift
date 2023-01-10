//
//  DetailViewController.swift
//  MacBox
//
//  Created by Strongbox on 27/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

import Cocoa
import QuickLookUI

protocol DetailTableCellViewPopupButton {
    func showPopupButtonMenu()
}

class DetailViewController: NSViewController {
    deinit {
        NSLog("😎 DEINIT [DetailViewController]")
    }

    @IBOutlet var tableView: TableViewWithKeyDownEvents!

    let synthesizer = NSSpeechSynthesizer()

    private weak var document: Document!
    private var database: ViewModel!
    private var loadedDocument: Bool = false
    private var fixedItemUuid: UUID? 

    var currentAttachmentPreviewIndex: Int = 0 

    var quickRevealButtonDown: Bool = false

    var dragAndDropPromiseQueue: OperationQueue = {
        let queue = OperationQueue()
        return queue
    }()

    var selectedField: DetailsViewField? {
        guard let idx = tableView.selectedRowIndexes.first,
              let field = fields[safe: idx]
        else {
            NSLog("🔴 selectedField couldn't get a selected field?!")
            return nil
        }

        return field
    }

    func rowViewForField(_ field: DetailsViewField) -> NSTableRowView? {
        guard let idx = fields.firstIndex(where: { $0 === field }) else { return nil }

        return tableView.rowView(atRow: idx, makeIfNecessary: false)
    }

    func cellViewForField(_ field: DetailsViewField) -> NSView? {
        guard let idx = fields.firstIndex(where: { $0 === field }) else { return nil }

        return tableView.view(atColumn: 0, row: idx, makeIfNecessary: false)
    }

    

    private var cached: [DetailsViewField]?
    private var fields: [DetailsViewField] {
        if cached == nil {
            cached = loadFields()
        }

        return cached!
    }

    @objc func refresh() {

        cached = nil
        tableView.reloadData()
    }

    @objc
    func handleCopy() -> Bool {
        guard view.window?.firstResponder == tableView, let selectedField = selectedField else {
            return false
        }
                
        if selectedField.fieldType == .notes {
            if let cellView = cellViewForField(selectedField) as? NotesTableCellView {
                if cellView.isSomeTextSelected {
                    NSLog("Some Notes Text Selected not copying")
                    cellView.copySelectedText()
                    let loc = NSLocalizedString("mac_notes_partially_copied_to_clipboard", comment: "Notes (Partially) Copied") 
            
                    showPopupToast(loc, view: cellView)

                    return true
                }
            }
        }

        NSLog("There is a field selected... copying")

        copyFieldToClipboard(selectedField)
        
        return true
    }
    
    func loadFields() -> [DetailsViewField] {
        let selectedNode: Node

        guard let dbModel = database.commonModel else {

            return []
        }

        if let fixedItemUuid = fixedItemUuid {
            guard let node = database.getItemBy(fixedItemUuid) else {
                NSLog("✅ DetailViewController::load - fixedItemUuid empty")
                return []
            }

            selectedNode = node
        }
        else {
            guard database.nextGenSelectedItems.count == 1,
                  let uuid = database.nextGenSelectedItems.first,
                  let node = database.getItemBy(uuid)
            else {
                NSLog("✅ DetailViewController::load - database.nextGenSelectedItems could not find")
                return []
            }

            selectedNode = node
        }



        let model = EntryViewModel.fromNode(selectedNode, format: database.format, model: dbModel, sortCustomFields: !database.customSortOrderForFields)

        var ret: [DetailsViewField] = []

        ret.append(getTitleField(model, selectedNode))
        ret.append(contentsOf: getUsernameFields(model, selectedNode))
        ret.append(contentsOf: getPasswordFields(model, selectedNode))
        ret.append(contentsOf: getAuditIssueFields(model, selectedNode))
        ret.append(contentsOf: getTotpFields(model))
        ret.append(contentsOf: getEmailFields(model, selectedNode))
        ret.append(contentsOf: getExpiresFields(model))
        ret.append(contentsOf: loadUrlFields(model, selectedNode))
        ret.append(contentsOf: loadTagsFields(model))
        ret.append(contentsOf: loadCustomFields(model, selectedNode))
        ret.append(contentsOf: loadAttachments(model))
        ret.append(contentsOf: loadNotes(model, selectedNode))
        ret.append(contentsOf: loadMetadataFields(model))

        return ret
    }

    func dereference(_ string: String, node: Node) -> String {
        return database.dereference(string, node: node)
    }

    func getTitleField(_ model: EntryViewModel, _ node: Node) -> DetailsViewField {
        let titleField = DetailsViewField(name: NSLocalizedString("generic_fieldname_title", comment: "Title"),
                                          value: dereference(model.title, node: node),
                                          fieldType: .title,
                                          icon: model.icon)

        return titleField
    }

    func getUsernameFields(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        if model.username.count > 0 {
            return [DetailsViewField(name: NSLocalizedString("generic_fieldname_username", comment: "Username"),
                                     value: dereference(model.username, node: node),
                                     fieldType: .customField)]
        } else {
            return []
        }
    }

    func getPasswordFields(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        if model.password.count > 0 {
            let dereferencedPassword = dereference(model.password, node: node)

            return [DetailsViewField(name: NSLocalizedString("generic_fieldname_password", comment: "Password"),
                                     value: dereferencedPassword,
                                     fieldType: .customField,
                                     concealed: !Settings.sharedInstance().revealPasswordsImmediately && !quickRevealButtonDown,
                                     concealable: true,
                                     showStrength: true)]
        } else {
            return []
        }
    }

    func getAuditIssueFields(_: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        if database.isFlagged(byAudit: node.uuid) {


            for issue in database.getQuickAuditAllIssuesSummary(forNode: node.uuid) {
                ret.append(DetailsViewField(name: issue,
                                            value: issue,
                                            fieldType: .auditIssue,
                                            object: node.uuid))
            }
        }

        if database.isExcluded(fromAudit: node.uuid) {
            ret.append(DetailsViewField(name: "", 
                                        value: "",
                                        fieldType: .auditIssue,
                                        object: node.uuid))
        }

        return ret
    }

    func getTotpFields(_ model: EntryViewModel) -> [DetailsViewField] {
        if model.totp != nil, database.showTotp {
            return [DetailsViewField(name: NSLocalizedString("generic_fieldname_totp", comment: "TOTP"), value: "", fieldType: .totp, object: model.totp!)]
        } else {
            return []
        }
    }

    func getEmailFields(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        if model.email.count > 0 {
            return [DetailsViewField(name: NSLocalizedString("generic_fieldname_email", comment: "Email"),
                                     value: dereference(model.email, node: node),
                                     fieldType: .customField)]
        } else {
            return []
        }
    }

    func getExpiresFields(_ model: EntryViewModel) -> [DetailsViewField] {
        if let expires = model.expires {
            return [DetailsViewField(name: NSLocalizedString("generic_fieldname_expiry_date", comment: "Expiry Date"),
                                     value: "",
                                     fieldType: .expiry,
                                     object: expires)]
        } else {
            return []
        }
    }

    func getUrlsHeaderField() -> DetailsViewField {
        return DetailsViewField(name: NSLocalizedString("generic_fieldname_urls", comment: "URLs"),
                                value: "",
                                fieldType: .header,
                                object: DetailsViewField.FieldType.url)
    }

    func getUrlField(_ model: EntryViewModel, _ node : Node, _ dereferencedPassword: String) -> DetailsViewField {
        return DetailsViewField(name: NSLocalizedString("generic_fieldname_url", comment: "URL"),
                                value: dereference(model.url, node: node),
                                fieldType: .url,
                                object: dereferencedPassword)
    }

    fileprivate func loadUrlFields(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        var fields: [DetailsViewField] = []

        let alternativeUrls = model.customFields.filter { NodeFields.isAlternativeURLCustomFieldKey($0.key) }

        if !alternativeUrls.isEmpty {
            fields.append(getUrlsHeaderField())
        }

        let dereferencedPassword = dereference(model.password, node: node)

        if model.url.count > 0 {
            fields.append(getUrlField(model, node, dereferencedPassword))
        }

        for alternativeUrl in alternativeUrls {
            let deref = dereference(alternativeUrl.value, node: node)

            fields.append(DetailsViewField(name: alternativeUrl.key, value: deref, fieldType: .url, object: dereferencedPassword))
        }

        return fields
    }

    fileprivate func loadTagsFields(_ model: EntryViewModel) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        if model.tags.count > 0 {
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_tags", comment: "Tags"), value: "", fieldType: .header, object: DetailsViewField.FieldType.tags))
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_tags", comment: "Tags"), value: "", fieldType: .tags, object: model.tags))
        }

        return ret
    }

    fileprivate func loadCustomFields(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        let filtered = model.customFields.filter { field in 
            !NodeFields.isTotpCustomFieldKey(field.key) && !NodeFields.isAlternativeURLCustomFieldKey(field.key)
        }

        if !filtered.isEmpty {
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_custom_fields", comment: "Custom Fields"),
                                        value: "",
                                        fieldType: .header,
                                        object: DetailsViewField.FieldType.customField))

            for field in filtered {
                let concealEmpty = database.concealEmptyProtectedFields
                let isEmpty = field.value.count == 0
                let concealable = (isEmpty && concealEmpty) || (!isEmpty && field.concealedInUI)

                let deref = dereference(field.value, node: node)

                ret.append(DetailsViewField(name: field.key,
                                            value: deref,
                                            fieldType: .customField,
                                            concealed: !Settings.sharedInstance().revealPasswordsImmediately && !quickRevealButtonDown,
                                            concealable: concealable))
            }
        }

        return ret
    }

    fileprivate func loadAttachments(_ model: EntryViewModel) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        if model.attachments.count > 0 {
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_attachments", comment: "Attachments"),
                                        value: "",
                                        fieldType: .header,
                                        object: DetailsViewField.FieldType.attachment))

            for key in model.attachments.allKeys() {
                guard let attachment = model.attachments[key] else {
                    continue
                }

                ret.append(DetailsViewField(name: key as String, value: "", fieldType: .attachment, object: attachment))
            }
        }

        return ret
    }

    fileprivate func loadNotes(_ model: EntryViewModel, _ node: Node) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        if model.notes.count > 0 {
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_notes", comment: "Notes"),
                                        value: "",
                                        fieldType: .header,
                                        object: DetailsViewField.FieldType.notes))

            let deref = dereference(model.notes, node: node)
            ret.append(DetailsViewField(name: NSLocalizedString("generic_fieldname_notes", comment: "Notes"),
                                        value: deref,
                                        fieldType: .notes))
        }

        return ret
    }

    fileprivate func loadMetadataFields(_ model: EntryViewModel) -> [DetailsViewField] {
        var ret: [DetailsViewField] = []

        if !model.metadata.isEmpty {
            ret.append(DetailsViewField(name: NSLocalizedString("item_details_section_header_metadata", comment: "Metadata"),
                                        value: "",
                                        fieldType: .header,
                                        object: DetailsViewField.FieldType.metadata))

            for meta in model.metadata {
                ret.append(DetailsViewField(name: meta.key, value: meta.value, fieldType: .metadata))
            }
        }

        return ret
    }

    











    
    












    



    @objc
    func onDoubleClick() {
        if tableView.clickedRow == tableView.selectedRow {
            performDefaultActionOnSelected()
        }
    }

    func onShowFieldPopupMenu() {
        guard let selectedFieldRow = tableView.selectedRowIndexes.first,
              let cellView = tableView.view(atColumn: 0, row: selectedFieldRow, makeIfNecessary: false) as? DetailTableCellViewPopupButton
        else {
            NSLog("🔴 could not get select field as popup button")
            return
        }

        cellView.showPopupButtonMenu()
    }

    func performDefaultActionOnSelected() {
        guard let field = selectedField else { return }

        switch field.fieldType {
        case .attachment:
            previewAttachment(field)
        case .title, .customField, .url, .totp:
            copyFieldToClipboard(field)
        case .header, .metadata, .expiry, .tags, .auditIssue, .notes:
            break
        }
    }

    func onShowQuickView() {
        guard let field = selectedField else { return }

        switch field.fieldType {
        case .attachment:
            previewAttachment(field)




        default:
            break
        }
    }

    

    func copyFieldToClipboard(_ name: String, _ value: String, notificationView: NSView?) {
        ClipboardManager.sharedInstance().copyConcealedString(value)

        let loc = NSLocalizedString("mac_field_copied_to_clipboard_no_item_title_fmt", comment: "%@ Copied")
        let message = String(format: loc, name)

        showPopupToast(message, view: notificationView)
    }

    func showPopupToast(_ message: String, view: NSView? = nil) {
        let view = view ?? self.view

        guard let hud = MBProgressHUD.showAdded(to: view, animated: true) else {
            return
        }

        let color = CIColor(cgColor: NSColor.systemBlue.cgColor)
        let defaultColor = NSColor(deviceRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)

        hud.labelText = message
        hud.color = defaultColor
        hud.mode = MBProgressHUDModeText
        hud.margin = 0.0
        hud.yOffset = 2.0
        hud.removeFromSuperViewOnHide = true
        hud.dismissible = false
        hud.cornerRadius = 5.0
        hud.dimBackground = true

        let when = DispatchTime.now() + 0.75
        DispatchQueue.main.asyncAfter(deadline: when) {
            hud.hide(true)
        }
    }

    

    func getCopyFieldMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let sel = #selector(onCopyValueMenuItem(sender:))

        let itemCopy = NSMenuItem(title: NSLocalizedString("generic_action_verb_copy_to_clipboard", comment: "Copy"),
                                  action: sel,
                                  keyEquivalent: "")

        itemCopy.target = self
        itemCopy.representedObject = field
        if #available(macOS 11.0, *) {
            itemCopy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        }

        return itemCopy
    }

    func getCopyFieldNameMenuItem(_ field: DetailsViewField, overrideTitle: String? = nil) -> NSMenuItem {
        let itemCopyFieldName = NSMenuItem(title: overrideTitle ?? NSLocalizedString("generic_action_verb_copy_field_name_to_clipboard", comment: "Copy Field Name"),
                                           action: #selector(onCopyValueNameMenuItem(sender:)), keyEquivalent: "")

        itemCopyFieldName.representedObject = field
        itemCopyFieldName.target = self

        if #available(macOS 11.0, *) {
            itemCopyFieldName.image = NSImage(systemSymbolName: "doc.on.doc.fill", accessibilityDescription: nil)
        }

        return itemCopyFieldName
    }

    func getSpellOutFieldNameMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let itemSpellOut = NSMenuItem(title: NSLocalizedString("generic_action_verb_spell_out_field", comment: "Spell Out"),
                                      action: #selector(onSpellOutMenuItem(sender:)), keyEquivalent: "")

        itemSpellOut.representedObject = field
        itemSpellOut.target = self

        if #available(macOS 11.0, *) {
            itemSpellOut.image = NSImage(systemSymbolName: "speaker.wave.3", accessibilityDescription: nil)
        }

        return itemSpellOut
    }

    func getSpeakFieldNameMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let itemSpeak = NSMenuItem(title: NSLocalizedString("generic_action_verb_speak_field", comment: "Speak"),
                                   action: #selector(onSayItMenuItem(sender:)), keyEquivalent: "")
        itemSpeak.representedObject = field
        itemSpeak.target = self

        if #available(macOS 11.0, *) {
            itemSpeak.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        }

        return itemSpeak
    }

    func getLaunchUrlMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let itemSpeak = NSMenuItem(title: NSLocalizedString("generic_action_verb_launch_url", comment: "Launch URL"), action: #selector(onLaunchUrlMenuItem(sender:)), keyEquivalent: "")
        itemSpeak.representedObject = field
        itemSpeak.target = self

        if #available(macOS 11.0, *) {
            itemSpeak.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        }

        return itemSpeak
    }

    func getLaunchUrlAndCopyPasswordMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let itemSpeak = NSMenuItem(title: NSLocalizedString("browse_action_launch_url_copy_password", comment: "Launch URL & Copy Password"),
                                   action: #selector(onLaunchUrlAndCopyPasswordMenuItem(sender:)), keyEquivalent: "")
        itemSpeak.representedObject = field
        itemSpeak.target = self

        if #available(macOS 11.0, *) {
            itemSpeak.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        }

        return itemSpeak
    }

    func getShowLargeTextViewMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let title = field.fieldType == .totp ? NSLocalizedString("generic_action_show_qr_code", comment: "Show QR Code") : NSLocalizedString("generic_action_show_large_text_view", comment: "Show Large Text View")

        let item = NSMenuItem(title: title, action: #selector(onShowLargeTextView(sender:)), keyEquivalent: "")
        item.representedObject = field
        item.target = self

        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        }

        return item
    }

    func getPreviewAttachmentMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("generic_action_preview_attachment", comment: "Preview Attachment"),
                              action: #selector(onPreviewAttachment(sender:)), keyEquivalent: "")
        item.representedObject = field
        item.target = self

        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        }

        return item
    }

    func getExportAttachmentMenuItem(_ field: DetailsViewField) -> NSMenuItem {
        let item = NSMenuItem(title: NSLocalizedString("generic_action_export_attachment", comment: "Export Attachment"),
                              action: #selector(onExportAttachment(sender:)), keyEquivalent: "")
        item.representedObject = field
        item.target = self

        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        }

        return item
    }

    func getToggleConcealRevealMenuItem(_ field: DetailsViewField) -> NSMenuItem? {
        guard let cellView = cellViewForField(field) as? GenericDetailFieldTableCellView else { return nil }

        let concealed = cellView.concealed
        let title = concealed ? NSLocalizedString("generic_action_reveal", comment: "Reveal") : NSLocalizedString("generic_action_conceal", comment: "Conceal")

        let item = NSMenuItem(title: title, action: #selector(onToggleRevealConceal(sender:)), keyEquivalent: "")
        item.representedObject = field
        item.target = self

        if #available(macOS 11.0, *) {
            if concealed {
                item.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
            } else {
                item.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
            }
        }

        return item
    }

    func getCheckHaveIBeenPwnedForFieldMenuItem(_ field: DetailsViewField) -> NSMenuItem? {
        let title = NSLocalizedString("check_field_with_hibp", comment: "Check with 'Have I Been Pwned?'")

        let item = NSMenuItem(title: title, action: #selector(onCheckHaveIBeenPwnedForField(sender:)), keyEquivalent: "")
        item.representedObject = field
        item.target = self

        item.isEnabled = Settings.sharedInstance().isPro

        if #available(macOS 11.0, *) {
            item.image = NSImage(systemSymbolName: "exclamationmark.shield", accessibilityDescription: nil)
        }

        return item
    }

    func onPopupMenuNeedsUpdate(_ menu: NSMenu, _ originalField: DetailsViewField) {
        while menu.items.count > 1 {
            menu.items.removeLast()
        }

        

        var field = originalField
        if field.fieldType == .header {
            if field.object as? DetailsViewField.FieldType == .some(.notes) {
                if let notesField = fields.first(where: { $0.fieldType == .notes }) {
                    field = notesField
                } else {
                    NSLog("🔴 Could not find Notes Field!")
                }
            }
            else if field.object as? DetailsViewField.FieldType == .some(.customField) {
                let itemAscending = NSMenuItem(title: NSLocalizedString("generic_sort_order_ascending", comment: "Ascending"), action: #selector(onToggleCustomFieldsSortOrder(sender:)), keyEquivalent: "")
                
                itemAscending.representedObject = NSNumber(booleanLiteral: false)
                itemAscending.target = self
                itemAscending.state = database.customSortOrderForFields ? .off : .on
                
                let itemCustom = NSMenuItem(title: NSLocalizedString("generic_sort_order_custom", comment: "Custom"), action: #selector(onToggleCustomFieldsSortOrder(sender:)), keyEquivalent: "")
                itemCustom.representedObject = NSNumber(booleanLiteral: true)
                itemCustom.target = self
                itemCustom.state = database.customSortOrderForFields ? .on : .off

                menu.addItem(itemAscending)
                menu.addItem(itemCustom)
                
                return
            }
        }

        

        let header = NSMenuItem()
        header.attributedTitle = NSAttributedString(string: field.name, attributes: [.font: FontManager.shared.boldBodyFont])
        header.isEnabled = false
        menu.addItem(header)

        

        if field.fieldType != .attachment {
            menu.addItem(getCopyFieldMenuItem(field))
            if field.fieldType == .customField, field.concealable {
                if let menuItem = getToggleConcealRevealMenuItem(field) {
                    menu.addItem(menuItem)
                }

                if let menuItem2 = getCheckHaveIBeenPwnedForFieldMenuItem(field) {
                    menu.addItem(menuItem2)
                }
            }
            menu.addItem(getShowLargeTextViewMenuItem(field))
        }

        if field.fieldType == .url {
            menu.addItem(NSMenuItem.separator())

            menu.addItem(getLaunchUrlMenuItem(field))
            menu.addItem(getLaunchUrlAndCopyPasswordMenuItem(field))
        }

        menu.addItem(NSMenuItem.separator())

        if field.fieldType != .attachment {
            menu.addItem(getSpellOutFieldNameMenuItem(field))
            menu.addItem(getSpeakFieldNameMenuItem(field))
        }

        if field.fieldType == .attachment {
            menu.addItem(getPreviewAttachmentMenuItem(field))
            menu.addItem(getExportAttachmentMenuItem(field))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(getCopyFieldNameMenuItem(field, overrideTitle: NSLocalizedString("generic_action_copy_filename", comment: "Copy Filename")))
        } else {
            menu.addItem(NSMenuItem.separator())
            menu.addItem(getCopyFieldNameMenuItem(field))
        }
    }

    @objc
    func onCopyValueMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        copyFieldToClipboard(field)
    }

    @objc
    func onCopyValueNameMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        copyFieldNameToClipboard(field)
    }

    @objc
    func onLaunchUrlMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        launchUrl(field)
    }

    @objc
    func onToggleCustomFieldsSortOrder(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let sort = menuItem.representedObject as? NSNumber else {
            return
        }
        
        NSLog("onToggleCustomFieldsSortOrder: %hhd", sort.boolValue)
        
        database.customSortOrderForFields = sort.boolValue
        refresh()
    }

    @objc
    func onLaunchUrlAndCopyPasswordMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        launchAndCopyPassword(field)
    }

    @objc
    func onSayItMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        sayIt(field)
    }

    @objc
    func onSpellOutMenuItem(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        spellOut(field)
    }

    @objc
    func onShowLargeTextView(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        showLargeTextView(field)
    }

    @objc
    func onPreviewAttachment(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        previewAttachment(field)
    }

    @objc
    func onExportAttachment(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        exportAttachment(field)
    }

    @objc
    func onToggleRevealConceal(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        toggleRevealConceal(field)
    }

    @objc
    func onCheckHaveIBeenPwnedForField(sender: Any?) {
        guard let menuItem = sender as? NSMenuItem, let field = menuItem.representedObject as? DetailsViewField else {
            return
        }

        checkHaveIBeenPwnedForField(field)
    }

    

    func copyFieldToClipboard(_ field: DetailsViewField) {
        if field.fieldType == .totp {
            guard let token = field.object as? OTPToken else { return }
            copyFieldToClipboard(field.name, token.password, notificationView: rowViewForField(field))
        } else {
            copyFieldToClipboard(field.name, field.value, notificationView: rowViewForField(field))
        }
    }

    func copyFieldNameToClipboard(_ field: DetailsViewField) {
        copyFieldToClipboard(NSLocalizedString("generic_field_name", comment: "Field Name"), field.name, notificationView: rowViewForField(field))
    }

    func launchUrl(_ field: DetailsViewField) {
        guard field.fieldType == .url else { return }

        database.launchUrlString(field.value)
    }

    func launchAndCopyPassword(_ field: DetailsViewField) {
        guard field.fieldType == .url else { return }

        if database.launchUrlString(field.value) {
            if let password = field.object as? String {
                copyFieldToClipboard(NSLocalizedString("generic_fieldname_password", comment: "Password"), password, notificationView: rowViewForField(field))
            }
        }
    }

    func spellOut(_ field: DetailsViewField) {
        try? synthesizer.setObject(NSSpeechSynthesizer.SpeechPropertyKey.Mode.literal, forProperty: .characterMode)

        if field.fieldType == .totp {
            guard let token = field.object as? OTPToken else { return }
            synthesizer.startSpeaking(token.password)
        } else {
            synthesizer.startSpeaking(field.value)
        }
    }

    func sayIt(_ field: DetailsViewField) {
        try? synthesizer.setObject(NSSpeechSynthesizer.SpeechPropertyKey.Mode.normal, forProperty: .characterMode)

        if field.fieldType == .totp {
            guard let token = field.object as? OTPToken else { return }
            synthesizer.startSpeaking(token.password)
        } else {
            synthesizer.startSpeaking(field.value)
        }
    }

    func showLargeTextView(_ field: DetailsViewField) {
        let vc = LargeTextViewAndQrCode.instantiateFromStoryboard()
        vc.fieldName = field.name

        if field.fieldType == .totp {
            guard let token = field.object as? OTPToken, let url = token.url(true) else { return }
            vc.string = url.absoluteString
            vc.largeText = false
        } else {
            vc.string = field.value
        }

        guard let view = rowViewForField(field) else { return }

        present(vc, asPopoverRelativeTo: .zero, of: view, preferredEdge: NSRectEdge.minY, behavior: .semitransient)
    }

    func previewAttachment(_ field: DetailsViewField) {
        let attachmentFields = fields.filter { field in
            field.fieldType == .attachment
        }

        guard let idx = attachmentFields.firstIndex(where: { f in
            f.name == field.name
        }) else {
            NSLog("🔴 Ruh Roh - Could not find the attachment in our attachments fields")
            return
        }

        currentAttachmentPreviewIndex = idx

        if QLPreviewPanel.sharedPreviewPanelExists() {
            QLPreviewPanel.shared().currentPreviewItemIndex = currentAttachmentPreviewIndex
        }

        QLPreviewPanel.shared().makeKeyAndOrderFront(self)
    }

    func exportAttachment(_ field: DetailsViewField) {
        guard let attachment = field.object as? DatabaseAttachment else {
            NSLog("🔴 Couldn't get attachment from field")
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = field.name

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

    func toggleRevealConceal(_ field: DetailsViewField) {
        guard let cellView = cellViewForField(field) as? GenericDetailFieldTableCellView else { return }

        cellView.onToggleConcealReveal(nil)
    }

    func checkHaveIBeenPwnedForField(_ field: DetailsViewField) {
        checkHaveIBeenPwned(field.value)
    }

    func checkHaveIBeenPwned(_ value: String) {
        macOSSpinnerUI.sharedInstance().show(NSLocalizedString("audit_manual_pwn_progress_message", comment: "Checking HIBP"), viewController: self)

        database.oneTimeHibpCheck(value) { [weak self] pwned, error in
            macOSSpinnerUI.sharedInstance().dismiss()

            DispatchQueue.main.async {
                self?.onHibpResult(pwned, error)
            }
        }
    }

    func onHibpResult(_ pwned: Bool, _ error: Error?) {
        if error != nil {
            MacAlerts.error(error, window: view.window)
        } else {
            if !pwned {
                MacAlerts.info(NSLocalizedString("audit_manual_pwn_check_result_title", comment: "Manual HIBP Result"),
                               informativeText: NSLocalizedString("audit_manual_pwn_check_result_not_pwned", comment: "Your password has NOT been pwned as is likely secure."),
                               window: view.window,
                               completion: nil)
            } else {
                MacAlerts.info(NSLocalizedString("audit_manual_pwn_check_result_title", comment: "Manual HIBP Result"),
                               informativeText: NSLocalizedString("audit_manual_pwn_check_result_pwned", comment: "This password is pwned and is vulnerable."),
                               window: view.window,
                               completion: nil)

                database.restartBackgroundAudit() 
            }
        }
    }
}

extension DetailViewController: DocumentViewController {
    func onDocumentLoaded() {


        load()
    }

    func load(explicitDocument: Document? = nil, explicitItemUuid: UUID? = nil) {
        if loadedDocument {
            return
        }

        if let explicitDocument = explicitDocument {
            document = explicitDocument
            fixedItemUuid = explicitItemUuid
        }
        else {
            guard let doc = view.window?.windowController?.document as? Document else {
                NSLog("🔴 DetailViewController::load Document not set!")
                return
            }
            document = doc
        }

        database = document.viewModel
        loadedDocument = true

        setupUI()

        listenToNotifications()
    }

    func refreshOnModelNotificationReceived(_ notification: Notification) {
        guard let notifyModel = notification.object as? ViewModel, notifyModel == database else {
            return
        }

        refresh()
    }

    func listenToNotifications() {
        

        let auditNotificationsOfInterest: [String] = [
            
            kAuditCompletedNotificationKey,
        ]

        for ofInterest in auditNotificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else { return }
                self.onAuditUpdateNotification(notification)
            }
        }

        let notificationsOfInterest: [String] = [kModelUpdateNotificationNextGenSelectedItemsChanged,
                                                 kModelUpdateNotificationDatabasePreferenceChanged,
                                                 kModelUpdateNotificationItemEdited,
                                                 kModelUpdateNotificationTagsChanged,
                                                 kModelUpdateNotificationHistoryItemRestored,
                                                 kModelUpdateNotificationIconChanged,
                                                 kModelUpdateNotificationItemsMoved,
                                                 kModelUpdateNotificationTitleChanged]

        for ofInterest in notificationsOfInterest {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(ofInterest), object: nil, queue: nil) { [weak self] notification in
                guard let self = self else {
                    return
                }

                self.refreshOnModelNotificationReceived(notification)
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(kModelUpdateNotificationFullReload),
                                               object: nil, queue: nil)
        { [weak self] notification in
            guard let self = self else { return }

            if notification.object as? NSDocument != self.database.document {
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.refresh()
            }
        }

        NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }

            self.refresh()
        }
    }

    func overrideValidateProposedFirstResponderForRow(row: Int) -> Bool? {
        guard let field = fields[safe: row] else {
            return false
        }


        
        if field.fieldType == .metadata {
            return true
        }
        else if field.fieldType == .url {
            return true
        }
        else if field.fieldType == .notes {
            
            
            

            if view.window?.firstResponder == tableView { 
                return selectedField?.fieldType == .notes
            }
            else {
                return false
            }
        }
        else if field.fieldType == .auditIssue {
            return true
        }
        else {
            return nil
        }
    }

    func setupUI() {
        tableView.register(NSNib(nibNamed: NSNib.Name("GenericDetailFieldTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("GenericDetailFieldTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("TitleCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("TitleCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("MetaDataTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("MetaDataTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("NotesTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("NotesTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("AttachmentTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("AttachmentTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("HeaderTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("HeaderTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("TotpTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("TotpTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("TagsTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("TagsTableCellView"))
        tableView.register(NSNib(nibNamed: NSNib.Name("UrlTableCellView"), bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier("UrlTableCellView"))
        tableView.register(NSNib(nibNamed: AuditIssueTableCellView.nibName, bundle: nil), forIdentifier: AuditIssueTableCellView.reuseIdentifier)

        tableView.selectionHighlightStyle = .regular
        tableView.overrideValidateProposedFirstResponderForRow = { [weak self] row in self?.overrideValidateProposedFirstResponderForRow(row: row) }

        if #available(macOS 10.13, *) {
            tableView.registerForDraggedTypes([.fileURL])
        }
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        tableView.doubleAction = #selector(onDoubleClick)

        tableView.onEnterKey = { [weak self] in
            self?.performDefaultActionOnSelected()
        }
        tableView.onAltEnter = { [weak self] in
            self?.onShowFieldPopupMenu()
        }
        tableView.onSpaceBar = { [weak self] in
            self?.onShowQuickView()
        }
        tableView.onEscKey = { [weak self] in
            self?.synthesizer.stopSpeaking()
        }

        let menu = NSMenu(title: "")
        menu.delegate = self
        tableView.menu = menu

        tableView.emptyMessageProvider = { [weak self] in 
            self?.noneSingleSelectionMessageProvider()
        }

        tableView.delegate = self
        tableView.dataSource = self
    }

    func noneSingleSelectionMessageProvider() -> NSAttributedString {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [.paragraphStyle: paragraphStyle,
                                                         .font: FontManager.shared.bodyFont,
                                                         .foregroundColor: NSColor.secondaryLabelColor]

        let count = database.nextGenSelectedItems.count
        let header = count == 0 ? NSLocalizedString("detail_view_no_selection_header", comment: "No Selection") : NSLocalizedString("detail_view_multiple_items_selected_header", comment: "Multiple Items")
        let message = count == 0 ? NSLocalizedString("detail_view_no_selection_message", comment: "Select an Item") : String(format: NSLocalizedString("detail_view_no_multiple_items_selected_message_fmt", comment: "%@ Items Selected"), String(count))

        let final = String(format: "%@\n%@", header, message)

        let foo = NSMutableAttributedString(string: final, attributes: attributes)

        foo.addAttributes([.font: FontManager.shared.bodyFont,
                           .foregroundColor: NSColor.labelColor], range: NSMakeRange(0, header.count))

        return foo
    }

    func onAuditUpdateNotification(_ notification: Notification) {
        
        guard let dict = notification.object as? [String: Any], let model = dict["model"] as? Model else {
            NSLog("🔴 Couldn't real model from notification")
            return
        }

        if model != database.commonModel {
            return
        }



        refresh()
    }
}

extension DetailViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {


        menu.removeAllItems()

        if let selectedField = selectedField {
            onPopupMenuNeedsUpdate(menu, selectedField)
        }
    }
}

extension DetailViewController: NSTableViewDataSource {
    func numberOfRows(in _: NSTableView) -> Int {
        return fields.count
    }
}

extension DetailViewController: NSTableViewDelegate {
    func onCopyField(field: DetailsViewField?) {
        if let field = field {
            copyFieldToClipboard(field)
        }
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard let field = fields[safe: row] else {
            NSLog("🔴 TableViewDelegate (viewFor:) called with out of range row = [%d]", row)
            return nil
        }

        switch field.fieldType {
        case .url:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("UrlTableCellView"), owner: nil) as? UrlTableCellView else {
                return nil
            }

            cell.setContent(field,
                            popupMenuUpdater:  { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) },
                            onCopyButton: Settings.sharedInstance().showCopyFieldButton ? { [weak self] field in self?.onCopyField(field: field)} : nil)

            cell.onLaunch = { [weak self] in
                self?.launchUrl(field)
            }
            cell.onLaunchAndCopy = { [weak self] in
                self?.launchAndCopyPassword(field)
            }
            return cell
        case .tags:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TagsTableCellView"), owner: nil) as? TagsTableCellView else {
                return nil
            }

            let tags = field.object as! [String]

            cell.tags = tags

            return cell
        case .expiry:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GenericDetailFieldTableCellView"), owner: nil) as? GenericDetailFieldTableCellView else {
                return nil
            }

            cell.setContent(field, popupMenuUpdater:  { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) })

            return cell
        case .customField:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("GenericDetailFieldTableCellView"), owner: nil) as? GenericDetailFieldTableCellView else {
                return nil
            }

            cell.setContent(field,
                            popupMenuUpdater:  { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) },
                            onCopyButton: Settings.sharedInstance().showCopyFieldButton ? { [weak self] field in self?.onCopyField(field: field)} : nil,
                            containingWindow: view.window)

            return cell
        case .title:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TitleCellView"), owner: nil) as? TitleCellView else {
                return nil
            }

            cell.titleLabel.stringValue = field.value
            cell.image.image = NodeIconHelper.getNodeIcon(field.icon, predefinedIconSet: database!.iconSet)

            return cell
        case .header:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderTableCellView"), owner: nil) as? HeaderTableCellView else {
                return nil
            }

            let subtype = field.object as? DetailsViewField.FieldType

            var sortImage : NSImage? = nil
            if #available(macOS 11.0, *) {
                sortImage = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: nil)
            }
            
            let sortTitle = String(format: NSLocalizedString("sort_status_fmt", comment: "Sort: %@"), database.customSortOrderForFields ? NSLocalizedString("generic_sort_order_custom", comment: "Custom") : NSLocalizedString("generic_sort_order_ascending", comment: "Ascending"));
            
            cell.setContent(field,
                            popupMenuUpdater: (subtype == .some(.notes) || subtype == .some(.customField)) ?  { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) } : nil,
                            showCopyButton: subtype == .some(.notes),
                            onCopyClicked: subtype == .some(.notes) ? { [weak self] in self?.onCopyEntiresNotes() } : nil,
                            popupMenuImage: (subtype == .some(.customField) ? sortImage : nil),
                            popupMenuText: (subtype == .some(.customField) ? sortTitle : ""))

            return cell
        case .metadata:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("MetaDataTableCellView"), owner: nil) as? MetaDataTableCellView else {
                return nil
            }

            cell.nameLabel.stringValue = field.name
            cell.valueLabel.stringValue = field.value

            return cell
        case .notes:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("NotesTableCellView"), owner: nil) as? NotesTableCellView else {
                return nil
            }

            cell.setMarkdownOrText(string: field.value, markdown: Settings.sharedInstance().markdownNotes)

            return cell
        case .attachment:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AttachmentTableCellView"), owner: nil) as? AttachmentTableCellView else {
                return nil
            }

            cell.setContent(field, popupMenuUpdater:  { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) })
            return cell
        case .totp:
            guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("TotpTableCellView"), owner: nil) as? TotpTableCellView else {
                return nil
            }

            cell.setContent(field,
                            popupMenuUpdater: { [weak self] menu, originalField in self?.onPopupMenuNeedsUpdate(menu, originalField) } ,
                            onCopyButton: Settings.sharedInstance().showCopyFieldButton ? { [weak self] field in self?.onCopyField(field: field)} : nil)

            return cell
        case .auditIssue:
            guard let cell = tableView.makeView(withIdentifier: AuditIssueTableCellView.reuseIdentifier, owner: nil) as? AuditIssueTableCellView else {
                return nil
            }

            guard let uuid = field.object as? UUID else { return nil }

            weak var weakView = cell
            cell.setContent(field.value) { [weak self] in
                guard let self = self, let weakView = weakView else { return }
                self.showAuditDrillDown(uuid, view: weakView)
            }

            return cell
        }
    }

    func onCopyEntiresNotes() {
        NSApplication.shared.sendAction(#selector(WindowController.onCopyNotes(_:)), to: nil, from: self)
    }

    func showAuditDrillDown(_ uuid: UUID, view: NSView) {
        let vc = AuditDrillDown.fromStoryboard()

        vc.uuid = uuid
        vc.database = database

        present(vc, asPopoverRelativeTo: NSZeroRect, of: view, preferredEdge: NSRectEdge.maxY, behavior: .transient)
    }

    func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
        return CustomRowView()
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard let field = fields[safe: row] else {
            NSLog("🔴 isGroupRow: called with out of range row = [%d], %@, equals = %hhd", row, tableView, tableView == self.tableView)
            return false
        }

        return field.fieldType == .header
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let field = fields[safe: row] else {
            NSLog("🔴 shouldSelectRow: called with out of range row = [%d]", row)
            return false
        }

        return field.fieldType != .header && field.fieldType != .metadata && field.fieldType != .auditIssue && field.fieldType != .title
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if #available(macOS 10.13, *) {
            return pasteboardWriterForRow(tableView, row: row)
        } else {
            return nil
        }
    }

    @available(macOS 10.13, *)
    func pasteboardWriterForRow(_: NSTableView, row: Int) -> NSPasteboardWriting? {
        guard let field = fields[safe: row], field.fieldType == .attachment else {
            return nil
        }

        let filename = field.name
        let filenameExtension = (field.name as NSString).pathExtension

        var provider: NSFilePromiseProvider

        if #available(macOS 11.0, *) {
            let typeIdentifier = UTType(filenameExtension: filenameExtension) ?? UTType.data
            provider = NSFilePromiseProvider(fileType: typeIdentifier.identifier, delegate: self)
        }
        else {
            guard let typeIdentifier = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, filenameExtension as CFString, nil) else {
                NSLog("🔴 Could not determine typeIdentifier for filename [%@]", field.name)
                return nil
            }

            provider = NSFilePromiseProvider(fileType: typeIdentifier.takeRetainedValue() as String, delegate: self)
        }

        provider.userInfo = [CreateEditViewController.FilePromiseProviderUserInfoKeys.filename: filename]

        return provider
    }
}

extension DetailViewController: NSFilePromiseProviderDelegate {
    enum DragAndDropFromDetailsError: Error {
        case attachmentDragAndDropError
    }

    @available(macOS 10.12, *)
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        NSLog("filePromiseProvider::fileNameForType called with [%@]", fileType)

        if let userInfo = filePromiseProvider.userInfo as? [String: Any],
           let filename = userInfo[CreateEditViewController.FilePromiseProviderUserInfoKeys.filename] as? String
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
               let filename = userInfo[CreateEditViewController.FilePromiseProviderUserInfoKeys.filename] as? String,
               let attachmentField = fields.first(where: { field in
                   field.fieldType == .attachment && field.name == filename
               }),
               let attachment = attachmentField.object as? DatabaseAttachment
            {
                try attachment.nonPerformantFullData.write(to: url)
            } else {
                throw DragAndDropFromDetailsError.attachmentDragAndDropError
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

extension DetailViewController: QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
        return fields.filter { field in
            field.fieldType == .attachment
        }.count
    }

    func previewPanel(_: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        let attachmentFields = fields.filter { field in
            field.fieldType == .attachment
        }

        guard let field = attachmentFields[safe: index], let attachment = field.object as? DatabaseAttachment else { return nil }

        let path = FileManager.sharedInstance().tmpAttachmentPreviewPath as NSString
        let tmp = path.appendingPathComponent(field.name as String)

        let inputStream = attachment.getPlainTextInputStream()!
        let outputStream = OutputStream(toFileAtPath: tmp, append: false)!

        StreamUtils.pipe(from: inputStream, to: outputStream)

        return NSURL(fileURLWithPath: tmp)
    }

    override func acceptsPreviewPanelControl(_: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        panel.dataSource = self
        panel.currentPreviewItemIndex = currentAttachmentPreviewIndex
    }

    override func endPreviewPanelControl(_: QLPreviewPanel!) {
        FileManager.sharedInstance().deleteAllTmpAttachmentPreviewFiles()
    }
}
