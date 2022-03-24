//
//  Document.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Document.h"
#import "Utils.h"
#import "MacAlerts.h"
#import "CreateFormatAndSetCredentialsWizard.h"
#import "WindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "NSArray+Extensions.h"
#import "NodeDetailsViewController.h"
#import "BiometricIdHelper.h"
#import "DatabasesManagerVC.h"
#import "AutoFillManager.h"
#import "SampleItemsGenerator.h"
#import "DatabaseModelConfig.h"
#import "Serializator.h"
#import "MacUrlSchemes.h"
#import "MacSyncManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "DatabaseUnlocker.h"
#import "MBProgressHUD.h"
#import "MMWormhole.h"
#import "AutoFillWormhole.h"
#import "QuickTypeRecordIdentifier.h"
#import "OTPToken+Generation.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kModelUpdateNotificationFullReload = @"kModelUpdateNotificationFullReload"; 

@interface Document ()

@property WindowController* windowController;
@property NSTimer* managedDatabasePollForChangesTimer;
@property BOOL pollingInProgress;
@property BOOL isPromptingAboutUnderlyingFileChange;
@property MMWormhole* wormhole;

@end

@implementation Document

- (void)dealloc {
    NSLog(@"=====================================================================");
    NSLog(@"😎 Document DEALLOC...");
    NSLog(@"=====================================================================");
}



+ (BOOL)autosavesInPlace {
    return Settings.sharedInstance.autoSave;
}

- (MacDatabasePreferences *)databaseMetadata {
    if ( self.viewModel ) {
        return self.viewModel.databaseMetadata;
    }
    else if ( self.fileURL ) {
        MacDatabasePreferences* ret = [MacDatabasePreferences fromUrl:self.fileURL];
        
        if ( ret == nil ) {
            NSLog(@"🔴 WARNWARN: NIL MacDatabasePreferences - None Found in Document::databaseMetadata for URL: [%@]", self.fileURL);
            ret = [MacDatabasePreferences addOrGet:self.fileURL]; 
        }
        else {
            NSLog(@"✅ Got metadata for database URL: [%@]", self.fileURL);
        }
        
        return ret;
    }
    else {
        NSLog(@"🔴 WARNWARN: NIL fileUrl in Document::databaseMetadata");
        return nil;
    }
}

- (BOOL)isModelLocked {
    return self.viewModel ? self.viewModel.locked : YES;
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation {
    return YES;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    return YES;
}

- (void)makeWindowControllers {
    NSLog(@"makeWindowControllers -> viewModel = [%@]", self.viewModel);

    if ( ( !Settings.sharedInstance.nextGenUI ) ) {
        NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        
        self.windowController = [storyboard instantiateControllerWithIdentifier:@"Document Window Controller"];
    }
    else {
        self.windowController = [[NSStoryboard storyboardWithName:@"NextGen" bundle:nil] instantiateInitialController];
    }
    
    [self.windowController changeContentView]; 
    
    [self addWindowController:self.windowController];
}




- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"Sync Manager Mode: readFromURL - Loading Locked Model... [%@]", url);
            
    [NSFileCoordinator addFilePresenter:self]; 

    return [self loadLockedModel];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    NSLog(@"readFromFileWrapper");

    if ( fileWrapper.isDirectory ) { 
        if(outError != nil) {
            NSString* loc = NSLocalizedString(@"mac_strongbox_cant_open_file_wrappers", @"Strongbox cannot open File Wrappers, Directories or Compressed Packages like this. Please directly select a KeePass or Password Safe database file.");
            *outError = [Utils createNSError:loc errorCode:-1];
        }
        return NO;
    }
    
    return [super readFromFileWrapper:fileWrapper ofType:typeName error:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"🔴 WARNWARN: Document::readFromData called %ld - [%@]", data.length, typeName);
    return NO;
}




- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
    SEL theAction = [anItem action];


    
    if (theAction == @selector(saveDocument:)) {
        return !self.viewModel.locked && !self.viewModel.isEffectivelyReadOnly;
    }
    
    return [super validateUserInterfaceItem:anItem];
}

- (IBAction)saveDocument:(id)sender {
    NSLog(@"Document::saveDocument");

    if(self.viewModel.locked || self.viewModel.isEffectivelyReadOnly) {
        NSLog(@"🔴 WARNWARN: Document is Read-Only or Locked! How did you get here?");
        return;
    }

    [super saveDocument:sender];
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"✅ saveToURL: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, url);

    [self asyncBackgroundUpdate];

    if (saveOperation != NSSaveToOperation) {
        [self updateChangeCount:NSChangeCleared];
    }
    
    completionHandler(nil);
}

