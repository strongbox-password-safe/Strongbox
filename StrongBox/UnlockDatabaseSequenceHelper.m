//
//  OpenSafeSequenceHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "UnlockDatabaseSequenceHelper.h"
#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "Utils.h"
#import "AutoFillManager.h"

#import "StrongboxiOSFilesManager.h"
#import "StrongboxUIDocument.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "BiometricsManager.h"
#import "BookmarksHelper.h"
#import "YubiManager.h"
#import "AppPreferences.h"
#import "Kdbx4Database.h"
#import "Kdbx4Serialization.h"
#import "KeePassCiphers.h"
#import "NSDate+Extensions.h"
#import "FilesAppUrlBookmarkProvider.h"

#import <FileProvider/FileProvider.h>
#import "VirtualYubiKeys.h"
#import <Foundation/FoundationErrors.h>
#import "Serializator.h"

#import "IOSCompositeKeyDeterminer.h"
#import "Platform.h"
#import "DuressActionHelper.h"

#import "SyncManager.h"
#import "WorkingCopyManager.h"
#import "Constants.h"

#ifndef IS_APP_EXTENSION

#import "OfflineDetector.h"

#endif

#if TARGET_OS_IPHONE

#import "DatabasePreferences.h"

#else

#endif


@interface UnlockDatabaseSequenceHelper () <UIDocumentPickerDelegate>



@property (nonnull) UIViewController* viewController;
@property (nonnull, readonly) DatabasePreferences* database;
@property (nonnull) NSString* databaseUuid;

@property BOOL isAutoFillOpen;
@property BOOL explicitOffline;
@property BOOL explicitOnline;
@property (nonnull) UnlockDatabaseCompletionBlock completion;



@property BOOL unlockedWithConvenienceFactors;
@property CompositeKeyFactors* relocationFactors;

@end

@implementation UnlockDatabaseSequenceHelper

+ (instancetype)helperWithViewController:(UIViewController *)viewController database:(DatabasePreferences *)database {
    return [self helperWithViewController:viewController database:database isAutoFillOpen:NO explicitOffline:NO explicitOnline:NO];
}

+ (instancetype)helperWithViewController:(UIViewController*)viewController
                                database:(DatabasePreferences*)database
                          isAutoFillOpen:(BOOL)isAutoFillOpen
                         explicitOffline:(BOOL)explicitOffline
                          explicitOnline:(BOOL)explicitOnline {
    return [[UnlockDatabaseSequenceHelper alloc] initWithViewController:viewController
                                                                   safe:database
                                                         isAutoFillOpen:isAutoFillOpen
                                                        explicitOffline:explicitOffline
                                                         explicitOnline:explicitOnline];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                                  safe:(DatabasePreferences*)safe
                        isAutoFillOpen:(BOOL)isAutoFillOpen
                       explicitOffline:(BOOL)explicitOffline
                        explicitOnline:(BOOL)explicitOnline {
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.databaseUuid = safe.uuid;
        self.isAutoFillOpen = isAutoFillOpen;
        self.explicitOffline = explicitOffline;
        self.explicitOnline = explicitOnline;
    }
    
    return self;
}

- (DatabasePreferences *)database {
    return [DatabasePreferences fromUuid:self.databaseUuid];
}

- (void)beginUnlockSequence:(UnlockDatabaseCompletionBlock)completion {
    return [self beginUnlockSequence:NO biometricPreCleared:NO explicitManualUnlock:NO explicitEagerSync:NO completion:completion];
}

- (void)beginUnlockSequence:(BOOL)isAutoFillQuickTypeOpen
        biometricPreCleared:(BOOL)biometricPreCleared
       explicitManualUnlock:(BOOL)explicitManualUnlock
          explicitEagerSync:(BOOL)explicitEagerSync
                 completion:(UnlockDatabaseCompletionBlock)completion {
    self.completion = completion;
    
    IOSCompositeKeyDeterminer* determiner = [IOSCompositeKeyDeterminer determinerWithViewController:self.viewController
                                                                                           database:self.database
                                                                                     isAutoFillOpen:self.isAutoFillOpen
                                                         transparentAutoFillBackgroundForBiometrics:isAutoFillQuickTypeOpen
                                                                                biometricPreCleared:biometricPreCleared
                                                                                noConvenienceUnlock:explicitManualUnlock];
    
    [determiner getCredentials:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        if (result == kGetCompositeKeyResultSuccess) {
            self.unlockedWithConvenienceFactors = fromConvenience;
            [self beginUnlockWithCredentials:factors explicitEagerSync:explicitEagerSync];
        }
        else if (result == kGetCompositeKeyResultDuressIndicated ) {
            [DuressActionHelper performDuressAction:self.viewController database:self.database isAutoFillOpen:self.isAutoFillOpen completion:self.completion];
        }
        else if (result == kGetCompositeKeyResultError) {
            self.completion(kUnlockDatabaseResultError, nil, error);
        }
        else {
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
    }];
}



