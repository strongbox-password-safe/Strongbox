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

NSString* const kModelUpdateNotificationLongRunningOperationStart = @"kModelUpdateNotificationLongRunningOperationStart"; 
NSString* const kModelUpdateNotificationLongRunningOperationDone = @"kModelUpdateNotificationLongRunningOperationDone";
NSString* const kModelUpdateNotificationFullReload = @"kModelUpdateNotificationFullReload";
NSString* const kModelUpdateNotificationDatabaseChangedByOther = @"kModelUpdateNotificationDatabaseChangedByOther";
NSString* const kModelUpdateNotificationSyncDone = @"kModelUpdateNotificationBackgroundSyncDone";

NSString* const kNotificationUserInfoLongRunningOperationStatus = @"status";
NSString* const kNotificationUserInfoParamKey = @"param";

@interface Document ()

@property WindowController* windowController;




@property CompositeKeyFactors* credentialsForUnlock;
@property NSString *selectedItemForUnlock;
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
    
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    
    [self addWindowController:self.windowController];
}




- (BOOL)isLegacyFileUrl:(NSURL*)url {
    return ( url && url.scheme.length && [url.scheme isEqualToString:kStrongboxFileUrlScheme] );
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"readFromURL: [%@]", url);

    if ( ![self isLegacyFileUrl:url] ) {
        NSLog(@"Sync Manager Mode: readFromURL - Loading Locked Model...");
                
        [NSFileCoordinator addFilePresenter:self];

        return [self loadLockedModel];
    }
    else {
        return [super readFromURL:url ofType:typeName error:outError];
    }
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    NSLog(@"readFromFileWrapper");

    if(fileWrapper.isDirectory) { 
        if(outError != nil) {
            NSString* loc = NSLocalizedString(@"mac_strongbox_cant_open_file_wrappers", @"Strongbox cannot open File Wrappers, Directories or Compressed Packages like this. Please directly select a KeePass or Password Safe database file.");
            *outError = [Utils createNSError:loc errorCode:-1];
        }
        return NO;
    }
    
    return [super readFromFileWrapper:fileWrapper ofType:typeName error:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"readFromData: %ld - [%@]", data.length, typeName);

    if ( self.credentialsForUnlock ) { 
        BOOL ret = [self loadModelFromData:data key:self.credentialsForUnlock selectedItem:self.selectedItemForUnlock outError:outError];

        self.credentialsForUnlock = nil;
        self.selectedItemForUnlock = nil;

        return ret;
    }
    else {
        NSError* error;

        if(![Serializator isValidDatabaseWithPrefix:data error:&error]) {
            if(outError != nil) {
                *outError = error;
            }
            
            return NO;
        }

        return [self loadLockedModel];
    }
}

- (BOOL)loadLockedModel {
    _viewModel = [[ViewModel alloc] initLocked:self
                                      metadata:self.databaseMetadata];
    
    return YES;
}

- (BOOL)loadModelFromData:(NSData*)data
                      key:(CompositeKeyFactors*)key
             selectedItem:(NSString*)selectedItem
                 outError:(NSError **)outError {
    NSError* error;
    if(![Serializator isValidDatabaseWithPrefix:data error:&error]) {
        if(outError != nil) {
            *outError = error;
        }
        
        return NO;
    }

    DatabaseModel *db = [self getModelFromData:data key:key error:&error];

    if(!db) {
        if(outError != nil) {
            *outError = error;
        }
        
        if(self.viewModel && !self.viewModel.locked) {
            _viewModel = [[ViewModel alloc] initLocked:self
                                              metadata:self.databaseMetadata];

            [self notifyFullModelReload];
        }
        
        return NO;
    }
    
    
    _viewModel = [[ViewModel alloc] initUnlockedWithDatabase:self
                                                    metadata:self.databaseMetadata
                                                    database:db
                                                selectedItem:selectedItem];
    
    [self updateQuickTypeAutoFill];
    
    [self notifyFullModelReload];
        
    return YES;
}

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
              completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSLog(@"Document::revertWithUnlock: [%@]", self.fileURL);

    if ( ![self isLegacyFileUrl:self.fileURL] ) {
        if ( self.databaseMetadata ) {
            if ( !self.databaseMetadata.offlineMode ) {
                NSLog(@"ONLINE MODE: syncWorkingCopyAndUnlock");
                
                [self syncWorkingCopyAndUnlock:self.databaseMetadata
                                viewController:viewController
                                           key:compositeKeyFactors
                                  selectedItem:self.viewModel.selectedItem
                                    completion:completion];
            }
            else {
                NSLog(@"OFFLINE MODE: syncWorkingCopyAndUnlock");

                [self loadWorkingCopyAndUnlock:self.databaseMetadata
                                           key:compositeKeyFactors
                                  selectedItem:self.viewModel.selectedItem
                                    completion:completion];
            }
        }
        else {
            NSLog(@"WARNWARN: No database metadata found!!");
        }
    }
    else {
        [self legacyRevertWithUnlock:compositeKeyFactors viewController:viewController selectedItem:self.viewModel.selectedItem completion:completion];
    }
}

