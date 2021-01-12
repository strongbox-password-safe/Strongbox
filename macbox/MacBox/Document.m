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
#import "Alerts.h"
#import "CreateFormatAndSetCredentialsWizard.h"
#import "WindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "NSArray+Extensions.h"
#import "NodeDetailsViewController.h"
#import "BiometricIdHelper.h"
#import "DatabasesManagerView.h"
#import "AutoFillManager.h"
#import "SampleItemsGenerator.h"
#import "DatabaseModelConfig.h"
#import "Serializator.h"

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
        DatabaseModel* db = [[DatabaseModel alloc] initWithFormat:format compositeKeyFactors:compositeKeyFactors];
        [SampleItemsGenerator addSampleGroupAndRecordToRoot:db passwordConfig:Settings.sharedInstance.passwordGenerationConfig];
        self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:nil];
    }
    
    return self;
}

- (void)makeWindowControllers {
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    [self addWindowController:self.windowController];
    [[self getViewController] setInitialModel:self.model]; 
}

- (IBAction)saveDocument:(id)sender {
    if(self.model.locked) {
        NSString* loc = NSLocalizedString(@"mac_cannot_save_db_while_locked", @"Cannot save database while it is locked.");
        [Alerts info:loc window:self.windowController.window];
        return;
    }

    [super saveDocument:sender];
    
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate randomlyShowUpgradeMessage];
    }
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
        completionHandler(error);
        
        NSLog(@"saveToURL: %lu - [%@]", (unsigned long)saveOperation, self.fileModificationDate);
        
        
        
        if (self.model && self.model.databaseMetadata.autoFillEnabled && self.model.databaseMetadata.quickTypeEnabled) {
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:self.model.database databaseUuid:self.model.databaseMetadata.uuid];
        }
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:kDatabasesListViewForceRefreshNotification object:nil];
        });
    }];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    [self unblockUserInteraction];
    return [self getDataFromModel:self.model error:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    if(self.credentialsForUnlock) {
        NSError* error;
        if(![Serializator isValidDatabaseWithPrefix:data error:&error]) {
            if(outError != nil) {
                *outError = error;
            }
            
            return NO;
        }

        DatabaseModel *db = [self getModelFromData:data error:&error];
        
        if(!db) {
            if(outError != nil) {
                *outError = error;
            }
            
            self.credentialsForUnlock = nil;
            self.selectedItemForUnlock = nil;
            
            if(self.model && !self.model.locked) {
                self.model = [[ViewModel alloc] initLocked:self];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self getViewController] updateModel:self.model];
                });
            }
            
            return NO;
        }
        
        self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:self.selectedItemForUnlock];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self getViewController] updateModel:self.model];
        });
    }
    else {
        self.model = [[ViewModel alloc] initLocked:self];
        NSLog(@"Model initialized [%@]", self.model);
        
        
        
    }

    self.credentialsForUnlock = nil;
    self.selectedItemForUnlock = nil;
        
    return YES;
}

- (ViewController*)getViewController {
    return (ViewController*)self.windowController.contentViewController;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    if(fileWrapper.isDirectory) { 
        if(outError != nil) {
            NSString* loc = NSLocalizedString(@"mac_strongbox_cant_open_file_wrappers", @"Strongbox cannot open File Wrappers, Directories or Compressed Packages like this. Please directly select a KeePass or Password Safe database file.");
            *outError = [Utils createNSError:loc errorCode:-1];
        }
        return NO;
    }
    
    return [super readFromFileWrapper:fileWrapper ofType:typeName error:outError];
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
            selectedItem:(NSString *)selectedItem
              completion:(void (^)(BOOL, NSError * _Nullable))completion {
    self.credentialsForUnlock = compositeKeyFactors;
    self.selectedItemForUnlock = selectedItem;
    
    NSError* error;
    
    
    
    
    
    
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

- (DatabaseModel*)getModelFromData:(NSData*)data error:(NSError **)outError {
    __block DatabaseModel* db = nil;
    __block NSError* retError = nil;

    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    
    [Serializator fromLegacyData:data
                              ckf:self.credentialsForUnlock
                           config:DatabaseModelConfig.defaults
                       completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
        
        db = model;
        retError = error;
        dispatch_group_leave(group);
    }];
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    *outError = retError;
    return db;
}



- (void)close {
    [super close];

    
    
    if (NSDocumentController.sharedDocumentController.documents.count == 0) {
        [DatabasesManagerView show:NO];
    }
}

@end