- (BOOL)userIsLikelyOffline {
#if !defined(IS_APP_EXTENSION) && !defined(NO_OFFLINE_DETECTION)
    return OfflineDetector.sharedInstance.isOffline;
#endif
    return NO;
}

- (void)beginUnlockWithCredentials:(CompositeKeyFactors*)factors explicitEagerSync:(BOOL)explicitEagerSync {
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.database.uuid];
  
    if ( self.explicitOnline && self.explicitOffline ) {
        slog(@"🔴 WARNWARN - Something very wrong, explicit Online and Offline Request to Unlock!");
    }
    
    BOOL offline = (self.explicitOffline || self.database.forceOpenOffline) && !self.explicitOnline;

    if( self.isAutoFillOpen || offline ) {
        slog(@"✅ beginUnlockWithCredentials - AutoFill or Explicit Offline Request Mode... Unlocking Local if available.");
        
        if(localCopyUrl == nil) {
            [Alerts warn:self.viewController
                   title:NSLocalizedString(@"open_sequence_couldnt_open_local_title", @"Could Not Open Offline")
                 message:NSLocalizedString(@"open_sequence_couldnt_open_local_message", @"Could not open Strongbox's local copy of this database. A online sync is required.")];
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            return;
        }

        BOOL forceReadOnly = !self.isAutoFillOpen && !AppPreferences.sharedInstance.isPro;
        [self unlockLocalCopy:factors forceReadOnly:forceReadOnly offline:YES];
    }
    else {
        SyncStatus *status = [SyncManager.sharedInstance getSyncStatus:self.database];
        BOOL syncStateGood = status.state == kSyncOperationStateInitial || status.state == kSyncOperationStateDone;
        
        syncStateGood = syncStateGood | self.database.persistLazyEvenLastSyncErrors; 
        
        if ( !explicitEagerSync && syncStateGood && localCopyUrl && self.database.storageProvider != kLocalDevice && self.database.lazySyncMode && !self.explicitOnline ) { 
            
            
            
            [self beginLazySyncModeWithCredentials:factors];
        }
        else {
            [self beginEagerSyncModeWithCredentials:factors];
        }
    }
}

- (void)beginLazySyncModeWithCredentials:(CompositeKeyFactors*)factors {
    slog(@"✅ beginLazySyncModeWithCredentials");

    [self unlockLocalCopy:factors forceReadOnly:NO offline:self.database.forceOpenOffline];
}

- (void)beginEagerSyncModeWithCredentials:(CompositeKeyFactors*)factors {
    slog(@"✅ beginEagerSyncModeWithCredentials");
    
    NSURL* localCopyUrl = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.database.uuid];

    BOOL userLikelyOffline = [self userIsLikelyOffline];
    
    BOOL isPro = AppPreferences.sharedInstance.isPro;

    BOOL userOfflineAndConfiguredForImmediateOffline = userLikelyOffline && self.database.offlineDetectedBehaviour == kOfflineDetectedBehaviourImmediateOffline;
    
    if( userOfflineAndConfiguredForImmediateOffline ) {
        if(localCopyUrl == nil) {
            [Alerts warn:self.viewController
                   title:NSLocalizedString(@"open_sequence_couldnt_open_local_title", @"Could Not Open Offline")
                 message:NSLocalizedString(@"open_sequence_couldnt_open_local_message", @"Could not open Strongbox's local copy of this database. A online sync is required.")];
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            return;
        }
        
        BOOL forceReadOnly = !self.isAutoFillOpen && !isPro;
        [self unlockLocalCopy:factors forceReadOnly:forceReadOnly offline:YES];
        return;
    }

    BOOL offlinePossible = localCopyUrl != nil;
    BOOL notLocalDevice = self.database.storageProvider != kLocalDevice;
    BOOL offerIfOfflineDetected = self.database.offlineDetectedBehaviour != kOfflineDetectedBehaviourTryConnectThenAsk;

    if ( userLikelyOffline && offlinePossible && notLocalDevice && offerIfOfflineDetected ) {
        NSString* primaryStorageDisplayName = [SyncManager.sharedInstance getPrimaryStorageDisplayName:self.database];
        NSString* loc1 = NSLocalizedString(@"open_sequence_user_looks_offline_open_local_ro_fmt", "It looks like you may be offline and '%@' may not be reachable. Would you like to open in offline mode instead?\n\nNB: You can also edit offline in the Pro version.");
        NSString* loc2 = NSLocalizedString(@"open_sequence_user_looks_offline_open_local_fmt", "It looks like you may be offline and '%@' may not be reachable. Would you like to open in offline mode instead?");

        NSString* loc = isPro ? loc2 : loc1;
        NSString* message = [NSString stringWithFormat:loc, primaryStorageDisplayName];
        
        [Alerts twoOptionsWithCancel:self.viewController
                               title:NSLocalizedString(@"open_sequence_yesno_use_local_copy_title", @"Open Offline?")
                             message:message
                   defaultButtonText:NSLocalizedString(@"open_sequence_yes_use_local_copy_option", @"Yes, Open Offline")
                    secondButtonText:NSLocalizedString(@"open_sequence_yesno_use_offline_cache_no_try_connect_option", @"No, Try to connect anyway")
                              action:^(int response) {
            if (response == 0) { 
                [self unlockLocalCopy:factors forceReadOnly:!isPro offline:YES];
            }
            else if (response == 1) { 
                [self syncAndUnlock:factors];
            }
            else {
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
        }];
    }
    else {
        [self syncAndUnlock:factors];
    }
}

