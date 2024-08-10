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
            let allDatabases = getAllDatabases()

            var ret = [SearchResult(headerTitle: NSLocalizedString("generic_databases_plural", comment: "Databases"), icon: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)!)]

            ret.append(contentsOf: allDatabases)
            return ret
        }

        var results = searchUnlockedDatabases(searchText: searchText)

        if results.isEmpty {
            let locked = getLockedDatabases()

            if locked.isEmpty {
                let loc = NSLocalizedString("quick_search_no_results_found", comment: "No Results Found.")
                let header = SearchResult(headerTitle: loc, icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
                results.insert(header, at: 0)
                return results
            } else {
                let loc = NSLocalizedString("no_results_found_some_locked", comment: "No results found. Some databases are locked.")

                let header = SearchResult(headerTitle: loc,
                                          icon: NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)!)

                results = getAllDatabases()
                results.insert(header, at: 0)

                return results
            }
        } else {
            if results.count == 1 {
                let loc = NSLocalizedString("search_results_summary_1_match_found", comment: "1 Match Found.")
                let header = SearchResult(headerTitle: loc, icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
                results.insert(header, at: 0)
            } else {
                let locFmt = NSLocalizedString("search_results_summary_n_match_found_fmt", comment: "%@ Matches Found.")
                let loc = String(format: locFmt, String(results.count))
                let header = SearchResult(headerTitle: loc, icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)!)
                results.insert(header, at: 0)
            }

            return results
        }
    }

    func getAllDatabases() -> [SearchResult] {
        let all = MacDatabasePreferences.allDatabases
            .map { database in
                SearchResult(database: database)
            }

        return all
    }

    func getLockedDatabases() -> [SearchResult] {
        let all = MacDatabasePreferences.allDatabases
            .filter { database in
                !DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
            }
            .map { database in
                SearchResult(database: database)
            }

        return all
    }

    private func searchUnlockedDatabases(searchText: String) -> [SearchResult] {
        let unlockedDatabases = MacDatabasePreferences.allDatabases.filter { database in
            DatabasesCollection.shared.isUnlocked(uuid: database.uuid)
        }

        var collected: [(Model, Node)] = []
        for database in unlockedDatabases {
            guard let model = DatabasesCollection.shared.getUnlocked(uuid: database.uuid) else {
                continue
            }

            let nodes = model.searchAutoBestMatch(searchText, scope: .all)

            swlog("🐞 Search - Got [%d] results in [%@]", nodes.count, model.metadata.nickName)

            collected += nodes.map { node in
                (model, node)
            }
        }

        return collected.map { mapNodeToSearchResult(model: $0.0, node: $0.1) }
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