- (void)asyncBackgroundUpdate {
    NSUUID* updateId = NSUUID.UUID;
    NSLog(@"Document::asyncBackgroundUpdate start [%@]", updateId);
    self.viewModel.asyncUpdateId = updateId;
    [self.viewModel asyncUpdateAndSync:^(AsyncUpdateResult * _Nonnull result) {
        [self onAsyncBackgroundUpdateDone:result updateId:updateId]; 
    }];
}

- (void)onAsyncBackgroundUpdateDone:(AsyncUpdateResult*)result updateId:(NSUUID*)updateId {
    NSLog(@"onAsyncBackgroundUpdateDone: [%@] - %@", result, updateId);

    if ( [self.viewModel.asyncUpdateId isEqual:updateId] ) {
        self.viewModel.asyncUpdateId = nil;
        
        
        
        [self onSyncOrUpdateDone:result.userCancelled userInteractionRequired:result.userInteractionRequired localWasChanged:result.localWasChanged update:YES error:result.error];
    }
    else {
        NSLog(@"Not clearing asyncUpdateID as another has been queued... [%@]", self.viewModel.asyncUpdateId);
    }
    
    [self notifyUpdatesDatabasesList];
}

- (void)synchronousForegroundUpdate {
    [self.viewModel update:self.windowController.contentViewController handler:^(BOOL userCancelled, BOOL localWasChanged, NSError * _Nullable error) {
        [self onSyncOrUpdateDone:userCancelled userInteractionRequired:NO localWasChanged:localWasChanged update:YES error:error];
    }];
}



- (void)synchronousForegroundSync {
    NSLog(@"synchronousForegroundSync");

    if ( self.viewModel.offlineMode ) {
        NSLog(@"WARNWARN: performFullInteractiveSync called in Offline Mode!!");
        return;
    }

    [MacSyncManager.sharedInstance sync:self.databaseMetadata
                          interactiveVC:self.windowController.contentViewController
                                    key:self.viewModel.compositeKeyFactors
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        BOOL userInteractionRequired = result == kSyncAndMergeResultUserInteractionRequired;
        BOOL userCancelled = result == kSyncAndMergeResultUserCancelled;
         
        [self onSyncOrUpdateDone:userCancelled userInteractionRequired:userInteractionRequired localWasChanged:localWasChanged update:NO error:error]; 
    }];
}




- (void)close {
    [super close];

    [self unListenForSleepWakeEvents];
    
    [self stopMonitoringManagedFile];
    
    [self cleanupWormhole];
    
    
        
    if (NSDocumentController.sharedDocumentController.documents.count == 0 &&
        Settings.sharedInstance.showDatabasesManagerOnCloseAllWindows &&
        !Settings.sharedInstance.runningAsATrayApp ) {
        [DBManagerPanel.sharedInstance show];
    }
}



- (void)encodeRestorableStateWithCoder:(NSCoder *) coder {

    [coder encodeObject:self.fileURL forKey:@"StrongboxNonFileRestorationStateURL"];
}




- (void)listenForSleepWakeEvents {
    [self unListenForSleepWakeEvents];
    
    NSLog(@"listenForSleepWakeEvents");
    
    
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onSleep)
                                                               name:NSWorkspaceWillSleepNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onSleep)
                                                               name:NSWorkspaceScreensDidSleepNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onSleep)
                                                               name:NSWorkspaceSessionDidResignActiveNotification object:nil];

    NSString* notificationName = [NSString stringWithFormat:@"%@.%@", @"com.apple", @"screenIsLocked"];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(onSleep) name:notificationName object:nil];

    
    
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onWake)
                                                               name:NSWorkspaceDidWakeNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onWake)
                                                               name:NSWorkspaceScreensDidWakeNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(onWake)
                                                               name:NSWorkspaceSessionDidBecomeActiveNotification object:nil];

    NSString* notificationName2 = [NSString stringWithFormat:@"%@.%@", @"com.apple", @"screenIsUnlocked"];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(onWake) name:notificationName2 object:nil];
}

