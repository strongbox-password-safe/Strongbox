//
//  QuickSearchPaletteViewController.swift
//  MacBox
//
//  Created by Strongbox on 16/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Cocoa
import SwiftUI

class QuickSearchPaletteViewController: NSViewController, NSSearchFieldDelegate {
    enum ViewMode {
        case results
        case actions
    }

    var results: [SearchResult] = []
    var model: QuickSearchViewModel!

    var viewMode: ViewMode = .results {
        didSet {
            bindViewType()

            refreshBottomKeyboardHints()
        }
    }

    var eventMonitor: Any? = nil

    @IBOutlet var stackView: NSStackView!
    @IBOutlet var searchField: NSSearchField!
    @IBOutlet var tableViewResults: NSTableView!
    @IBOutlet var tableViewActions: NSTableView!
    @IBOutlet var resultsHeightConstraint: NSLayoutConstraint!
    @IBOutlet var actionsHeightConstraint: NSLayoutConstraint!
    @IBOutlet var scrollViewResults: NSScrollView!
    @IBOutlet var scrollViewActions: NSScrollView!
    @IBOutlet var stackViewHints: NSStackView!

    @IBOutlet var horizontalLine: NSBox!

    @IBAction func onStrongboxButton(_: Any) {
        showStrongbox()
    }

    func showStrongbox() {
        Task {
            view.window?.close()
            try await model.showAndActivateStrongbox()
        }
    }

    class func instantiateFromStoryboard() -> Self {
        let sb = NSStoryboard(name: "QuickSearchViewController", bundle: nil)

        return sb.instantiateInitialController() as! Self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        loadResults()

        customizeUI()

        viewMode = .results
        bindViewType()

        refreshAll()

        observeDatabaseLockedStateChangeNotifications()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        installKeyboardMonitor()
        observeTotpUpdateNotifications()

        if searchField.stringValue.isEmpty {
            loadResults()

            viewMode = .results
            bindViewType()

            refreshAll()
        } else {
            refreshBottomKeyboardHints()
        }

        if viewMode == .actions {
            focusActionsTable()
        } else {
            focusSearchField()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        removeKeyboardMonitor()
        unObserveTotpUpdateNotifications()
    }

    func observeDatabaseLockedStateChangeNotifications() {
        NotificationCenter.default.addObserver(forName: .DatabasesCollection.lockStateChanged, object: nil, queue: nil) { [weak self] _ in

            self?.reloadAndRefreshAll()
        }
    }

    func observeTotpUpdateNotifications() {
        NotificationCenter.default.addObserver(forName: .totpUpdate, object: nil, queue: nil) { [weak self] _ in
            self?.refreshOtpCodes()
        }
    }

    func unObserveTotpUpdateNotifications() {
        NotificationCenter.default.removeObserver(self, name: .totpUpdate, object: nil)
    }

    func refreshOtpCodes() {
        refreshOtpCodesForResults()
        refreshOtpCodesForActions()
    }

    func refreshOtpCodesForActions() {
        if let result = selectedResult, result.totp != nil, !selectedActions.isEmpty {
            tableViewActions.beginUpdates()
            tableViewActions.reloadData(forRowIndexes: IndexSet(integer: 0), columnIndexes: IndexSet(integer: 0))
            tableViewActions.endUpdates()
        }
    }

    func refreshOtpCodesForResults() {
        guard let scrollView = tableViewResults.enclosingScrollView else { return }

        let visibleRect = scrollView.contentView.visibleRect
        let rowRange = tableViewResults.rows(in: visibleRect)

        if rowRange.length > 0 {
            tableViewResults.beginUpdates()

            for i in 0 ... rowRange.length {
                let row = rowRange.location + i

                if let result = results[safe: row], result.totp != nil {
                    tableViewResults.reloadData(forRowIndexes: IndexSet(integer: rowRange.location + i), columnIndexes: IndexSet(integer: 0))
                }
            }

            tableViewResults.endUpdates()
        }
    }

