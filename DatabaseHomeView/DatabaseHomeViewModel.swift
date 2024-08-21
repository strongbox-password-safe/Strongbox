//
//  DatabaseHomeViewModel.swift
//  Strongbox
//
//  Created by Strongbox on 27/07/2024.
//  Copyright © 2024 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

enum DatabaseNavigationDestination {
    case allEntries
    case groups
    case totps
    case favourites
    case auditIssues
    case sshKeys
    case passkeys
    case attachments
    case expiredAndExpiring
    case tags(tag: String?)
    case entryDetail(uuid: UUID)
    case recycleBin
}

@objc
enum HomeViewSection: Int, CaseIterable, Identifiable {
    case favourites
    case navigation
    case quickTags
    case otherViews

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .favourites:
            return "browse_vc_section_title_pinned"
        case .navigation:
            return "generic_noun_navigation"
        case .otherViews:
            return "quick_view_section_title_quick_views"
        case .quickTags:
            return "home_quick_tags_section_header"
        }
    }

    var imageName: String {
        switch self {
        case .favourites:
            return "star"
        case .navigation:
            return "location"
        case .otherViews:
            return "scope"
        case .quickTags:
            return "tag"
        }
    }
}

protocol DatabaseActionsInterface {
    var hasDoneDatabaseOnLaunchTasks: Bool { get set }
    var syncStatus: SyncStatus { get }
    var isRunningAsyncUpdate: Bool { get }
    var lastAsyncUpdateResult: AsyncJobResult? { get }

    var tabBarControllerIsHidden: Bool { get }
    var biometricsIsFaceId: Bool { get }

    func close()
    func navigateTo(destination: DatabaseNavigationDestination, homeModel: DatabaseHomeViewModel)

    func onPulldownToRefresh() async
    func updateAndQueueSync() async -> Bool

    func copyPassword(entry: any SwiftEntryModelInterface)

    func copyAllFields(entry: any SwiftEntryModelInterface)
    func copyUsername(entry: any SwiftEntryModelInterface)
    func copyTotp(entry: any SwiftEntryModelInterface)
    func copyUrl(entry: any SwiftEntryModelInterface)
    func copyEmail(entry: any SwiftEntryModelInterface)
    func copyNotes(entry: any SwiftEntryModelInterface)
    func copyAndLaunch(entry: any SwiftEntryModelInterface)
    func copyCustomField(key: String, entry: any SwiftEntryModelInterface)

    func showPassword(entry: any SwiftEntryModelInterface)
    func showAuditDrillDown(entry: any SwiftEntryModelInterface)

    func deleteItem(item: any SwiftItemModelInterface) async -> Bool
    func emptyRecycleBin() async

    func presentConfigureTabsView()
    func presentCustomizeView()
    func presentConvenienceUnlockPreferences()

    func presentAutoFillSettings()
    func presentAuditSettings()
    func presentAutoLockSettings()
    func presentAdvancedSettings()
    func presentHardwareKeySettings()
    func presentEncryptionSettings()
    func presentSetMasterCredentials()

    func onAddEntry()
    func exportDatabase()
    func printDatabase()
}

struct DummyDatabaseActionsInterface: DatabaseActionsInterface {
    var hasDoneDatabaseOnLaunchTasks: Bool = false

    var syncStatus: SyncStatus = .init(databaseId: UUID().uuidString)
    var isRunningAsyncUpdate: Bool = false
    var lastAsyncUpdateResult: AsyncJobResult? = nil

    func presentHardwareKeySettings() {
        swlog("DummyDatabaseActionsInterface::presentHardwareKeySettings() called")
    }

    func onAddEntry() {
        swlog("DummyDatabaseActionsInterface::onAddEntry() called")
    }

    func exportDatabase() {
        swlog("DummyDatabaseActionsInterface::exportDatabase() called")
    }

    func printDatabase() {
        swlog("DummyDatabaseActionsInterface::printDatabase() called")
    }

    func presentSetMasterCredentials() {
        swlog("DummyDatabaseActionsInterface::presentSetMasterCredentials() called")
    }

    func presentEncryptionSettings() {
        swlog("DummyDatabaseActionsInterface::func presentEncryptionSettings() called")
    }

    func presentAutoFillSettings() {
        swlog("DummyDatabaseActionsInterface::presentAutoFillSettings() called")
    }

    func presentAuditSettings() {
        swlog("DummyDatabaseActionsInterface::presentAuditSettings() called")
    }

    func presentAutoLockSettings() {
        swlog("DummyDatabaseActionsInterface::presentAutoLockSettings() called")
    }

    func presentAdvancedSettings() {
        swlog("DummyDatabaseActionsInterface::presentAdvancedSettings() called")
    }