- (void)unListenForSleepWakeEvents {
    NSLog(@"unListenForSleepWakeEvents");
    
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (void)onSleep {
    NSLog(@"XXX - onSleep");
    [self stopMonitoringManagedFile];
}

- (void)onWake {
    [self startMonitoringManagedFile];
}

- (void)startMonitoringManagedFile {
    if ( !self.databaseMetadata ||
        self.viewModel.locked ||
        self.viewModel.offlineMode ||
        !self.databaseMetadata.monitorForExternalChanges ) {
        [self stopMonitoringManagedFile];
        return;
    }
        
    if(self.managedDatabasePollForChangesTimer == nil) {
        NSLog(@"startMonitoringManagedFile - OK");
        
        [self listenForSleepWakeEvents];
        
        self.managedDatabasePollForChangesTimer = [NSTimer timerWithTimeInterval:self.databaseMetadata.monitorForExternalChangesInterval
                                                                          target:self
                                                                        selector:@selector(pollForDatabaseChanges)
                                                                        userInfo:nil
                                                                         repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:self.managedDatabasePollForChangesTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopMonitoringManagedFile {
    NSLog(@"stopMonitoringManagedFile");
    
    if ( self.managedDatabasePollForChangesTimer ) {
        [self.managedDatabasePollForChangesTimer invalidate];
        self.managedDatabasePollForChangesTimer = nil;
    }
}

- (void)pollForDatabaseChanges {
    if ( self.pollingInProgress ) {
        NSLog(@"pollingInProgress - Will not queue up another Poll.");
        return;
    }
    
    if ( !self.databaseMetadata.monitorForExternalChanges || self.viewModel.offlineMode) {
        [self stopMonitoringManagedFile];
        return;
    }

    if ( self.viewModel.offlineMode ) {
        NSLog(@"WARNWARN: pollForDatabaseChanges called in Offline Mode!!");
        return;
    }
    
    [self checkForRemoteChanges];
}

- (void)checkForRemoteChanges {


    self.pollingInProgress = YES;
    [MacSyncManager.sharedInstance pollForChanges:self.databaseMetadata
                                       completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        self.pollingInProgress = NO;
        
        if ( localWasChanged ) {
            NSLog(@"checkForRemoteChanges - Change Found");
            [self onFileChangedByOtherApplication];
        }
    }];
}

- (NSURL *)presentedItemURL {
    if ( ![self.fileURL.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        return [super presentedItemURL];
    }
    else {
        NSURL* foo = fileUrlFromManagedUrl(self.fileURL);
        
        [super presentedItemURL]; 
        
        
        return foo;
    }
}

- (void)presentedItemDidChange {
    NSLog(@"presentedItemDidChange - [%@]", self.fileModificationDate.friendlyDateTimeStringBothPrecise);

    
    
    if( !self.databaseMetadata.monitorForExternalChanges ) {
        return;
    }

    if ( [self.fileURL.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        [self checkForRemoteChanges];
    }
    else {
        if( !self.fileModificationDate ) {
            NSLog(@"presentedItemDidChange but NO self.fileModificationDate?");
            return;
        }
        





    }
}




- (void)notifyFullModelReload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationFullReload
                                                          object:self
                                                        userInfo:@{ }];
    });
}

- (void)notifyUpdatesDatabasesList {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListViewForceRefreshNotification object:nil];
    });
}




- (BOOL)loadLockedModel {
    _viewModel = [[ViewModel alloc] initLocked:self databaseUuid:self.databaseMetadata.uuid];

    WindowController* wc = self.windowController; 
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [wc changeContentView];
    });
    
    return YES;
}

- (void)lock:(NSString*)selectedItem {
    if(self.isDocumentEdited) {
        NSLog(@"Cannot lock document with edits!");
        return;
    }
    
    
    [self.undoManager removeAllActions];
    
    self.wasJustLocked = YES;
    
    [self loadLockedModel];

    [self cleanupWormhole];
    
    self.selectedItem = selectedItem; 
}

- (void)unlock:(CompositeKeyFactors *)compositeKeyFactors
viewController:(NSViewController *)viewController
alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
fromConvenience:(BOOL)fromConvenience
    completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    NSLog(@"Document::unlock: [%@]", self.fileURL);

    if ( !self.databaseMetadata.offlineMode ) {
        NSLog(@"ONLINE MODE: syncWorkingCopyAndUnlock");
        
        [self syncWorkingCopyAndUnlock:viewController
                   alertOnJustPwdWrong:alertOnJustPwdWrong
                       fromConvenience:fromConvenience
                                   key:compositeKeyFactors
                          selectedItem:self.selectedItem
                            completion:completion];
    }
    else {
        NSLog(@"OFFLINE MODE: loadWorkingCopyAndUnlock");

        [self loadWorkingCopyAndUnlock:compositeKeyFactors
                        viewController:viewController
                   alertOnJustPwdWrong:alertOnJustPwdWrong
                       fromConvenience:fromConvenience
                          selectedItem:self.selectedItem
                            completion:completion];
    }
}

