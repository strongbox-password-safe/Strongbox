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
#import "DatabasesManager.h"
#import "MacSyncManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "DatabaseUnlocker.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

NSString* const kModelUpdateNotificationLongRunningOperationStart = @"kModelUpdateNotificationLongRunningOperationStart"; 
NSString* const kModelUpdateNotificationLongRunningOperationDone = @"kModelUpdateNotificationLongRunningOperationDone";
NSString* const kModelUpdateNotificationFullReload = @"kModelUpdateNotificationFullReload";
NSString* const kModelUpdateNotificationDatabaseChangedByOther = @"kModelUpdateNotificationDatabaseChangedByOther";
NSString* const kModelUpdateNotificationSyncDone = @"kModelUpdateNotificationBackgroundSyncDone";

NSString* const kNotificationUserInfoLongRunningOperationStatus = @"status";
NSString* const kNotificationUserInfoParamKey = @"param";

@interface Document ()

@property WindowController* windowController;
@property NSTimer* managedDatabasePollForChangesTimer;
@property BOOL pollingInProgress;

@end

@implementation Document

+ (BOOL)autosavesInPlace {
    return Settings.sharedInstance.autoSave;
}

- (DatabaseMetadata *)databaseMetadata {
    if ( self.fileURL ) {
        return [DatabasesManager.sharedInstance getDatabaseByFileUrl:self.fileURL];
    }
    
    return nil;
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
    
    [self.windowController updateContentView]; 
    
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

- (BOOL)loadLockedModel {
    NSLog(@"loadLockedModel");
    _viewModel = [[ViewModel alloc] initLocked:self
                                      metadata:self.databaseMetadata];
    
    WindowController* wc = self.windowController; 
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [wc updateContentView];
    });
    
    return YES;
}

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
         fromConvenience:(BOOL)fromConvenience
              completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    [self revertWithUnlock:compositeKeyFactors
            viewController:viewController
       alertOnJustPwdWrong:YES
           fromConvenience:fromConvenience
                completion:completion];
}

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController *)viewController
     alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
         fromConvenience:(BOOL)fromConvenience
              completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    NSLog(@"Document::revertWithUnlock: [%@]", self.fileURL);

    if ( self.databaseMetadata ) {
        if ( !self.databaseMetadata.offlineMode ) {
            NSLog(@"ONLINE MODE: syncWorkingCopyAndUnlock");
            
            [self syncWorkingCopyAndUnlock:self.databaseMetadata
                            viewController:viewController
                       alertOnJustPwdWrong:alertOnJustPwdWrong
                           fromConvenience:fromConvenience
                                       key:compositeKeyFactors
                              selectedItem:self.selectedItem
                                completion:completion];
        }
        else {
            NSLog(@"OFFLINE MODE: syncWorkingCopyAndUnlock");

            [self loadWorkingCopyAndUnlock:self.databaseMetadata
                                       key:compositeKeyFactors
                            viewController:viewController
                       alertOnJustPwdWrong:alertOnJustPwdWrong
                           fromConvenience:fromConvenience
                              selectedItem:self.selectedItem
                                completion:completion];
        }
    }
    else {
        NSLog(@"WARNWARN: No database metadata found!!");
    }
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

    
    
    
    

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(debouncedSaveDocument:) object:nil];
    [self performSelector:@selector(debouncedSaveDocument:) withObject:nil afterDelay:0.25f];
}

- (void)debouncedSaveDocument:(id)sender {
    if(self.viewModel.locked) {
        return;
    }

    
    [super saveDocument:sender];
    
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate randomlyShowUpgradeMessage];
    }
}

- (void)saveDocumentWithDelegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    NSLog(@"saveDocumentWithDelegate... [%@] - [%@]", contextInfo, self.fileURL);

    [super saveDocumentWithDelegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {

    NSLog(@"runModalSavePanelForSaveOperation");

    [super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
         delegate:(id)delegate
  didSaveSelector:(SEL)didSaveSelector
      contextInfo:(void *)contextInfo {
    NSLog(@"saveToURL delegate... [%@]", url);
    
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"saveToURL: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, url);

    
        
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
        NSError* error;
        BOOL success = [self writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:&error];
        NSLog(@"saveToURL Done: Success = %hhd, %lu - [%@] - [%@]", success, (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, error);

        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(error);
        
            if ( success ) {
                [self updateQuickTypeAutoFill]; 

                

                [self notifyUpdatesDatabasesList];
            }
        });
    });
}

