//
//  MainSplitViewController.swift
//  Strongbox
//
//  Created by Strongbox on 10/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation
import SwiftUI

@objc
class PresentUnlockedDatabaseParams: NSObject {
    var suppressInitialLazySync: Bool
    var onLoadAdd2FAOtpAuthUrl: URL?

    @objc
    init(suppressInitialLazySync: Bool, onLoadAdd2FAOtpAuthUrl: URL? = nil) {
        self.suppressInitialLazySync = suppressInitialLazySync
        self.onLoadAdd2FAOtpAuthUrl = onLoadAdd2FAOtpAuthUrl
    }
}

class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    deinit {
        unListenToNotifications()

        swlog("😎 DEINIT [MainSplitViewController]")
    }

    var cancelOtpTimer: Bool = false
    var nextGenSyncInProgress: Bool = false
    @objc var hasDoneDatabaseOnLaunchTasks = false

    @objc var model: Model!
    @objc var presentationParams: PresentUnlockedDatabaseParams!

    @objc
    class func fromStoryboard() -> Self {
        let storyboard = UIStoryboard(name: "MasterDetail", bundle: nil)
        return storyboard.instantiateInitialViewController() as! Self
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        

        if UIDevice.current.userInterfaceIdiom == .pad {
            let fraction = 0.5
            preferredPrimaryColumnWidthFraction = fraction
            maximumPrimaryColumnWidth = fraction * UIScreen.main.bounds.size.width
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        swlog("MainSplitViewController::viewDidLoad")

        

        let browseTabController = BrowseTabViewController.fromStoryboard(model: model)
        let emptyDetails = UIStoryboard(name: "EmptyDetails", bundle: nil).instantiateInitialViewController()!

        viewControllers = [browseTabController, emptyDetails]

        delegate = self
        preferredDisplayMode = .oneBesideSecondary 

        listenToNotifications()

        startOtpRefresh()

        if !presentationParams.suppressInitialLazySync, model.metadata.storageProvider != .kLocalDevice, model.metadata.lazySyncMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in

                self?.beginOnLoadLazySync()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.model.restartBackgroundAudit()
        }
    }

    var firstAppearance = true
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if firstAppearance {
            firstAppearance = false
            

            if let otpAuthUrl = presentationParams.onLoadAdd2FAOtpAuthUrl {
                begin2FAImport(otpAuthUrl: otpAuthUrl)
            }
        }
    }

    func beginOnLoadLazySync() {
        if model.isInOfflineMode {
            swlog("✅ MainSplitViewController::beginOnLoadLazySync. Offline Mode - Not Syncing.")
            return
        }

        swlog("✅ MainSplitViewController::beginOnLoadLazySync. Syncing....")

        sync()
    }

    func listenToNotifications() {
        unListenToNotifications()

        swlog("MainSplitViewController: listenToNotifications")

        NotificationCenter.default.addObserver(self, selector: #selector(onAutoFillChangedConfig(object:)), name: .autoFillChangedConfig, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBeginImport2FAOtpAuthUrlNotification(object:)), name: .beginImport2FAOtpAuthUrl, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(onWiFiSyncUpdatedWorkingCopy(object:)),
                                               name: Notification.Name("wiFiSyncServiceNameDidChange"), 
                                               object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(onCloudKitUpdateAvailableNotification(object:)),
                                               name: Notification.Name("cloudKitDatabaseUpdateAvailable"), 
                                               object: nil)
    }

    func unListenToNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func onBeginImport2FAOtpAuthUrlNotification(object: Any?) {
        swlog("🟢 MainSplitViewController::onBeginImport2FAOtpAuthUrlNotification - [%@]", object)

        guard let notification = object as? Notification, let otpAuthUrl = notification.object as? URL else {
            swlog("🔴 Couldn't get URL in notification")
            return
        }

        begin2FAImport(otpAuthUrl: otpAuthUrl)
    }

    @objc func onAutoFillChangedConfig(object _: Any?) {
        swlog("🟢 MainSplitViewController::onAutoFillChangedConfig - reloading and doing background sync...")

        
        

        reloadModelFromWorkingCache { [weak self] success in
            if success {
                self?.sync() 
            }
        }
    }

    @objc func onWiFiSyncUpdatedWorkingCopy(object _: Any?) {
        swlog("🟢 MainSplitViewController::onWiFiSyncUpdatedWorkingCopy - reloading from working copy...")

        

        reloadModelFromWorkingCache()
    }

    @objc func onCloudKitUpdateAvailableNotification(object: Any?) {
        swlog("🟢 MainSplitViewController::onCloudKitUpdateAvailableNotification")

        guard let notification = object as? NSNotification, let uuid = notification.object as? String else {
            swlog("🔴 Could not read onCloudKitUpdateAvailableNotification!")
            return
        }

        guard uuid == model.databaseUuid else {
            return
        }

        guard !AppModel.shared.isEditing(uuid) else {
            swlog("Received change available notification for database \(uuid) but edits in progress, not initiating a sync")
            return
        }

        sync()
    }

    func splitViewController(_: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        swlog("splitViewController::collapseSecondaryViewController 2nd [%@]", secondaryViewController)
        swlog("splitViewController::collapseSecondaryViewController primary [%@]", primaryViewController)

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            swlog("🔴 Could not determine masterNav from view hierarchy? collapseSecondary")
            return false
        }

        if let detailsNav = secondaryViewController as? UINavigationController,
           let detailsVc = detailsNav.topViewController as? ItemDetailsViewController
        {
            swlog("Displaying a details view, will not collapse to Browse, collapsing to detail instead - [displayMode = %@, isCollapsed = %hhd]", String(describing: displayMode), isCollapsed)

            
            
            
            

            detailsNav.navigationBar.isHidden = true 

            

            detailsNav.popViewController(animated: false)
            detailsNav.removeFromParent()

            

            detailsVc.willMove(toParent: nil)
            detailsVc.view.removeFromSuperview()
            detailsVc.removeFromParent()

            masterNav.pushViewController(detailsVc, animated: false)

            viewControllers = [primaryViewController]

            return true
        }

        return false
    }

    func splitViewController(_: UISplitViewController, showDetail vc: UIViewController, sender _: Any?) -> Bool {
        swlog("splitViewController::showDetail: [%@]", String(describing: vc))

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            swlog("🔴 Could not determine masterNav from view hierarchy? showDetail")
            return false
        }

        if isCollapsed {
            masterNav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            viewControllers = [viewControllers.first!, nav]
        }

        return true
    }

    func splitViewController(_: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        swlog("splitViewController::separateSecondaryFrom: [%@]", String(describing: primaryViewController))

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            swlog("🔴 Could not determine masterNav from view hierarchy? separateSecondaryFrom")
            return nil
        }

        if let detailsVc = masterNav.topViewController as? ItemDetailsViewController {
            masterNav.popViewController(animated: false)
            return UINavigationController(rootViewController: detailsVc)
        } else {
            let storyboard = UIStoryboard(name: "EmptyDetails", bundle: nil)
            return storyboard.instantiateInitialViewController()
        }
    }

    @objc public func closeAndCleanup(completion: (() -> Void)? = nil) {
        swlog("MainSplitViewController: onClose")

        killOtpTimer()

        NotificationCenter.default.post(name: .masterDetailViewClose, object: model.metadata.uuid) 

        model.closeAndCleanup()

        presentingViewController?.dismiss(animated: true, completion: completion)
    }

    func killOtpTimer() {
        cancelOtpTimer = true
    }

    func startOtpRefresh() {
        NotificationCenter.default.post(name: .centralUpdateOtpUi, object: nil)

        if !cancelOtpTimer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.startOtpRefresh()
            }
        }
    }

    

    func getMostAppropriateViewControllerForInteraction() -> UIViewController {
        if let nav = viewControllers.first as? UINavigationController,
           let visible = nav.visibleViewController
        {
            return visible
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        return appDelegate.getVisibleViewController() ?? self
    }

    

    @available(*, renamed: "updateAndQueueSync()")
    @objc public func updateAndQueueSync(completion: ((_ savedWorkingCopy: Bool) -> Void)? = nil) {
        swlog("MainSplitViewController::updateAndQueueSync start")

        let updateId = UUID()
        model.metadata.asyncUpdateId = updateId

        

        let success = model.asyncUpdate { result in
            self.onAsyncUpdateDone(result: result, updateId: updateId, completion: completion)
        }

        if !success, let completion {
            completion(false)
        }
    }

    @objc public func updateAndQueueSync() async -> Bool {
        await withCheckedContinuation { continuation in
            updateAndQueueSync { result in
                continuation.resume(returning: result)
            }
        }
    }

    func onAsyncUpdateDone(result: AsyncJobResult, updateId: UUID, completion: ((_: Bool) -> Void)? = nil) {
        swlog("Async Update [\(String(describing: updateId))] Done with [String(describing: result.success)]")

        if model.metadata.asyncUpdateId == updateId {
            model.metadata.asyncUpdateId = nil
        } else {
            swlog("Not clearing asyncUpdateID as another has been queued... [%@]", String(describing: model.metadata.asyncUpdateId))
        }

        if result.success {
            onUpdateSucceeded(completion: completion)
        } else {
            if result.userCancelled {
                onUserCancelledDuringUpdate(completion: completion)
            } else {
                onErrorDuringUpdate(error: result.error, completion: completion)
            }
        }
    }

    func onUpdateSucceeded(completion: ((_: Bool) -> Void)?) {
        swlog("MainSplitViewController::onUpdateSucceeded")

        if !model.isInOfflineMode {
            sync()
        }

        if let completion {
            completion(true)
        }
    }

    func onUserCancelledDuringUpdate(completion: ((_: Bool) -> Void)?) {
        displayGenericUpdateProblemTryAgainAlert(completion: completion)
    }

    func onErrorDuringUpdate(error: Error?, completion: ((_: Bool) -> Void)?) {
        displayGenericUpdateProblemTryAgainAlert(errorDescription: error?.localizedDescription, completion: completion)
    }

    func displayGenericUpdateProblemTryAgainAlert(errorDescription: String? = nil, completion: ((_: Bool) -> Void)?) {
        let vc = getMostAppropriateViewControllerForInteraction()

        var message = NSLocalizedString("error_could_not_save_message", comment: "Your changes could not be safely saved. You are now working on an in-memory version only of your database. We recommend you try to save again.")

        if let errorDescription {
            message = message.appendingFormat("\n\n%@", errorDescription)
        }

        Alerts.oneOptions(withCancel: vc,
                          title: NSLocalizedString("moveentry_vc_error_saving", comment: "Error Saving"),
                          message: message,
                          buttonText: NSLocalizedString("sync_status_error_updating_try_again_action", comment: "Try Again"))
        { response in
            if response {
                DispatchQueue.main.async { [weak self] in
                    self?.updateAndQueueSync(completion: completion)
                }
            } else {
                if let completion {
                    completion(false)
                }
            }
        }
    }

    

    @objc
    func onManualPullDownRefresh(completion: @escaping () -> Void) {
        if model.isInOfflineMode {
            if model.metadata.allowPulldownRefreshSyncInOfflineMode {
                doSyncAfterPulldownRefresh(ignoreOfflineMode: true, completion: completion)
            } else {
                Alerts.twoOptions(withCancel: self,
                                  title: NSLocalizedString("manual_pulldown_sync_sync_in_offline_mode_question_title", comment: "Sync in Offline Mode?"),
                                  message: NSLocalizedString("manual_pulldown_sync_sync_in_offline_mode_question_message", comment: "Would you like to sync even though the database is in Offline mode?"),
                                  defaultButtonText: NSLocalizedString("manual_pulldown_sync_sync_in_offline_mode_option_sync_once", comment: "Sync this once"),
                                  secondButtonText: NSLocalizedString("manual_pulldown_sync_sync_in_offline_mode_option_always", comment: "Always sync when I do this"))
                { [weak self] response in
                    guard let self else {
                        return
                    }

                    if response == 0 { 
                        doSyncAfterPulldownRefresh(ignoreOfflineMode: true, completion: completion)
                    } else if response == 1 { 
                        model.metadata.allowPulldownRefreshSyncInOfflineMode = true
                        doSyncAfterPulldownRefresh(ignoreOfflineMode: true, completion: completion)
                    } else {
                        completion()
                    }
                }
            }
        } else {
            doSyncAfterPulldownRefresh(ignoreOfflineMode: false, completion: completion)
        }
    }

    func doSyncAfterPulldownRefresh(ignoreOfflineMode: Bool, completion: @escaping () -> Void) {
        sync(ignoreOfflineModeAndTrySync: ignoreOfflineMode) { _, localWasChanged, _ in
            if localWasChanged {
                StrongboxToastMessages.showSlimInfoStatusBar(body: NSLocalizedString("browse_vc_pulldown_refresh_updated_title", comment: "Database Updated"), delay: 1.5)
            }

            completion()
        }
    }

    

    @objc func sync(ignoreOfflineModeAndTrySync: Bool = false, completion: SyncAndMergeCompletionBlock? = nil) {
        swlog("MainSplitViewController::sync BEGIN")

        guard !model.isInOfflineMode || ignoreOfflineModeAndTrySync else {
            swlog("🔴 Database is in Offline Mode - Cannot Sync!")

            if let completion {
                completion(.error, false, Utils.createNSError("🔴 Database is in Offline Mode - Cannot Sync!", errorCode: -1))
            }

            return
        }

        SyncManager.sharedInstance().backgroundSyncDatabase(model.metadata, join: false, key: model.ckfs) { [weak self] result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, localWasChanged: localWasChanged, error: error, wasInteractive: false, completion: completion)
            }
        }
    }

    func interactiveSync(interactiveVc: UIViewController, completion: SyncAndMergeCompletionBlock?) {
        SyncManager.sharedInstance().sync(model.metadata, interactiveVC: interactiveVc, key: model.ckfs, join: false) { [weak self] result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, localWasChanged: localWasChanged, error: error, wasInteractive: true, completion: completion)
            }
        }
    }

    func onSyncCompleted(result: SyncAndMergeResult, localWasChanged: Bool, error: Error?, wasInteractive: Bool, completion: SyncAndMergeCompletionBlock?) {
        if result == .success {
            onSyncSuccess(localWasChanged: localWasChanged, completion: completion)
        } else if result == .error {
            onSyncError(error: error, completion: completion)
        } else if result == .userPostponedSync {
            onSyncUserPostponed(completion: completion)
        } else if result == .resultUserCancelled {
            onSyncUserCancelled(completion: completion)
        } else if result == .resultUserInteractionRequired {
            onSyncUserInteractionRequired(wasInteractive: wasInteractive, completion: completion)
        } else {
            swlog("🔴 Unknown or expected Sync Result!")
        }
    }

    func onSyncUserCancelled(completion: SyncAndMergeCompletionBlock?) {
        swlog("MainSplitViewController::onSyncUserCancelled")

        if let completion {
            completion(.resultUserCancelled, false, nil)
        }
    }

    func onSyncUserPostponed(completion: SyncAndMergeCompletionBlock?) {
        swlog("MainSplitViewController::onSyncUserPostponed")

        if let completion {
            completion(.userPostponedSync, false, nil)
        }
    }

    func onSyncUserInteractionRequired(wasInteractive: Bool, completion: SyncAndMergeCompletionBlock?) {
        swlog("MainSplitViewController::onSyncUserInteractionRequired")

        if wasInteractive {
            swlog("🔴 Something very wrong - User interaction required after an interactive sync? SANITY")
            if let completion {
                completion(.error, false, Utils.createNSError("Something very wrong - User interaction required after an interactive sync? SANITY", errorCode: -1))
            }

            return
        }

        let vc = getMostAppropriateViewControllerForInteraction()

        interactiveSync(interactiveVc: vc, completion: completion)
    }

    func onSyncError(error: Error?, completion: SyncAndMergeCompletionBlock?) {
        swlog("🔴 MainSplitViewController::onSyncError - Error Occurred => [%@]", String(describing: error))

        let vc = getMostAppropriateViewControllerForInteraction()

        let fmt = NSLocalizedString("sync_error_message_including_error_detail_fmt", comment: "Your database is safely saved but there was an error syncing. Would you like to try again or take a look at the Sync Log?\n\n%@\n")

        let message = String(format: fmt, error?.localizedDescription ?? "")

        Alerts.twoOptions(withCancel: vc,
                          title: NSLocalizedString("open_sequence_storage_provider_error_title", comment: "Sync Error"),
                          message: message,
                          defaultButtonText: NSLocalizedString("sync_status_error_updating_try_again_action", comment: "Try Again"),
                          secondButtonText: NSLocalizedString("safes_vc_action_view_sync_status", comment: "View Sync Log"))
        { [weak self] response in
            if response == 0 {
                DispatchQueue.main.async { [weak self] in
                    self?.sync(completion: completion)
                }
            } else if response == 1 {
                self?.showSyncLog()
            }
        }
    }

    func showSyncLog() {
        let nav = SyncLogViewController.create(withDatabase: model.metadata)

        let vc = getMostAppropriateViewControllerForInteraction()

        vc.present(nav, animated: true)
    }

    fileprivate func reloadModelFromWorkingCache(_ completion: ((Bool) -> Void)? = nil) {
        let vc = getMostAppropriateViewControllerForInteraction()

        model.reloadDatabase(fromLocalWorkingCopy: {
            vc
        }, noProgressSpinner: false) { [weak self] success in
            if success {
                
                swlog("✅ Successfully reloaded database")

            } else {
                

                swlog("🔴 Could not Unlock updated database after reload. Key changed?! - Force Locking.")

                self?.closeAndCleanup()
            }

            completion?(success)
        }
    }

    func onSyncSuccess(localWasChanged: Bool, completion: SyncAndMergeCompletionBlock?) {
        swlog("✅ MainSplitViewController::onSyncSuccess => Sync Successfully Completed [localWasChanged = %@]", localizedYesOrNoFromBool(localWasChanged))

        if localWasChanged {
            reloadModelFromWorkingCache()
        }

        if let completion {
            completion(.success, localWasChanged, nil)
        }
    }

    

    func begin2FAImport(otpAuthUrl: URL) {
        guard let token = OTPToken(url: otpAuthUrl) else {
            Alerts.info(self,
                        title: NSLocalizedString("generic_error", comment: "Error"),
                        message: NSLocalizedString("invalid_otpauth_url", comment: "Invalid OTPAuth URL"))
            return
        }

        let sortedGroups = AddOrCreateHelper.getSortedGroups(model)
        var sortedPaths = sortedGroups.map { AddOrCreateHelper.getGroupPathDisplayString($0, model.database) }
        let rootPath = AddOrCreateHelper.getGroupPathDisplayString(model.database.effectiveRootGroup, model.database, true)
        sortedPaths.insert(rootPath, at: 0)

        let entries = NSMutableArray(array: model.allSearchableNoneExpiredEntries)
        let sorted = model.filterAndSort(forBrowse: entries, includeGroups: false)

        let title = (token.name ?? token.issuer) ?? NSLocalizedString("generic_unknown", comment: "Unknown")

        let wizard = AddOrCreateWizard(
            mode: .totp,
            title: title,
            groups: sortedPaths,
            entries: sorted,
            selectedGroupIdx: 0,
            model: model
        ) { [weak self] cancel, createNew, title, selectedGroupIdx, selectedEntry in
            guard let self else { return }

            visibleViewController.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                guard !cancel else { return }

                var success: Bool
                if createNew {
                    guard let title, let selectedGroupIdx, let group = selectedGroupIdx == 0 ? model.database.effectiveRootGroup : sortedGroups[safe: selectedGroupIdx - 1] else {
                        swlog("🔴 Could not get proper params to create new TOTP!")
                        Alerts.info(visibleViewController, title: NSLocalizedString("generic_error", comment: "Error"), message: "Could not get proper params to create new TOTP")
                        return
                    }

                    success = onCreateNew(model: model, group: group, title: title, token: token)
                } else {
                    guard let selectedEntry, let entry = model.getItemBy(selectedEntry) else {
                        swlog("🔴 Could not get proper params to add new TOTP!")
                        Alerts.info(visibleViewController, title: NSLocalizedString("generic_error", comment: "Error"), message: "Could not get proper params to add new TOTP")
                        return
                    }

                    success = onAddToExistingEntry(model: model, entry: entry, token: token)
                }

                if !success {
                    Alerts.info(visibleViewController,
                                title: NSLocalizedString("generic_error", comment: "Error"),
                                message: NSLocalizedString("error_adding_2fa_code", comment: "Error Adding 2FA Code"))
                }
            }
        }

        let vc = UIHostingController(rootView: wizard)
        vc.modalPresentationStyle = .formSheet

        visibleViewController.present(vc, animated: true)
    }

    func onCreateNew(model: Model, group: Node, title: String, token: OTPToken) -> Bool {
        let node = Node(asRecord: title, parent: group)

        if !model.addChildren([node], destination: group) {
            swlog("🔴 Could not add!")
            return false
        }

        return onAddToExistingEntry(model: model, entry: node, token: token)
    }

    func onAddToExistingEntry(model: Model, entry: Node, token: OTPToken) -> Bool {
        let appendUrlToNotes = model.originalFormat == .passwordSafe || model.originalFormat == .keePass1
        entry.fields.setTotp(token,
                             appendUrlToNotes: appendUrlToNotes,
                             addLegacyFields: AppPreferences.sharedInstance().addLegacySupplementaryTotpCustomFields,
                             addOtpAuthUrl: AppPreferences.sharedInstance().addOtpAuthUrl)

        Task {
            if await updateAndQueueSync() {
                StrongboxToastMessages.showSlimInfoStatusBar(body: NSLocalizedString("2fa_code_saved", comment: "2FA Code Saved"),
                                                             delay: 1.0)
                presentItemDetailsModal(uuid: entry.uuid)
            }
        }

        return true
    }

    @MainActor
    func presentItemDetailsModal(uuid: UUID) {
        let vc = ItemDetailsViewController.fromStoryboard(model, nodeUuid: uuid)
        vc.isStandaloneDetailsModal = true
        vc.explicitHideMetadata = true
        vc.explicitHideHistory = true

        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet

        visibleViewController.present(nav, animated: true)
    }

    var visibleViewController: UIViewController {
        presentedViewController ?? self
    }
}