- (void)syncWorkingCopyAndUnlock:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    NSLog(@"syncWorkingCopyAndUnlock ENTER");
        
    [MacSyncManager.sharedInstance sync:self.databaseMetadata
                          interactiveVC:viewController
                                    key:key
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            [self loadWorkingCopyAndUnlock:key
                            viewController:viewController
                       alertOnJustPwdWrong:alertOnJustPwdWrong
                           fromConvenience:fromConvenience
                              selectedItem:selectedItem
                                completion:completion];
        }
        else if (result == kSyncAndMergeError ) {
            if(completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, NO, NO, error);
                });
            }
        }
        else if (result == kSyncAndMergeResultUserCancelled ) {
            if(completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, YES, NO, nil);
                });
            }
        }
        else {
            NSLog(@"🔴 WARNWARN: Unhandled Sync Result [%lu] - error = [%@]", (unsigned long)result, error);
            if(completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, NO, NO, error);
                });
            }
        }
    }];
}

- (void)loadWorkingCopyAndUnlock:(CompositeKeyFactors*)key
                  viewController:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    BOOL openOffline = self.databaseMetadata.offlineMode || self.databaseMetadata.alwaysOpenOffline; 

    if ( openOffline != self.databaseMetadata.offlineMode ) {
        self.databaseMetadata.offlineMode = openOffline;
    }

    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.databaseMetadata
                                                        viewController:viewController
                                                         forceReadOnly:NO
                                                        isAutoFillOpen:NO
                                                           offlineMode:openOffline];
    
    unlocker.alertOnJustPwdWrong = alertOnJustPwdWrong;
    
    [unlocker unlockLocalWithKey:key
              keyFromConvenience:fromConvenience
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess ) {
            [self onUnlockDatabaseSuccessful:model];
        }
        else if ( result == kUnlockDatabaseResultError ) {
            [self onUnlockDatabaseError];
        }
        else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
            [self onUnlockDatabaseError];
        }
        else {
            
        }
        
        if(completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError* caolError = error ? error : innerStreamError;
                completion(result == kUnlockDatabaseResultSuccess,
                           result == kUnlockDatabaseResultUserCancelled,
                           result == kUnlockDatabaseResultIncorrectCredentials,
                           caolError);
            });
        }
    }];
}

- (void)onUnlockDatabaseError {
    if ( self.viewModel && !self.viewModel.locked ) {
        _viewModel = [[ViewModel alloc] initLocked:self databaseUuid:self.databaseMetadata.uuid];

        WindowController* wc = self.windowController;

        dispatch_async(dispatch_get_main_queue(), ^{
            [wc changeContentView];
        });

        [self notifyFullModelReload];
    }
    else {
        
    }
}

- (void)onUnlockDatabaseSuccessful:(Model*)model {
    BOOL wasLocked = self.viewModel && self.viewModel.locked;
    
    _viewModel = [[ViewModel alloc] initUnlocked:self databaseUuid:self.databaseMetadata.uuid model:model];
    
    if ( wasLocked ) { 
        WindowController* wc = self.windowController;

        dispatch_async(dispatch_get_main_queue(), ^{
            [wc changeContentView];
        });
    }
    else {
        [self notifyFullModelReload]; 
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
        [self.viewModel restartBackgroundAudit];
    });
    
    
    [NSFileCoordinator addFilePresenter:self];

    [self startMonitoringManagedFile];
    
    [self listenToAutoFillWormhole];
}




- (void)onSyncOrUpdateDone:(BOOL)userCancelled
   userInteractionRequired:(BOOL)userInteractionRequired
           localWasChanged:(BOOL)localWasChanged
                    update:(BOOL)update
                     error:(NSError*)error {
    __weak Document* weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( update ) {
            [weakSelf onUpdateFinished:userInteractionRequired userCancelled:userCancelled localWasChanged:localWasChanged error:error];
        }
        else {
            [weakSelf onSyncFinished:userInteractionRequired userCancelled:userCancelled localWasChanged:localWasChanged error:error];
        }
    });
}



