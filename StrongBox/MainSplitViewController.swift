//
//  MainSplitViewController.swift
//  Strongbox
//
//  Created by Strongbox on 10/12/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Foundation

class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    deinit {
        unListenToNotifications()

        NSLog("😎 DEINIT [MainSplitViewController]")
    }

    var cancelOtpTimer: Bool = false
    var nextGenSyncInProgress: Bool = false
    @objc var model: Model!
    @objc var hasAlreadyDoneStartWithSearch = false

    override func awakeFromNib() {
        super.awakeFromNib()

        

        if UIDevice.current.userInterfaceIdiom == .pad {
            let fraction = 0.45
            preferredPrimaryColumnWidthFraction = fraction
            maximumPrimaryColumnWidth = fraction * UIScreen.main.bounds.size.width
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLog("MainSplitViewController::viewDidLoad")

        

        let browseTabController = BrowseTabViewController.fromStoryboard(model: model)
        let emptyDetails = UIStoryboard(name: "EmptyDetails", bundle: nil).instantiateInitialViewController()!

        viewControllers = [browseTabController, emptyDetails]

        delegate = self
        preferredDisplayMode = .allVisible 

        listenToNotifications()

        startOtpRefresh()

        if model.metadata.storageProvider != .kLocalDevice, model.metadata.lazySyncMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in

                self?.beginOnLoadLazySync()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.model.restartBackgroundAudit()
        }
    }

    func beginOnLoadLazySync() {
        if model.isInOfflineMode {
            NSLog("✅ MainSplitViewController::beginOnLoadLazySync. Offline Mode - Not Syncing.")
            return
        }

        NSLog("✅ MainSplitViewController::beginOnLoadLazySync. Syncing....")

        sync()
    }

    func unListenToNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    func listenToNotifications() {
        unListenToNotifications()

        NSLog("MainSplitViewController: listenToNotifications")









        NotificationCenter.default.addObserver(self, selector: #selector(onAutoFillChangedConfig(object:)), name: .autoFillChangedConfig, object: nil)
    }

    @objc func onAutoFillChangedConfig(object _: Any?) {
        NSLog("🟢 MainSplitViewController::onAutoFillChangedConfig - reloading and doing background sync...")

        
        

        reloadModelFromWorkingCache { [weak self] success in
            if success {
                self?.sync() 
            }
        }
    }

    func splitViewController(_: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        NSLog("splitViewController::collapseSecondaryViewController 2nd [%@] -> primary [%@]", secondaryViewController, primaryViewController)

        if UIDevice.current.userInterfaceIdiom == .pad { 
            if #available(iOS 17.0, *) {
                return false
            }
        }

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            NSLog("🔴 Could not determine masterNav from view hierarchy?")
            return false
        }

        if let detailsNav = secondaryViewController as? UINavigationController,
           let detailsVc = detailsNav.topViewController as? ItemDetailsViewController
        {
            NSLog("Displaying a details view, will not collapse to Browse, collapsing to detail instead - [displayMode = %@, isCollapsed = %hhd]", String(describing: displayMode), isCollapsed)

            
            detailsNav.popViewController(animated: false) 

            masterNav.pushViewController(detailsVc, animated: false)
            viewControllers = [primaryViewController]

            return true
        }

        return false
    }

    func splitViewController(_: UISplitViewController, showDetail vc: UIViewController, sender _: Any?) -> Bool {
        NSLog("splitViewController::showDetail: [%@]", String(describing: vc))

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            NSLog("🔴 Could not determine masterNav from view hierarchy?")
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
        NSLog("splitViewController::separateSecondaryFrom: [%@]", String(describing: primaryViewController))

        if UIDevice.current.userInterfaceIdiom == .pad { 
            if #available(iOS 17.0, *) {
                return nil
            }
        }

        guard let tabBar = viewControllers.first as? UITabBarController,
              let masterNav = tabBar.selectedViewController as? UINavigationController
        else {
            NSLog("🔴 Could not determine masterNav from view hierarchy?")
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













    @objc public func onClose() {
        NSLog("MainSplitViewController: onClose")

        killOtpTimer()

        NotificationCenter.default.post(name: .masterDetailViewClose, object: model.metadata.uuid)

        presentingViewController?.dismiss(animated: true)
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
        if let nav = viewControllers.first as? UINavigationController, let visible = nav.visibleViewController {
            return visible
        }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        return appDelegate.getVisibleViewController() ?? self
    }

    

    @objc public func updateAndQueueSync(completion: ((_ savedWorkingCopy: Bool) -> Void)? = nil) {
        NSLog("MainSplitViewController::updateAndQueueSync start")

        let updateId = UUID()
        model.metadata.asyncUpdateId = updateId

        

        let success = model.asyncUpdate { result in
            self.onAsyncUpdateDone(result: result, updateId: updateId, completion: completion)
        }

        if !success, let completion {
            completion(false)
        }
    }

    func onAsyncUpdateDone(result: AsyncJobResult, updateId: UUID, completion: ((_: Bool) -> Void)? = nil) {
        NSLog("Async Update [%@] Done with [%@]", String(describing: updateId), String(describing: result.success))

        if model.metadata.asyncUpdateId == updateId {
            model.metadata.asyncUpdateId = nil
        } else {
            NSLog("Not clearing asyncUpdateID as another has been queued... [%@]", String(describing: model.metadata.asyncUpdateId))
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
        NSLog("MainSplitViewController::onUpdateSucceeded")

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

    

    @objc public func sync(completion: SyncAndMergeCompletionBlock? = nil) {
        NSLog("MainSplitViewController::sync BEGIN")

        guard !model.isInOfflineMode else {
            NSLog("🔴 Database is in Offline Mode - Cannot Sync!")

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
            NSLog("🔴 Unknown or expected Sync Result!")
        }
    }

    func onSyncUserCancelled(completion: SyncAndMergeCompletionBlock?) {
        NSLog("MainSplitViewController::onSyncUserCancelled")

        if let completion {
            completion(.resultUserCancelled, false, nil)
        }
    }

    func onSyncUserPostponed(completion: SyncAndMergeCompletionBlock?) {
        NSLog("MainSplitViewController::onSyncUserPostponed")

        if let completion {
            completion(.userPostponedSync, false, nil)
        }
    }

    func onSyncUserInteractionRequired(wasInteractive: Bool, completion: SyncAndMergeCompletionBlock?) {
        NSLog("MainSplitViewController::onSyncUserInteractionRequired")

        if wasInteractive {
            NSLog("🔴 Something very wrong - User interaction required after an interactive sync? SANITY")
            if let completion {
                completion(.error, false, Utils.createNSError("Something very wrong - User interaction required after an interactive sync? SANITY", errorCode: -1))
            }

            return
        }

        let vc = getMostAppropriateViewControllerForInteraction()

        interactiveSync(interactiveVc: vc, completion: completion)
    }

    func onSyncError(error: Error?, completion: SyncAndMergeCompletionBlock?) {
        NSLog("🔴 MainSplitViewController::onSyncError - Error Occurred => [%@]", String(describing: error))

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
                
                NSLog("✅ Successfully reloaded database")

            } else {
                

                NSLog("🔴 Could not Unlock updated database after reload. Key changed?! - Force Locking.")

                self?.onClose()
            }

            completion?(success)
        }
    }

    func onSyncSuccess(localWasChanged: Bool, completion: SyncAndMergeCompletionBlock?) {
        NSLog("✅ MainSplitViewController::onSyncSuccess => Sync Successfully Completed [localWasChanged = %@]", localizedYesOrNoFromBool(localWasChanged))

        if localWasChanged {
            reloadModelFromWorkingCache()
        }

        if let completion {
            completion(.success, localWasChanged, nil)
        }
    }
}
