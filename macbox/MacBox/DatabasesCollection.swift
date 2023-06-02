//
//  DatabasesCollection.swift
//  MacBox
//
//  Created by Strongbox on 02/11/2022.
//  Copyright © 2022 Mark McGuill. All rights reserved.
//

import Cocoa


extension Notification.Name {
    enum DatabasesCollection {
        static let lockStateChanged = Notification.Name("DatabasesCollectionLockStateChangedNotification")
        static let autoLockAppInBackgroundTimeout = Notification.Name("autoLockAppInBackgroundTimeout")
    }
}

class DatabasesCollection: NSObject {
    @objc static let shared = DatabasesCollection()
    
    var unlockedCollection : ConcurrentMutableDictionary<NSString, Model> = ConcurrentMutableDictionary<NSString, Model>()
    var pollingInProgressSetC : ConcurrentMutableSet<NSString> = ConcurrentMutableSet()
    var pollingTimersC : ConcurrentMutableDictionary<NSString, Timer> = ConcurrentMutableDictionary<NSString, Timer>() 
    
    var idleTimer : Timer? = nil
    
    private override init() {
        super.init()
        
        listenToSafariAutoFillWormhole()
        listenToEvents()
        watchForIdle()
    }
    
    
    
    private func listenToSafariAutoFillWormhole () {
        SafariAutoFillWormhole.sharedInstance()?.listenToAutoFillWormhole()
    }
    
    private func listenToEvents () {
        listenToScreenLockEvents()
        
        NotificationCenter.default.addObserver(forName: .preferencesChanged, object: nil, queue: nil) { [weak self] _ in
            guard let self = self else { return }
            
            self.onPreferencesChanged()
        }
        
        NotificationCenter.default.addObserver(forName: .DatabasesCollection.autoLockAppInBackgroundTimeout, object: nil, queue: nil) { [weak self] _ in
            NSLog("🐞 DEBUG - DatabasesCollection - Received AutoLockInBackgroundTimeout notification - Attempting Lock")
            self?.onAutoLockTimeout( background: true )
        }
    }
    
