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
        case let .entryDetail(uuid):
            let vc = ItemDetailsViewController.fromStoryboard(viewModel, nodeUuid: uuid)
            splitViewController.showDetailViewController(vc, sender: nil)
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
        }
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
        let vc = ItemDetailsViewController.fromStoryboard(viewModel, nodeUuid: nil)
        splitViewController.showDetailViewController(vc, sender: nil)
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
}