- (void)legacyRevertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
                viewController:(NSViewController*)viewController
                  selectedItem:(NSString *)selectedItem
                    completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSError* error;

    self.credentialsForUnlock = compositeKeyFactors;
    self.selectedItemForUnlock = selectedItem;

    
    
    
    
    
    [self.undoManager removeAllActions]; 
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.fileURL options:NSFileWrapperReadingImmediate error:&error];
    
    if(!wrapper) {
        NSLog(@"Could not create file wrapper: [%@]", error);
        completion(NO, error);
        return;
    }
    
    BOOL success = [self readFromFileWrapper:wrapper ofType:self.fileType error:&error];
    if(success) {
        self.fileModificationDate = wrapper.fileAttributes.fileModificationDate;
    }
    
    self.credentialsForUnlock = nil;
    self.selectedItemForUnlock = nil;

    if(completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
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
    
    
    
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation
                delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"saveToURL: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, url);

    if ( [self isLegacyFileUrl:self.fileURL] ) {
        NSLog(@"saveToURL... LEGACY [%@]", url);

        
        
        [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
            completionHandler(error);

            NSLog(@"saveToURL Done: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate, error);

            [self updateQuickTypeAutoFill];

            

            [self notifyUpdatesDatabasesList];
        }];
    }
    else {
        NSLog(@"saveToURL... NEW [%@]", url);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
            NSError* error;
            BOOL success = [self writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:&error];
            NSLog(@"saveToURL Done: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, error);

            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(error);

                if ( success ) {
                    [self updateQuickTypeAutoFill];

                    

                    [self notifyUpdatesDatabasesList];
                }
            });
        });
    }
}