- (void)onUpdateFinished:(BOOL)userInteractionRequired
           userCancelled:(BOOL)userCancelled
         localWasChanged:(BOOL)localWasChanged
                   error:(NSError*_Nullable)error {
    __weak Document* weakSelf = self;
    
    if ( error || userCancelled ) {
        
        
        
        
        
        
        [MacAlerts error:NSLocalizedString(@"sync_status_error_updating_title", @"Error Updating")
                   error:error
                  window:self.windowController.window
              completion:^{
            [MacAlerts twoOptions:NSLocalizedString(@"sync_status_error_updating_title", @"Error Updating")
                  informativeText:NSLocalizedString(@"sync_status_error_updating_try_again_prompt", @"There was an error updating your database. Would you like to try updating again, or would you prefer to revert to the latest successful update?")
                option1AndDefault:NSLocalizedString(@"sync_status_error_updating_try_again_action", @"Try Again")
                          option2:NSLocalizedString(@"sync_status_error_updating_revert_action", @"Revert to Latest")
                           window:self.windowController.window
                       completion:^(NSUInteger option) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( option == 1 ) {
                        [weakSelf synchronousForegroundUpdate];
                    }
                    else {
                        [weakSelf refreshUnlockedFromWorkingCopy];
                    }
                });
            }];
        }];
    }
    else if ( userInteractionRequired ) {
        NSLog(@"Background sync failed, will now try an interactive sync...");
        
        [MacAlerts yesNo:NSLocalizedString(@"sync_status_user_interaction_required_prompt_title", @"Assistance Required")
         informativeText:NSLocalizedString(@"sync_status_user_interaction_required_prompt_yes_or_no", @"There was a problem updating your database and your assistance is required to resolve. Would you like to resolve this problem now?")
                  window:self.windowController.window
              completion:^(BOOL yesNo) {
            if ( yesNo ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self synchronousForegroundUpdate];
                });
            }
        }];
    }
    else {
        [self showToastNotification:NSLocalizedString(@"notification_sync_successful", @"Sync Successful") error:NO];
        
        if ( localWasChanged ) {
            NSLog(@"Update successful and local was changed, reloading...");
            [self refreshUnlockedFromWorkingCopy];
        }
    }
}

- (void)onSyncFinished:(BOOL)userInteractionRequired userCancelled:(BOOL)userCancelled localWasChanged:(BOOL)localWasChanged error:(NSError*_Nullable)error {
    if ( userInteractionRequired ) {
        NSLog(@"Background sync failed, will now try an interactive sync...");
        [self synchronousForegroundSync];
    }
    else if ( userCancelled ) {
        
    }
    else if ( error ) {
        NSString* message = [NSString stringWithFormat:@"%@: %@",
                             NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error"),
                             error.localizedDescription];
        [self showToastNotification:message error:YES];
    }
    else {
        [self showToastNotification:NSLocalizedString(@"notification_sync_successful", @"Sync Successful") error:NO];
        
        if ( localWasChanged ) {
            NSLog(@"Sync successful and local was changed, reloading...");
            [self refreshUnlockedFromWorkingCopy];
        }
    }
}

- (void)refreshUnlockedFromWorkingCopy {
    NSLog(@"Document::refreshUnlockedFromWorkingCopy...");
    
    [self.viewModel reloadDatabaseFromLocalWorkingCopy:self.windowController.contentViewController
                                            completion:^(BOOL success) {
        if ( success ) {
            [self notifyFullModelReload]; 
        }
        else {
            [self onUnlockDatabaseError];
        }
    }];
}



- (void)onFileChangedByOtherApplication {
    NSLog(@"XXXX - [%@] - onFileChangedByOtherApplication", self);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self onDatabaseChangedByExternalOther];
    });
}