- (void)syncAndUnlock:(CompositeKeyFactors*)factors {
    [self syncAndUnlock:YES factors:factors];
}

- (void)syncAndUnlock:(BOOL)join factors:(CompositeKeyFactors*)factors {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
    });

    [SyncManager.sharedInstance sync:self.database
                       interactiveVC:self.viewController
                                 key:factors
                                join:join
                          completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
             
            if (result == kSyncAndMergeResultUserInteractionRequired) {
                
                [self syncAndUnlock:NO factors:factors];
            }
            else if (result == kSyncAndMergeResultUserCancelled) {
                
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
            else if (result == kSyncAndMergeError) {
                [self handleSyncAndMergeError:factors error:error];
            }
            else if ( result == kSyncAndMergeSuccess || result == kSyncAndMergeUserPostponedSync ) {
                
                [self unlockLocalCopy:factors forceReadOnly:NO offline:NO];
            }
            else {
                slog(@"WARNWARN: Unknown response from Sync: %lu", (unsigned long)result);
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
        });
    }];
}

- (void)handleSyncAndMergeError:(CompositeKeyFactors*)factors error:(NSError*)error {
    slog(@"Unlock Interactive Sync Error: [%@]", error);
    if (self.database.storageProvider == kFilesAppUrlBookmark && [self errorIndicatesWeShouldAskUseToRelocateDatabase:error]) {
        [self askAboutRelocatingDatabase:factors];
    }
    else if ( error.code == kStorageProviderSFTPorWebDAVSecretMissingErrorCode ) {
        self.completion(kUnlockDatabaseResultError, nil, error);
    }
    else {
        if ( self.database.couldNotConnectBehaviour == kCouldNotConnectBehaviourOpenOffline ) {
            [self openOffline:factors];
        }
        else {
            NSString* message = NSLocalizedString(@"open_sequence_storage_provider_error_open_local_ro_instead", @"A sync error occured. If this happens repeatedly you should try removing and re-adding your database.\n\n%@\nWould you like to open Strongbox's local copy in read-only mode instead?");
            NSString* viewSyncError = NSLocalizedString(@"open_sequence_storage_provider_view_sync_error_details", @"View Error Details");

            [Alerts threeOptionsWithCancel:self.viewController
                                     title:NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error")
                                   message:message
                         defaultButtonText:NSLocalizedString(@"open_sequence_yes_use_local_copy_option", @"Yes, Open Offline")
                          secondButtonText:NSLocalizedString(@"database_properties_title_always_offline", @"Always Open Offline")
                           thirdButtonText:viewSyncError
                                    action:^(int response) {
                if ( response == 0 ) {
                    [self openOffline:factors];
                }
                else if ( response == 1 ) {
                    self.database.couldNotConnectBehaviour = kCouldNotConnectBehaviourOpenOffline;
                    [self openOffline:factors];
                }
                else if ( response == 2) { 
                    self.completion(kUnlockDatabaseResultViewDebugSyncLogRequested, nil, nil);
                }
                else {
                    self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
                }
            }];
        }
    }
}

- (void)openOffline:(CompositeKeyFactors*)factors {
    BOOL isPro = AppPreferences.sharedInstance.isPro;
    [self unlockLocalCopy:factors forceReadOnly:!isPro offline:YES];
}

