//
//  SearchResult.swift
//  MacBox
//
//  Created by Strongbox on 20/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

enum SearchResultActionType: Hashable {
    case copyUsernameOrEmail
    case copyEmail
    case copyPassword
    case copyTotp
    case copyNotes
    case copyField(fieldName: String)
    case launchUrl(fieldName: String)
    case launchInBrowser
    case launchInBrowserAndCopyPassword
    case showInStrongbox
    case unlockDatabase
    case defaultAction

    case dummySeparator

    var lowerCaseKeyboardMapping: String {
        switch self {
        case .copyUsernameOrEmail:
            "b"
        case .copyEmail:
            "e"
        case .copyPassword:
            "c"
        case .copyTotp:
            "t"
        case .copyNotes:
            "n"
        case .copyField:
            ""
        case .launchUrl:
            ""
        case .launchInBrowser:
            "l"
        case .launchInBrowserAndCopyPassword:
            "p"
        case .showInStrongbox:
            "o"
        case .unlockDatabase:
            ""
        case .dummySeparator:
            ""
        case .defaultAction:
            ""
        }
    }
}

struct SearchResultAction {
    let title: String
    let subtitle: String
    let keyboardShortcutOverride: String?
    let actionType: SearchResultActionType

    init(title: String, subtitle: String = "", keyboardShortcutOverride: String? = nil, actionType: SearchResultActionType) {
        self.title = title
        self.subtitle = subtitle
        self.keyboardShortcutOverride = keyboardShortcutOverride
        self.actionType = actionType
    }

    var keyboardShortcut: String {
        if let keyboardShortcutOverride {
            return keyboardShortcutOverride
        } else {
            return actionType.lowerCaseKeyboardMapping
        }
    }
}

enum SearchResultActionError: Error {
    case invalidActionForType
    case invalidParameter
}

enum SearchResultActionConsequence {
    case refreshResults
    case closeWindow
    case nop
}

enum SearchResultType {
    case entry(model: Model, node: Node)
    case database(database: MacDatabasePreferences)
    case header
}