    func presentConvenienceUnlockPreferences() {
        swlog("DummyDatabaseActionsInterface::presentConvenienceUnlockPreferences() called")
    }

    func presentConfigureTabsView() {
        swlog("DummyDatabaseActionsInterface::presentConfigureTabsView() called")
    }

    func presentCustomizeView() {
        swlog("DummyDatabaseActionsInterface::presentCustomizeView() called")
    }

    var tabBarControllerIsHidden: Bool = true

    var biometricsIsFaceId: Bool = true

    func emptyRecycleBin() async {
        swlog("DummyDatabaseActionsInterface::emptyRecycleBin() called")
    }

    func deleteItem(item _: any SwiftItemModelInterface) async -> Bool {
        swlog("DummyDatabaseActionsInterface::deleteItem() called")
        return true
    }

    func copyAllFields(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyAllFields() called")
    }

    func copyUsername(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyUsername() called")
    }

    func copyTotp(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyTotp() called")
    }

    func copyUrl(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyUrl() called")
    }

    func copyEmail(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyEmail() called")
    }

    func copyNotes(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyNotes() called")
    }

    func copyAndLaunch(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyAndLaunch() called")
    }

    func copyCustomField(key _: String, entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyCustomField() called")
    }

    func showAuditDrillDown(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::showAuditDrillDown() called")
    }

    func showPassword(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::showPassword() called")
    }

    func copyPassword(entry _: any SwiftEntryModelInterface) {
        swlog("DummyDatabaseActionsInterface::copyPassword() called")
    }

    func close() {}

    func navigateTo(destination: DatabaseNavigationDestination, homeModel _: DatabaseHomeViewModel) {
        swlog("DummyDatabaseActionsInterface::navigateTo() called with \(destination)")
    }

    func onPulldownToRefresh() async {
        swlog("DummyDatabaseActionsInterface::onPulldownToRefresh() called")
    }

    func updateAndQueueSync() async -> Bool {
        swlog("DummyDatabaseActionsInterface::updateAndQueueSync() called")
        return true
    }
}

class DatabaseHomeViewModel: ObservableObject {
    @Published
    var database: SwiftDatabaseModelInterface
    var actions: DatabaseActionsInterface

    init(database: SwiftDatabaseModelInterface = SwiftDummyDatabaseModel.testModel,
         externalWorldAdaptor: DatabaseActionsInterface = DummyDatabaseActionsInterface())
    {
        self.database = database
        actions = externalWorldAdaptor
    }

    var isItemsCanBeExported: Bool { database.isItemsCanBeExported }

    var entryCount: Int { database.entryCount }
    var groupCount: Int { database.groupCount }

    func search(searchText: String, searchScope: SearchScope) -> [any SwiftEntryModelInterface] {
        database.search(searchText: searchText, searchScope: searchScope)
    }

    func close() {
        actions.close()
    }

    func navigateTo(destination: DatabaseNavigationDestination) {
        actions.navigateTo(destination: destination, homeModel: self)
    }

    func onPulldownToRefresh() async {
        await actions.onPulldownToRefresh()
    }

    func toggleFavourite(entry: any SwiftEntryModelInterface) {
        let needsSave = entry.toggleFavourite()
        if needsSave {
            Task {
                await actions.updateAndQueueSync()
            }
        }
    }

    func copyPassword(entry: any SwiftEntryModelInterface) {
        actions.copyPassword(entry: entry)
    }

    func copyAllFields(entry: any SwiftEntryModelInterface) {
        actions.copyAllFields(entry: entry)
    }

    func copyUsername(entry: any SwiftEntryModelInterface) {
        actions.copyUsername(entry: entry)
    }

    func copyTotp(entry: any SwiftEntryModelInterface) {
        actions.copyTotp(entry: entry)
    }

    func copyUrl(entry: any SwiftEntryModelInterface) {
        actions.copyUrl(entry: entry)
    }

    func copyEmail(entry: any SwiftEntryModelInterface) {
        actions.copyEmail(entry: entry)
    }

    func copyNotes(entry: any SwiftEntryModelInterface) {
        actions.copyNotes(entry: entry)
    }

    func copyAndLaunch(entry: any SwiftEntryModelInterface) {
        actions.copyAndLaunch(entry: entry)
    }

    func copyCustomField(key: String, entry: any SwiftEntryModelInterface) {
        actions.copyCustomField(key: key, entry: entry)
    }

    func showPassword(entry: any SwiftEntryModelInterface) {
        actions.showPassword(entry: entry)
    }

    func showAuditDrillDown(entry: any SwiftEntryModelInterface) {
        actions.showAuditDrillDown(entry: entry)
    }

    func canRecycle(item: any SwiftItemModelInterface) -> Bool {
        database.canRecycle(item: item)
    }

    func deleteItem(item: any SwiftItemModelInterface) async -> Bool {
        await actions.deleteItem(item: item)
    }

