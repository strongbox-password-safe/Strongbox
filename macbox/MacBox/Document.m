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
#import "SafeMetaData.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"
#import "NodeDetailsWindowController.h"
#import "BiometricIdHelper.h"

@interface Document ()

@property (strong, nonatomic) ViewModel* model;
@property WindowController* windowController;
@property (strong, nonatomic) CreateFormatAndSetCredentialsWizard *masterPasswordWindowController;

@property CompositeKeyFactors* ckfForRevertWithUnlock;
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
        DatabaseModel *db = [[DatabaseModel alloc] initNew:compositeKeyFactors format:format];
        self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:nil];
    }
    
    return self;
}

- (void)makeWindowControllers {
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    
    [self addWindowController:self.windowController];

    [self setWindowModel:self.model];
}

- (IBAction)saveDocument:(id)sender {
    if(self.model.locked) {
        NSString* loc = NSLocalizedString(@"mac_cannot_save_db_while_locked", @"Cannot save database while it is locked.");
        [Alerts info:loc window:self.windowController.window];
        return;
    }

    [super saveDocument:sender];

    SafeMetaData* safe = [self getSafeMetaData];
    if(safe && safe.isTouchIdEnabled && safe.touchIdPassword) {
        // Autosaving here as I think it makes sense, also avoids issue with Touch ID Password getting out of sync some how
        // Update Touch Id Password
        
//        NSLog(@"Updating Touch ID Password in case is has changed");
        safe.touchIdPassword = self.model.compositeKeyFactors.password;
        safe.touchIdKeyFileDigest = self.model.compositeKeyFactors.keyFileDigest;
    }
    
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate showUpgradeModal:5];
    }
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
        completionHandler(error);
        //self.lastKnownModifiedDate = self.fileModificationDate;
        NSLog(@"saveToURL: %lu - [%@]", (unsigned long)saveOperation, self.fileModificationDate);
    }];
}

- (SafeMetaData*)getSafeMetaData {
    if(!self.model || !self.model.fileUrl) {
        return nil;
    }
    
    return [SafesList.sharedInstance.snapshot firstOrDefault:^BOOL(SafeMetaData * _Nonnull obj) {
        return [obj.fileIdentifier isEqualToString:self.model.fileUrl.absoluteString];
    }];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    [self unblockUserInteraction];
    return [self.model getPasswordDatabaseAsData:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    NSError* error;
    if(![DatabaseModel isAValidSafe:data error:&error]) {
        if(outError != nil) {
            *outError = error;
        }
        
        return NO;
    }

    if(self.ckfForRevertWithUnlock) {
        DatabaseModel* db = [[DatabaseModel alloc] initExisting:data compositeKeyFactors:self.ckfForRevertWithUnlock error:&error];
        
        if(!db) {
            if(outError != nil) {
                *outError = error;
            }
            
            self.ckfForRevertWithUnlock = nil;
            self.selectedItemForUnlock = nil;
            
            if(self.model && !self.model.locked) {
                self.model = [[ViewModel alloc] initLocked:self];
                [self setWindowModel:self.model];
            }
            return NO;
        }
        
        self.model = [[ViewModel alloc] initUnlockedWithDatabase:self database:db selectedItem:self.selectedItemForUnlock];
    }
    else {
        self.model = [[ViewModel alloc] initLocked:self];
    }

    self.ckfForRevertWithUnlock = nil;
    self.selectedItemForUnlock = nil;
    
    dispatch_async(dispatch_get_main_queue(),  ^{
        [self setWindowModel:self.model];
    });
    
    return YES;
}

- (ViewController*)getViewController {
    return (ViewController*)self.windowController.contentViewController;
}

- (void)setWindowModel:(ViewModel*)model {
    [[self getViewController] resetModel:self.model];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    if(fileWrapper.isDirectory) { // Strongbox crashes unless we check if someone is trying to open a package/wrapper...
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
    self.ckfForRevertWithUnlock = compositeKeyFactors;
    self.selectedItemForUnlock = selectedItem;
    
    NSError* error;
    
    // The natural option here would be revertToContents... but it breaks sometimes with Google Drive :(
    // So we try to do all the things it would do...
    
    //    BOOL success = [self revertToContentsOfURL:self.fileURL ofType:self.fileType error:&error];
    
    [self.undoManager removeAllActions]; // Clear undo stack
    NSFileWrapper* wrapper = [[NSFileWrapper alloc] initWithURL:self.fileURL options:NSFileWrapperReadingImmediate error:&error];
    BOOL success = [self readFromFileWrapper:wrapper ofType:self.fileType error:&error];
    if(success) {
        self.fileModificationDate = wrapper.fileAttributes.fileModificationDate;
    }
    
    self.ckfForRevertWithUnlock = nil;
    self.selectedItemForUnlock = nil;

    if(completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    }
}

@end
