//
//  QuickSearchViewModel.swift
//  MacBox
//
//  Created by Strongbox on 16/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation

class QuickSearchViewModel {
    var quickSearchShortcut: String?
    var showStrongboxShortcut: String?

    init() {
        let mas1 = MASShortcutBinder.shared().value(forKey: kPreferenceLaunchQuickSearchShortcut) as? MASShortcut
        let mas2 = MASShortcutBinder.shared().value(forKey: NSNotification.Name.preferenceGlobalShowShortcut.rawValue) as? MASShortcut

        quickSearchShortcut = QuickSearchViewModel.getShortcutTextFromMasShortcut(mas1)
        showStrongboxShortcut = QuickSearchViewModel.getShortcutTextFromMasShortcut(mas2)

        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: nil) { [weak self] _ in
            self?.refreshShortcutTexts()
        }
    }

    func refreshShortcutTexts() {
        let mas1 = MASShortcutBinder.shared().value(forKey: kPreferenceLaunchQuickSearchShortcut) as? MASShortcut
        let mas2 = MASShortcutBinder.shared().value(forKey: NSNotification.Name.preferenceGlobalShowShortcut.rawValue) as? MASShortcut

        DispatchQueue.main.async { [weak self] in
            self?.quickSearchShortcut = QuickSearchViewModel.getShortcutTextFromMasShortcut(mas1)
            self?.showStrongboxShortcut = QuickSearchViewModel.getShortcutTextFromMasShortcut(mas2)
        }
    }

    func search(searchText: String) -> [SearchResult] {
        if searchText.isEmpty {
            return getDatabasesResults()
        }

        return searchUnlockedDatabases(searchText: searchText)
    }

    func getDatabasesResults() -> [SearchResult] {
        let all = MacDatabasePreferences.allDatabases
            .filter { database in
                !DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
            }
            .map { database in
                SearchResult(database: database)
            }

        if all.isEmpty {
            return []
        }

        var ret = [SearchResult(headerTitle: NSLocalizedString("locked_databases_heading", comment: "Locked Databases"), icon: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)!)]

        ret.append(contentsOf: all)

        return ret
    }

    func searchUnlockedDatabases(searchText: String) -> [SearchResult] {
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        var collected: [(Model, Node)] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }

            let nodes = model.search(searchText,
                                     scope: .all,
                                     dereference: true,
                                     includeKeePass1Backup: false,
                                     includeRecycleBin: false,
                                     includeExpired: false,
                                     includeGroups: false,
                                     browseSortField: .title,
                                     descending: false,
                                     foldersSeparately: false)

            NSLog("🐞 Search - Got [%d] results in [%@]", nodes.count, model.metadata.nickName)

            collected += nodes.map { node in
                (model, node)
            }
        }

        var ret = collected.map { mapNodeToSearchResult(model: $0.0, node: $0.1) }

        let headerTitleKey = unlockedDatabases.isEmpty ? "quick_search_all_databases_locked" : (ret.isEmpty ? "quick_search_no_results_found" : "quick_view_title_no_matches_title")

        let loc = NSLocalizedString(headerTitleKey, comment: "")

        let symbolName = unlockedDatabases.isEmpty ? "lock" : "magnifyingglass"

        let header = SearchResult(headerTitle: loc, icon: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!)

        ret.insert(header, at: 0)

        return ret
    }

    func mapNodeToSearchResult(model: Model, node: Node) -> SearchResult {
        SearchResult(model: model, node: node)
    }

    class func getShortcutTextFromMasShortcut(_ shortcut: MASShortcut?) -> String? {
        if let shortcut, let keyCodeString = shortcut.keyCodeString {
            return "\(shortcut.modifierFlagsString)\(keyCodeString)"
        } else {
            return nil
        }
    }

    func performAction(result: SearchResult, actionType: SearchResultActionType) async throws -> SearchResultActionConsequence {
        try await result.performAction(actionType: actionType)
    }

    @MainActor
    func showAndActivateStrongbox() async throws {
        let appDelegate = NSApp.delegate as? AppDelegate

        await appDelegate?.showAndActivateStrongbox(nil)
    }
}