    private func watchForIdle () {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [weak self] timer in
            let interval = self?.getSystemIdleInterval()
            let timeout = Settings.sharedInstance().autoLockTimeoutSeconds
            
            
            
            if let interval, timeout > 0, Int(interval) > timeout {
                self?.onAutoLockTimeout()
            }
        })
    }
    
    func listenToScreenLockEvents () {
        
        
        
        
        
        
        
        
        let notificationName = String ( format: "%@.%@", "com.apple", "screenIsLocked")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name(rawValue: notificationName), object: nil)
        
        let notificationName2 = String ( format: "%@.%@", "com.apple", "sessionDidMoveOffConsole") 
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onScreenLocked), name: NSNotification.Name(rawValue: notificationName2), object: nil)
        
        
        
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onSleep), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        
        
        
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter .addObserver(self, selector: #selector(onWake(_:)), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        
        let notificationName3 = String ( format: "%@.%@", "com.apple", "screenIsUnlocked")
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(onWake(_:)), name: NSNotification.Name(rawValue: notificationName3), object: nil)
    }
    
    func onAutoLockTimeout( background : Bool = false ) {
        NSLog("🐞 onAutoLockTimeout: Maybe Locking Databases... [Background = %hhd]", background );
        
        tryToLockAll()
    }
    
    @objc func onScreenLocked() {
        NSLog("onScreenLocked...");
        
        if ( Settings.sharedInstance().lockDatabasesOnScreenLock ) {
            tryToLockAll()
        }
        
        stopAllPollingTimers()
    }
    
    @objc func onSleep () {
        NSLog("onSleep: Stopping Polling...");
        
        stopAllPollingTimers()
    }
    
    @objc func onWake( _ notification : NSNotification ) {
        NSLog("onWake: Restarting Polling... %@", notification);
        
        restartPollingTimers()
    }
    
    func getSystemIdleInterval () -> TimeInterval {
        var lastEvent:CFTimeInterval = 0
        
        lastEvent = CGEventSource.secondsSinceLastEventType(CGEventSourceStateID.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        
        return lastEvent
    }
    
    
    
    func notifyLockStateChanged( uuid: String ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .DatabasesCollection.lockStateChanged, object: uuid)
        }
    }
    
    func addOrUpdateUnlocked ( model : Model ) {
        let existing = getUnlocked (uuid: model.databaseUuid )
        
        if let existing, model == existing {
            NSLog("🔴 This database is already unlocked Will not add again");
            return
        }
        
        unlockedCollection.setObject(model, forKey: model.databaseUuid as NSString)
        
        if existing == nil {
            startPollForRemoteChangesTimer ( uuid : model.databaseUuid )
        }
        
        NSLog("✅ unlocked database [%@] added to collection...", model.metadata.nickName)
        
        notifyLockStateChanged( uuid : model.databaseUuid)
    }
    
    @objc public func isDocumentWindowOpen ( uuid : String ) -> Bool {
        return documentForDatabase(uuid: uuid) != nil
    }
    
    @objc public func documentForDatabase ( uuid: String ) -> Document? {
        guard let dc = DocumentController.shared as? DocumentController else {
            NSLog("🔴 Couldn't get shared document controller")
            return nil
        }
        
        return dc.document(forDatabase: uuid)
    }
    
    @objc public func documentIsOpenWithPendingChanges ( uuid : String ) -> Bool {
        guard let doc = documentForDatabase(uuid: uuid) else {
            return false
        }
        
        return doc.hasUnautosavedChanges || doc.isDocumentEdited
    }
    
    @objc public func closeAnyDocumentWindows ( uuid : String ) {
        if ( isUnlocked(uuid: uuid )) {
            NSLog("🔴 This database is unlocked. Cannot close! NOP");
            return
        }
        
        if let doc = documentForDatabase(uuid: uuid) {
            doc.close()
        }
    }
    
    static func getDbManagerPanelVc () -> NSViewController {
        
        
        
        NSApp.activate(ignoringOtherApps: true)
        NSApp.arrangeInFront(nil);
        
        DBManagerPanel.sharedInstance.show()
        
        
        
        let ret = DBManagerPanel.sharedInstance.contentViewController!
        
        NSLog("🐞 XXXX DEBUG: getDbManagerPanelVc => returning %@", ret);
        
        return ret
    }
    
    public func initiateDatabaseUnlock ( uuid : String, message : String? = nil, completion : (( _ : Bool ) -> Void)? = nil ) {
        if ( isUnlocked(uuid: uuid )) {
            NSLog("🔴 This database was already unlocked! NOP");
            DispatchQueue.global().async {
                completion?(true)
            }
            return
        }
        
        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            NSLog("🔴 No such database");
            DispatchQueue.global().async {
                completion?(false)
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            let determiner = MacCompositeKeyDeterminer(database: prefs,
                                                       isNativeAutoFillAppExtensionOpen: false,
                                                       isAutoFillQuickTypeOpen: false,
                                                       onDemandUiProvider: DatabasesCollection.getDbManagerPanelVc)
            

            
            determiner.createWindowForManualCredentialsEntry = false; 

            
            
            
            let appDelegate = NSApplication.shared.delegate as! AppDelegate
            appDelegate.cancelAutoLockInBackgroundTimer()

            determiner.getCkfs ( message ) { [weak self] result, ckfs, fromConvenience, error in
                if let ckfs, result == .success {
                    if !NSApplication.shared.isActive {
                        
                        
                        
                        appDelegate.startAutoLockForAppInBackgroundTimer()
                    }

                    self?.unlockModelFromLocalWorkingCopy(database: prefs, ckfs: ckfs, fromConvenience: fromConvenience) { result, model, error in
                        DispatchQueue.global().async {
                            completion?(result == .success)
                        }
                    }
                    
                    
                }
                else if result == .error, let error {
                    self?.displayUnlockingErrorMessage(error: error, eagerVc: nil)
                    DispatchQueue.global().async {
                        completion?(false)
                    }
                }
                else {
                    DispatchQueue.global().async {
                        completion?(false)
                    }
                }
            }
        }
    }
    
    @objc public func initiateLockRequest ( uuid : String ) {
        if ( !isUnlocked(uuid: uuid )) {
            NSLog("🔴 This database was not in the unlocked collection! NOP");
            return
        }
        
        if let doc = documentForDatabase(uuid: uuid) {
            DispatchQueue.main.async {
                doc.initiateLockSequence()
            }
        }
        else {
            forceLock(uuid: uuid)
        }
    }
    
    @objc public func tryToLockAll () {
        let keys = unlockedCollection.allKeys
        
        for uuid in keys {
            initiateLockRequest(uuid: uuid as String)
        }
    }
    
    @objc func forceLock ( uuid : String ) {
        unlockedCollection.removeObject(forKey: uuid as NSString)
        stopPollForRemoteChangesTimer(uuid: uuid)
        NSLog("✅ unlocked database [%@] removed from collection...", uuid)
        
        notifyLockStateChanged( uuid : uuid )
    }
    
    @objc public func isUnlocked ( uuid : String) -> Bool {
        let ret = getUnlocked(uuid: uuid) != nil
        
        
        
        return ret
    }
    
    @objc public func getUnlocked ( uuid : String ) -> Model? {
        let ret = unlockedCollection.object(forKey: uuid as NSString)
        
        
        
        return ret
    }
    
    
    
    func onPreferencesChanged() {
        NSLog("DatabasesCollection::onPreferencesChanged() notification received")
        
        
        
        restartPollingTimers()
    }
    
    
    
    func stopAllPollingTimers ( ) {
        NSLog("Stop all Polling Timers...")
        
        let keys = pollingTimersC.allKeys
        keys.forEach { key in
            if let timer = pollingTimersC.object(forKey: key) {
                timer.invalidate()
            }
            pollingTimersC.removeObject(forKey: key)
        }
    }
    
    func restartPollingTimers () {
        NSLog("Restart Polling Timers...")
        
        stopAllPollingTimers()
        
        for uuid in unlockedCollection.allKeys {
            startPollForRemoteChangesTimer(uuid: uuid as String)
        }
    }
    
    private func startPollForRemoteChangesTimer ( uuid : String ) {
        NSLog("startPollForRemoteChangesTimer")
        
        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            NSLog("🔴 No such database");
            return
        }
        
        if pollingTimersC.object(forKey: uuid as NSString) != nil {
            NSLog("🔴 Already a timer in place");
            return
        }
        
        if let model = getUnlocked(uuid: uuid), model.metadata.monitorForExternalChanges, !model.isInOfflineMode {
            let nTimer = Timer.scheduledTimer(withTimeInterval:TimeInterval( prefs.monitorForExternalChangesInterval) , repeats: true) { [weak self] timer in
                self?.pollForDatabaseRemoteChanges( uuid : uuid )
            }
            
            pollingTimersC.setObject(nTimer, forKey: uuid as NSString)
        }
        else {
            NSLog("Not monitoring database external changes because OfflineMode or configured Off.")
        }
    }
    
    private func stopPollForRemoteChangesTimer ( uuid : String ) {
        NSLog("stopPollForRemoteChangesTimer")
        
        if let timer = pollingTimersC.object(forKey: uuid as NSString) {
            timer.invalidate()
            pollingTimersC.removeObject(forKey: uuid as NSString)
        }
    }
    
    private func pollForDatabaseRemoteChanges ( uuid : String ) {

        
        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            NSLog("🔴 No such database");
            return
        }
        
        if pollingInProgressSetC.contains(uuid as NSString) {
            NSLog("pollForDatabaseRemoteChanges - pollingInProgress - Will not queue up another Poll.");
            return
        }
        
        pollingInProgressSetC.add(uuid as NSString)
        MacSyncManager.sharedInstance().poll(forChanges: prefs) { [weak self] result, changesPresent, error in
            self?.pollingInProgressSetC.remove(uuid as NSString)
            
            if let error {
                NSLog("🔴 error polling: [%@]", String(describing: error))
            }
            
            if result == .success && changesPresent {
                NSLog("pollForDatabaseRemoteChanges - Changes Found");
                
                self?.onDatabaseRemoteChanged(uuid: uuid)
            }
        }
    }
    
    func onDatabaseRemoteChanged ( uuid : String ) {
        if isUnlocked(uuid: uuid) {
            
            
            if let document = documentForDatabase(uuid: uuid ) {
                document.onDatabaseChangedByExternalOther()
            }
            else { 
                sync(uuid: uuid, allowInteractive: false)
            }
        }
        else {
            NSLog("⚠️ Got change notification for locked database? Shouldn't be possible. Stopping Timer")
            stopPollForRemoteChangesTimer(uuid: uuid)
        }
    }
    
    
    
    @objc public func unlockModelFromLocalWorkingCopy ( database : MacDatabasePreferences,
                                                        ckfs : CompositeKeyFactors,
                                                        fromConvenience : Bool,
                                                        alertOnJustPwdWrong : Bool = true,
                                                        offlineUnlockRequested : Bool = false,
                                                        showProgressSpinner : Bool = false,
                                                        eagerVc : NSViewController? = nil,
                                                        suppressErrorMessaging : Bool = false,
                                                        forceReadOnly : Bool = false,
                                                        completion: UnlockDatabaseCompletionBlock? = nil ) {
        NSLog("✅ unlockModelFromLocalWorkingCopy - %@", database.uuid)
                
        let openOffline = database.alwaysOpenOffline || offlineUnlockRequested;
        
        let unlocker = DatabaseUnlocker(forDatabase: database,
                                        forceReadOnly: forceReadOnly,
                                        isNativeAutoFillAppExtensionOpen: false,
                                        offlineMode: openOffline) {
            if let eagerVc {
                NSLog("On Demand UI requested by DatabaseUnlocker - returning eagerly provided VC")
                return eagerVc
            }
            else {
                NSLog("On Demand UI requested by DatabaseUnlocker - returning background VC")
                return DatabasesCollection.getDbManagerPanelVc()
            }
        }

        unlocker.alertOnJustPwdWrong = alertOnJustPwdWrong;
        unlocker.noProgressSpinner = !showProgressSpinner;
        
        unlocker.unlockLocal(withKey: ckfs, keyFromConvenience: fromConvenience) { [weak self] result, model, error in
            NSLog("✅ Unlocked Local with %@, %@, %@", String (describing: result), String (describing: model), String (describing: error))
            
            if result == .success, let model {
                self?.addOrUpdateUnlocked(model: model)
            }
            else if result == .error, let error {
                if !suppressErrorMessaging {
                    self?.displayUnlockingErrorMessage( error: error, eagerVc: eagerVc )
                }
            }
            
            if let completion {
                completion(result, model, error)
            }
        }
    }
    
    func displayUnlockingErrorMessage ( error : Error, eagerVc : NSViewController?  ) {
        DispatchQueue.main.async {
            let vc = DatabasesCollection.getDbManagerPanelVc()
            
            MacAlerts.error(NSLocalizedString("open_sequence_problem_opening_title", comment: "There was a problem opening the database."),
                            error: error,
                            window: vc.view.window) { }
        }
    }
    
    

    func getMostAppropriateViewControllerForInteraction( uuid : String ) -> NSViewController {
        if let doc = documentForDatabase(uuid: uuid ),
           let vc = doc.windowControllers.first?.contentViewController,
           vc.view.window != nil {
            return vc
        }
        else {
            return DatabasesCollection.getDbManagerPanelVc()
        }
    }
    
    
    
    @objc public func updateAndQueueSync ( uuid : String, allowInteractiveSync : Bool = false ) -> Bool {
        guard let model = getUnlocked(uuid: uuid) else {
            NSLog("🔴 Couldn't find this database unlocked to update")
            return false
        }
        
        let updateId = UUID()
        NSLog("DatabasesCollection::updateAndQueueSync start [%@]", String(describing: uuid));
        model.metadata.asyncUpdateId = updateId
        
        return model.asyncUpdate { result in
            self.onAsyncUpdateDone(result: result, updateId: updateId, model: model, allowInteractiveSync: allowInteractiveSync) 
        }
    }
    
    func onUserCancelledDuringUpdate (model : Model) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: model.databaseUuid)
        
        MacAlerts.info(NSLocalizedString("error_could_not_save_message", comment: "Your changes could not be safely saved. You are now working on an in-memory version only of your database. We recommend you try to save again"), window: vc.view.window )
    }

    func onErrorDuringUpdate (model : Model, error : Error? ) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: model.databaseUuid)
        
        if let error {
            MacAlerts.error( NSLocalizedString("error_could_not_save_title", comment: "Error Saving\nWe recommend you try to save again"), error: error, window: vc.view.window)
        }
        else {
            MacAlerts.info(NSLocalizedString("error_could_not_save_message", comment: "Your changes could not be safely saved. You are now working on an in-memory version only of your database. We recommend you try to save again"), window: vc.view.window )
        }
    }

    func onUpdateSucceeded(_ model: Model, _ allowInteractiveSync: Bool) {
        NSLog("DatabasesCollection::onUpdateSucceeded")
        
        if !model.isInOfflineMode {
            sync(uuid: model.databaseUuid, allowInteractive: allowInteractiveSync )
        }
        else {
            
            
        }
    }
    
    func onAsyncUpdateDone ( result : AsyncUpdateResult, updateId : UUID, model : Model, allowInteractiveSync : Bool ) {
        NSLog("Async Update [%@] Done with [%@]", String(describing: updateId), String(describing: result.success));
                
        if model.metadata.asyncUpdateId == updateId {
            model.metadata.asyncUpdateId = nil;
            
            if result.success {
                onUpdateSucceeded(model, allowInteractiveSync)
            }
            else {
                if result.userCancelled {
                    onUserCancelledDuringUpdate(model : model )
                }
                else {
                    onErrorDuringUpdate(model : model, error : result.error )
                }
            }
        }
        else {
            NSLog("Not clearing asyncUpdateID as another has been queued... [%@]", String(describing: model.metadata.asyncUpdateId));
        }
    
        notifyUpdatesDatabasesList();
    }
 
    
    
    @objc public func sync( uuid : String, allowInteractive : Bool = false, suppressErrorAlerts : Bool = false, ckfsForConflict : CompositeKeyFactors? = nil, completion : SyncAndMergeCompletionBlock? = nil ) {
        NSLog("DatabasesCollection::sync")
        
        
        
        guard let prefs = MacDatabasePreferences.getById(uuid) else {
            NSLog("🔴 No such database to sync");
            return
        }

        guard !prefs.alwaysOpenOffline else { 
            NSLog("🔴 Database is in Offline Mode - Cannot Sync!");
            return
        }

        if let model = getUnlocked(uuid: uuid) {
            if model.isInOfflineMode {
                NSLog("🔴 Database is in Offline Mode - Cannot Sync!");
                return
            }
            
            if let document = documentForDatabase(uuid: uuid), (document.hasUnautosavedChanges || document.isDocumentEdited) {
                NSLog("🔴 Cannot Sync while Document Open with Changes/Edits");
                return
            }
        }
        
        MacSyncManager.sharedInstance().backgroundSyncDatabase(prefs) { [weak self] result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, metadata: prefs, localWasChanged: localWasChanged, error: error, allowInteractive: allowInteractive, wasInteractive: false, suppressErrorAlerts: suppressErrorAlerts, ckfsForConflict: ckfsForConflict, completion: completion )
            }
        }
    }
    
    func interactiveSync ( metadata : MacDatabasePreferences, ckfs : CompositeKeyFactors, suppressErrorAlerts : Bool, interactiveVc : NSViewController, completion : SyncAndMergeCompletionBlock? ) {
        MacSyncManager.sharedInstance().sync(metadata, interactiveVC: interactiveVc, key: ckfs, join: false) { result, localWasChanged, error in
            DispatchQueue.main.async { [weak self] in
                self?.onSyncCompleted(result: result, metadata: metadata, localWasChanged: localWasChanged, error: error, allowInteractive: true, wasInteractive: true, suppressErrorAlerts: suppressErrorAlerts, ckfsForConflict: ckfs, completion: completion )
            }
        }
    }

    func onSyncCompleted ( result : SyncAndMergeResult, metadata : MacDatabasePreferences, localWasChanged : Bool, error : Error?, allowInteractive : Bool, wasInteractive : Bool, suppressErrorAlerts : Bool, ckfsForConflict : CompositeKeyFactors?, completion : SyncAndMergeCompletionBlock? ) {
        if result == .success {
            onSyncSuccess(uuid: metadata.uuid, localWasChanged: localWasChanged, allowInteractive: allowInteractive, completion: completion)
        }
        else if result == .error {
            onSyncError(metadata: metadata, error: error, allowInteractive: allowInteractive, wasInteractive: wasInteractive, suppressErrorAlerts: suppressErrorAlerts, completion: completion )
        }
        else if result == .userPostponedSync {
            onSyncUserPostponed(completion: completion)
        }
        else if result == .resultUserCancelled {
            onSyncUserCancelled(completion: completion)
        }
        else if result == .resultUserInteractionRequired {
            onSyncUserInteractionRequired(metadata: metadata, allowInteractive: allowInteractive, suppressErrorAlerts: suppressErrorAlerts, wasInteractive: wasInteractive, ckfsForConflict: ckfsForConflict, completion: completion)
        }
        else {
            NSLog("🔴 Unknown or expected Sync Result!")
        }
    }
    
    func onSyncUserCancelled (completion : SyncAndMergeCompletionBlock?) {
        NSLog("DatabasesCollection::onSyncUserCancelled")
        
        if let completion {
            completion(.resultUserCancelled, false, nil)
        }
    }
    
    func onSyncUserPostponed (completion : SyncAndMergeCompletionBlock?) {
        NSLog("DatabasesCollection::onSyncUserPostponed")
        
        
        
        
        
        if let completion {
            completion(.userPostponedSync, false, nil)
        }
    }
    
    func onSyncUserInteractionRequired ( metadata : MacDatabasePreferences, allowInteractive : Bool, suppressErrorAlerts : Bool, wasInteractive : Bool, ckfsForConflict : CompositeKeyFactors?, completion : SyncAndMergeCompletionBlock? ) {
        NSLog("DatabasesCollection::onSyncUserInteractionRequired")
        
        if wasInteractive {
            NSLog("🔴 Something very wrong - User interaction required after an interactive sync? SANITY");
            if let completion {
                completion(.error, false, Utils.createNSError("Something very wrong - User interaction required after an interactive sync? SANITY", errorCode: -1))
            }
            
            return
        }
        
        if allowInteractive {
            let vc = getMostAppropriateViewControllerForInteraction(uuid: metadata.uuid)
            
            if let ckfsForConflict { 
                interactiveSync( metadata: metadata, ckfs: ckfsForConflict, suppressErrorAlerts: suppressErrorAlerts, interactiveVc: vc, completion: completion  )
            }
            else if let model = getUnlocked(uuid: metadata.uuid ) { 
                interactiveSync( metadata: metadata, ckfs: model.ckfs, suppressErrorAlerts: suppressErrorAlerts, interactiveVc: vc, completion: completion  )
            }
            else {
                
                
                NSLog("⚠️ Interactive Sync Required and Allowed but no unlocked database or ckfs passed for interactive Sync")
                if let completion {
                    completion(.resultUserInteractionRequired, false, nil)
                }
            }
        }
        else {
            NSLog("Background Sync Done => User Interaction is Required but interactive sync not allowed");
            
            if let completion {
                completion(.resultUserInteractionRequired, false, nil)
            }
        }
    }
    
    func onSyncError ( metadata : MacDatabasePreferences, error : Error?, allowInteractive : Bool, wasInteractive : Bool, suppressErrorAlerts : Bool, completion : SyncAndMergeCompletionBlock? ) {
        NSLog("🔴 DatabasesCollection::onSyncError - Error Occurred => [%@]", String.init(describing: error))
        
        if let error {
            if allowInteractive, !suppressErrorAlerts {
                showSyncErrorAlertWithOptions(metadata: metadata, error: error)
            }
            else {
                
            }
        }
        else {
            NSLog("🔴 Sync returned error status but no Error - Something very wrong")
        }
        
        if let completion {
            completion(.error, false, error)
        }
    }
    
    fileprivate func showSyncErrorAlertWithOptions(metadata : MacDatabasePreferences, error : Error) {
        let vc = getMostAppropriateViewControllerForInteraction(uuid: metadata.uuid)
        
        let fmt = NSLocalizedString("sync_error_message_including_error_detail_fmt", comment: "Your database is safely saved but there was an error syncing. Would you like to try again or take a look at the Sync Log?\n\n%@\n")
        
        let message = String(format: fmt, error.localizedDescription);
        
        MacAlerts.twoOptions(withCancel: NSLocalizedString("open_sequence_storage_provider_error_title", comment: "Sync Error"),
                             informativeText: message,
                             option1AndDefault: NSLocalizedString("sync_status_error_updating_try_again_action", comment: "Try Again"),
                             option2: NSLocalizedString("safes_vc_action_view_sync_status", comment: "View Sync Log"),
                             window: vc.view.window,
                             completion: { [weak self] response in
            if response == 0 {
                NSApplication.shared.sendAction(#selector(NSDocument.save(_:)), to: nil, from: self)
            }
            else if response == 1 {
                self?.showSyncLog(metadata: metadata, interactiveVc: vc)
            }
        })
    }
    
    func showSyncLog (metadata : MacDatabasePreferences, interactiveVc : NSViewController ) {
        let vc = SyncLogViewController.show(forDatabase: metadata);
        interactiveVc.presentAsSheet(vc)
    }
    
    func onSyncSuccess ( uuid : String, localWasChanged : Bool, allowInteractive : Bool, completion : SyncAndMergeCompletionBlock? ) {
        NSLog("✅ DatabasesCollection::onSyncSuccess => Sync Successfully Completed [localWasChanged = %@]", localizedYesOrNoFromBool(localWasChanged))
        
        if localWasChanged, let existing = getUnlocked(uuid: uuid ) {
            NSLog("DatabasesCollection::onSyncSuccess - database is unlocked - refreshing our unlocked model...");
                   
            
            
        
            existing.reloadDatabase(fromLocalWorkingCopy: {
                let vc = self.getMostAppropriateViewControllerForInteraction(uuid: uuid)
                return vc
            }, noProgressSpinner: !allowInteractive) { [weak self] success in
                if success {
                    
                    
                    
                    NSLog("✅ Successfully reloaded Model after Sync found changes")
                }
                else {
                    
                    
                    NSLog("🔴 Could not Unlock updated database after Sync. Key changed?! - Force Locking.");
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

    func notifyViewsToRefresh( uuid : String ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .genericRefreshAllDatabaseViews, object: uuid)
        }
    }
}
