//
//  Document.m
//  MacBox
//
//  Created by Mark on 01/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "Document.h"
#import "ViewController.h"
#import "ViewModel.h"
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

@interface Document ()

@property (strong, nonatomic) ViewModel* model;
@property WindowController* windowController;




@property CompositeKeyFactors* credentialsForUnlock;
@property NSString *selectedItemForUnlock;

@end

@implementation Document

+ (BOOL)autosavesInPlace {
    return Settings.sharedInstance.autoSave;
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation {
    return YES;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    return YES;
}

- (instancetype)initWithCredentials:(DatabaseFormat)format compositeKeyFactors:(CompositeKeyFactors *)compositeKeyFactors {
    if (self = [super init]) {
        NSLog(@"initWithCredentials - fileURL: [%@]", self.fileURL);
        DatabaseModel* db = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:compositeKeyFactors];
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:db passwordConfig:Settings.sharedInstance.passwordGenerationConfig];
        self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:nil];
    }
    
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"initWithContentsOfURL - : [%@]", url);

    return [super initWithContentsOfURL:url ofType:typeName error:outError];
}

- (void)makeWindowControllers {
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    [self addWindowController:self.windowController];
    [[self getViewController] setInitialModel:self.model]; 
}

- (ViewController*)getViewController {
    return (ViewController*)self.windowController.contentViewController;
}


- (IBAction)saveDocument:(id)sender {
    NSLog(@"Document::saveDocument");

    if(self.model.locked) {
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
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
        completionHandler(error);
        
        
        NSLog(@"saveToURL: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate, error);
        
        
        
        if (self.model && self.model.databaseMetadata.autoFillEnabled && self.model.databaseMetadata.quickTypeEnabled) {
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database
                                                               databaseUuid:self.model.databaseMetadata.uuid
                                                              displayFormat:self.model.databaseMetadata.quickTypeDisplayFormat];
        }
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListViewForceRefreshNotification object:nil];
        });
    }];
}

- (BOOL)writeSafelyToURL:(NSURL *)url
                  ofType:(NSString *)typeName
        forSaveOperation:(NSSaveOperationType)saveOperation
                   error:(NSError *__autoreleasing  _Nullable *)outError {
    if (url && url.scheme.length) {
        if ([url.scheme isEqualToString:kStrongboxSFTPUrlScheme]) {
            NSLog(@"writeSafelyToURL for SFTP... [%@]", url);
            
            NSData* data = [self dataOfType:typeName error:outError];
            if ( !data ) {
                NSLog(@"Could not get dataOfType");
                return NO;
            }

            
            
            
            
            
            
            DatabaseMetadata* databaseMetadata = [DatabasesManager.sharedInstance getDatabaseByFileUrl:self.fileURL]; 
            
            BOOL success = [MacSyncManager.sharedInstance updateLocalCopyMarkAsRequiringSync:databaseMetadata data:data error:outError];

            if (!success) {
                NSLog(@"Could not updateLocalCopyMarkAsRequiringSync");
                return NO;
            }

            
            





































            
            
            
            NSDate* modDate = NSDate.date; 
            [self setFileModificationDate:modDate];
            
            return YES;
        }
    }

    return [super writeSafelyToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    NSLog(@"Document::dataOfType: [%@]", typeName);
    
    [self unblockUserInteraction];
    return [self getDataFromModel:self.model error:outError];
}




- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {
    NSLog(@"readFromURL: [%@]", url.scheme);
    
    if (url && url.scheme.length) {
        if ([url.scheme isEqualToString:kStrongboxSFTPUrlScheme]) {
            NSLog(@"SFTP - Loading Locked Model...");
            
            
            
            return [self loadLockedModel];
        }
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
        return [self loadLockedModel];
    }
}

- (BOOL)loadLockedModel {
    self.model = [[ViewModel alloc] initLocked:self];
    
    NSLog(@"loadLockedModel: Model initialized [%@]", self.model);
    
    
    

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
        
        if(self.model && !self.model.locked) {
            self.model = [[ViewModel alloc] initLocked:self];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self getViewController] updateModel:self.model];
            });
        }
        
        return NO;
    }
    
    self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:selectedItem];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self getViewController] updateModel:self.model];
    });
        
    return YES;
}