- (void)unlockLocalCopy:(CompositeKeyFactors*)factors forceReadOnly:(BOOL)forceReadOnly offline:(BOOL)offline {
    slog(@"✅ unlockLocalCopy");
    
    DatabaseUnlocker* unlocker = [DatabaseUnlocker unlockerForDatabase:self.database
                                                        viewController:self.viewController
                                                         forceReadOnly:forceReadOnly
                                      isNativeAutoFillAppExtensionOpen:self.isAutoFillOpen
                                                           offlineMode:offline];
    
    [unlocker unlockLocalWithKey:factors keyFromConvenience:self.unlockedWithConvenienceFactors completion:self.completion];
}



static UnlockDatabaseSequenceHelper *sharedInstance = nil; 

- (BOOL)errorIndicatesWeShouldAskUseToRelocateDatabase:(NSError*)error {
    return (error.code == NSFileProviderErrorNoSuchItem || 
            error.code == NSFileReadNoPermissionError ||   
            error.code == NSFileReadNoSuchFileError ||     
            error.code == NSFileNoSuchFileError);
}

- (void)askAboutRelocatingDatabase:(CompositeKeyFactors*)factors {
    NSString* message = NSLocalizedString(@"open_sequence_storage_provider_try_relocate_files_db_message", @"Strongbox is having trouble locating your database. This can happen sometimes especially after iOS updates or with some 3rd party providers (e.g.Nextcloud).\n\nYou now need to tell Strongbox where to locate it. Alternatively you can open Strongbox's local copy and fix this later.\n\nFor Nextcloud please use WebDAV instead...");
    
    NSString* relocateDatabase = NSLocalizedString(@"open_sequence_storage_provider_try_relocate_files_db", @"Locate Database...");

    BOOL isPro = AppPreferences.sharedInstance.isPro;

    NSString* openOfflineText = isPro ? NSLocalizedString(@"open_sequence_use_local_copy_option", @"Open Offline") : NSLocalizedString(@"open_sequence_use_local_copy_option_ro", @"Open Offline (Read-Only)");
    
    [Alerts twoOptionsWithCancel:self.viewController
                           title:NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error")
                         message:message
               defaultButtonText:relocateDatabase
                secondButtonText:openOfflineText
                          action:^(int response) {
        if (response == 0) {
            [self onRelocateFilesBasedDatabase:factors];
        }
        else if (response == 1) {
            [self unlockLocalCopy:factors forceReadOnly:!isPro offline:YES];
        }
        else {
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
    }];
}

- (void)onRelocateFilesBasedDatabase:(CompositeKeyFactors*)factors {
    
    
    sharedInstance = self;
    self.relocationFactors = factors;
    
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeOpen];
    vc.delegate = self; 
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    sharedInstance = nil;
    self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    slog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    if (!document) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self readReselectedFilesDatabase:NO data:nil url:url];
        });
        return;
    }

    [document openWithCompletionHandler:^(BOOL success) {
        NSData* data = document.data;
        
        [document closeWithCompletionHandler:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self readReselectedFilesDatabase:success data:data url:url];
        });
    }];
    
    sharedInstance = nil;
}

- (void)readReselectedFilesDatabase:(BOOL)success data:(NSData*)data url:(NSURL*)url {
    if(!success || !data) {
        [Alerts warn:self.viewController
               title:@"Error Opening This Database"
             message:@"Could not access this file."];
        self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
    else {
        NSError* error;
        
        if (![Serializator isValidDatabaseWithPrefix:data error:&error]) {
            [Alerts error:self.viewController
                    title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_invalid_database_filename_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                    error:error];
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            return;
        }
        
        if([url.lastPathComponent compare:self.database.fileName] != NSOrderedSame) {
            [Alerts yesNo:self.viewController
                    title:NSLocalizedString(@"open_sequence_database_different_filename_title",@"Different Filename")
                  message:NSLocalizedString(@"open_sequence_database_different_filename_message",@"This doesn't look like it's the right file because the filename looks different than the one you originally added. Do you want to continue?")
                   action:^(BOOL response) {
                       if(response) {
                           [self updateFilesBookmarkWithRelocatedUrl:url];
                       }
                   }];
        }
        else {
            [self updateFilesBookmarkWithRelocatedUrl:url];
        }
    }
}

- (void)updateFilesBookmarkWithRelocatedUrl:(NSURL*)url {
    NSError* error;
    NSData* bookMark = [BookmarksHelper getBookmarkDataFromUrl:url error:&error];
    
    if (error) {
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_error_could_not_bookmark_file", @"Could not bookmark this file")
                error:error];
        self.completion(kUnlockDatabaseResultError, nil, nil);
    }
    else {
        NSString* identifier = [FilesAppUrlBookmarkProvider.sharedInstance getJsonFileIdentifier:bookMark];

        self.database.fileIdentifier = identifier;
                
        [self syncAndUnlock:YES factors:self.relocationFactors]; 
    }
}




@end