    func installKeyboardMonitor() {
        if eventMonitor == nil {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] in
                guard let self else { return $0 }

                if onKeyboardMonitorKeyDown(with: $0) {
                    return nil
                }

                return $0
            }
        } else {
            swlog("🔴 Try to install event monitor twice?")
        }
    }

    func removeKeyboardMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        } else {
            swlog("🔴 Try to remove none existing event monitor?")
        }
        eventMonitor = nil
    }

    func customizeUI() {
        addBlurEffect()

        searchField.delegate = self

        tableViewResults.register(NSNib(nibNamed: kEntryTableCellViewIdentifier, bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: kEntryTableCellViewIdentifier))
        tableViewResults.register(NSNib(nibNamed: ResultsHeaderCell.NibName, bundle: nil), forIdentifier: ResultsHeaderCell.Identifier)


        tableViewResults.register(NSNib(nibNamed: kDatabaseCellView, bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: kDatabaseCellView))

        tableViewActions.register(NSNib(nibNamed: kEntryTableCellViewIdentifier, bundle: nil), forIdentifier: NSUserInterfaceItemIdentifier(rawValue: kEntryTableCellViewIdentifier))

        tableViewActions.register(NSNib(nibNamed: ActionGroupCell.NibName, bundle: nil), forIdentifier: ActionGroupCell.Identifier)
        tableViewActions.register(NSNib(nibNamed: ActionTableCellView.NibName, bundle: nil), forIdentifier: ActionTableCellView.Identifier)

        tableViewResults.delegate = self
        tableViewResults.dataSource = self
        tableViewResults.doubleAction = #selector(onTableViewDoubleClick)
        tableViewResults.sizeLastColumnToFit()

        tableViewActions.delegate = self
        tableViewActions.dataSource = self
        tableViewActions.doubleAction = #selector(onTableViewDoubleClick)
        tableViewActions.sizeLastColumnToFit() 

        stackView.setCustomSpacing(12, after: horizontalLine)
    }

    func addBlurEffect() {
        let blurView = NSVisualEffectView(frame: view.bounds)

        let top1 = blurView.topAnchor.constraint(equalTo: view.topAnchor)
        let bottom1 = blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let left1 = blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let right1 = blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor)

        blurView.blendingMode = .behindWindow
        blurView.material = .sidebar
        blurView.state = .active
        blurView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(blurView, positioned: .below, relativeTo: nil)

        NSLayoutConstraint.activate([
            top1, bottom1, left1, right1,
        ])
    }

    @IBAction func onSearch(_: Any) {
        loadResults()
        viewMode = .results
        bindViewType()
        refreshAll()
    }

    func reloadAndRefreshAll() {
        viewMode = .results
        bindViewType()
        loadResults()
        refreshAll()
    }

    func loadResults() {
        results = model.search(searchText: searchField.stringValue)
        
    }

    func refreshAll() {
        refreshResults()
        refreshActions()
        refreshBottomKeyboardHints()
    }

    fileprivate func setResultsHeight() {
        let estimatedCellHeight = 52.0
        let totalHeight = estimatedCellHeight * Double(results.count)
        let maxHeight = 350.0
        let height = min(maxHeight, totalHeight)

        let headerHeight = 30.0

        resultsHeightConstraint.constant = height + headerHeight
    }

    fileprivate func setActionsHeight() {
        let estimatedCellHeight = 50.0
        let totalHeight = estimatedCellHeight * Double(selectedActions.count + 1) 
        let maxHeight = 350.0
        let height = min(maxHeight, totalHeight)

        actionsHeightConstraint.constant = height
    }

    func bindViewType() {
        if !results.isEmpty {
            if viewMode == .results {
                scrollViewResults.isHidden = false
                scrollViewActions.isHidden = true
            } else {
                scrollViewActions.isHidden = false
                scrollViewResults.isHidden = true
            }

            horizontalLine.isHidden = true
        } else {
            scrollViewResults.isHidden = true
            scrollViewActions.isHidden = true
            horizontalLine.isHidden = false
        }
    }

    func refreshResults() {
        tableViewResults.reloadData()

        if !results.isEmpty {
            setResultsHeight()

            let anyEntry = results.first(where: { result in
                if case .entry = result.type {
                    return true
                } else {
                    return false
                }
            })

            if anyEntry != nil {
                tableViewResults.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false) 
            } else {
                tableViewResults.selectRowIndexes(IndexSet(), byExtendingSelection: false)
            }
        }
    }

    func refreshActions() {
        tableViewActions.reloadData()

        if !results.isEmpty {
            setActionsHeight()
            tableViewActions.selectRowIndexes(IndexSet(integer: 2), byExtendingSelection: false)
        }
    }

    func refreshBottomKeyboardHints() {
        for view in stackViewHints.arrangedSubviews {
            stackViewHints.removeView(view)
        }

        if let shortcut = model.quickSearchShortcut {
            let rootView1 = KeyboardShortcutView(shortcut: shortcut, title: NSLocalizedString("quick_search", comment: "Quick Search"))
            let fun1 = NSHostingView(rootView: rootView1)
            stackViewHints.addArrangedSubview(fun1)
        }

        let rootView1 = KeyboardShortcutView(shortcut: "⌘/", title: NSLocalizedString("keyboard_shortcuts", comment: "Keyboard Shortcuts"))
        let fun1 = NSHostingView(rootView: rootView1)
        stackViewHints.addArrangedSubview(fun1)

        if let selectedResult {
            if viewMode == .results {
                if case .entry = selectedResult.type {
                    if let range = searchField.currentEditor()?.selectedRange, range.length == 0, range.location == searchField.stringValue.count {
                        let rootView2 = KeyboardShortcutView(shortcut: "→", title: NSLocalizedString("view_actions", comment: "View Actions"))
                        let fun2 = NSHostingView(rootView: rootView2)
                        stackViewHints.addArrangedSubview(fun2)
                    }
                } else if case let .database(database) = selectedResult.type {
                    if DatabasesCollection.shared.isUnlocked(uuid: database.uuid) {
                        let rootView2 = KeyboardShortcutView(shortcut: "↩", title: NSLocalizedString("action_show_in_strongbox", comment: "Show in Strongbox"))
                        let fun2 = NSHostingView(rootView: rootView2)
                        stackViewHints.addArrangedSubview(fun2)
                    } else {
                        let rootView2 = KeyboardShortcutView(shortcut: "↩", title: NSLocalizedString("casg_unlock_action", comment: "Unlock"))
                        let fun2 = NSHostingView(rootView: rootView2)
                        stackViewHints.addArrangedSubview(fun2)
                    }
                }
            } else {
                let rootView2 = KeyboardShortcutView(shortcut: "←", title: NSLocalizedString("view_results", comment: "View Results"))
                let fun2 = NSHostingView(rootView: rootView2)
                stackViewHints.addArrangedSubview(fun2)
            }
        }

        let showStrongbox = KeyboardShortcutView(shortcut: model.showStrongboxShortcut ?? "⌘S", title: NSLocalizedString("system_tray_menu_item_show", comment: "Show Strongbox"))
        let showStrongboxView = NSHostingView(rootView: showStrongbox)
        stackViewHints.addArrangedSubview(showStrongboxView)
    }

    var selectedResult: SearchResult? {
        if let index = tableViewResults.selectedRowIndexes.first {
            return results[safe: index]
        } else {
            return nil
        }
    }

    var selectedActions: [SearchResultAction] {
        selectedResult?.actions ?? []
    }

    func onKeyboardMonitorKeyDown(with event: NSEvent) -> Bool {
        defer {
            DispatchQueue.main.async { [weak self] in 
                self?.refreshBottomKeyboardHints() 
            }
        }

        swlog("🐞 onKeyboardMonitorKeyDown \(event) - \(event.modifierFlags) - \(event.keyCode)")

        let mod = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        swlog("🐞 onKeyboardMonitorKeyDown-Mod-deviceIndependentFlagsMask \(mod)")


























        if let presentedViewControllers, !presentedViewControllers.isEmpty {
            
            return false
        }

        if event.modifierFlags.contains(.command) {
            if let chars = event.charactersIgnoringModifiers {
                if chars == "f" || chars == "l" { 
                    focusSearchField()
                    return true
                } else if chars == "w" || chars == "q" || chars == "a" { 
                    return false
                } else if event.specialKey == .leftArrow ||
                    event.specialKey == .rightArrow ||
                    event.specialKey == .delete ||
                    event.specialKey == .deleteLine ||
                    event.specialKey == .deleteForward ||
                    event.specialKey == .deleteCharacter ||
                    event.specialKey == .clearLine
                { 
                    swlog("\(String(describing: event.specialKey))")
                    return false
                } else if chars == "/" {
                    performSegue(withIdentifier: "segueToKeyboardShortcuts", sender: nil)
                    return true
                } else if chars == "s" {
                    showStrongbox()
                } else if let result = selectedResult {
                    if viewMode == .actions {
                        let action = selectedActions.first { action in
                            action.keyboardShortcut == chars.lowercased()
                        }

                        if let action {
                            performAction(result: result, actionType: action.actionType)
                            return true
                        }
                    } else if viewMode == .results {
                        let all: [SearchResultActionType] = [
                            .copyUsernameOrEmail,
                            .copyEmail,
                            .copyPassword,
                            .copyTotp,
                            .copyNotes,
                            .launchInBrowser,
                            .launchInBrowserAndCopyPassword,
                            .showInStrongbox,
                        ]

                        let actionType = all.first { action in
                            action.lowerCaseKeyboardMapping == chars.lowercased()
                        }

                        if let actionType {
                            performAction(result: result, actionType: actionType)
                            return true
                        }
                    }
                }
            }

            return true 
        } else if event.modifierFlags.contains(.numericPad) || event.modifierFlags.isEmpty { 
            if event.specialKey == .downArrow {
                if viewMode == .results {
                    onDownArrowInResults()
                } else {
                    onDownArrowInActions()
                }

                return true
            } else if event.specialKey == .upArrow {
                if viewMode == .results {
                    onUpArrowInResults()
                } else {
                    onUpArrowInActions()
                }

                return true
            } else if event.specialKey == .leftArrow {
                if viewMode == .actions {
                    onLeftArrowInActions()
                    return true 
                }
            } else if event.specialKey == .rightArrow {
                
                if let range = searchField.currentEditor()?.selectedRange, range.length == 0, range.location == searchField.stringValue.count, viewMode == .results {
                    onRightArrowInResults()
                    return true
                }
            }
        } else {
            if event.keyCode == kVK_Escape {
                let fr = view.window?.firstResponder

                if viewMode == .actions, fr == tableViewActions { 
                    focusSearchField()
                    return true
                }
            } else if event.specialKey == .enter || event.keyCode == kVK_Return {
                if viewMode == .results {
                    onEnterInResults()
                } else {
                    onEnterInActions()
                }

                return true
            }
        }

        return false
    }

    func focusActionsTable() {
        view.window?.makeFirstResponder(tableViewActions)
    }

    func focusSearchField() {
        view.window?.makeFirstResponder(searchField)

        if let range = searchField.currentEditor()?.selectedRange {
            searchField.currentEditor()?.selectedRange = NSMakeRange(range.length, 0)
        }



    }

    func onDownArrowInResults() {
        if !results.isEmpty {
            let sel = tableViewResults.selectedRow
            if sel >= 0 { 
                let newRow = min(sel + 1, results.count - 1)

                tableViewResults.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)

                let newRowSel = min(newRow + 1, results.count - 1)

                tableViewResults.scrollRowToVisible(newRowSel)
            } else {
                tableViewResults.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false) 
            }
        }
    }

    func onUpArrowInResults() {
        if !results.isEmpty, tableViewResults.selectedRow != -1 {
            if tableViewResults.selectedRow == 1 {
                focusSearchField()
            } else {
                let newRow = max(1, tableViewResults.selectedRow - 1)

                tableViewResults.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
                tableViewResults.scrollRowToVisible(newRow - 1)
            }
        }
    }

    func onRightArrowInResults() {
        if let result = selectedResult, !selectedActions.isEmpty {
            if case .entry = result.type {
                viewMode = .actions
                view.window?.makeFirstResponder(tableViewActions)
            }
        }
    }

    func onLeftArrowInActions() {
        viewMode = .results
        focusSearchField()
    }

    func onUpArrowInActions() {
        let offsetRow = 2

        if tableViewActions.selectedRow == offsetRow {
            focusSearchField()
            tableViewActions.scroll(CGPoint.zero)
        } else {
            if let actions = selectedResult?.actions, tableViewActions.selectedRow != -1, tableViewActions.selectedRow >= offsetRow {
                let currentIdx = tableViewActions.selectedRow - offsetRow

                var newIdx = currentIdx - 1
                while newIdx > 0, actions[newIdx].actionType == .dummySeparator {
                    newIdx -= 1
                }

                newIdx = max(0, newIdx)
                let newRow = newIdx + offsetRow
                tableViewActions.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)

                tableViewActions.scrollRowToVisible(newRow - 1)

                if newRow == offsetRow {
                    tableViewActions.scroll(CGPoint.zero)
                }
            }
        }
    }

    func onDownArrowInActions() {
        let offsetRow = 2

        if let actions = selectedResult?.actions, tableViewActions.selectedRow != -1, tableViewActions.selectedRow >= offsetRow {
            let currentIdx = tableViewActions.selectedRow - offsetRow
            let lastActionIdx = actions.count - 1

            var newIdx = currentIdx + 1
            while newIdx < actions.count, actions[newIdx].actionType == .dummySeparator {
                newIdx += 1
            }

            newIdx = min(lastActionIdx, newIdx)

            let newRowIdx = newIdx + offsetRow

            tableViewActions.selectRowIndexes(IndexSet(integer: newRowIdx), byExtendingSelection: false)

            tableViewActions.scrollRowToVisible(newRowIdx)
        }
    }

    func onEnterInResults() {
        performDefaultActionOnSelectedResult()
    }

    func onEnterInActions() {
        performSelectedAction()
    }

    @IBAction func onTableViewDoubleClick(_ sender: Any?) {
        guard let clicked = sender as? NSTableView else {
            return
        }

        if tableViewResults == clicked {
            performDefaultActionOnSelectedResult()
        } else if tableViewActions == clicked {
            performSelectedAction()
        }
    }

    func performSelectedAction() {
        if let result = selectedResult,
           tableViewActions.selectedRow > 1,
           let action = result.actions[safe: tableViewActions.selectedRow - 2]
        {
            performAction(result: result, actionType: action.actionType)
        } else {
            swlog("🔴 Couldn't get action!")
        }
    }

    func performDefaultActionOnSelectedResult() {
        if let result = selectedResult {
            performAction(result: result, actionType: .defaultAction)
        }
    }

    @MainActor
    func showProMessage() async {
        view.window?.close()

        try? await model.showAndActivateStrongbox()

        DBManagerPanel.sharedInstance.show()
        let window = DBManagerPanel.sharedInstance.window

        await MacAlerts.info(NSLocalizedString("mac_autofill_pro_feature_title", comment: "Pro Feature"),
                             informativeText: NSLocalizedString("quick_search_pro_feature_message", comment: "Quick Search is a Pro feature. Please upgrade to enjoy lightning fast access to your databases."),
                             window: window)
    }

    func performAction(result: SearchResult, actionType: SearchResultActionType) {
        Task { @MainActor in
            if case .entry = result.type, !Settings.sharedInstance().isPro {
                await showProMessage()
                return
            }

            let delay = 0.25

            do {
                let op = try await model.performAction(result: result, actionType: actionType)

                showToast(message: getToastMessage(result: result, action: actionType), delay: delay)

                switch op {
                case .refreshResults:
                    reloadAndRefreshAll()
                case .closeWindow:
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    view.window?.close()
                case .nop:
                    break
                }
            } catch {
                swlog("🔴 Could not perform action! \(error)")
                NSSound.beep()
            }
        }
    }

    func getToastMessage(result: SearchResult, action: SearchResultActionType) -> String {
        switch action {
        case .copyUsernameOrEmail:
            NSLocalizedString("item_details_username_copied", comment: "")
        case .copyPassword:
            NSLocalizedString("item_details_password_copied", comment: "")
        case .copyTotp:
            NSLocalizedString("autofill_info_totp_copied_title", comment: "")
        case .copyNotes:
            NSLocalizedString("item_details_notes_copied", comment: "")
        case let .copyField(fieldName):
            String(format: NSLocalizedString("item_details_something_copied_fmt", comment: ""), fieldName)
        case .copyEmail:
            NSLocalizedString("item_details_email_copied", comment: "Email Copied")
        case .launchInBrowserAndCopyPassword:
            NSLocalizedString("mac_node_details_password_copied_url_launched", comment: "")
        case .launchUrl, .launchInBrowser:
            NSLocalizedString("item_details_url_launched", comment: "URL Launched")
        case .showInStrongbox:
            ""
        case .unlockDatabase:
            ""
        case .dummySeparator:
            ""
        case .defaultAction:
            switch result.type {
            case .entry:
                NSLocalizedString("item_details_url_launched", comment: "URL Launched")
            case .database:
                ""
            case .header:
                ""
            }
        }
    }

    func showToast(message: String, delay: Double = 0.2) {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            let defaultColor = NSColor(deviceRed: 0.23, green: 0.5, blue: 0.82, alpha: 0.6)

            guard let hud = MBProgressHUD.showAdded(to: view, animated: true) else {
                swlog("🔴 Couldn't create Toast!")
                return
            }

            hud.labelText = message
            hud.color = defaultColor
            hud.mode = MBProgressHUDModeText
            hud.margin = 10
            hud.yOffset = 0.0
            hud.removeFromSuperViewOnHide = true
            hud.dismissible = true

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                hud.hide(true)
            }
        }
    }

    

    override func prepare(for segue: NSStoryboardSegue, sender _: Any?) {
        if segue.identifier == "segueToKeyboardShortcuts" {
            if let vc = segue.destinationController as? KeyboardShortcutsHelpViewController {
                vc.showStrongboxShortcut = model.showStrongboxShortcut ?? ""
                vc.quickSearchShortcut = model.quickSearchShortcut ?? ""
            }
        }
    }
}