- (BOOL)writeSafelyToURL:(NSURL *)url
                  ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation
                   error:(NSError *__autoreleasing  _Nullable *)outError {
    if ( NSThread.isMainThread ) {
        NSLog(@"WARNWARN: writeSafelyToURL called on main thread- this will break YubiKeys requiring Touch! ");
    }
    
    if ( ![self isLegacyFileUrl:self.fileURL] ) {
        return [self syncManagerWriteSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
    }
    else {
        NSLog(@"writeSafelyToURL LEGACY - [%@]", url);
        return [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
    }
}

- (BOOL)syncManagerWriteSafelyToURL:(NSURL *)url
                             ofType:(NSString *)typeName
                   forSaveOperation:(NSSaveOperationType)saveOperation
                              error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"syncManagerWriteSafelyToURL... [%@]", url);
    
    
    
    NSData* data = [self dataOfType:typeName error:outError];
    if ( !data ) {
        NSLog(@"Could not get dataOfType");
        return NO;
    }

    if ( !self.databaseMetadata ) {
        DatabaseMetadata* metadata = [DatabasesManager.sharedInstance addOrGet:url];
        
        NSLog(@"self.databaseMetadata not found... creating [%@]", metadata);

        return NO;
    }
                
    BOOL success = [MacSyncManager.sharedInstance updateLocalCopyMarkAsRequiringSync:self.databaseMetadata
                                                                                data:data
                                                                               error:outError];
    if (!success) {
        NSLog(@"Could not updateLocalCopyMarkAsRequiringSync");
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
    NSLog(@"Document::dataOfType: [%@]", typeName);
    
    [self unblockUserInteraction];
    return [self getDataFromModel:self.viewModel error:outError];
}




- (NSData*)getDataFromModel:(ViewModel*)model error:(NSError **)outError {
    __block NSData *ret = nil;
    __block NSError *retError = nil;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [self.viewModel getPasswordDatabaseAsData:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        
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

- (DatabaseModel*)getModelFromData:(NSData*)data key:(CompositeKeyFactors*)key error:(NSError **)outError {
    __block DatabaseModel* db = nil;
    __block NSError* retError = nil;

    [self notifyLongRunningOpStart:NSLocalizedString(@"open_sequence_progress_decrypting", @"Decrypting...")];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    [Serializator fromLegacyData:data
                             ckf:key
                          config:DatabaseModelConfig.defaults
                      completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
        
        db = model;
        retError = error;
        dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    [self notifyLongRunningOpDone];
    
    if (outError) {
        *outError = retError;
    }
    
    return db;
}




- (void)close {
    [super close];

    [self unListenForSleepWakeEvents];
    
    [self stopMonitoringManagedFile];
    
    
    
    if (NSDocumentController.sharedDocumentController.documents.count == 0 && Settings.sharedInstance.showDatabasesManagerOnCloseAllWindows) {
        [DatabasesManagerVC show];
    }
}

- (void)updateQuickTypeAutoFill {
    if (self.viewModel && self.viewModel.database && self.databaseMetadata && self.databaseMetadata.autoFillEnabled && self.databaseMetadata.quickTypeEnabled) {
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.viewModel.database
                                                           databaseUuid:self.databaseMetadata.uuid
                                                          displayFormat:self.databaseMetadata.quickTypeDisplayFormat];
    }
}



- (void)encodeRestorableStateWithCoder:(NSCoder *) coder {
    NSLog(@"encodeRestorableStateWithCoder - [%@]", self.fileURL.scheme);

    if ( ![self isLegacyFileUrl:self.fileURL] ) {
        [coder encodeObject:self.fileURL forKey:@"StrongboxNonFileRestorationStateURL"];
        return;
    }
    else {
        [super encodeRestorableStateWithCoder:coder];
    }
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

    
    if ( !self.databaseMetadata || self.viewModel.locked || self.viewModel.offlineMode || !self.databaseMetadata.monitorForExternalChanges || [self isLegacyFileUrl:self.fileURL] ) {
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
    
    if ( !self.databaseMetadata.monitorForExternalChanges || [self isLegacyFileUrl:self.fileURL] || self.viewModel.offlineMode) {
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
    NSLog(@"checkForRemoteChanges");
    
    self.pollingInProgress = YES;
    [MacSyncManager.sharedInstance pollForChanges:self.databaseMetadata
                                       completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        self.pollingInProgress = NO;
        
        if ( localWasChanged ) {
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
        
        BOOL mod = [self fileHasBeenModified];
        if( mod ) {
            [self notifyDatabaseHasBeenChangedByOther];
        }
    }
}

- (BOOL)fileHasBeenModified {
    NSLog(@"legacyFileBasedisFileHasBeenModified");

    if(!self.fileURL) {
        NSLog(@"fileUrl is nil!");
        return NO;
    }
    
    NSError* error;
    NSDictionary<NSFileAttributeKey, id> *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:self.fileURL.path error:&error];
    if(!attributes) {
        NSLog(@"error: %@", error);
        return NO;
    }
    
    NSDate* mod = [attributes fileModificationDate];

    BOOL changed = ![mod isEqualToDateWithinEpsilon:self.fileModificationDate];
    
    NSLog(@"Document Changed? [%@] File=[%@] vs Doc=[%@]", localizedYesOrNoFromBool(changed), mod.friendlyDateTimeStringBothPrecise, self.fileModificationDate.friendlyDateTimeStringBothPrecise);
    
    return changed;
}




- (void)notifyLongRunningOpStart:(NSString*)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationLongRunningOperationStart
                                                          object:self
                                                        userInfo:@{ kNotificationUserInfoLongRunningOperationStatus : status }];
    });
}

- (void)notifyLongRunningOpDone {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationLongRunningOperationDone
                                                          object:self
                                                        userInfo:@{ }];
    });
}

- (void)notifyFullModelReload {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:kModelUpdateNotificationFullReload
                                                          object:self
                                                        userInfo:@{ }];
    });
}

- (void)notifyDatabaseHasBeenChangedByOther {
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
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSLog(@"syncWorkingCopyAndUnlock ENTER");
    
    if ( self.viewModel.offlineMode ) {
        NSLog(@"WARNWARN: syncWorkingCopyAndUnlock called in Offline Mode!!");

        if(completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
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
                              selectedItem:selectedItem
                                completion:completion];
        }
        else {
            if(completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
    }];
}

- (void)reloadFromLocalWorkingCopy:(CompositeKeyFactors *)key selectedItem:(NSString *)selectedItem {
    [self loadWorkingCopyAndUnlock:self.databaseMetadata key:key selectedItem:selectedItem completion:nil];
}

- (void)loadWorkingCopyAndUnlock:(DatabaseMetadata*)databaseMetadata
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSDate* modDate;
    NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache2:databaseMetadata.uuid modified:&modDate];
    
    if (workingCopy == nil) {
        NSLog(@"loadWorkingCopyAndUnlock - Could not get local working copy");
        completion(NO, [Utils createNSError:@"Could not get local working copy" errorCode:-123]);
        return;
    }
        
    NSError* error;
    NSData* workingData = [NSData dataWithContentsOfURL:workingCopy options:kNilOptions error:&error];
    if ( error ) {
        NSLog(@"loadWorkingCopyAndUnlock - dataWithContentsOfURL error = [%@]", error);
        completion(NO, error);
        return;
    }


    BOOL success = [self loadModelFromData:workingData key:key selectedItem:selectedItem outError:&error];

    [NSFileCoordinator addFilePresenter:self];

    [self startMonitoringManagedFile];

    
    
    
    
    





    
    
    
    if(completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    }
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

@end