    var expireCount: Int {
        database.expiredEntryCount + database.expiringEntryCount
    }

    var showOtherViews: Bool {
        let total = database.tagCount +
            (auditModel.isEnabled ? 1 : 0) +
            database.passkeyEntryCount +
            database.sshKeyEntryCount +
            database.attachmentsEntryCount +
            expireCount +
            database.recycleBinCount

        return total > 0 && database.isHomeViewSectionVisible(section: .otherViews)
    }

    var showNavigationSection: Bool {
        let total = entryCount +
            database.favourites.count +
            database.totpCodeEntries.count +
            database.groupCount

        return total > 0 && database.isHomeViewSectionVisible(section: .navigation)
    }

    var showFavouritesSection: Bool {
        !database.favourites.isEmpty && database.isHomeViewSectionVisible(section: .favourites)
    }

    var showQuickTagsSection: Bool {
        database.tagCount > 0 && database.isHomeViewSectionVisible(section: .quickTags)
    }

    var allHomeSectionsInvisible: Bool {
        let vis = HomeViewSection.allCases.first { isHomeViewSectionVisible(section: $0) }
        return vis == nil
    }

    var showEmptyDatabaseView: Bool {
        !showFavouritesSection && !showNavigationSection && !showQuickTagsSection && !showOtherViews
    }

    var auditModel: AuditViewModel {
        database.auditModel
    }

    var startWithSearch: Bool {
        get {
            database.startWithSearch
        }
        set {
            database.startWithSearch = newValue
        }
    }

    var hasDoneDatabaseOnLaunchTasks: Bool {
        get {
            actions.hasDoneDatabaseOnLaunchTasks
        }
        set {
            actions.hasDoneDatabaseOnLaunchTasks = newValue
        }
    }

    var tabBarControllerIsHidden: Bool {
        actions.tabBarControllerIsHidden
    }

    var biometricsIsFaceId: Bool {
        actions.biometricsIsFaceId
    }

    func presentConfigureTabsView() {
        actions.presentConfigureTabsView()
    }

    func presentCustomizeView() {
        actions.presentCustomizeView()
    }

    func presentConvenienceUnlockPreferences() {
        actions.presentConvenienceUnlockPreferences()
    }

    func presentAutoFillSettings() {
        actions.presentAutoFillSettings()
    }

    func presentAuditSettings() {
        actions.presentAuditSettings()
    }

    func presentAutoLockSettings() {
        actions.presentAutoLockSettings()
    }

    func presentAdvancedSettings() {
        actions.presentAdvancedSettings()
    }

    func presentHardwareKeySettings() {
        actions.presentHardwareKeySettings()
    }

    func presentEncryptionSettings() {
        actions.presentEncryptionSettings()
    }

    func presentSetMasterCredentials() {
        actions.presentSetMasterCredentials()
    }

    var disableExport: Bool {
        database.disableExport
    }

    var disablePrinting: Bool {
        database.disablePrinting
    }

    func onAddEntry() {
        actions.onAddEntry()
    }

    func exportDatabase() {
        actions.exportDatabase()
    }

    func printDatabase() {
        actions.printDatabase()
    }

    var syncStatus: SyncStatus? {
        actions.syncStatus
    }

    var isRunningAsyncUpdate: Bool {
        actions.isRunningAsyncUpdate
    }

    var lastAsyncUpdateResult: AsyncJobResult? {
        actions.lastAsyncUpdateResult
    }

    var showIcons: Bool {
        database.showIcons
    }

    var title: String {
        database.nickName
    }

    var subtitle: String {
        var status: [String] = []
        if database.isReadOnly {
            status.append(NSLocalizedString("databases_toggle_read_only_context_menu", comment: "Read-Only"))
        }
        if database.isInOfflineMode {
            status.append(NSLocalizedString("browse_vc_pulldown_refresh_offline_title", comment: "Offline Mode"))
        }

        return status.count > 1 ? String(format: "(%@)", status.joined(separator: ", ")) : status.joined(separator: ", ")
    }

    func isHomeViewSectionVisible(section: HomeViewSection) -> Bool {
        database.isHomeViewSectionVisible(section: section)
    }

    func setHomeViewSectionVisible(section: HomeViewSection, visible: Bool) {
        database.setHomeViewSectionVisible(section: section, visible: visible)
    }

    var recycleBinGroup: (any SwiftGroupModelInterface)? {
        database.recycleBinGroup
    }

    func emptyRecycleBin() async {
        await actions.emptyRecycleBin()
    }

    var shouldShowYubiKeySettingsOption: Bool {
        AppPreferences.sharedInstance().hardwareKeyCachingBeta && database.format == .keePass4 && database.ckfs.yubiKeyCR != nil
    }
}