- (BOOL)writeSafelyToURL:(NSURL *)url
                  ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation
                   error:(NSError *__autoreleasing  _Nullable *)outError {
    if ( NSThread.isMainThread ) {
        NSLog(@"🔴 WARNWARN: writeSafelyToURL called on main thread- this will break YubiKeys requiring Touch! ");
    }
    
    return [self syncManagerWriteSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
}

- (BOOL)syncManagerWriteSafelyToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation
                              error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"syncManagerWriteSafelyToURL... [%@]", url);
    
    
    
    NSError* dataOfTypeError;
    NSData* data = [self dataOfType:typeName error:&dataOfTypeError];
    if ( !data ) {
        NSLog(@"Could not get dataOfType = [%@]", dataOfTypeError);
        if ( outError ) {
            *outError = dataOfTypeError;
        }
        return NO;
    }

    if ( !self.databaseMetadata ) {
        DatabaseMetadata* metadata = [DatabasesManager.sharedInstance addOrGet:url];
        
        NSLog(@"self.databaseMetadata not found... creating [%@]", metadata);

        return NO;
    }
                
    NSError* updateError;
    BOOL success = [MacSyncManager.sharedInstance updateLocalCopyMarkAsRequiringSync:self.databaseMetadata
                                                                                data:data
                                                                               error:&updateError];
    if (!success) {
        NSLog(@"Could not get dataOfType = [%@]", dataOfTypeError);
        if ( outError ) {
            *outError = updateError;
        }

        NSLog(@"Could not updateLocalCopyMarkAsRequiringSync: [%@]", updateError);
        return NO;
    }

    [self backgroundSync];
    
    if (saveOperation != NSSaveToOperation) {
        dispatch_async(dispatch_get_main_queue(), ^{ 
            [self updateChangeCount:NSChangeCleared];
        });
    }
    
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"✅ Document::dataOfType: [%@]", typeName);
    
    [self unblockUserInteraction];
    return [self getDataFromModel:self.viewModel error:outError];
}




- (NSData*)getDataFromModel:(ViewModel*)model error:(NSError **)outError {
    __block NSData *ret = nil;
    __block NSError *retError = nil;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [self.viewModel getPasswordDatabaseAsData:^(BOOL userCancelled, NSData * _Nullable data, NSError * _Nullable error) {
        NSLog(@"getDataFromModel: Got Data... Cancelled=[%hhd], Error = [%@]", userCancelled, error);
        ret = data;
        retError = error;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    if (outError) {
        *outError = retError;
    }
    
    return ret;
}




- (void)close {
    [super close];

    [self unListenForSleepWakeEvents];
    
    [self stopMonitoringManagedFile];
    
    
        
    if (NSDocumentController.sharedDocumentController.documents.count == 0 &&
        Settings.sharedInstance.showDatabasesManagerOnCloseAllWindows &&
        !Settings.sharedInstance.runningAsATrayApp ) {
        [DBManagerPanel.sharedInstance show];
    }
}

- (void)updateQuickTypeAutoFill {
    if (self.viewModel && self.viewModel.database && self.databaseMetadata && self.databaseMetadata.autoFillEnabled && self.databaseMetadata.quickTypeEnabled) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel.database
                                                           databaseUuid:self.databaseMetadata.uuid
                                                          displayFormat:self.databaseMetadata.quickTypeDisplayFormat
                                                        alternativeUrls:self.databaseMetadata.autoFillScanAltUrls
                                                           customFields:self.databaseMetadata.autoFillScanCustomFields
                                                                  notes:self.databaseMetadata.autoFillScanNotes
                                           concealedCustomFieldsAsCreds:self.databaseMetadata.autoFillConcealedFieldsAsCreds
                                         unConcealedCustomFieldsAsCreds:self.databaseMetadata.autoFillUnConcealedFieldsAsCreds];
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
    if ( !self.databaseMetadata || self.viewModel.locked || self.viewModel.offlineMode || !self.databaseMetadata.monitorForExternalChanges ) {
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
            NSLog(@"XXXX - checkForRemoteChanges - Change Found");
            [self notifyDatabaseHasBeenChangedByOther];
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

- (void)notifyDatabaseHasBeenChangedByOther {
    NSLog(@"XXXX - notifyDatabaseHasBeenChangedByOther");
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationDatabaseChangedByOther
                                                          object:self
                                                        userInfo:@{ }];
    });
}

- (void)notifyUpdatesDatabasesList {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListViewForceRefreshNotification object:nil];
    });
}

- (void)notifyViewsSyncDone:(SyncAndMergeResult)result
            localWasChanged:(BOOL)localWasChanged
                      error:(NSError*)error {

    
    NSDictionary *params = @{ @"result" : @(result),
                              @"localWasChanged" : @(localWasChanged), };
    
    NSMutableDictionary *userInfo = params.mutableCopy;
    if (error ) {
        userInfo[@"error"] = error;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationSyncDone
                                                          object:self
                                                        userInfo:userInfo];
    });
}