- (void)presentedItemDidChange {
    if(!Settings.sharedInstance.detectForeignChanges) {
        return;
    }
    
    if(!self.fileModificationDate) {
        NSLog(@"presentedItemDidChange but NO self.lastKnownModifiedDate?");
        return;
    }
    
    if([self fileHasBeenModified]) {
        dispatch_async(dispatch_get_main_queue(), ^{
           [[self getViewController] onFileChangedByOtherApplication];
        });
    }
}

- (BOOL)fileHasBeenModified {
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

- (void)revertWithUnlock:(CompositeKeyFactors *)compositeKeyFactors
          viewController:(NSViewController*)viewController
            selectedItem:(NSString *)selectedItem
              completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSLog(@"Document::revertWithUnlock: [%@]", self.fileURL);

    if ( self.fileURL && self.fileURL.scheme.length ) {
        if ( [self.fileURL.scheme isEqualToString:kStrongboxSFTPUrlScheme] ) {
            NSLog(@"SFTP - revertWithUnlock... Loading Model...");
            
            
            
            
            
            
            
            DatabaseMetadata* databaseMetadata = [DatabasesManager.sharedInstance getDatabaseByFileUrl:self.fileURL];

            [self syncWorkingCopyAndUnlock:databaseMetadata viewController:viewController key:compositeKeyFactors selectedItem:selectedItem completion:completion];
        }
        else {
            [self legacyRevertWithUnlock:compositeKeyFactors viewController:viewController selectedItem:selectedItem completion:completion];
        }
    }
    else {
        [self legacyRevertWithUnlock:compositeKeyFactors viewController:viewController selectedItem:selectedItem completion:completion];
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
        if (result == kSyncAndMergeResultUserCancelled) {
            NSLog(@"TODO: User Cancelled ");
        }
        else if ( result == kSyncAndMergeError ) {
            if(completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, error);
                });
            }
        }
        else if ( result == kSyncAndMergeSuccess ) {
            [self loadWorkingCopyAndUnlock:databaseMetadata
                            viewController:viewController
                                       key:key
                              selectedItem:selectedItem
                                completion:completion];
        }
        else {
            
            NSLog(@"TODO: TODO: Check Result   kSyncAndMergeResultUserInteractionRequired,        
        }
    }];
}

- (void)loadWorkingCopyAndUnlock:(DatabaseMetadata*)databaseMetadata
                  viewController:(NSViewController*)viewController
                             key:(CompositeKeyFactors*)key
                    selectedItem:(NSString *)selectedItem
                      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    NSURL* workingCopy = [WorkingCopyManager.sharedInstance getLocalWorkingCache:databaseMetadata];
    
    if (workingCopy == nil) {
        
        NSLog(@"        
        return;
    }
    
    
    
    NSError* error;
    NSData* sftpData = [NSData dataWithContentsOfURL:workingCopy options:kNilOptions error:&error];
    if ( error ) {
        
        NSLog(@"        
        return;
    }

    NSLog(@"Read working copy bytes OK [%ld] - loading model", sftpData.length);
    BOOL success = [self loadModelFromData:sftpData key:key selectedItem:selectedItem outError:&error];

    if(completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    }
}

- (void)setDatabaseMetadata:(id)databaseMetadata {
    [self.model setDatabaseMetadata:databaseMetadata];
}




- (NSData*)getDataFromModel:(ViewModel*)model error:(NSError **)outError {
    __block NSData *ret = nil;
    __block NSError *retError = nil;
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);

    [self.model getPasswordDatabaseAsData:^(BOOL userCancelled, NSData * _Nullable data, NSString * _Nullable debugXml, NSError * _Nullable error) {
        
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

@end