- (void)onDatabaseChangedByExternalOther {
    if(self.isPromptingAboutUnderlyingFileChange) {
        NSLog(@"Already in Use...");
        return;
    }
    
    self.isPromptingAboutUnderlyingFileChange = YES;
    if (self.viewModel && !self.viewModel.locked) {
        NSLog(@"ViewController::onDatabaseChangedByExternalOther - Reloading...");
        
        if(!self.viewModel.document.isDocumentEdited) {
            if( !self.databaseMetadata.autoReloadAfterExternalChanges ) {
                NSString* loc = NSLocalizedString(@"mac_db_changed_externally_reload_yes_or_no", @"The database has been changed by another application, would you like to reload this latest version and automatically unlock?");

                [MacAlerts yesNo:loc
                       window:self.windowController.window
                   completion:^(BOOL yesNo) {
                    if(yesNo) {
                        NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                        [self showPopupChangeToastNotification:loc];
                        
                        self.selectedItem = [self selectedItemSerializationId];
                        
                        [self syncAndReloadAfterExternalFileChange];
                    }
                    
                    self.isPromptingAboutUnderlyingFileChange = NO;
                }];
                return;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                [self showPopupChangeToastNotification:loc];

                self.selectedItem = [self selectedItemSerializationId];
                
                [self syncAndReloadAfterExternalFileChange];
            
                self.isPromptingAboutUnderlyingFileChange = NO;

                return;
            }
        }
        else {
            NSLog(@"Local Changes Present... ignore this, we can't auto reload...");
        }
    }
    else {
        NSLog(@"Ignoring File Change by Other Application because Database is locked/not set.");
    }
    
    self.isPromptingAboutUnderlyingFileChange = NO;
}

- (void)syncAndReloadAfterExternalFileChange {
    NSLog(@"Document::reloadAfterExternalFileChange ENTER");
    
    if ( self.viewModel ) {
        
        [self synchronousForegroundSync];
    }
    else { 
        [MacAlerts info:@"Model is not set. Could not unlock. Please close and reopen your database"
                 window:self.windowController.window];
    }
}



- (NSString*)selectedItemSerializationId {
    if ( Settings.sharedInstance.nextGenUI ) {
        return nil; 
    }
    else {
        Node* item = [self.windowController getSingleSelectedItem];
        
        if ( item ) {
            return [self.viewModel.database getCrossSerializationFriendlyIdId:item.uuid];
        }
        else {
            return nil;
        }
    }
}



- (void)showPopupChangeToastNotification:(NSString*)message {
    [self showToastNotification:message error:NO];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.windowController.window.isMiniaturized ) {
        NSLog(@"Not Showing Popup Change notification because window is miniaturized");
        return;
    }

    [self showToastNotification:message error:error yOffset:150.f];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error yOffset:(CGFloat)yOffset {
    if ( !self.viewModel.showChangeNotifications ) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        NSColor *defaultColor = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
        NSColor *errorColor = [NSColor colorWithDeviceRed:1 green:0.55 blue:0.05 alpha:0.90];

        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.windowController.contentViewController.view animated:YES];
        hud.labelText = message;
        hud.color = error ? errorColor : defaultColor;
        hud.mode = MBProgressHUDModeText;
        hud.margin = 10.f;
        hud.yOffset = yOffset;
        hud.removeFromSuperViewOnHide = YES;
        hud.dismissible = YES;
        
        NSTimeInterval delay = error ? 3.0f : 0.5f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [hud hide:YES];
        });
    });
}



- (void)cleanupWormhole {
    NSLog(@"✅ cleanupWormhole");

    if ( self.wormhole ) {

        [self.wormhole stopListeningForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId];

        NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusRequestId, self.databaseMetadata.uuid];
        [self.wormhole stopListeningForMessageWithIdentifier:requestId];
        
        NSString* convRequestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, self.databaseMetadata.uuid];
        [self.wormhole stopListeningForMessageWithIdentifier:convRequestId];

        [self.wormhole clearAllMessageContents];
        self.wormhole = nil;
    }
}

- (void)listenToAutoFillWormhole {
    NSLog(@"✅ listenToAutoFillWormhole");
    
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:Settings.sharedInstance.appGroupName
                                                         optionalDirectory:kAutoFillWormholeName];

    
    
    __weak Document* weakSelf = self;
    [self.wormhole listenForMessageWithIdentifier:kAutoFillWormholeQuickTypeRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ([userSession isEqualToString:NSUserName()]) { 
            NSString* json = dict ? dict[@"id"] : nil;
            [weakSelf onQuickTypeAutoFillWormholeRequest:json];
        }
    }];
    
    
    
    NSString* requestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusRequestId, self.databaseMetadata.uuid];

    [self.wormhole listenForMessageWithIdentifier:requestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [weakSelf onAutoFillDatabaseUnlockedStatusWormholeRequest:databaseId];
        }
    }];
    
    

    NSString* convRequestId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockRequestId, self.databaseMetadata.uuid];

    [self.wormhole listenForMessageWithIdentifier:convRequestId
                                         listener:^(id messageObject) {
        NSDictionary *dict = (NSDictionary*)messageObject;
        NSString* userSession = dict[@"user-session-id"];
        
        if ( [userSession isEqualToString:NSUserName()] ) { 
            NSString* databaseId = dict[@"database-id"];
            [weakSelf onAutoFillWormholeMasterCredentialsRequest:databaseId];
        }
    }];
}

