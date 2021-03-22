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

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation {
    return YES;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    return YES;
}

- (instancetype)initWithCredentials:(DatabaseFormat)format compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    if (self = [super init]) {
        DatabaseModel* db = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:compositeKeyFactors];
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:db passwordConfig:Settings.sharedInstance.passwordGenerationConfig];
        _viewModel = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:nil];
    }
    
    return self;
}

- (void)makeWindowControllers {
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    [self addWindowController:self.windowController];
}




- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"readFromURL: [%@]", url.scheme);

    if (url && url.scheme.length && ![url.scheme isEqualToString:kStrongboxFileUrlScheme] ) {
        NSLog(@"Non File - Loading Locked Model...");
        
        
        
        return [self loadLockedModel];
    }
    
    return [super readFromURL:url ofType:typeName error:outError];
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
    _viewModel = [[ViewModel alloc] initLocked:self];
    return YES;
}

- (BOOL)loadModelFromData:(NSData*)data key:(CompositeKeyFactors*)key selectedItem:(NSString*)selectedItem outError:(NSError **)outError {
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
            _viewModel = [[ViewModel alloc] initLocked:self];
            [self notifyFullModelReload];
        }
        
        return NO;
    }
    
    _viewModel = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:selectedItem];
    
    [self updateQuickTypeAutoFill];
    
    [self notifyFullModelReload];
        
    return YES;
}

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
              completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSLog(@"Document::revertWithUnlock: [%@]", self.fileURL);

    NSURL* url = self.fileURL;
    if (url && url.scheme.length && ![url.scheme isEqualToString:kStrongboxFileUrlScheme] ) {
        NSLog(@"None File - revertWithUnlock... Loading Model...");
        [self syncWorkingCopyAndUnlock:self.databaseMetadata viewController:viewController key:compositeKeyFactors selectedItem:self.viewModel.selectedItem completion:completion];
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




- (IBAction)saveDocument:(id)sender {
    NSLog(@"Document::saveDocument");

    if(self.viewModel.locked) {
        NSString* loc = NSLocalizedString(@"mac_cannot_save_db_while_locked", @"Cannot save database while it is locked.");
        [MacAlerts info:loc window:self.windowController.window];
        return;
    }

    [super saveDocument:sender];
    
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate randomlyShowUpgradeMessage];
    }
}




















- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    NSLog(@"saveToURL... [%@]", url);

    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
        completionHandler(error);
        
        
        NSLog(@"saveToURL Done: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate, error);
        
        [self updateQuickTypeAutoFill];
        
        
        
        [self notifyUpdatesDatabasesList];
    }];
}

- (BOOL)writeSafelyToURL:(NSURL *)url
                  ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation
                   error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"writeSafelyToURL - [%@]", url);
    
    if (url && url.scheme.length && ![url.scheme isEqualToString:kStrongboxFileUrlScheme] ) {
        NSLog(@"writeSafelyToURL for non file SFTP... [%@]", url);
        
        
        
        NSData* data = [self dataOfType:typeName error:outError];
        if ( !data ) {
            NSLog(@"Could not get dataOfType");
            return NO;
        }

        if ( !self.databaseMetadata ) {
            NSLog(@"self.databaseMetadata not found");
            return NO;
        }
                    
        BOOL success = [MacSyncManager.sharedInstance updateLocalCopyMarkAsRequiringSync:self.databaseMetadata data:data error:outError];
        if (!success) {
            NSLog(@"Could not updateLocalCopyMarkAsRequiringSync");
            return NO;
        }

        
        
        NSDate* modDate = nil;
        [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.databaseMetadata modified:&modDate];
        [self setFileModificationDate:modDate ? modDate : NSDate.date];

        [self syncAfterSave];
        
        
        
        return YES;
    }

    return [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
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
    NSURL* url = self.fileURL;

    NSLog(@"encodeRestorableStateWithCoder - [%@]", url.scheme);

    if (url && url.scheme.length) {
        if ([url.scheme isEqualToString:kStrongboxSFTPUrlScheme]) {
            [coder encodeObject:self.fileURL forKey:@"StrongboxNonFileRestorationStateURL"];
            return;
        }
    }

    [super encodeRestorableStateWithCoder:coder];
}





- (void)onSyncChangedUnderlyingWorkingCopy {
    NSLog(@"onSyncChangedUnderlyingWorkingCopy");

    
    
    [self notifyDatabaseHasBeenChangedByOther];
}

- (void)presentedItemDidChange {
    NSLog(@"presentedItemDidChange");

    if(!Settings.sharedInstance.detectForeignChanges) {
        return;
    }
    
    if(!self.fileModificationDate) {
        NSLog(@"presentedItemDidChange but NO self.fileModificationDate?");
        return;
    }
    
    if([self legacyFileBasedisFileHasBeenModified]) {
        [self notifyDatabaseHasBeenChangedByOther];
    }
}

- (BOOL)legacyFileBasedisFileHasBeenModified {
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
    if ([mod compare:self.fileModificationDate] == NSOrderedDescending) {
        NSLog(@"X - Document Changed [%@]/[%@] - [%@] - XXXXXXXXXXXXX", mod, self.fileModificationDate, self.fileURL);
        return YES;
    }

    return NO;
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

- (void)notifyViewsSyncDone:(SyncAndMergeResult)result localWasChanged:(BOOL)localWasChanged error:(NSError*)error {
    NSLog(@"notifyViewsSyncDone: %ld-%hhd", result, localWasChanged);
    
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
    
    [MacSyncManager.sharedInstance sync:databaseMetadata
                          interactiveVC:viewController
                                    key:key
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        if ( result == kSyncAndMergeSuccess ) {
            [self loadWorkingCopyAndUnlock:databaseMetadata
                            viewController:viewController
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

- (void)reloadFromLocalWorkingCopy:(NSViewController *)viewController key:(CompositeKeyFactors *)key selectedItem:(NSString *)selectedItem {
    [self loadWorkingCopyAndUnlock:self.databaseMetadata viewController:viewController key:key selectedItem:selectedItem completion:nil];
}

- (void)loadWorkingCopyAndUnlock:(DatabaseMetadata*)databaseMetadata
                  viewController:(NSViewController*)viewController
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSDate* modDate;
    NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache:databaseMetadata modified:&modDate];
    
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

    
    
    
    
    
    



    if(completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    }
}

- (void)syncAfterSave {
    NSLog(@"syncAfterSave");

    [MacSyncManager.sharedInstance backgroundSyncDatabase:self.databaseMetadata
                                               completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        [self notifyViewsSyncDone:result localWasChanged:localWasChanged error:error];
    }];
}

- (void)performFullInteractiveSync:(NSViewController*)viewController key:(CompositeKeyFactors*)key {
    NSLog(@"performFullInteractiveSync");

    [MacSyncManager.sharedInstance sync:self.databaseMetadata
                          interactiveVC:viewController
                                    key:key
                                   join:NO
                             completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        [self notifyViewsSyncDone:result localWasChanged:localWasChanged error:error];
    }];
}




    






















        
        
        
        
        
    

            
    




    




@end