extension QuickSearchPaletteViewController: NSTableViewDelegate {
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let obj = notification.object as? NSTableView, tableViewResults == obj {
            refreshActions()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        if tableView == tableViewResults {
            if let result = results[safe: row] {
                switch result.type {
                case .database(database: _):
                    return getDatabaseView(tableView, result: result)
                case .entry(model: _, node: _):
                    return getEntryView(tableView, result: result)
                case .header:
                    return getResultsHeaderCell(result: result)
                }
            } else {
                swlog("🔴 row not present in results! \(row)")
                return nil
            }
        } else {
            return getActionViewFor(row: row)
        }
    }

    func getResultsHeaderCell(result: SearchResult) -> NSView? {
        guard let cell = tableViewResults.makeView(withIdentifier: ResultsHeaderCell.Identifier, owner: self) as? ResultsHeaderCell else {
            return nil
        }

        cell.setContent(title: result.title, icon: result.image)

        return cell
    }

    func getEntryView(_ tableView: NSTableView, result: SearchResult) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: kEntryTableCellViewIdentifier), owner: self) as! EntryTableCellView

        if case let .entry(model, node) = result.type {
            let path = model.database.getPathDisplayString(node)
            let database = model.metadata.nickName

            view.setContent(result.title, username: result.subtitle, totp: result.totp, image: result.image, path: path, database: database)
        }

        return view
    }

    func getDatabaseView(_ tableView: NSTableView, result: SearchResult) -> NSView? {
        let view = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: kDatabaseCellView), owner: self) as! DatabaseCellView

        guard let database = MacDatabasePreferences.getById(result.id) else {
            return nil
        }

        view.setWithDatabase(database, nickNameEditClickEnabled: false, showSyncState: false, indicateAutoFillDisabled: false, wormholeUnlocked: false, disabled: false, hideRightSideFields: true)

        return view
    }

    func getActionViewFor(row: Int) -> NSView? {
        if row == 0 {
            if let result = selectedResult {
                return getEntryView(tableViewActions, result: result)
            } else {
                swlog("🔴 main row not present in actions! \(row)")
                return nil
            }
        } else if row == 1 {
            guard let cell = tableViewActions.makeView(withIdentifier: ActionGroupCell.Identifier, owner: self) as? ActionGroupCell else {
                return nil
            }

            cell.setContent(title: NSLocalizedString("generic_actions", comment: "Actions"))

            return cell
        } else {
            guard let action = selectedResult?.actions[safe: row - 2] else {
                swlog("🔴 Couldn't find action at row \(row)")
                return view
            }

            if action.actionType == .dummySeparator {
                guard let cell = tableViewActions.makeView(withIdentifier: ActionGroupCell.Identifier, owner: self) as? ActionGroupCell else {
                    return nil
                }

                cell.setContent(title: "")
                return cell
            } else {
                guard let cell = tableViewActions.makeView(withIdentifier: ActionTableCellView.Identifier, owner: self) as? ActionTableCellView else {
                    return nil
                }

                let keyboardShortcut = action.keyboardShortcut.isEmpty ? "" : String(format: "⌘ %@", action.keyboardShortcut.uppercased())

                cell.setContent(title: action.title, subTitle: action.subtitle, keyboardShortcut: keyboardShortcut)

                return cell
            }
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if tableView == tableViewResults {
            if row == 0 {
                return NSTableRowView()
            }
        }

        return SelectionActiveAlwaysRowView()
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == tableViewActions {
            if row < 2 {
                return false
            }

            if let actions = selectedResult?.actions, let action = actions[safe: row - 2] {
                return action.actionType != .dummySeparator
            } else {
                return false
            }
        } else if tableView == tableViewResults {
            if row < 1 {
                return false
            }
        }

        return true
    }
}

extension QuickSearchPaletteViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {


        if tableView == tableViewResults {
            return results.count
        } else {
            if selectedResult != nil {
                let actions = selectedActions
                return actions.count + 2 
            } else {
                return 0
            }
        }
    }
}
