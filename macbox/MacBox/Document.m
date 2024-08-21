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
#import "WindowController.h"
#import "Settings.h"
#import "AppDelegate.h"
#import "NSArray+Extensions.h"
#import "BiometricIdHelper.h"
#import "AutoFillManager.h"
#import "SampleItemsGenerator.h"
#import "DatabaseModelConfig.h"
#import "Serializator.h"
#import "MacUrlSchemes.h"
#import "MacSyncManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "MBProgressHUD.h"
#import "Strongbox-Swift.h"
#import "DatabasesManagerVC.h"

NSString* const kModelUpdateNotificationFullReload = @"kModelUpdateNotificationFullReload"; 
NSString* const kGenericRefreshAllDatabaseViewsNotification = @"genericRefreshAllDatabaseViews";

@interface Document ()

@property WindowController* windowController;
@property BOOL isPromptingAboutUnderlyingFileChange;
@property (nullable, readonly) NextGenSplitViewController* splitViewController;

@end

@implementation Document

- (void)dealloc {
    slog(@"😎 Document DEALLOC...");
}

- (MacDatabasePreferences *)databaseMetadata {
    if ( self.viewModel ) {
        return self.viewModel.databaseMetadata;
    }
    else if ( self.fileURL ) {
        MacDatabasePreferences* ret = [MacDatabasePreferences fromUrl:self.fileURL];
        
        if ( ret == nil ) {
            slog(@"🔴 WARNWARN: NIL MacDatabasePreferences - None Found in Document::databaseMetadata for URL: [%@]", self.fileURL);
            ret = [MacDatabasePreferences addOrGet:self.fileURL]; 
        }
        else {
            
        }
        
        return ret;
    }
    else {
        slog(@"🔴 WARNWARN: NIL fileUrl in Document::databaseMetadata");
        return nil;
    }
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

- (void)makeWindowControllers {


    self.windowController = [[NSStoryboard storyboardWithName:@"NextGen" bundle:nil] instantiateInitialController];
    
    [self addWindowController:self.windowController];
    
    [self.windowController changeContentView]; 
    
    [self listenForNotifications];
}

- (void)listenForNotifications {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseReloaded:)
                                               name:kDatabaseReloadedNotification
                                             object:nil];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onLockStateChanged:)
                                               name:kDatabasesCollectionLockStateChangedNotification
                                             object:nil];
}

- (void)onLockStateChanged:(id)notification {
    NSString* databaseUuid = ((NSNotification*)notification).object;
    
    if ( ![databaseUuid isEqualToString:self.databaseMetadata.uuid] ) {
        return;
    }
    

    
    [self bindToLockState];
}

- (void)bindToLockState {


    Model* model = [DatabasesCollection.shared getUnlockedWithUuid:self.databaseMetadata.uuid];
    
    if ( !self.viewModel || self.viewModel.locked ) {
        if ( model ) {


            _viewModel = [[ViewModel alloc] initUnlocked:self databaseUuid:self.databaseMetadata.uuid model:model];
            [self bindWindowControllerAfterLockStatusChange];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
                if ( !self.viewModel.locked ) {
                    [self.viewModel restartBackgroundAudit];
                }
            });
        }
    }
    else {
        if ( !model ) {
            slog(@"✅ Document::bindToLockState => Newly Locked");

            _viewModel = [[ViewModel alloc] initLocked:self databaseUuid:self.databaseMetadata.uuid];
            [self bindWindowControllerAfterLockStatusChange];
        }
    }
}

- (void)onDatabaseReloaded:(id)notification {
    NSString* databaseUuid = ((NSNotification*)notification).object;
    
    if ( [databaseUuid isEqualToString:self.databaseMetadata.uuid] ) {
        slog(@"Document::onDatabaseReloaded => Notifying views to fully reload");
        
        [self notifyFullModelReload];
    }
}




- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing  _Nullable *)outError {


    if ( !self.viewModel ) { 
        _viewModel = [[ViewModel alloc] initLocked:self databaseUuid:self.databaseMetadata.uuid];
    }
    
    [self bindToLockState];
    
    return YES;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    slog(@"readFromFileWrapper");

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
    slog(@"🔴 WARNWARN: Document::readFromData called %ld - [%@]", data.length, typeName);
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
    slog(@"✅ Document::saveDocument");

    if(self.viewModel.locked || self.viewModel.isEffectivelyReadOnly) {
        slog(@"🔴 WARNWARN: Document is Read-Only or Locked! How did you get here?");
        return;
    }

    [super saveDocument:sender];
}

- (void)saveToURL:(NSURL *)url
           ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
completionHandler:(void (^)(NSError * _Nullable))completionHandler {
    slog(@"✅ Document::saveToURL: %lu - [%@] - [%@]", (unsigned long)saveOperation, self.fileModificationDate.friendlyDateTimeStringBothPrecise, url);
    
    BOOL updateQueued = [DatabasesCollection.shared updateAndQueueSyncWithUuid:self.databaseMetadata.uuid allowInteractiveSync:YES];
    
    if ( !updateQueued ) {
        slog(@"🔴 Could not queue a save for this database. Is it read-only or locked?!");
        completionHandler([Utils createNSError:@"🔴 Could not queue a save for this database. Is it read-only or locked?!" errorCode:-1]);
    }
    else {
        if (saveOperation != NSSaveToOperation) {
            [self updateChangeCount:NSChangeCleared];
        }
                
        completionHandler(nil);
    }
}






- (void)encodeRestorableStateWithCoder:(NSCoder *) coder {

    
    [coder encodeObject:self.fileURL.absoluteString forKey:kDocumentRestorationNSCoderKeyForUrl];
    
    [super encodeRestorableStateWithCoder:coder];
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



- (NextGenSplitViewController*)splitViewController {
    if ( [self.windowController.contentViewController isKindOfClass:NextGenSplitViewController.class] ) { 
        NextGenSplitViewController* vc = (NextGenSplitViewController*)self.windowController.contentViewController;
        return vc;
    }
    else {
        return nil;
    }
}

- (BOOL)isEditsInProgress {
    if ( self.splitViewController ) { 
        return self.splitViewController.editsInProgress;
    }
    
    return NO;
}
- (BOOL)isDisplayingEditSheet {
    if ( self.splitViewController ) { 
        return self.splitViewController.isDisplayingEditSheet;
    }
    
    return NO;
}




- (void)close {
    
    
    
    [self closeAllWindows];
    
    if ( Settings.sharedInstance.lockDatabaseOnWindowClose ) {
        [DatabasesCollection.shared forceLockWithUuid:self.databaseMetadata.uuid];
    }
    
    self.databaseMetadata.userRequestOfflineOpenEphemeralFlagForDocument = NO; 
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
    [super close];
}

- (void)initiateLockSequence {
    slog(@"✅ Document::initiateLockSequence called...");

    if( !self.viewModel && self.viewModel.locked ) {
        return;
    }
    
    BOOL isEditing = [self isEditsInProgress];

    slog(@"Document::initiateLockSequence called... isEditing = %hhd", isEditing);

    if ( isEditing ) {
        if (!Settings.sharedInstance.lockEvenIfEditing ) {
            slog(@"⚠️ NOT Locking because there is an edit in progress.");
            return;
        }
        else {
            slog(@"⚠️ Locking even though there is an edit in progress to to configuration.");
        }
    }
    
    if ( self.isDocumentEdited ) {
        slog(@"✅ Document::initiateLockSequence isDocumentEdited = [YES]");

        NSString* loc = NSLocalizedString(@"generic_locking_ellipsis", @"Locking...");
        
        [macOSSpinnerUI.sharedInstance show:loc viewController:self.windowController.contentViewController];
        
        [self saveDocumentWithDelegate:self didSaveSelector:@selector(onSaveBeforeLockingCompletion:) contextInfo:nil];
    }
    else {
        
        
        [self onSaveBeforeLockingCompletion:nil];
    }
}

- (void)closeAllWindows {

    
    if ( !self.viewModel.locked ) {
        if ( [self.windowController.contentViewController isKindOfClass:NextGenSplitViewController.class] ) { 
            
            
            
            NextGenSplitViewController* vc = (NextGenSplitViewController*)self.windowController.contentViewController;
            
            [vc onLockDoneKillAllWindows];
        }
    }
}

- (IBAction)onSaveBeforeLockingCompletion:(id)sender {
    slog(@"Document::onSaveBeforeLockingCompletion called...");
    
    [macOSSpinnerUI.sharedInstance dismiss];
    
    
    
    if ( [self.windowController.contentViewController isKindOfClass:NextGenSplitViewController.class] ) { 
        
        NextGenSplitViewController* vc = (NextGenSplitViewController*)self.windowController.contentViewController;
        
        
        [vc onLockDoneKillAllWindows];
    }
    
    [self forceLock];
 
    
    
    if ( Settings.sharedInstance.clearClipboardEnabled ) {
        AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
        [appDelegate clearClipboardWhereAppropriate];
    }
}

- (void)forceLock {
    slog(@"✅ Document::forceLock called");
    
    if( self.isDocumentEdited ) {
        slog(@"⚠️ Cannot lock document with edits!");
        return;
    }
    
    
    
    [self.undoManager removeAllActions];
    
    [DatabasesCollection.shared forceLockWithUuid:self.databaseMetadata.uuid];
    
    _viewModel = [[ViewModel alloc] initLocked:self databaseUuid:self.databaseMetadata.uuid];
    [self bindWindowControllerAfterLockStatusChange];
}

- (void)bindWindowControllerAfterLockStatusChange {
    WindowController* wc = self.windowController;
    
    
    
    if ( NSThread.isMainThread ) {
        [wc changeContentView];
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [wc changeContentView];
        });
    }
}



