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

@interface Document ()

@property (strong, nonatomic) ViewModel* model;
@property WindowController* windowController;
@property (strong, nonatomic) CreateFormatAndSetCredentialsWizard *masterPasswordWindowController;

@end

@implementation Document

- (instancetype)initWithCredentials:(DatabaseFormat)format password:(NSString*)password keyFileDigest:(NSData*)keyFileDigest {
    self = [super init];
    
    if (self) {
        self.model = [[ViewModel alloc] initNewWithSampleData:self format:format password:password keyFileDigest:keyFileDigest];
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
        [Alerts info:@"Cannot save database while it is locked." window:self.windowController.window];
        return;
    }

    [super saveDocument:sender];

    SafeMetaData* safe = [self getSafeMetaData];
    if(safe && safe.isTouchIdEnabled && safe.touchIdPassword) {
        // Autosaving here as I think it makes sense, also avoids issue with Touch ID Password getting out of sync some how
        // Update Touch Id Password
        
        NSLog(@"Updating Touch ID Password in case is has changed");
        safe.touchIdPassword = self.model.masterPassword;
        safe.touchIdKeyFileDigest = self.model.masterKeyFileDigest;
    }
    
    if(![Settings sharedInstance].fullVersion && ![Settings sharedInstance].freeTrial){
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate showUpgradeModal:5];
    }
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
//    NSLog(@"Start dataOfType");
//    NSDate *methodStart = [NSDate date];
//
    [self unblockUserInteraction];
    
    NSData* ret = [self.model getPasswordDatabaseAsData:outError];
    
//    NSDate *methodFinish = [NSDate date];
//    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
//    NSLog(@"dataOfType executionTime = %f", executionTime);

    return ret;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    //NSLog(@"Start readFromData");
    //NSDate *methodStart = [NSDate date];

    self.model = [[ViewModel alloc] initWithData:data document:self];
    
    if(!self.model) {
        if(outError != nil) {
            *outError = [Utils createNSError:@"This is not a valid file." errorCode:-1];
        }
        
        return NO;
    }
        
    [self setWindowModel:self.model];
    
    //NSDate *methodFinish = [NSDate date];
    //NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    //NSLog(@"readFromData executionTime = %f", executionTime);

    return YES;
}

- (void)setWindowModel:(ViewModel*)model {
    ViewController *vc = (ViewController*)self.windowController.contentViewController;
    
    [vc setModel:self.model];
}

+ (BOOL)autosavesInPlace {
    return Settings.sharedInstance.autoSave;
}

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation {
    return YES;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    return YES;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    if(fileWrapper.isDirectory) { // Strongbox crashes unless we check if someone is trying to open a package/wrapper...
        if(outError != nil) {
            *outError = [Utils createNSError:@"Strongbox cannot open File Wrappers, Directories or Compressed Packages like this. Please dorectly select a KeePass or Password Safe database file." errorCode:-1];
        }
        return NO;
    }
    
    return [super readFromFileWrapper:fileWrapper ofType:typeName error:outError];
}

@end