struct SearchResult: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let image: NSImage
    let type: SearchResultType

    init(headerTitle: String, icon: NSImage) {
        type = .header
        id = UUID().uuidString
        title = headerTitle
        subtitle = ""
        image = icon
    }

    init(model: Model, node: Node) {
        let vm = EntryViewModel.fromNode(node, model: model)

        type = .entry(model: model, node: node)

        image = NodeIconHelper.getIconFor(node, predefinedIconSet: model.metadata.keePassIconSet, format: model.originalFormat)

        id = node.uuid.uuidString
        title = SearchResult.dereference(model: model, node: node, string: vm.title)

        var user = SearchResult.dereference(model: model, node: node, string: vm.username)
        if user.isEmpty {
            user = SearchResult.dereference(model: model, node: node, string: vm.email)
        }

        let url = SearchResult.dereference(model: model, node: node, string: vm.url)
        subtitle = url.isEmpty ? user : String(format: "%@ - %@", user, url)
    }

    init(database: MacDatabasePreferences) {
        type = .database(database: database)

        id = database.uuid
        title = database.nickName
        subtitle = SafeStorageProviderFactory.getStorageSubtitle(forDatabasesManager: database)
        image = SafeStorageProviderFactory.getImageFor(database.storageProvider, database: database)
    }

    var totp: OTPToken? {
        guard case let .entry(_, node) = type else {
            return nil
        }

        return node.fields.otpToken
    }

    var actions: [SearchResultAction] {
        switch type {
        case let .entry(model, node):
            return getActionsForEntry(model: model, node: node)
        case let .database(database):
            return getActionsForDatabase(database: database)
        case .header:
            return []
        }
    }

    static func dereference(model: Model, node: Node, string: String) -> String {
        model.dereference(string, node: node)
    }

    func getActionsForEntry(model: Model, node: Node) -> [SearchResultAction] {
        var ret: [SearchResultAction] = []
        let email = SearchResult.dereference(model: model, node: node, string: node.fields.email)
        let user = SearchResult.dereference(model: model, node: node, string: node.fields.username)

        if !user.isEmpty {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_username", comment: "Copy Username"), subtitle: user, actionType: .copyUsernameOrEmail))
        } else if !email.isEmpty {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_username", comment: "Copy Username"), subtitle: email, actionType: .copyUsernameOrEmail))
        }

        let pw = SearchResult.dereference(model: model, node: node, string: node.fields.password)
        if !pw.isEmpty {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_copy_password", comment: "Copy Password"), actionType: .copyPassword))
        }

        if !ret.isEmpty {
            ret.append(SearchResultAction(title: "", actionType: .dummySeparator))
        }

        ret.append(SearchResultAction(title: NSLocalizedString("action_show_in_strongbox", comment: "Show in Strongbox"), actionType: .showInStrongbox))

        let notes = SearchResult.dereference(model: model, node: node, string: node.fields.notes)

        if (!user.isEmpty && !email.isEmpty) || node.fields.otpToken != nil || !notes.isEmpty {
            ret.append(SearchResultAction(title: "", actionType: .dummySeparator))
        }

        if !user.isEmpty, !email.isEmpty {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_copy_email", comment: "Copy Email"), subtitle: email, actionType: .copyEmail))
        }

        if node.fields.otpToken != nil {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_copy_totp", comment: "Copy 2FA Code"), actionType: .copyTotp))
        }

        if !notes.isEmpty {
            ret.append(SearchResultAction(title: NSLocalizedString("browse_prefs_tap_action_copy_copy_notes", comment: "Copy Notes"), subtitle: notes, actionType: .copyNotes))
        }

        let url = SearchResult.dereference(model: model, node: node, string: node.fields.url)
        if !url.isEmpty {
            ret.append(SearchResultAction(title: "", actionType: .dummySeparator))

            ret.append(SearchResultAction(title: NSLocalizedString("generic_action_verb_launch_url", comment: "Launch URL"), actionType: .launchInBrowser))
            ret.append(SearchResultAction(title: NSLocalizedString("browse_action_launch_url_copy_password", comment: "Launch URL & Copy Password"), actionType: .launchInBrowserAndCopyPassword))
        }

        let vm = EntryViewModel.fromNode(node, model: model)

        if !vm.customFieldsFiltered.isEmpty {
            ret.append(SearchResultAction(title: "", actionType: .dummySeparator))
        }

        var i = 1
        for field in vm.customFieldsFiltered {
            let val = field.protected ? "" : SearchResult.dereference(model: model, node: node, string: field.value)

            if NodeFields.isAlternativeURLCustomFieldKey(field.key) {
                ret.append(SearchResultAction(title: String(format: NSLocalizedString("action_launch_field_fmt", comment: "Launch '%@'"), field.key), subtitle: val, keyboardShortcutOverride: i < 10 ? String(i) : "", actionType: .launchUrl(fieldName: field.key)))
            } else {
                ret.append(SearchResultAction(title: String(format: NSLocalizedString("action_copy_field_fmt", comment: "Copy '%@'"), field.key), subtitle: val, keyboardShortcutOverride: i < 10 ? String(i) : "", actionType: .copyField(fieldName: field.key)))
            }

            i += 1
        }

        return ret
    }

    func getActionsForDatabase(database _: MacDatabasePreferences) -> [SearchResultAction] {
        var ret: [SearchResultAction] = []

        ret.append(SearchResultAction(title: NSLocalizedString("casg_unlock_action", comment: "Unlock"), actionType: .unlockDatabase))

        return ret
    }

    private func performDefaultAction() async throws -> SearchResultActionConsequence {
        switch type {
        case let .entry(model, node):
            return try await performDefaultActionOnEntry(model: model, entry: node)
        case let .database(database):
            return try await performDefaultActionOnDatabase(database: database)
        case .header:
            return .nop
        }
    }

    private func performDefaultActionOnEntry(model _: Model, entry _: Node) async throws -> SearchResultActionConsequence {
        try await onLaunchInBrowser()
    }

    private func performDefaultActionOnDatabase(database _: MacDatabasePreferences) async throws -> SearchResultActionConsequence {
        try await onUnlockDatabase()
    }

    func performAction(action: SearchResultAction) async throws -> SearchResultActionConsequence {
        try await performAction(actionType: action.actionType)
    }

    func performAction(actionType: SearchResultActionType) async throws -> SearchResultActionConsequence {
        switch actionType {
        case .copyUsernameOrEmail:
            return try await onCopyUsernameOrEmail()
        case .copyPassword:
            return try await onCopyPassword()
        case .copyTotp:
            return try await onCopyTotp()
        case .copyNotes:
            return try await onCopyNotes()
        case let .copyField(fieldName):
            return try await onCopyField(fieldName: fieldName)
        case let .launchUrl(fieldName):
            return try await onLaunchUrl(fieldName: fieldName)
        case .launchInBrowser:
            return try await onLaunchInBrowser()
        case .launchInBrowserAndCopyPassword:
            return try await onLaunchInBrowser(copyPw: true)
        case .showInStrongbox:
            return try await onOpenInStrongbox()
        case .unlockDatabase:
            return try await onUnlockDatabase()
        case .copyEmail:
            return try await onCopyEmail()
        case .dummySeparator:
            return .nop
        case .defaultAction:
            return try await performDefaultAction()
        }
    }

    func onCopyUsernameOrEmail() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        var user = SearchResult.dereference(model: model, node: node, string: node.fields.username)
        if user.isEmpty {
            user = SearchResult.dereference(model: model, node: node, string: node.fields.email)
        }

        if !user.isEmpty {
            copyToClipboard(user)
            return .closeWindow
        }

        throw SearchResultActionError.invalidParameter
    }

    func onCopyEmail() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        let vm = EntryViewModel.fromNode(node, model: model)

        let str = SearchResult.dereference(model: model, node: node, string: vm.email)

        if !str.isEmpty {
            copyToClipboard(str)
            return .closeWindow
        }

        throw SearchResultActionError.invalidParameter
    }

    func onCopyPassword() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        return try copyPassword(model: model, node: node)
    }

    func onCopyTotp() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }
        let vm = EntryViewModel.fromNode(node, model: model)

        if let str = vm.totp?.password, !str.isEmpty {
            copyToClipboard(str)
            return .closeWindow
        }

        throw SearchResultActionError.invalidParameter
    }

    func onCopyNotes() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }
        let vm = EntryViewModel.fromNode(node, model: model)

        let str = SearchResult.dereference(model: model, node: node, string: vm.notes)

        if !str.isEmpty {
            copyToClipboard(str)
            return .closeWindow
        }

        throw SearchResultActionError.invalidParameter
    }

    func onCopyField(fieldName: String) async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }
        let vm = EntryViewModel.fromNode(node, model: model)

        let theField = vm.customFieldsFiltered.first { field in
            field.key == fieldName
        }

        if let theField {
            let str = SearchResult.dereference(model: model, node: node, string: theField.value)

            if !str.isEmpty {
                copyToClipboard(str)
                return .closeWindow
            }
        }

        throw SearchResultActionError.invalidParameter
    }

    func onLaunchUrl(fieldName: String) async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }
        let vm = EntryViewModel.fromNode(node, model: model)

        let theField = vm.customFieldsFiltered.first { field in
            field.key == fieldName
        }

        if let theField {
            let str = SearchResult.dereference(model: model, node: node, string: theField.value)
            if !str.isEmpty, model.launchUrlString(str) {
                return .closeWindow
            }
        }

        throw SearchResultActionError.invalidParameter
    }

    func onLaunchInBrowser(copyPw: Bool = false) async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        if model.launchUrl(node) {
            if copyPw {
                return try copyPassword(model: model, node: node)
            } else {
                return .closeWindow
            }
        }

        throw SearchResultActionError.invalidParameter
    }

    @MainActor
    func onOpenInStrongbox() async throws -> SearchResultActionConsequence {
        guard case let .entry(model, node) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        let appDelegate = NSApp.delegate as? AppDelegate

        await appDelegate?.showAndActivateStrongbox(model.databaseUuid)

        _ = DatabasesCollection.shared.selectEntryInUI(uuid: model.databaseUuid, nodeId: node.uuid)

        return .closeWindow
    }

    @MainActor
    func onLaunchDatabaseMainWindow() async throws -> SearchResultActionConsequence {
        guard case let .database(database: database) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        DatabasesCollection.shared.showDatabaseDocumentWindow(uuid: database.uuid)

        return .closeWindow
    }

    @MainActor
    func onUnlockDatabase() async throws -> SearchResultActionConsequence {
        guard case let .database(database: database) = type else {
            throw SearchResultActionError.invalidActionForType
        }

        if DatabasesCollection.shared.isUnlocked(uuid: database.uuid) {
            return try await onLaunchDatabaseMainWindow()
        } else {
            return await withCheckedContinuation { continuation in
                DatabasesCollection.shared.initiateDatabaseUnlock(uuid: database.uuid, syncAfterUnlock: true) { _ in
                    continuation.resume(returning: .refreshResults)
                }
            }
        }
    }

    func copyPassword(model: Model, node: Node) throws -> SearchResultActionConsequence {
        let str = SearchResult.dereference(model: model, node: node, string: node.fields.password)

        if !str.isEmpty {
            copyToClipboard(str)
            return .closeWindow
        }

        throw SearchResultActionError.invalidParameter
    }

    func copyToClipboard(_ string: String) {
        ClipboardManager.sharedInstance().copyConcealedString(string)
    }
}