- (void)syncWorkingCopyAndUnlock:(DatabaseMetadata*)databaseMetadata
                  viewController:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    NSLog(@"syncWorkingCopyAndUnlock ENTER");
    
    if ( self.viewModel.offlineMode ) {
        NSLog(@"🔴 WARNWARN: syncWorkingCopyAndUnlock called in Offline Mode!!");

        if(completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, NO, NO, nil);
            });
        }

        return;
    }
    
    [MacSyncManager.sharedInstance sync:databaseMetadata
                          interactiveVC:viewController
                                    key:key
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            [self loadWorkingCopyAndUnlock:databaseMetadata
                                       key:key
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

- (void)backgroundSync {


    if ( self.viewModel.offlineMode ) {
        NSLog(@"WARNWARN: BACKGROUND SYNC called in Offline Mode!!");
        return;
    }
    
    [MacSyncManager.sharedInstance backgroundSyncDatabase:self.databaseMetadata
                                               completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        [self onSyncDone:result localWasChanged:localWasChanged error:error];
    }];
}

- (void)performFullInteractiveSync:(NSViewController*)viewController key:(CompositeKeyFactors*)key {
    NSLog(@"performFullInteractiveSync");

    if ( self.viewModel.offlineMode ) {
        NSLog(@"WARNWARN: performFullInteractiveSync called in Offline Mode!!");
        return;
    }

    [MacSyncManager.sharedInstance sync:self.databaseMetadata
                          interactiveVC:viewController
                                    key:key
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        [self onSyncDone:result localWasChanged:localWasChanged error:error];
    }];
}

- (void)onSyncDone:(SyncAndMergeResult)result localWasChanged:(BOOL)localWasChanged error:(NSError * _Nullable)error {
    if ( result == kSyncAndMergeSuccess ) {
        
        










    }
    
    [self notifyViewsSyncDone:result localWasChanged:localWasChanged error:error]; 
}



- (void)lock:(NSString*)selectedItem {
    if(self.isDocumentEdited) {
        NSLog(@"Cannot lock document with edits!");
        return;
    }
    
    
    [self.undoManager removeAllActions];
    
    self.wasJustLocked = YES;
    
    [self loadLockedModel];

    self.selectedItem = selectedItem; 
}



- (void)reloadFromLocalWorkingCopy:(CompositeKeyFactors *)key
                    viewController:(NSViewController*)viewController
                      selectedItem:(NSString *)selectedItem {
    [self loadWorkingCopyAndUnlock:self.databaseMetadata
                               key:key
                    viewController:viewController
               alertOnJustPwdWrong:YES
                   fromConvenience:NO
                      selectedItem:selectedItem
                        completion:nil];
}

- (void)loadWorkingCopyAndUnlock:(DatabaseMetadata*)databaseMetadata
                             key:(CompositeKeyFactors*)key
                  viewController:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.databaseMetadata
                                                        viewController:viewController
                                                         forceReadOnly:NO
                                                        isAutoFillOpen:NO
                                                           offlineMode:self.databaseMetadata.offlineMode];
    
    unlocker.alertOnJustPwdWrong = alertOnJustPwdWrong;
    
    [unlocker unlockLocalWithKey:key
              keyFromConvenience:fromConvenience
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable innerStreamError, NSError * _Nullable error) {
        if ( result == kUnlockDatabaseResultSuccess ) {
            [self onUnlockDatabaseSuccessful:model.database]; 
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
        _viewModel = [[ViewModel alloc] initLocked:self metadata:self.databaseMetadata];

        WindowController* wc = self.windowController;

        dispatch_async(dispatch_get_main_queue(), ^{
            [wc updateContentView];
        });

        [self notifyFullModelReload];
    }
    else {
        
    }
}

- (void)onUnlockDatabaseSuccessful:(DatabaseModel*)db {
    BOOL wasLocked = self.viewModel && self.viewModel.locked;
    
    _viewModel = [[ViewModel alloc] initUnlockedWithDatabase:self
                                                    metadata:self.databaseMetadata
                                                    database:db];

    if ( wasLocked ) { 
        WindowController* wc = self.windowController;

        dispatch_async(dispatch_get_main_queue(), ^{
            [wc updateContentView];
        });
    }
    
    [self notifyFullModelReload]; 
    
    
    [NSFileCoordinator addFilePresenter:self];

    [self startMonitoringManagedFile];
}

@end
