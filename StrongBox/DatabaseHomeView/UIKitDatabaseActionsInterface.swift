//
//  UIKitDatabaseActionsInterface.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

class UIKitDatabaseActionsInterface: DatabaseActionsInterface {
    let viewModel: Model
    var browseActionsHelper: BrowseActionsHelper!

    weak var navController: UINavigationController! {
        didSet {
            browseActionsHelper = BrowseActionsHelper(model: viewModel, viewController: navController, updateDatabaseAction: { [weak self] clearSelectedDetailItem, completion in
                Task { [weak self] in
                    guard let self else {
                        return
                    }

                    let savedLocal = await saveAndNotifyAfterChanges(clearSelectedDetailItem: clearSelectedDetailItem)
                    completion?(savedLocal)
                }
            })
        }
    } 

    init(viewModel: Model) {
        self.viewModel = viewModel
    }

    @MainActor
    var splitViewController: MainSplitViewController {
        navController.splitViewController as! MainSplitViewController
    }

    @MainActor
    var tabBarController: BrowseTabViewController {
        navController.tabBarController as! BrowseTabViewController
    }

    @MainActor
    func close() {
        splitViewController.closeAndCleanup()
    }

    @MainActor
    func navigateTo(destination: DatabaseNavigationDestination, homeModel: DatabaseHomeViewModel) {
        switch destination {
        case let .entryDetail(uuid, search):
            let vc = ItemDetailsViewController.fromStoryboard(viewModel, nodeUuid: uuid)

            let isSplitViewExpanded = !self.splitViewController.isCollapsed

            if search && !isSplitViewExpanded {
                navController.pushViewController(vc, animated: true)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now()+0.1, execute: {
                    self.splitViewController.showDetailViewController(vc, sender: nil)
                })
            }
        case .allEntries:
            let browse = BrowseSafeView.fromStoryboard(.list, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .groups:
            let browse = BrowseSafeView.fromStoryboard(.hierarchy, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .totps:
            let browse = BrowseSafeView.fromStoryboard(.totpList, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .favourites:
            let browse = BrowseSafeView.fromStoryboard(.favourites, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case let .tags(tag):
            let browse = BrowseSafeView.fromStoryboard(.tags, model: viewModel)
            browse.currentTag = tag
            navController.pushViewController(browse, animated: true)
        case .recycleBin:
            guard let recycleBinUuid = viewModel.database.recycleBinNodeUuid else {
                swlog("🔴 Recycle Bin Navigation requested but no recycle bin exists! ")
                return
            }
            let browse = BrowseSafeView.fromStoryboard(.hierarchy, model: viewModel)
            browse.currentGroupId = recycleBinUuid
            navController.pushViewController(browse, animated: true)
        case .sshKeys:
            let browse = BrowseSafeView.fromStoryboard(.sshKeys, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .passkeys:
            let browse = BrowseSafeView.fromStoryboard(.passkeys, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .attachments:
            let browse = BrowseSafeView.fromStoryboard(.attachments, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .expiredAndExpiring:
            let browse = BrowseSafeView.fromStoryboard(.expiredAndExpiring, model: viewModel)
            navController.pushViewController(browse, animated: true)
        case .auditIssues:
            let auditNavView = UIHostingController(rootView: AuditNavigationView(model: homeModel, showCloseButton: false))
            navController.pushViewController(auditNavView, animated: true)
        case .watchEntries:
            let browse = BrowseSafeView.fromStoryboard(.watchEntries, model: viewModel)
            navController.pushViewController(browse, animated: true)
        }
    }

    @MainActor
    func interactiveSyncAppleWatch(_ withInteractiveGuide: Bool = false, allowUserToOptOut: Bool = false) {
        splitViewController.syncAppleWatchNow(interactiveGuide: withInteractiveGuide, allowUserToOptOut: false)
    }

    func onPulldownToRefresh() async {
        await splitViewController.onManualPullDownRefresh {}
    }

    func showPassword(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.showPassword(entry.uuid)
    }

    func showAuditDrillDown(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.showAuditDrillDown(entry.uuid)
    }

    func presentHardwareKeySettings() {
        browseActionsHelper.showHardwareKeySettings()
    }

    func updateAndQueueSync() async -> Bool {
        await splitViewController.updateAndQueueSync()
    }

    func copyPassword(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyPassword(entry.uuid)
    }

    func copyAllFields(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyAllFields(entry.uuid)
    }

    func copyUsername(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyUsername(entry.uuid)
    }

    func copyTotp(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyTotp(entry.uuid)
    }

    func copyUrl(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyUrl(entry.uuid)
    }

    func copyEmail(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyEmail(entry.uuid)
    }

    func copyNotes(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyNotes(entry.uuid)
    }

    func copyAndLaunch(entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyAndLaunch(entry.uuid)
    }

    func copyCustomField(key: String, entry: any SwiftEntryModelInterface) {
        browseActionsHelper.copyCustomField(key, uuid: entry.uuid)
    }

    func deleteItem(item: any SwiftItemModelInterface) async -> Bool {
        await browseActionsHelper.deleteSingleItem(item.uuid)
    }

    var canExportItems: Bool {
        browseActionsHelper.canExportItems()
    }

    @MainActor
    func moveItems(items: [any SwiftItemModelInterface]) async -> Bool {
        let uuids = items.map(\.uuid)

        return await withCheckedContinuation { continuation in
            browseActionsHelper.moveItems(uuids) { actionPerformed in
                continuation.resume(returning: actionPerformed)
            }
        }
    }

    @MainActor
    func exportItems(items: [any SwiftItemModelInterface]) async -> Bool {
        let uuids = items.map(\.uuid)

        return await withCheckedContinuation { continuation in
            browseActionsHelper.exportItems(uuids) { actionPerformed in
                continuation.resume(returning: actionPerformed)
            }
        }
    }

    @MainActor
    func deleteItems(items: [any SwiftItemModelInterface]) async -> Bool {
        let nodes = items.compactMap { viewModel.getItemBy($0.uuid) }
        guard !nodes.isEmpty else { return false }

        let grouped = Dictionary(grouping: nodes) { node in
            viewModel.canRecycle(node.uuid)
        }

        let toBeRecycled = grouped[true] ?? []
        let toBeDeleted = grouped[false] ?? []

        let title: String
        let message: String
        if toBeDeleted.isEmpty {
            title = NSLocalizedString("browse_vc_are_you_sure", comment: "Are you sure?")
            message = NSLocalizedString("browse_vc_are_you_sure_recycle", comment: "Are you sure you want to send these item(s) to the Recycle Bin?")
        } else if toBeRecycled.isEmpty {
            title = NSLocalizedString("browse_vc_are_you_sure", comment: "Are you sure?")
            message = NSLocalizedString("browse_vc_are_you_sure_delete", comment: "Are you sure you want to permanently delete these item(s)?")
        } else {
            title = NSLocalizedString("browse_vc_partial_recycle_alert_title", comment: "Partial Recycle")
            message = NSLocalizedString("browse_vc_partial_recycle_alert_message", comment: "Some of the items you have selected cannot be recycled and will be permanently deleted. Is that ok?")
        }

        return await withCheckedContinuation { continuation in
            Alerts.yesNo(navController, title: title, message: message) { [weak self] response in
                guard let self, response else {
                    continuation.resume(returning: false)
                    return
                }

                if !toBeDeleted.isEmpty {
                    self.viewModel.deleteItems(toBeDeleted)
                }

                if !toBeRecycled.isEmpty, !self.viewModel.recycleItems(toBeRecycled) {
                    Alerts.warn(self.navController,
                                title: NSLocalizedString("browse_vc_error_deleting", comment: "Error Deleting"),
                                message: NSLocalizedString("browse_vc_error_deleting_message", comment: "There was a problem deleting at least one of these items."))
                    continuation.resume(returning: false)
                    return
                }

                Task { @MainActor in
                    let saved = await self.saveAndNotifyAfterChanges(clearSelectedDetailItem: true)
                    continuation.resume(returning: saved)
                }
            }
        }
    }

    @MainActor
    func merge(entryA: any SwiftEntryModelInterface, entryB: any SwiftEntryModelInterface) async -> Bool {
        guard let nodeA = viewModel.getItemBy(entryA.uuid),
              let nodeB = viewModel.getItemBy(entryB.uuid),
              !nodeA.isGroup, !nodeB.isGroup, !nodeA.isCreditCard(), !nodeB.isCreditCard()
        else {
            return false
        }

        let titleAtoB = String(format: NSLocalizedString("merge_alert_action_button_title", comment: "Merge two entries alert button title."), nodeA.title, nodeB.title)
        let titleBtoA = String(format: NSLocalizedString("merge_alert_action_button_title", comment: "Merge two entries alert button title."), nodeB.title, nodeA.title)
        let message = String(format: NSLocalizedString("merge_alert_message", comment: "Merge two entries alert message."), nodeA.title, nodeB.title, nodeA.title, nodeB.title, nodeA.title, nodeB.title)

        return await withCheckedContinuation { continuation in
            let sheet = UIAlertController(title: NSLocalizedString("generic_action_merge", comment: "Merge"),
                                          message: message,
                                          preferredStyle: .actionSheet)

            sheet.addAction(UIAlertAction(title: titleAtoB, style: .default) { [weak self] _ in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                self.viewModel.merge(nodeA,
                                     into: nodeB,
                                     mergeLocationChangedDate: true,
                                     includeHistory: true,
                                     allowOverwrite: true)

                Task { @MainActor in
                    let saved = await self.saveAndNotifyAfterChanges(clearSelectedDetailItem: true)
                    continuation.resume(returning: saved)
                }
            })

            sheet.addAction(UIAlertAction(title: titleBtoA, style: .default) { [weak self] _ in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                self.viewModel.merge(nodeB,
                                     into: nodeA,
                                     mergeLocationChangedDate: true,
                                     includeHistory: true,
                                     allowOverwrite: true)

                Task { @MainActor in
                    let saved = await self.saveAndNotifyAfterChanges(clearSelectedDetailItem: true)
                    continuation.resume(returning: saved)
                }
            })

            sheet.addAction(UIAlertAction(title: NSLocalizedString("generic_cancel", comment: "Cancel"), style: .cancel) { _ in
                continuation.resume(returning: false)
            })

            navController.present(sheet, animated: true)
        }
    }

    func emptyRecycleBin() async {
        await browseActionsHelper.emptyRecycleBin()
    }

    @MainActor
    var tabBarControllerIsHidden: Bool {
        guard let tabBarController = navController.tabBarController else {
            swlog("🔴 Couldn't get tab bar controller?!")
            return true
        }

        return tabBarController.tabBar.isHidden
    }

    var biometricsIsFaceId: Bool {
        BiometricsManager.sharedInstance().isFaceId()
    }

    var watchIsPairedAndInstalled: Bool {
        WatchAppManager.shared.watchIsPairedAndInstalled
    }

    @MainActor
    func presentConfigureTabsView() {
        let vc = ConfigureTabsViewController.fromStoryboard(model: viewModel)
        navController.present(vc, animated: true)
    }

    @MainActor
    func presentCustomizeView() {
        let vc = BrowsePreferencesTableViewController.fromStoryboard()
        vc.model = viewModel

        let embedInNav = UINavigationController(rootViewController: vc)
        embedInNav.modalPresentationStyle = .formSheet
        navController.present(embedInNav, animated: true)
    }

    @MainActor
    func presentConvenienceUnlockPreferences() {
        let vc = ConvenienceUnlockPreferences.fromStoryboard(with: viewModel)
        navController.present(vc, animated: true)
    }

    @MainActor
    func presentAutoFillSettings() {
        let vc = AutoFillPreferencesViewController.fromStoryboard(with: viewModel)
        navController.present(vc, animated: true)
    }

    @MainActor
    func presentAuditSettings() {
        let vc = AuditConfigurationVcTableViewController.fromStoryboard()
        vc.model = viewModel

        vc.updateDatabase = { [weak self] in
            Task { [weak self] in
                await self?.saveAndNotifyAfterChanges()
            }
        }

        let embedInNav = UINavigationController(rootViewController: vc)
        embedInNav.modalPresentationStyle = .formSheet
        navController.present(embedInNav, animated: true)
    }

    @MainActor
    func presentAutoLockSettings() {
        let vc = AutomaticLockingPreferences.fromStoryboard(with: viewModel)
        let embedInNav = UINavigationController(rootViewController: vc)
        embedInNav.modalPresentationStyle = .formSheet
        navController.present(embedInNav, animated: true)
    }

    @MainActor
    func presentAdvancedSettings() {
        let vc = AdvancedDatabaseSettings.fromStoryboard()

        vc.viewModel = viewModel

        vc.onDatabaseBulkIconUpdate = { [weak self] selectedFavIcons in
            self?.browseActionsHelper.onDatabaseBulkIconUpdate(selectedFavIcons)
        }

        let embedInNav = UINavigationController(rootViewController: vc)
        embedInNav.modalPresentationStyle = .formSheet
        navController.present(embedInNav, animated: true)
    }

    @MainActor
    func presentEncryptionSettings() {
        let embedInNav = EncryptionPreferencesViewController.fromStoryboard()

        let vc = embedInNav.topViewController as! EncryptionPreferencesViewController

        vc.model = viewModel

        vc.onChangedDatabaseEncryptionSettings = { [weak self] in
            Task { [weak self] in
                await self?.saveAndNotifyAfterChanges()
            }
        }

        embedInNav.modalPresentationStyle = .formSheet
        navController.present(embedInNav, animated: true)
    }

    @MainActor
    func presentSetMasterCredentials() {
        browseActionsHelper.presentSetCredentials()
    }

    @MainActor
    func onAddEntry() {
        
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1, execute: {
            let vc = ItemDetailsViewController.fromStoryboard(self.viewModel, nodeUuid: nil)
            self.showDetailController(viewController: vc)
        })
    }

    @MainActor
    func onAddCreditCard() {
        
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.1, execute: {
            let vc = SwiftUIViewFactory.getCreditCardEditorViewWithModel(self.viewModel,
                                                                         itemId: nil,
                                                                         parentGroupId: nil,
                                                                         createNewItem: true,
                                                                         editImmediately: true,
                                                                         forcedReadOnly: self.viewModel.isReadOnly) { [weak self] saved in
                if saved {
                    Task { await self?.saveAndNotifyAfterChanges() }
                }
            }
            self.showDetailController(viewController: vc)
        })
    }
    
    @MainActor
    func exportDatabase() {
        browseActionsHelper.exportDatabase()
    }

    @MainActor
    func printDatabase() {
        browseActionsHelper.printDatabase()
    }

    @MainActor
    func saveAndNotifyAfterChanges(clearSelectedDetailItem: Bool = false) async -> Bool {
        notifyModelUpdated()

        if clearSelectedDetailItem, !splitViewController.isCollapsed {
            let sb = UIStoryboard(name: "EmptyDetails", bundle: nil)

            if let vc = sb.instantiateInitialViewController() {
                splitViewController.showDetailViewController(vc, sender: nil)
            }
        }

        return await updateAndQueueSync()
    }

    @MainActor
    func notifyModelUpdated() {
        NotificationCenter.default.post(name: .modelEdited, object: viewModel)
    }

    var syncStatus: SyncStatus {
        SyncManager.sharedInstance().getSyncStatus(viewModel.metadata)
    }

    var isRunningAsyncUpdate: Bool {
        viewModel.isRunningAsyncUpdate
    }

    var lastAsyncUpdateResult: AsyncJobResult? {
        viewModel.lastAsyncUpdateResult
    }

    @MainActor
    var hasDoneDatabaseOnLaunchTasks: Bool {
        get {
            splitViewController.hasDoneDatabaseOnLaunchTasks
        }
        set {
            splitViewController.hasDoneDatabaseOnLaunchTasks = newValue
        }
    }
    
    @MainActor
    private func showDetailController(viewController: UIViewController) {
        if splitViewController.isCollapsed {
            self.navController.pushViewController(viewController, animated: true)
        } else {
            self.splitViewController.showDetailViewController(viewController, sender: self)
        }
    }
}
