//
//  DatabasesCollection.swift
//  MacBox
//
//  Created by Strongbox on 02/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa

public extension Notification.Name {
    enum DatabasesCollection {
        static let lockStateChanged = Notification.Name("DatabasesCollectionLockStateChangedNotification")
        static let autoLockAppInBackgroundTimeout = Notification.Name("autoLockAppInBackgroundTimeout")
    }
}

class DatabasesCollection: NSObject {
    @objc static let shared = DatabasesCollection()

    var unlockedCollection: ConcurrentMutableDictionary<NSString, Model> = .init()
    var pollingInProgressSetC: ConcurrentMutableSet<NSString> = ConcurrentMutableSet()
    var pollingTimersC: ConcurrentMutableDictionary<NSString, Timer> = .init() 

    var idleTimer: Timer? = nil

    override private init() {
        super.init()

        listenToSafariAutoFillWormhole()
        listenToEvents()
        watchForIdle()
    }

    

    private func listenToSafariAutoFillWormhole() {
        SafariAutoFillWormhole.sharedInstance()?.listenToAutoFillWormhole()
    }

    private func listenToEvents() {
        listenToScreenLockEvents()

        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }

            self.onSettingsChanged()
        }

        NotificationCenter.default.addObserver(forName: .DatabasesCollection.autoLockAppInBackgroundTimeout, object: nil, queue: nil) { [weak self] _ in
            swlog("🐞 DEBUG - DatabasesCollection - Received AutoLockInBackgroundTimeout notification - Attempting Lock")
            self?.onAutoLockTimeout(background: true)
        }

        let note = Notification.Name("cloudKitDatabaseUpdateAvailable") 

        NotificationCenter.default.addObserver(forName: note, object: nil, queue: nil) { [weak self] notification in
            guard let uuid = notification.object as? String else {
                swlog("🔴 Couldn't read cloudkit update notification...")
                return
            }

            self?.onDatabaseRemoteChanged(uuid: uuid)
        }
    }

    private func watchForIdle() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self] _ in
            let interval = self?.getSystemIdleInterval()
            let timeout = Settings.sharedInstance().autoLockTimeoutSeconds

            

            if let interval, timeout > 0, Int(interval) > timeout {
                self?.onAutoLockTimeout()
            }
        })
    }

    func listenToScreenLockEvents() {
        
        
        
        
        

        

        let notificationName = String(format: "%@.%@", "com.apple", "screenIsLocked")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name(rawValue: notificationName), object: nil)

        let notificationName2 = String(format: "%@.%@", "com.apple", "sessionDidMoveOffConsole") 
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name(rawValue: notificationName2), object: nil)

        

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)

        

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        let notificationName3 = String(format: "%@.%@", "com.apple", "screenIsUnlocked")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onWake(_:)), name: NSNotification.Name(rawValue: notificationName3), object: nil)
    }

    func onAutoLockTimeout(background: Bool = false) {
        swlog("🐞 onAutoLockTimeout: Maybe Locking Databases... [Background = %hhd]", background)

        tryToLockAll()
    }

    @objc func onScreenLocked() {
        swlog("onScreenLocked...")

        if Settings.sharedInstance().lockDatabasesOnScreenLock {
            tryToLockAll()
        }

        stopAllPollingTimers()
    }

    @objc func onSleep() {
        swlog("onSleep: Stopping Polling...")

        stopAllPollingTimers()
    }

    @objc func onWake(_ notification: NSNotification) {
        swlog("onWake: Restarting Polling... %@", notification)

        restartPollingTimers()
    }

    func getSystemIdleInterval() -> TimeInterval {
        var lastEvent: CFTimeInterval = 0

        lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)

        return lastEvent
    }

    

    func notifyLockStateChanged(uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .DatabasesCollection.lockStateChanged, object: uuid)
        }
    }

    func addOrUpdateUnlocked(model: Model) {
        let existing = getUnlocked(uuid: model.databaseUuid)

        if let existing, model == existing {
            swlog("🔴 This database is already unlocked Will not add again")
            return
        }

        unlockedCollection.setObject(model, forKey: model.databaseUuid as NSString)

        if existing == nil {
            startPollForRemoteChangesTimer(uuid: model.databaseUuid)
        }



        notifyLockStateChanged(uuid: model.databaseUuid)
    }

    @objc public func isDocumentWindowOpen(uuid: String) -> Bool {
        documentForDatabase(uuid: uuid) != nil
    }

    @objc public func documentForDatabase(uuid: String) -> Document? {
        guard let dc = DocumentController.shared as? DocumentController else {
            swlog("🔴 Couldn't get shared document controller")
            return nil
        }

        return dc.document(forDatabase: uuid)
    }

    @objc public func databaseHasEditsOrIsBeingEdited(uuid: String) -> Bool {
        guard let doc = documentForDatabase(uuid: uuid) else {
            return false
        }

        return doc.hasUnautosavedChanges || doc.isDocumentEdited || doc.isEditsInProgress 
    }

    @objc public func selectEntryInUI(uuid: String, nodeId: UUID) -> Bool {
        

        guard let doc = documentForDatabase(uuid: uuid) else {
            swlog("🔴 Couldn't get document for this db!")
            return false
        }

        setModelNavigationContextWithViewNode(doc.viewModel, .special(.allEntries))

        doc.viewModel.nextGenSelectedItems = [nodeId]

        return true
    }

    @objc public func popAndPinEntryInUI(uuid: String, nodeId: UUID) -> Bool {
        

        guard let doc = documentForDatabase(uuid: uuid) else {
            swlog("🔴 Couldn't get document for this db!")
            return false
        }

        setModelNavigationContextWithViewNode(doc.viewModel, .special(.allEntries))
        doc.viewModel.nextGenSelectedItems = [nodeId]

        NSApplication.shared.sendAction(#selector(NextGenSplitViewController.onPopOutDetailsAndPin(_:)), to: nil, from: self)

        return true
    }

    @objc public func closeAnyDocumentWindows(uuid: String) {
        if isUnlocked(uuid: uuid) {
            swlog("🔴 This database is unlocked. Cannot close! NOP")
            return
        }

        if let doc = documentForDatabase(uuid: uuid) {
            doc.close()
        }
    }

    @objc
    public func showDatabaseDocumentWindow(uuid: String, completion: ((_ document: Document?, _ error: Error?) -> Void)? = nil) {
        guard let dc = DocumentController.shared as? DocumentController, let database = MacDatabasePreferences.getById(uuid) else {
            swlog("🔴 Couldn't get shared document controller")
            return
        }

        dc.openDatabase(database, completion: completion)
    }

    static func getDbManagerPanelVc() -> NSViewController {
        
        

        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.suppressQuickLaunchForNextAppActivation = true 

        NSApp.activate(ignoringOtherApps: true)
        NSApp.arrangeInFront(nil)

        DBManagerPanel.sharedInstance.show()

        

        let ret = DBManagerPanel.sharedInstance.contentViewController!

        

        return ret
    }

    func initiateUnlockWithSynchronousTimeout(_ databaseId: String, timeoutSeconds: CGFloat, syncAfterUnlock: Bool = true, message: String? = nil) -> Bool {
        if isUnlocked(uuid: databaseId) {
            swlog("⚠️ This database was already unlocked! NOP")
            return true
        }

        var go = false

        let semaphore = DispatchSemaphore(value: 0)
        var done = false
        DatabasesCollection.shared.initiateDatabaseUnlock(uuid: databaseId, syncAfterUnlock: syncAfterUnlock, message: message) { success in
            if done {
                swlog("🔴 WARNWARN: Database Unlock Completion Called more than once?! 1.59.9 issue?")
                return
            } else {
                done = true
                go = success
                semaphore.signal()
            }
        }

        if semaphore.wait(timeout: .now() + timeoutSeconds) == .timedOut {
            swlog("⚠️ Waiting for Database Unlock, timed out.")
        } else {
            swlog("Waiting for Database Unlock done, result = [%@]", localizedOnOrOffFromBool(go))
        }

        return go
    }

    @objc
    public func initiateDatabaseUnlock(uuid: String, syncAfterUnlock: Bool, message: String? = nil, completion: ((_: Bool) -> Void)? = nil) {
        if isUnlocked(uuid: uuid) {
            swlog("⚠️ This database was already unlocked! NOP")
            DispatchQueue.global().async {
                completion?(true)
            }
            return
        }

        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            swlog("🔴 No such database")
            DispatchQueue.global().async {
                completion?(false)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.initiateDatabaseUnlockInternal(prefs: prefs, uuid: uuid, syncAfterUnlock: syncAfterUnlock, message: message, completion: completion)
        }
    }

    private func initiateDatabaseUnlockInternal(prefs: MacDatabasePreferences,
                                                uuid: String,
                                                syncAfterUnlock: Bool,
                                                message: String? = nil,
                                                completion: ((_: Bool) -> Void)? = nil)
    {
        let determiner = MacCompositeKeyDeterminer(database: prefs,
                                                   isNativeAutoFillAppExtensionOpen: false,
                                                   isAutoFillQuickTypeOpen: false,
                                                   onDemandUiProvider: DatabasesCollection.getDbManagerPanelVc)

        

        

        
        

        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.cancelAutoLockTimer()

        var ckfsCompletionCalled = false
        
        determiner.getCkfs(message) { [weak self] result, ckfs, fromConvenience, error in
            guard !ckfsCompletionCalled else {
                swlog("🔴 CKFs Completion Called Multiple Times!")
                return
            }
            ckfsCompletionCalled = true

            if !NSApplication.shared.isActive {
                
                

                appDelegate.startAutoLockTimer()
            }

            if let ckfs, result == .success {
                
                var unlockCompletionCalled = false
                self?.unlockModelFromLocalWorkingCopy(database: prefs, ckfs: ckfs, fromConvenience: fromConvenience) { result, _, _ in
                    swlog("🐞 Unlock Completion Called...")

                    guard !unlockCompletionCalled else {
                        swlog("🔴 Unlock Completion Called Multiple Times!")
                        return
                    }
                    unlockCompletionCalled = true

                    DispatchQueue.global().async {
                        if result == .success, syncAfterUnlock {
                            self?.sync(uuid: uuid, allowInteractive: false, suppressErrorAlerts: true, ckfsForConflict: ckfs)
                        }

                        completion?(result == .success)
                    }
                }
            } else if result == .error, let error {
                self?.displayUnlockingErrorMessage(error: error, eagerVc: nil)
                DispatchQueue.global().async {
                    completion?(false)
                }
            } else {
                DispatchQueue.global().async {
                    let unlocked = self?.isUnlocked(uuid: uuid) ?? false

                    if unlocked {
                        swlog("⚠️ MCE Cancelled - but database locked")
                    }

                    completion?(unlocked) 
                }
            }
        }
    }

    @objc public func initiateLockRequest(uuid: String) {
        if !isUnlocked(uuid: uuid) {
            swlog("🔴 This database was not in the unlocked collection! NOP")
            return
        }

        if let doc = documentForDatabase(uuid: uuid) {
            DispatchQueue.main.async {
                doc.initiateLockSequence()
            }
        } else {
            forceLock(uuid: uuid)
        }
    }

    @objc public func tryToLockAll() {
        let keys = unlockedCollection.allKeys

        for uuid in keys {
            initiateLockRequest(uuid: uuid as String)
        }
    }

    @objc func forceLock(uuid: String) {
        unlockedCollection.removeObject(forKey: uuid as NSString)
        stopPollForRemoteChangesTimer(uuid: uuid)


        notifyLockStateChanged(uuid: uuid)
    }

    @objc public func isUnlocked(uuid: String) -> Bool {
        let ret = getUnlocked(uuid: uuid) != nil

        

        return ret
    }

    @objc public func getUnlocked(uuid: String) -> Model? {
        let ret = unlockedCollection.object(forKey: uuid as NSString)

        

        return ret
    }

    

    func onSettingsChanged() {
        swlog("DatabasesCollection::onSettingsChanged() notification received")

        

        restartPollingTimers()
    }

    

    func stopAllPollingTimers() {
        swlog("Stop all Polling Timers...")

        let keys = pollingTimersC.allKeys
        for key in keys {
            if let timer = pollingTimersC.object(forKey: key) {
                timer.invalidate()
            }
            pollingTimersC.removeObject(forKey: key)
        }
    }

    func restartPollingTimers() {
        swlog("Restart Polling Timers...")

        stopAllPollingTimers()

        for uuid in unlockedCollection.allKeys {
            startPollForRemoteChangesTimer(uuid: uuid as String)
        }
    }

    private func startPollForRemoteChangesTimer(uuid: String) {


        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            swlog("🔴 No such database")
            return
        }

        if pollingTimersC.object(forKey: uuid as NSString) != nil {
            swlog("🔴 Already a timer in place")
            return
        }

        if let model = getUnlocked(uuid: uuid), model.metadata.monitorForExternalChanges, !model.isInOfflineMode {
            let nTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(prefs.monitorForExternalChangesInterval), repeats: true) { [weak self] _ in
                self?.pollForDatabaseRemoteChanges(uuid: uuid)
            }

            pollingTimersC.setObject(nTimer, forKey: uuid as NSString)
        } else {
            swlog("Not monitoring database external changes because OfflineMode or configured Off.")
        }
    }

    private func stopPollForRemoteChangesTimer(uuid: String) {
        swlog("stopPollForRemoteChangesTimer")

        if let timer = pollingTimersC.object(forKey: uuid as NSString) {
            timer.invalidate()
            pollingTimersC.removeObject(forKey: uuid as NSString)
        }
    }

    private func pollForDatabaseRemoteChanges(uuid: String) {


        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            swlog("🔴 No such database")
            return
        }

        if pollingInProgressSetC.contains(uuid as NSString) {
            swlog("pollForDatabaseRemoteChanges - pollingInProgress - Will not queue up another Poll.")
            return
        }

        pollingInProgressSetC.add(uuid as NSString)

        MacSyncManager.sharedInstance().poll(forChanges: prefs) { [weak self] result, changesPresent, error in
            self?.pollingInProgressSetC.remove(uuid as NSString)

            if let error {
                swlog("🔴 error polling: [%@]", String(describing: error))
            }

            if result == .success, changesPresent {
                swlog("pollForDatabaseRemoteChanges - Changes Found")

                self?.onDatabaseRemoteChanged(uuid: uuid)
            }
        }
    }

    func onDatabaseRemoteChanged(uuid: String) {
        if isUnlocked(uuid: uuid) {
            

            if let document = documentForDatabase(uuid: uuid) {
                document.onDatabaseChangedByExternalOther()
            } else { 
                sync(uuid: uuid, allowInteractive: false)
            }
        } else {
            swlog("⚠️ Got change notification for locked database? Shouldn't be possible. Stopping Timer")
            stopPollForRemoteChangesTimer(uuid: uuid)
        }
    }

    

    func checkEntitlements() -> Bool {
        if StrongboxProductBundle.isBusinessBundle {
            guard Settings.sharedInstance().businessOrganisationName != nil else {
                return false
            }
        }

        return true
    }

    @objc public func unlockModelFromLocalWorkingCopy(database: MacDatabasePreferences,
                                                      ckfs: CompositeKeyFactors,
                                                      fromConvenience: Bool,
                                                      alertOnJustPwdWrong: Bool = true,
                                                      offlineUnlockRequested: Bool = false,
                                                      showProgressSpinner: Bool = false,
                                                      eagerVc: NSViewController? = nil,
                                                      suppressErrorMessaging: Bool = false,
                                                      forceReadOnly: Bool = false,
                                                      completion: UnlockDatabaseCompletionBlock? = nil)
    {


        guard checkEntitlements() else {
            completion?(.error, nil, Utils.createNSError(NSLocalizedString("pro_status_unlicensed", comment: "Unlicensed"), errorCode: 1))
            return
        }

        let openOffline = database.alwaysOpenOffline || offlineUnlockRequested

        let unlocker = DatabaseUnlocker(forDatabase: database,
                                        forceReadOnly: forceReadOnly,
                                        isNativeAutoFillAppExtensionOpen: false,
                                        offlineMode: openOffline)
        {
            if let eagerVc {

                return eagerVc
            } else {

                return DatabasesCollection.getDbManagerPanelVc()
            }
        }

        unlocker.alertOnJustPwdWrong = alertOnJustPwdWrong
        unlocker.noProgressSpinner = !showProgressSpinner

        unlocker.unlockLocal(withKey: ckfs, keyFromConvenience: fromConvenience) { [weak self] result, model, error in


            if result == .success, let model {
                self?.addOrUpdateUnlocked(model: model)
            } else if result == .error, let error {
                if !suppressErrorMessaging {
                    self?.displayUnlockingErrorMessage(error: error, eagerVc: eagerVc)
                }
            }

            if let completion {
                completion(result, model, error)
            }
        }
    }

    func displayUnlockingErrorMessage(error: Error, eagerVc _: NSViewController?) {
        DispatchQueue.main.async {
            let vc = DatabasesCollection.getDbManagerPanelVc()

            MacAlerts.error(NSLocalizedString("open_sequence_problem_opening_title", comment: "There was a problem opening the database."),
                            error: error,
                            window: vc.view.window) {}
        }
    }

    

    func getMostAppropriateViewControllerForInteraction(uuid: String) -> NSViewController {
        if let doc = documentForDatabase(uuid: uuid),
           let vc = doc.windowControllers.first?.contentViewController,
           vc.view.window != nil
        {
            return vc
        } else {
            return DatabasesCollection.getDbManagerPanelVc()
        }
    }

    

    @objc public func updateAndQueueSync(uuid: String, allowInteractiveSync: Bool = false) -> Bool {
        guard let model = getUnlocked(uuid: uuid) else {
            swlog("🔴 Couldn't find this database unlocked to update")
            return false
        }

        let updateId = UUID()

        model.metadata.asyncUpdateId = updateId

        return model.asyncUpdate { result in
            self.onAsyncUpdateDone(result: result, updateId: updateId, model: model, allowInteractiveSync: allowInteractiveSync) 
        }
    }

    func onUserCancelledDuringUpdate(model: Model) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: model.databaseUuid)

        MacAlerts.info(NSLocalizedString("error_could_not_save_message", comment: "Your changes could not be safely saved. You are now working on an in-memory version only of your database. We recommend you try to save again"), window: vc.view.window)
    }

    func onErrorDuringUpdate(model: Model, error: Error?) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: model.databaseUuid)

        if let error {
            MacAlerts.error(NSLocalizedString("error_could_not_save_title", comment: "Error Saving\nWe recommend you try to save again"), error: error, window: vc.view.window)
        } else {
            MacAlerts.info(NSLocalizedString("error_could_not_save_message", comment: "Your changes could not be safely saved. You are now working on an in-memory version only of your database. We recommend you try to save again"), window: vc.view.window)
        }
    }

    func onUpdateSucceeded(_ model: Model, _ allowInteractiveSync: Bool) {


        if !model.isInOfflineMode {
            sync(uuid: model.databaseUuid, allowInteractive: allowInteractiveSync, ckfsForConflict: model.ckfs)
        } else {
            
            
        }
    }

    func onAsyncUpdateDone(result: AsyncJobResult, updateId: UUID, model: Model, allowInteractiveSync: Bool) {
        swlog("Async Update [%@] Done with [%@]", String(describing: updateId), String(describing: result.success))

        if model.metadata.asyncUpdateId == updateId {
            model.metadata.asyncUpdateId = nil

            if result.success {
                onUpdateSucceeded(model, allowInteractiveSync)
            } else {
                if result.userCancelled {
                    onUserCancelledDuringUpdate(model: model)
                } else {
                    onErrorDuringUpdate(model: model, error: result.error)
                }
            }
        } else {
            swlog("Not clearing asyncUpdateID as another has been queued... [%@]", String(describing: model.metadata.asyncUpdateId))
        }

        notifyUpdatesDatabasesList()
    }

    

    @objc public func sync(uuid: String, allowInteractive: Bool = false, suppressErrorAlerts: Bool = false, ckfsForConflict: CompositeKeyFactors? = nil, completion: SyncAndMergeCompletionBlock? = nil) {
        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            swlog("🔴 No such database to sync")
            completion?(.error, false, Utils.createNSError("🔴 No such database to sync", errorCode: -1234))
            return
        }

        guard !prefs.alwaysOpenOffline else { 
            swlog("🔴 Database is in Offline Mode - Cannot Sync!")

            completion?(.error, false, Utils.createNSError("🔴 Database is in Offline Mode - Cannot Sync!", errorCode: -1234))
            return
        }

        let model = getUnlocked(uuid: uuid)

        if let model {
            if model.isInOfflineMode {
                swlog("🔴 Database is in Offline Mode - Cannot Sync!")
                completion?(.error, false, Utils.createNSError("🔴 Database is in Offline Mode - Cannot Sync!", errorCode: -1234))
                return
            }

            if let document = documentForDatabase(uuid: uuid), document.hasUnautosavedChanges || document.isDocumentEdited {
                swlog("🔴 Cannot Sync while Document Open with Changes/Edits")
                completion?(.error, false, Utils.createNSError("🔴 Cannot Sync while Document Open with Changes/Edits", errorCode: -1234))
                return
            }
        }

        
        

        let ckfs = ckfsForConflict ?? model?.ckfs 

        MacSyncManager.sharedInstance().backgroundSyncDatabase(prefs, key: ckfs) { [weak self] result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, metadata: prefs, localWasChanged: localWasChanged, error: error, allowInteractive: allowInteractive, wasInteractive: false, suppressErrorAlerts: suppressErrorAlerts, ckfsForConflict: ckfs, completion: completion)
            }
        }
    }

    func interactiveSync(metadata: MacDatabasePreferences, ckfs: CompositeKeyFactors, suppressErrorAlerts: Bool, interactiveVc: NSViewController, completion: SyncAndMergeCompletionBlock?) {
        MacSyncManager.sharedInstance().sync(metadata, interactiveVC: interactiveVc, key: ckfs, join: false) { result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, metadata: metadata, localWasChanged: localWasChanged, error: error, allowInteractive: true, wasInteractive: true, suppressErrorAlerts: suppressErrorAlerts, ckfsForConflict: ckfs, completion: completion)
            }
        }
    }

    func onSyncCompleted(result: SyncAndMergeResult, metadata: MacDatabasePreferences, localWasChanged: Bool, error: Error?, allowInteractive: Bool, wasInteractive: Bool, suppressErrorAlerts: Bool, ckfsForConflict: CompositeKeyFactors?, completion: SyncAndMergeCompletionBlock?) {
        if result == .success {
            onSyncSuccess(uuid: metadata.uuid, localWasChanged: localWasChanged, allowInteractive: allowInteractive, completion: completion)
        } else if result == .error {
            onSyncError(metadata: metadata, error: error, allowInteractive: allowInteractive, wasInteractive: wasInteractive, suppressErrorAlerts: suppressErrorAlerts, completion: completion)
        } else if result == .userPostponedSync {
            onSyncUserPostponed(completion: completion)
        } else if result == .resultUserCancelled {
            onSyncUserCancelled(completion: completion)
        } else if result == .resultUserInteractionRequired {
            onSyncUserInteractionRequired(metadata: metadata, allowInteractive: allowInteractive, suppressErrorAlerts: suppressErrorAlerts, wasInteractive: wasInteractive, ckfsForConflict: ckfsForConflict, completion: completion)
        } else {
            swlog("🔴 Unknown or expected Sync Result!")
        }
    }

    func onSyncUserCancelled(completion: SyncAndMergeCompletionBlock?) {
        swlog("DatabasesCollection::onSyncUserCancelled")

        if let completion {
            completion(.resultUserCancelled, false, nil)
        }
    }

    func onSyncUserPostponed(completion: SyncAndMergeCompletionBlock?) {
        swlog("DatabasesCollection::onSyncUserPostponed")

        
        
        

        if let completion {
            completion(.userPostponedSync, false, nil)
        }
    }

    func onSyncUserInteractionRequired(metadata: MacDatabasePreferences, allowInteractive: Bool, suppressErrorAlerts: Bool, wasInteractive: Bool, ckfsForConflict: CompositeKeyFactors?, completion: SyncAndMergeCompletionBlock?) {
        swlog("DatabasesCollection::onSyncUserInteractionRequired")

        if wasInteractive {
            swlog("🔴 Something very wrong - User interaction required after an interactive sync? SANITY")
            if let completion {
                completion(.error, false, Utils.createNSError("Something very wrong - User interaction required after an interactive sync? SANITY", errorCode: -1))
            }

            return
        }

        if allowInteractive {
            let vc = getMostAppropriateViewControllerForInteraction(uuid: metadata.uuid)

            if let ckfsForConflict { 
                interactiveSync(metadata: metadata, ckfs: ckfsForConflict, suppressErrorAlerts: suppressErrorAlerts, interactiveVc: vc, completion: completion)
            } else if let model = getUnlocked(uuid: metadata.uuid) { 
                interactiveSync(metadata: metadata, ckfs: model.ckfs, suppressErrorAlerts: suppressErrorAlerts, interactiveVc: vc, completion: completion)
            } else {
                

                swlog("⚠️ Interactive Sync Required and Allowed but no unlocked database or ckfs passed for interactive Sync")
                if let completion {
                    completion(.resultUserInteractionRequired, false, nil)
                }
            }
        } else {
            swlog("Background Sync Done => User Interaction is Required but interactive sync not allowed")

            if let completion {
                completion(.resultUserInteractionRequired, false, nil)
            }
        }
    }

    func onSyncError(metadata: MacDatabasePreferences, error: Error?, allowInteractive: Bool, wasInteractive _: Bool, suppressErrorAlerts: Bool, completion: SyncAndMergeCompletionBlock?) {
        swlog("🔴 DatabasesCollection::onSyncError - Error Occurred => [%@]", String(describing: error))

        if let error {
            if allowInteractive, !suppressErrorAlerts {
                showSyncErrorAlertWithOptions(metadata: metadata, error: error)
            } else {
                
            }
        } else {
            swlog("🔴 Sync returned error status but no Error - Something very wrong")
        }

        if let completion {
            completion(.error, false, error)
        }
    }

    fileprivate func showSyncErrorAlertWithOptions(metadata: MacDatabasePreferences, error: Error) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: metadata.uuid)

        let fmt = NSLocalizedString("sync_error_message_including_error_detail_fmt", comment: "Your database is safely saved but there was an error syncing. Would you like to try again or take a look at the Sync Log?\n\n%@\n")

        let message = String(format: fmt, error.localizedDescription)

        MacAlerts.twoOptions(withCancel: NSLocalizedString("open_sequence_storage_provider_error_title", comment: "Sync Error"),
                             informativeText: message,
                             option1AndDefault: NSLocalizedString("sync_status_error_updating_try_again_action", comment: "Try Again"),
                             option2: NSLocalizedString("safes_vc_action_view_sync_status", comment: "View Sync Log"),
                             window: vc.view.window,
                             completion: { [weak self] response in
                                 if response == 0 {
                                     NSApplication.shared.sendAction(#selector(NSDocument.save(_:)), to: nil, from: self)
                                 } else if response == 1 {
                                     self?.showSyncLog(metadata: metadata, interactiveVc: vc)
                                 }
                             })
    }

    func showSyncLog(metadata: MacDatabasePreferences, interactiveVc: NSViewController) {
        let vc = SyncLogViewController.show(forDatabase: metadata)
        interactiveVc.presentAsSheet(vc)
    }

    func onSyncSuccess(uuid: String, localWasChanged: Bool, allowInteractive: Bool, completion: SyncAndMergeCompletionBlock?) {


        if localWasChanged, let existing = getUnlocked(uuid: uuid) {


            
            

            existing.reloadDatabase(fromLocalWorkingCopy: {
                let vc = self.getMostAppropriateViewControllerForInteraction(uuid: uuid)
                return vc
            }, noProgressSpinner: !allowInteractive) { [weak self] success in
                if success {
                    
                    

                    swlog("✅ Successfully reloaded Model after Sync found changes")
                } else {
                    

                    swlog("🔴 Could not Unlock updated database after Sync. Key changed?! - Force Locking.")
                    self?.forceLock(uuid: uuid)
                }
            }
        }

        if let completion {
            completion(.success, localWasChanged, nil)
        }
    }

    func notifyUpdatesDatabasesList() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .databasesListViewForceRefresh, object: nil)
        }
    }

    func notifyViewsToRefresh(uuid: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .genericRefreshAllDatabaseViews, object: uuid)
        }
    }

    @objc public func reloadFromWorkingCopy(_ uuid: String, dispatchSyncAfterwards: Bool, completion: (() -> Void)? = nil) { 
        if let existing = getUnlocked(uuid: uuid) {
            existing.reloadDatabase(fromLocalWorkingCopy: {
                let vc = self.getMostAppropriateViewControllerForInteraction(uuid: uuid)
                return vc
            }, noProgressSpinner: true) { [weak self] success in
                if success {
                    
                    

                    swlog("✅ Successfully reloaded Model after explicit reload request")

                    if dispatchSyncAfterwards {
                        self?.sync(uuid: uuid, allowInteractive: false, suppressErrorAlerts: true) { _, _, _ in
                            completion?()
                        }
                    } else {
                        completion?()
                    }
                } else {
                    

                    swlog("🔴 Could not Unlock updated database after explicit reload request. Key changed?! - Force Locking.")
                    self?.forceLock(uuid: uuid)
                    completion?()
                }
            }
        } else {
            if dispatchSyncAfterwards { 
                sync(uuid: uuid, allowInteractive: false, suppressErrorAlerts: true) { _, _, _ in
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }

    @objc public func getUnlockedDatabases() -> [Model] {
        unlockedCollection.allValues
    }
}
