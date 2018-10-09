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
#import "ChangeMasterPasswordWindowController.h"
#import "WindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "SafeMetaData.h"
#import "SafesList.h"
#import "NSArray+Extensions.h"

@interface Document ()

@property (strong, nonatomic) ViewModel* model;
@property WindowController* windowController;
@property (strong, nonatomic) ChangeMasterPasswordWindowController *masterPasswordWindowController;

@end

@implementation Document

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self.model = [[ViewModel alloc] initNewWithSampleData:self];
        self.dirty = YES;
    }
    
    return self;
}

- (void)makeWindowControllers {
    // Override to return the Storyboard file name of the document.
    
    self.windowController = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"Document Window Controller"];
    
    [self addWindowController:self.windowController];

    [self setWindowModel:self.model];
}

- (IBAction)saveDocument:(id)sender
{
    if(self.model.locked) {
        [Alerts info:@"Cannot save safe while it is locked." window:self.windowController.window];
        return;
    }
    
    if(!self.model.masterPasswordIsSet) {
        self.masterPasswordWindowController = [[ChangeMasterPasswordWindowController alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
        
        self.masterPasswordWindowController.titleText = @"Set a Master Password for New Safe";
        
        [self.windowController.window beginSheet:self.masterPasswordWindowController.window
                               completionHandler:^(NSModalResponse returnCode) {
                                   if(returnCode == NSModalResponseOK) {
                                       [self.model setMasterPassword:self.masterPasswordWindowController.confirmedPassword];
                                       return [super saveDocument:sender];
                                   }
                               }];
    }
    else {
        [super saveDocument:sender];
    
        SafeMetaData* safe = [self getSafeMetaData];
        if(safe && safe.isTouchIdEnabled && safe.touchIdPassword) {
            // Autosaving here as I think it makes sense, also avoids issue with Touch ID Password getting out of sync some how
            // Update Touch Id Password
            
            NSLog(@"Updating Touch ID Password in case is has changed");
            safe.touchIdPassword = self.model.masterPassword;
        }
        
        if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
            AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
            [appDelegate showUpgradeModal:5];
        }
        
        return;
    }
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * __nullable errorOrNil))completionHandler {
    // Update the Last Update Fields
    
    [self.model defaultLastUpdateFieldsToNow];
    
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError * __nullable errorOrNil) {
        if (!errorOrNil) {
            self.dirty = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                ViewController *vc = (ViewController*)self.windowController.contentViewController;
                [vc updateDocumentUrl]; // Refresh View to pick up document URL changes
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts error:errorOrNil window:self.windowController.window]; // TODO: Should we do this here? 
            });
            
            NSLog(@"Error during saveToURL: %@", errorOrNil);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(errorOrNil);
        });
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
    return [self.model getPasswordDatabaseAsData:outError];
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    self.model = [[ViewModel alloc] initWithData:data document:self];
    
    if(!self.model) {
        if(outError != nil) {
            *outError = [Utils createNSError:@"This is not a valid file." errorCode:-1];
        }
        
        return NO;
    }
    
    self.dirty = NO;
    
    [self setWindowModel:self.model];
    
    return YES;
}

- (void)setWindowModel:(ViewModel*)model {
    ViewController *vc = (ViewController*)self.windowController.contentViewController;
    
    [vc setModel:self.model];
}

- (BOOL)isDocumentEdited {
    return self.dirty;
}

- (BOOL)hasUnautosavedChanges {
    return self.dirty;
}

- (BOOL)hasUndoManager {
    return NO;
}

+ (BOOL)autosavesInPlace {
    return NO;
}

- (void)setDirty:(BOOL)dirty {
    _dirty = dirty;
    self.windowController.dirty = YES;
}

@end