- (void)onAutoFillWormholeMasterCredentialsRequest:(NSString*)databaseId {
    NSLog(@"✅ onAutoFillWormholeMasterCredentialsRequest: [%@]", databaseId );
    
    if ( self.viewModel && !self.viewModel.locked && databaseId) {
        if (!self.databaseMetadata.quickWormholeFillEnabled ) {
            return;
        }

        if ( [self.databaseMetadata.uuid isEqualToString:databaseId] ) {
            NSLog(@"Responding to Conv Unlock Req for Database - [%@]-%@", self, databaseId);

            NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeConvUnlockResponseId, databaseId];
            NSString* secretStoreId = NSUUID.UUID.UUIDString;
            NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
            [SecretStore.sharedInstance setSecureObject:self.viewModel.compositeKeyFactors.password
                                          forIdentifier:secretStoreId
                                              expiresAt:expiry];

            [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(),
                                                 @"secret-store-id" : secretStoreId }
                                  identifier:responseId];
        }
    }
}

- (void)onAutoFillDatabaseUnlockedStatusWormholeRequest:(NSString*)databaseId {
    NSLog(@"✅ onAutoFillDatabaseUnlockedStatusWormholeRequest");

    if ( self.viewModel && !self.viewModel.locked && databaseId) {
        if (!self.databaseMetadata.quickWormholeFillEnabled ) {
            return;
        }
        
        if ( [self.databaseMetadata.uuid isEqualToString:databaseId] ) {


            NSString* responseId = [NSString stringWithFormat:@"%@-%@", kAutoFillWormholeDatabaseStatusResponseId, databaseId];

            [self.wormhole passMessageObject:@{  @"user-session-id" : NSUserName(), @"unlocked" : databaseId }
                                  identifier:responseId];
        }
    }
}

- (void)onQuickTypeAutoFillWormholeRequest:(NSString*)json {
    NSLog(@"✅ onQuickTypeAutoFillWormholeRequest");

    if ( self.viewModel && !self.viewModel.locked && json) {
        QuickTypeRecordIdentifier* identifier = [QuickTypeRecordIdentifier fromJson:json];
        
        if( identifier && self.databaseMetadata && [self.databaseMetadata.uuid isEqualToString:identifier.databaseId] ) {
            if (!self.databaseMetadata.quickWormholeFillEnabled || !self.databaseMetadata.quickTypeEnabled ) {
                return;
            }
            
            
            
            DatabaseModel* model = self.viewModel.database;
            Node* node = [model.effectiveRootGroup.allChildRecords firstOrDefault:^BOOL(Node * _Nonnull obj) {
                return [obj.uuid.UUIDString isEqualToString:identifier.nodeId]; 
            }];

            NSString* secretStoreId = NSUUID.UUID.UUIDString;

            if(node) {
                NSString* password = @"";

                if ( identifier.fieldKey ) {
                    StringValue* sv = node.fields.customFields[identifier.fieldKey];
                    if ( sv ) {
                        password = sv.value;
                    }
                }
                else {
                    password = [model dereference:node.fields.password node:node];
                }
                
                NSString* user = [model dereference:node.fields.username node:node];
                NSString* totp = node.fields.otpToken ? node.fields.otpToken.password : @"";
                
                password = password ? password : @"";
                

                
                NSDictionary* securePayload = @{
                    @"user" : user,
                    @"password" : password,
                    @"totp" : totp,
                };
                
                NSDate* expiry = [NSDate.date dateByAddingTimeInterval:5]; 
                [SecretStore.sharedInstance setSecureObject:securePayload forIdentifier:secretStoreId expiresAt:expiry];
            }
            else {

            }
            
            [self.wormhole passMessageObject:@{ @"user-session-id" : NSUserName(),
                                                @"success" : @(node != nil),
                                                @"secret-store-id" : secretStoreId }
                                  identifier:kAutoFillWormholeQuickTypeResponseId];
        }
    }
}

@end