- (void)onDatabaseChangedByExternalOther {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _onDatabaseChangedByExternalOther];
    });
}

- (void)_onDatabaseChangedByExternalOther {
    if(self.isPromptingAboutUnderlyingFileChange) {
        slog(@"Already in Use...");
        return;
    }
    
    self.isPromptingAboutUnderlyingFileChange = YES;
    
    if (self.viewModel && !self.viewModel.locked) {
        slog(@"ViewController::onDatabaseChangedByExternalOther - Reloading...");
        
        if( !self.viewModel.document.isDocumentEdited ) { 
            if( !self.databaseMetadata.autoReloadAfterExternalChanges ) {
                NSString* loc = NSLocalizedString(@"mac_db_changed_externally_reload_yes_or_no", @"The database has been changed by another application, would you like to reload this latest version and automatically unlock?");

                [MacAlerts yesNo:loc
                          window:self.windowController.window
                      completion:^(BOOL yesNo) {
                    if(yesNo) {
                        NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                        [self showPopupChangeToastNotification:loc];
                        
                        [DatabasesCollection.shared syncWithUuid:self.databaseMetadata.uuid
                                                allowInteractive:YES
                                             suppressErrorAlerts:NO
                                                 ckfsForConflict:self.viewModel.compositeKeyFactors
                                                      completion:nil];
                    }
                    
                    self.isPromptingAboutUnderlyingFileChange = NO;
                }];
                return;
            }
            else {
                NSString* loc = NSLocalizedString(@"mac_db_reloading_after_external_changes_popup_notification", @"Reloading after external changes...");

                [self showPopupChangeToastNotification:loc];

                [DatabasesCollection.shared syncWithUuid:self.databaseMetadata.uuid
                                        allowInteractive:YES
                                     suppressErrorAlerts:NO
                                         ckfsForConflict:self.viewModel.compositeKeyFactors
                                              completion:nil];

                self.isPromptingAboutUnderlyingFileChange = NO;

                return;
            }
        }
        else {
            slog(@"Local Changes Present... ignore this, we can't auto reload...");
        }
    }
    else {
        slog(@"Ignoring File Change by Other Application because Database is locked/not set.");
    }
    
    self.isPromptingAboutUnderlyingFileChange = NO;
}



- (void)showPopupChangeToastNotification:(NSString*)message {
    [self showToastNotification:message error:NO];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.windowController.window.isMiniaturized ) {
        slog(@"Not Showing Popup Change notification because window is miniaturized");
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



- (void)import2FAToken:(OTPToken *)token {
    [self.splitViewController import2FATokenWithToken:token];
}

@end
