//
//  OpenSafeSequenceHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OpenSafeSequenceHelper.h"
#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "Alerts.h"
#import "SVProgressHUD.h"
#import "KeyFileParser.h"
#import "Utils.h"
#import "PinEntryController.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "AddNewSafeHelper.h"
#import "FileManager.h"
#import "StrongboxUIDocument.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "BiometricsManager.h"
#import "BookmarksHelper.h"
#import "YubiManager.h"
#import "SharedAppAndAutoFillSettings.h"
#import "AutoFillSettings.h"
#import "SyncManager.h"
#import "Kdbx4Database.h"
#import "Kdbx4Serialization.h"
#import "KeePassCiphers.h"
#import "NSDate+Extensions.h"
#import "FilesAppUrlBookmarkProvider.h"

#import <FileProvider/FileProvider.h>
#import "VirtualYubiKeys.h"

#ifndef IS_APP_EXTENSION
#import "OfflineDetector.h"
#import "ISMessages/ISMessages.h"
#endif

#import <Foundation/FoundationErrors.h>

@interface OpenSafeSequenceHelper () <UIDocumentPickerDelegate>

@property (nonatomic, strong) NSString* biometricIdName;
@property (nonnull) UIViewController* viewController;
@property (nonnull) SafeMetaData* safe;
@property BOOL canConvenienceEnrol;
@property (nonnull) UnlockDatabaseCompletionBlock completion;

@property BOOL isConvenienceUnlock;
@property BOOL isAutoFillOpen;
@property BOOL isAutoFillQuickTypeOpen;
@property BOOL openLocalOnly;

@property NSString* masterPassword;
@property NSData* undigestedKeyFileData; 
@property NSData* keyFileDigest; 

@property YubiKeyHardwareConfiguration* yubiKeyConfiguration;

@property BOOL biometricPreCleared; 

@property UIDocumentPickerViewController *documentPicker;

@property BOOL forcedReadOnly;
@property BOOL noConvenienceUnlock;

@end

@implementation OpenSafeSequenceHelper

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
                             completion:(UnlockDatabaseCompletionBlock)completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController
                                                       safe:safe
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                     openLocalOnly:openLocalOnly
                                biometricAuthenticationDone:NO
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(UnlockDatabaseCompletionBlock)completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController
                                                       safe:safe
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                              openLocalOnly:openLocalOnly
                                biometricAuthenticationDone:biometricAuthenticationDone
                                        noConvenienceUnlock:NO
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                    noConvenienceUnlock:(BOOL)noConvenienceUnlock
                             completion:(UnlockDatabaseCompletionBlock)completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController
                                                       safe:safe
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                    isAutoFillQuickTypeOpen:NO
                                     openLocalOnly:openLocalOnly
                                biometricAuthenticationDone:biometricAuthenticationDone
                                        noConvenienceUnlock:noConvenienceUnlock
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController *)viewController
                                   safe:(SafeMetaData *)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                          openLocalOnly:(BOOL)openLocalOnly
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                    noConvenienceUnlock:(BOOL)noConvenienceUnlock
                             completion:(UnlockDatabaseCompletionBlock)completion {
    OpenSafeSequenceHelper *helper = [[OpenSafeSequenceHelper alloc] initWithViewController:viewController
                                                                                       safe:safe
                                                                        canConvenienceEnrol:canConvenienceEnrol
                                                                             isAutoFillOpen:isAutoFillOpen
                                                                    isAutoFillQuickTypeOpen:isAutoFillQuickTypeOpen
                                                                              openLocalOnly:openLocalOnly
                                                                        biometricPreCleared:biometricAuthenticationDone
                                                                        noConvenienceUnlock:noConvenienceUnlock
                                                                                 completion:completion];
    
    [helper beginSeq];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                                  safe:(SafeMetaData*)safe
                   canConvenienceEnrol:(BOOL)canConvenienceEnrol
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                         openLocalOnly:(BOOL)openLocalOnly
                   biometricPreCleared:(BOOL)biometricPreCleared
                   noConvenienceUnlock:(BOOL)noConvenienceUnlock
                            completion:(UnlockDatabaseCompletionBlock)completion {
    self = [super init];
    if (self) {
        self.biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];
        self.viewController = viewController;
        self.safe = safe;
        self.canConvenienceEnrol = canConvenienceEnrol;
        self.completion = completion;
        self.isAutoFillOpen = isAutoFillOpen;
        self.isAutoFillQuickTypeOpen = isAutoFillQuickTypeOpen;
        self.openLocalOnly = openLocalOnly;
        self.biometricPreCleared = biometricPreCleared;
        self.noConvenienceUnlock = noConvenienceUnlock;
    }
    
    return self;
}

- (void)clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState {
    NSArray<SafeMetaData*>* databases = SafesList.sharedInstance.snapshot;
    
    
    
    

    for (SafeMetaData* database in databases) {
        if(database.isTouchIdEnabled) {
            NSLog(@"Clearing Biometrics for Database: [%@]", database.nickName);
            
            database.isEnrolledForConvenience = NO;
            database.convenienceMasterPassword = nil;
            
            
            database.hasBeenPromptedForConvenience = NO; 
            [SafesList.sharedInstance update:database];
        }
    }

    [BiometricsManager.sharedInstance clearBiometricRecordedDatabaseState];
}

- (void)beginSeq {
    if (!self.noConvenienceUnlock && self.safe.isEnrolledForConvenience && SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
        BOOL biometricPossible = self.safe.isTouchIdEnabled && BiometricsManager.isBiometricIdAvailable;
        BOOL biometricAllowed = !SharedAppAndAutoFillSettings.sharedInstance.disallowAllBiometricId;
        
        NSLog(@"Open Database: Biometric Possible [%d] - Biometric Available [%d]", biometricPossible, biometricAllowed);
                
        if(biometricPossible && biometricAllowed) {
            BOOL bioDbHasChanged = [BiometricsManager.sharedInstance isBiometricDatabaseStateHasChanged:self.isAutoFillOpen];

            if(bioDbHasChanged) {
                [self clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [Alerts warn:self.viewController
                           title:NSLocalizedString(@"open_sequence_warn_biometrics_db_changed_title", @"Biometrics Database Changed")
                         message:NSLocalizedString(@"open_sequence_warn_biometrics_db_changed_message", @"It looks like your biometrics database has changed, probably because you added a new face or fingerprint. Strongbox now requires you to re-enter your master credentials manually for security reasons.")
                      completion:^{
                        [self promptForManualCredentials];
                    }];
                });
            }
            else if (self.isAutoFillOpen && self.safe.mainAppAndAutoFillYubiKeyConfigsIncoherent) { 
                [self promptForManualCredentials];
            }
            else {
                [self showBiometricAuthentication];
            }
        }
        else if(!SharedAppAndAutoFillSettings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil) {
            if (self.isAutoFillOpen && self.safe.mainAppAndAutoFillYubiKeyConfigsIncoherent) { 
                [self promptForManualCredentials];
            }
            else {
                [self promptForConveniencePin];
            }
        }
        else {
            [self promptForManualCredentials];
        }
    }
    else {
        [self promptForManualCredentials];
    }
}



- (void)promptForConveniencePin {
    const int maxFailedPinAttempts = 3;
    
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* vc = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    vc.pinLength = self.safe.conveniencePin.length;
    vc.showFallbackOption = YES;
    
    if(self.safe.failedPinAttempts > 0) {
        vc.warning = [NSString stringWithFormat:
                      NSLocalizedString(@"open_sequence_pin_attempts_remaining_fmt",@"%d attempts remaining"), maxFailedPinAttempts - self.safe.failedPinAttempts];
    }
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if([pin isEqualToString:self.safe.conveniencePin]) {
                    self.isConvenienceUnlock = YES;
                    
                    if (self.safe.failedPinAttempts != 0) { 
                        self.safe.failedPinAttempts = 0;
                        [SafesList.sharedInstance update:self.safe];
                    }
                    
                    [self onGotCredentials:self.safe.convenienceMasterPassword
                           keyFileBookmark:self.safe.keyFileBookmark
                        oneTimeKeyFileData:nil
                                  readOnly:self.safe.readOnly
                             openLocalOnly:self.openLocalOnly
                      yubikeyConfiguration:self.safe.contextAwareYubiKeyConfig];
                }
                else if (self.safe.duressPin != nil && [pin isEqualToString:self.safe.duressPin]) {
                    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

                    [self performDuressAction];
                }
                else {
                    self.safe.failedPinAttempts++;
                    [SafesList.sharedInstance update:self.safe];
                    
                    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                    [gen notificationOccurred:UINotificationFeedbackTypeError];

                    if (self.safe.failedPinAttempts >= maxFailedPinAttempts) {
                        self.safe.failedPinAttempts = 0;
                        self.safe.isTouchIdEnabled = NO;
                        self.safe.conveniencePin = nil;
                        self.safe.isEnrolledForConvenience = NO;
                        self.safe.convenienceMasterPassword = nil;
                        
                        [SafesList.sharedInstance update:self.safe];
                        
                        [Alerts warn:self.viewController
                               title:NSLocalizedString(@"open_sequence_prompt_too_many_incorrect_pins_title",@"Too Many Incorrect PINs")
                             message:NSLocalizedString(@"open_sequence_prompt_too_many_incorrect_pins_message",@"You have entered the wrong PIN too many times. PIN Unlock is now disabled, and you must enter the master password to unlock this database.")];
                    }
                    else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self promptForConveniencePin];
                        });
                    }
                }
            }
            else if (response == kFallback) {
                [self promptForManualCredentials];
            }
            else {
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
        }];
    };
    
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)performDuressAction {
    if (self.safe.duressAction == kOpenDummy) {
        Model *viewModel = [[Model alloc] initAsDuressDummy:self.isAutoFillOpen templateMetaData:self.safe];
        self.completion(kUnlockDatabaseResultSuccess, viewModel, nil);
    }
    else if (self.safe.duressAction == kPresentError) {
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message", @"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue")
                error:error completion:^{
            self.completion(kUnlockDatabaseResultError, nil, error);
        }];
    }
    else if (self.safe.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe];
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message",@"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue") error:error completion:^{
            self.completion(kUnlockDatabaseResultError, nil, error);
        }];
    }
    else {
        self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
}

- (void)removeOrDeleteSafe {
    [SyncManager.sharedInstance removeDatabaseAndLocalCopies:self.safe];
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    [[SafesList sharedInstance] remove:self.safe.uuid];
}



- (void)showBiometricAuthentication {
    
    
    if(self.biometricPreCleared) {
        NSLog(@"BIOMETRIC has been PRE-CLEARED - Coalescing Auths - Proceeding without prompting for auth");
        [self onBiometricAuthenticationDone:YES error:nil];
    }
    else {
        

        CGFloat previousAlpha = self.viewController.view.alpha;
        if (self.isAutoFillQuickTypeOpen) {
            self.viewController.view.alpha = 0.0f;
        }
        
        BOOL ret = [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                                          fallbackTitle:NSLocalizedString(@"open_sequence_biometric_unlock_fallback", @"Unlock Manually...")
                                                             completion:^(BOOL success, NSError * _Nullable error) {
            [self onBiometricAuthenticationDone:success error:error];
            
            if (self.isAutoFillQuickTypeOpen) {
                self.viewController.view.alpha = previousAlpha;
            }
        }];

        if(!ret) { 
            NSLog(@"iOS13 Biometric Bug? Please try shaking your device to make the Biometric dialog appear. This is expected to be fixed in iOS13.2. Tap OK now and then shake.");
        }
    }
}

- (void)onBiometricAuthenticationDone:(BOOL)success
                                error:(NSError *)error {
    if (success) {
        if(![BiometricsManager.sharedInstance isBiometricDatabaseStateRecorded:self.isAutoFillOpen]) {
            [BiometricsManager.sharedInstance recordBiometricDatabaseState:self.isAutoFillOpen]; 
        }

        self.isConvenienceUnlock = YES;
        if(!SharedAppAndAutoFillSettings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForConveniencePin];
            });
        }
        else {
            [self onGotCredentials:self.safe.convenienceMasterPassword
                   keyFileBookmark:self.safe.keyFileBookmark
                oneTimeKeyFileData:nil
                          readOnly:self.safe.readOnly
                     openLocalOnly:self.openLocalOnly
              yubikeyConfiguration:self.safe.contextAwareYubiKeyConfig];
        }
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self.viewController
                         title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), self.biometricIdName]
                       message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_message_fmt", @"%@ Authentication Failed. You must now enter your password manually to open the database."), self.biometricIdName]
                    completion:^{
                        [self promptForManualCredentials];
                    }];
            });
        }
        else if (error.code == LAErrorUserFallback)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForManualCredentials];
            });
        }
        else if (error.code != LAErrorUserCancel)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self.viewController
                         title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), self.biometricIdName]
                       message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_not_configured_fmt", @"%@ has failed: %@. You must now enter your password manually to open the database."), self.biometricIdName, error]
                    completion:^{
                        [self promptForManualCredentials];
                    }];
            });
        }
        else {
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
    }
}



- (void)promptForManualCredentials {
    self.isConvenienceUnlock = NO;
    [self promptForPasswordAndOrKeyFile];
}

- (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:@"key"];
    
    return  expectedKeyFileName;
}

- (NSString*)getAutoDetectedKeyFileUrl {
    NSURL *directory = FileManager.sharedInstance.documentsDirectory;
    NSString* expectedKeyFileName = [self getExpectedAssociatedLocalKeyFileName:self.safe.fileName];
 
    NSError* error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString*>* files = [fm contentsOfDirectoryAtPath:directory.path error:&error];
    
    if(!files) {
        NSLog(@"Error looking for auto detected key file url: %@", error);
        return nil;
    }
    
    for (NSString *file in files) {
        if([file caseInsensitiveCompare:expectedKeyFileName] == NSOrderedSame) {
            NSURL* found = [directory URLByAppendingPathComponent:file];
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:found readOnly:YES error:&error];
            
            if (error) {
                NSLog(@"Error while getting auto-detected bookmark -> [%@]", error);
            }
            
            return bookmark;
        }
    }
    
    return nil;
}

- (void)promptForPasswordAndOrKeyFile {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CreateDatabaseOrSetCredentials" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    CASGTableViewController *scVc = (CASGTableViewController*)nav.topViewController;
    
    scVc.mode = kCASGModeGetCredentials;
    
    scVc.initialKeyFileBookmark = self.safe.keyFileBookmark;
    scVc.initialReadOnly = self.safe.readOnly;
    scVc.initialOpenLocalOnly = self.openLocalOnly;
    
    scVc.initialYubiKeyConfig = self.safe.contextAwareYubiKeyConfig;
    
    scVc.validateCommonKeyFileMistakes = self.safe.keyFileBookmark == nil; 
    
    
    
    BOOL probablyPasswordSafe = [self.safe.fileName.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; 
    
    scVc.initialFormat = self.safe.likelyFormat != kFormatUnknown ? self.safe.likelyFormat : heuristicFormat;
    
    NSDate* modDate;
    [SyncManager.sharedInstance isLocalWorkingCacheAvailable:self.safe modified:&modDate];
    scVc.showOpenLocalOnlyOption = self.safe.storageProvider != kLocalDevice && modDate != nil;
    
    
    
    if(!self.safe.keyFileBookmark) {
        NSString* autoDetectedKeyFileBookmark = [self getAutoDetectedKeyFileUrl];
        if(autoDetectedKeyFileBookmark) {
            scVc.autoDetectedKeyFile = YES;
            scVc.initialKeyFileBookmark = autoDetectedKeyFileBookmark;
        }
    }
    
    scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [self onGotCredentials:creds.password
                       keyFileBookmark:creds.keyFileBookmark
                    oneTimeKeyFileData:creds.oneTimeKeyFileData
                              readOnly:creds.readOnly
                         openLocalOnly:creds.openLocalOnly
                  yubikeyConfiguration:creds.yubiKeyConfig];
            }
            else {
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
        }];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}



- (void)onGotCredentials:(NSString*)password
         keyFileBookmark:(NSString*)keyFileBookmark
      oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                readOnly:(BOOL)readOnly
           openLocalOnly:(BOOL)openLocalOnly
    yubikeyConfiguration:(YubiKeyHardwareConfiguration*)yubikeyConfiguration {
    if(keyFileBookmark || oneTimeKeyFileData) {
        NSError *error;
        self.undigestedKeyFileData = getKeyFileData(keyFileBookmark, oneTimeKeyFileData, &error);

        if(self.undigestedKeyFileData == nil) {
            
            
            if(self.isConvenienceUnlock) {
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.conveniencePin = nil;
                self.safe.isTouchIdEnabled = NO;
                self.safe.hasBeenPromptedForConvenience = NO; 
                
                [SafesList.sharedInstance update:self.safe];
            }

            if(keyFileBookmark && self.isAutoFillOpen) {
                    [Alerts error:self.viewController
                            title:NSLocalizedString(@"open_sequence_error_reading_key_file_autofill_context", @"Could not read Key File. Has it been imported properly? Check Key Files Management in Preferences")
                            error:error
                       completion:^{
                        self.completion(kUnlockDatabaseResultError, nil, error);
                    }];
                    return;
            }
            else {
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"open_sequence_error_reading_key_file", @"Error Reading Key File")
                        error:error
                   completion:^{
                    self.completion(kUnlockDatabaseResultError, nil, error);
                }];
                return;
            }
        }
    }

    if(yubikeyConfiguration && yubikeyConfiguration.mode != kNoYubiKey) {
        self.yubiKeyConfiguration = yubikeyConfiguration;
    }
    
    

    BOOL readOnlyChanged = self.safe.readOnly != readOnly;
    
    BOOL keyFileChanged = (!(self.safe.keyFileBookmark == nil && keyFileBookmark == nil)) && (![self.safe.keyFileBookmark isEqual:keyFileBookmark]);
    
    BOOL yubikeyChanged = (!(self.safe.contextAwareYubiKeyConfig == nil && yubikeyConfiguration == nil)) && (![self.safe.contextAwareYubiKeyConfig isEqual:yubikeyConfiguration]);
    
    if(readOnlyChanged || keyFileChanged || yubikeyChanged) {
        self.safe.readOnly = readOnly;
        self.safe.keyFileBookmark = keyFileBookmark;
        self.safe.contextAwareYubiKeyConfig = yubikeyConfiguration;
        
        [SafesList.sharedInstance update:self.safe];
    }
    
    self.openLocalOnly = openLocalOnly;
    self.masterPassword = password;
    
    [self beginUnlockWithCredentials];
}



- (void)beginUnlockWithCredentials {
    NSDate* localCopyModDate;
    NSURL* localCopyUrl = [SyncManager.sharedInstance getLocalWorkingCache:self.safe modified:&localCopyModDate];

    if(self.isAutoFillOpen || self.openLocalOnly) {
        if(localCopyUrl == nil) {
            [Alerts warn:self.viewController
                   title:NSLocalizedString(@"open_sequence_couldnt_open_local_title", @"Could Not Open Local Copy")
                 message:NSLocalizedString(@"open_sequence_couldnt_open_local_message", @"Could not open Strongbox's local copy of this database. A online sync is required.")];
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
        else{
            self.forcedReadOnly = !self.isAutoFillOpen; 
            [self unlockLocalCopy];
        }
    }
#ifndef IS_APP_EXTENSION
    else if ( OfflineDetector.sharedInstance.isOffline &&
             [SyncManager.sharedInstance isLegacyImmediatelyOfferLocalCopyIfOffline:self.safe] && localCopyUrl != nil ) {
        NSString* primaryStorageDisplayName = [SyncManager.sharedInstance getPrimaryStorageDisplayName:self.safe];
        NSString* loc = NSLocalizedString(@"open_sequence_user_looks_offline_open_local_ro_fmt", "It looks like you may be offline and '%@' may not be reachable. Would you like to use Strongbox's local copy in read-only mode instead?");
        
        NSString* message = [NSString stringWithFormat:loc, primaryStorageDisplayName];
        
        [Alerts twoOptionsWithCancel:self.viewController
                               title:NSLocalizedString(@"open_sequence_yesno_use_local_copy_title", @"Use Local Copy?")
                             message:message
                   defaultButtonText:NSLocalizedString(@"open_sequence_yes_use_local_copy_option", @"Yes, Use Local (Read-Only)")
                    secondButtonText:NSLocalizedString(@"open_sequence_yesno_use_offline_cache_no_try_connect_option", @"No, Try to connect anyway")
                              action:^(int response) {
            if (response == 0) { 
                self.forcedReadOnly = YES;  
                [self unlockLocalCopy];
            }
            else if (response == 1) { 
                [self syncAndUnlockLocalCopy];
            }
            else {
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
        }];
    }
    else {
        [self syncAndUnlockLocalCopy];
    }
#endif
}

- (void)syncAndUnlockLocalCopy {
    [self syncAndUnlockLocalCopy:YES]; 
}

- (void)syncAndUnlockLocalCopy:(BOOL)join {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")];
    });
    
    [SyncManager.sharedInstance sync:self.safe
                       interactiveVC:self.viewController
                                join:join
                          completion:^(SyncAndMergeResult result, BOOL conflictAndLocalWasChanged, const NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
             
            if (result == kSyncAndMergeResultUserInteractionRequired) {
                
                [self syncAndUnlockLocalCopy:NO];
            }
            else if (result == kSyncAndMergeResultUserCancelled) {
                
                self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            }
            else if (result == kSyncAndMergeError) {
                NSLog(@"Unlock Interactive Sync Error: [%@]", error);

                if (self.safe.storageProvider == kFilesAppUrlBookmark) {
                    if ( @available(iOS 11.0, *) ) {
                        if ( error.code == NSFileProviderErrorNoSuchItem || 
                             error.code == NSFileReadNoPermissionError ||   
                             error.code == NSFileReadNoSuchFileError ||     
                             error.code == NSFileNoSuchFileError) {         
                            NSString* message = NSLocalizedString(@"open_sequence_storage_provider_try_relocate_files_db_message", @"Strongbox is having trouble locating your database. This can happen sometimes especially after iOS updates or with some 3rd party providers (e.g.Nextcloud).\n\nYou now need to tell Strongbox where to locate it. Alternatively you can open Strongbox's local copy and fix this later.\n\nFor Nextcloud please use WebDAV instead...");
                            
                            NSString* relocateDatabase = NSLocalizedString(@"open_sequence_storage_provider_try_relocate_files_db", @"Locate Database...");
                            
                            [Alerts twoOptionsWithCancel:self.viewController
                                                   title:NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error")
                                                 message:message
                                       defaultButtonText:relocateDatabase
                                        secondButtonText:NSLocalizedString(@"open_sequence_use_local_copy_option", @"Use Local (Read-Only)") 
                                                  action:^(int response) {
                                if (response == 0) {
                                    [self onRelocateFilesBasedDatabase];
                                }
                                else if (response == 1) {
                                    self.forcedReadOnly = YES; 
                                    [self unlockLocalCopy];
                                }
                                else {
                                    self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
                                }
                            }];

                            return;
                        }
                    }
                }

                NSString* message = NSLocalizedString(@"open_sequence_storage_provider_error_open_local_ro_instead", @"A sync error occured. If this happens repeatedly you should try removing and re-adding your database.\n\n%@\nWould you like to open Strongbox's local copy in read-only mode instead?");
                NSString* viewSyncError = NSLocalizedString(@"open_sequence_storage_provider_view_sync_error_details", @"View Error Details");

                [Alerts twoOptionsWithCancel:self.viewController
                                       title:NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error")
                                     message:message
                           defaultButtonText:NSLocalizedString(@"open_sequence_yes_use_local_copy_option", @"Yes, Use Local (Read-Only)")
                            secondButtonText:viewSyncError
                                      action:^(int response) {
                    if (response == 0) {
                        self.forcedReadOnly = YES; 
                        [self unlockLocalCopy];
                    }
                    else if (response == 1) { 
                        self.completion(kUnlockDatabaseResultViewDebugSyncLogRequested, nil, nil);
                    }
                    else {
                        self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
                    }
                }];
            }
            else { 
                self.forcedReadOnly = NO; 
                [self unlockLocalCopy];
            }
        });
    }];
}

- (void)unlockLocalCopy {
    NSDate* modDate;
    NSURL* localCopyUrl = [SyncManager.sharedInstance getLocalWorkingCache:self.safe modified:&modDate];

    if(localCopyUrl == nil) {
        [Alerts warn:self.viewController
               title:NSLocalizedString(@"open_sequence_couldnt_open_local_title", @"Could Not Open Local Copy")
             message:NSLocalizedString(@"open_sequence_couldnt_open_local_message", @"Could not open Strongbox's local copy of this database. A online sync is required.")];
        self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
    else if(self.isAutoFillOpen && !AutoFillSettings.sharedInstance.haveWarnedAboutAutoFillCrash && [OpenSafeSequenceHelper isAutoFillLikelyToCrash:localCopyUrl]) {
        [Alerts warn:self.viewController
               title:NSLocalizedString(@"open_sequence_autofill_creash_likely_title", @"AutoFill Crash Likely")
             message:NSLocalizedString(@"open_sequence_autofill_creash_likely_message", @"Your database has encryption settings that may cause iOS Password AutoFill extensions to be terminated due to excessive resource consumption. This will mean AutoFill appears not to work. Unfortunately this is an Apple imposed limit. You could consider reducing the amount of resources consumed by your encryption settings (Memory in particular with Argon2 to below 64MB).")
        completion:^{
            AutoFillSettings.sharedInstance.haveWarnedAboutAutoFillCrash = YES;
            [self unlockDatabaseAtUrl:localCopyUrl modDate:modDate];
        }];
    }
    else {
        [self unlockDatabaseAtUrl:localCopyUrl modDate:modDate];
    }
}

- (void)unlockDatabaseAtUrl:(NSURL*)url modDate:(NSDate*)modDate {
    NSError* error;
    BOOL valid = [DatabaseModel isValidDatabase:url error:&error];
    if (!valid) {
        [self openSafeWithDataDone:error openedSafe:nil modDate:modDate];
        return;
    }

    DatabaseFormat format = [DatabaseModel getDatabaseFormat:url];
    
    if (self.undigestedKeyFileData) {
        self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:self.undigestedKeyFileData checkForXml:format != kKeePass1];
    }

    if (self.yubiKeyConfiguration && self.yubiKeyConfiguration != kNoYubiKey) {
        [self unlockValidDatabaseWithAllCompositeKeyFactors:url
                                                     format:format
                                                    modDate:modDate
                                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [self getYubiKeyChallengeResponse:challenge completion:completion];
        }];
    }
    else {
        [self unlockValidDatabaseWithAllCompositeKeyFactors:url format:format modDate:modDate yubiKeyCR:nil];
    }
}

- (void)getYubiKeyChallengeResponse:(NSData*)challenge completion:(YubiKeyCRResponseBlock)completion {
#ifndef IS_APP_EXTENSION
    if([SharedAppAndAutoFillSettings.sharedInstance isProOrFreeTrial] || self.yubiKeyConfiguration.mode == kVirtual) {
        [YubiManager.sharedInstance getResponse:self.yubiKeyConfiguration
                                      challenge:challenge
                                     completion:completion];
    }
    else {
        NSString* loc = NSLocalizedString(@"open_sequence_yubikey_only_available_in_pro", @"YubiKey Unlock is only available in the Pro edition of Strongbox");
        NSError* error = [Utils createNSError:loc errorCode:-1];
        completion(NO, nil, error);
    }
#else
    if(self.yubiKeyConfiguration.mode == kVirtual) {
        VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:self.yubiKeyConfiguration.virtualKeyIdentifier];
        
        if (!key) {
            NSError* error = [Utils createNSError:@"Could not find Virtual Hardware Key!" errorCode:-1];
            completion(NO, nil, error);
        }
        else {
            NSLog(@"Doing Virtual Challenge Response...");
            NSData* response = [key doChallengeResponse:challenge];
            completion(NO, response, nil);
        }
    }
    else {
        NSString* loc = NSLocalizedString(@"open_sequence_cannot_use_yubikey_in_autofill_mode", @"YubiKey Unlock is not supported in AutoFill mode");
        NSError* error = [Utils createNSError:loc errorCode:-1];
        completion(NO, nil, error);
    }
#endif
}

- (void)unlockValidDatabaseWithAllCompositeKeyFactors:(NSURL*)url
                                               format:(DatabaseFormat)format
                                              modDate:(NSDate*)modDate
                                            yubiKeyCR:(YubiKeyCRHandlerBlock)yubiKeyCR {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD showWithStatus:NSLocalizedString(@"open_sequence_progress_decrypting", @"Decrypting...")];
    });
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        CompositeKeyFactors* cpf = [CompositeKeyFactors password:self.masterPassword
                                                   keyFileDigest:self.keyFileDigest
                                                       yubiKeyCR:yubiKeyCR];
        
        DatabaseModelConfig* modelConfig = [DatabaseModelConfig withPasswordConfig:SharedAppAndAutoFillSettings.sharedInstance.passwordGenerationConfig
                                                            sanityCheckInnerStream:YES];
    
        if(!self.isConvenienceUnlock &&
           (format == kKeePass || format == kKeePass4) &&
           self.masterPassword.length == 0 &&
           (self.keyFileDigest || yubiKeyCR)) {
            
            
            
            
            
            

            if (!yubiKeyCR) { 
                [DatabaseModel fromUrl:url
                                   ckf:cpf
                                config:modelConfig
                            completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, const NSError * _Nullable error) {
                    if(model == nil && error && error.code == kStrongboxErrorCodeIncorrectCredentials) {
                        CompositeKeyFactors* ckf = [CompositeKeyFactors password:nil
                                                                   keyFileDigest:self.keyFileDigest
                                                                       yubiKeyCR:yubiKeyCR];
                        
                        
                        
                        [DatabaseModel fromUrl:url
                               ckf:ckf
                            config:modelConfig
                        completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, const NSError * _Nullable error) {
                            if(model) {
                                self.masterPassword = nil;
                            }
                            
                            [self onGotDatabaseModelFromData:userCancelled model:model modDate:modDate error:error];
                        }];
                    }
                    else {
                        [self onGotDatabaseModelFromData:userCancelled model:model modDate:modDate error:error];
                    }
                }];
            }
            else { 
                [Alerts twoOptionsWithCancel:self.viewController
                                       title:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
                                     message:NSLocalizedString(@"casg_question_message_empty_password", @"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want.")
                           defaultButtonText:NSLocalizedString(@"casg_question_option_empty", @"Empty Password")
                            secondButtonText:NSLocalizedString(@"casg_question_option_none", @"No Password")
                                      action:^(int response) {
                    if(response == 0) {
                        self.masterPassword = @"";
                    }
                    else if(response == 1) {
                        self.masterPassword = nil;
                    }
                    
                    cpf.password = self.masterPassword;
                    [DatabaseModel fromUrl:url
                                       ckf:cpf
                                    config:modelConfig
                                completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, const NSError * _Nullable error) {
                        [self onGotDatabaseModelFromData:userCancelled model:model modDate:modDate error:error];
                    }];
                }];
            }
        }
        else {
            [DatabaseModel fromUrl:url
                               ckf:cpf
                            config:modelConfig
                        completion:^(BOOL userCancelled, DatabaseModel * _Nullable model, const NSError * _Nullable error) {
                [self onGotDatabaseModelFromData:userCancelled model:model modDate:modDate error:error];
            }];
        }
    });
}

- (void)onGotDatabaseModelFromData:(BOOL)userCancelled
                             model:(DatabaseModel*)model
                           modDate:(NSDate*)modDate
                             error:(const NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [SVProgressHUD dismiss];
        
        if (userCancelled) {
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
        }
        else {
            [self openSafeWithDataDone:error openedSafe:model modDate:modDate];
        }
    });
}

- (void)openSafeWithDataDone:(const NSError*)error
                  openedSafe:(DatabaseModel*)openedSafe
                     modDate:(NSDate*)modDate {
    [SVProgressHUD dismiss];
    
    if (openedSafe == nil) {
        if(!error) {
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
            self.completion(kUnlockDatabaseResultError, nil, error);
            return;
        }
        else if (error.code == kStrongboxErrorCodeIncorrectCredentials) {
            if(self.isConvenienceUnlock) { 
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.conveniencePin = nil;
                self.safe.isTouchIdEnabled = NO;
                self.safe.hasBeenPromptedForConvenience = NO; 
                
                [SafesList.sharedInstance update:self.safe];
            
                [Alerts info:self.viewController
                       title:NSLocalizedString(@"open_sequence_problem_opening_title", @"Could not open database")
                     message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_problem_opening_convenience_incorrect_message", @"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled.")]] ;
            }
            else {
                if (self.keyFileDigest) {
                    [Alerts info:self.viewController
                           title:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                         message:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message_verify_key_file", @"The credentials were incorrect for this database. Are you sure you are using this key file?\n\nNB: A key files are not the same as your database file.")];

                }
                else {
                    [Alerts info:self.viewController
                           title:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                         message:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.")];
                }
            }
        }
        else {
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        }
        
        self.completion(kUnlockDatabaseResultError, nil, error);
    }
    else {
        BOOL biometricPossible = BiometricsManager.isBiometricIdAvailable && !SharedAppAndAutoFillSettings.sharedInstance.disallowAllBiometricId;
        BOOL pinPossible = !SharedAppAndAutoFillSettings.sharedInstance.disallowAllPinCodeOpens;

        BOOL conveniencePossible = !self.isAutoFillOpen && self.canConvenienceEnrol && [SharedAppAndAutoFillSettings.sharedInstance isProOrFreeTrial] && (biometricPossible || pinPossible);
        BOOL convenienceNotYetPrompted = !self.safe.hasBeenPromptedForConvenience;
        
        BOOL quickLaunchPossible = !self.isAutoFillOpen && SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid == nil;
        BOOL quickLaunchNotYetPrompted = !self.safe.hasBeenPromptedForQuickLaunch;
        
        if (conveniencePossible && convenienceNotYetPrompted) {
            [self promptForConvenienceEnrolAndOpen:biometricPossible pinPossible:pinPossible openedSafe:openedSafe];
        }
        else if (quickLaunchPossible && quickLaunchNotYetPrompted) {
            [self promptForQuickLaunch:openedSafe];
        }
        else {
            [self onSuccessfulSafeOpen:openedSafe];
        }
    }
}

- (void)promptForQuickLaunch:(DatabaseModel*)openedSafe {
    if(!self.isAutoFillOpen && SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid == nil && !self.safe.hasBeenPromptedForQuickLaunch) {
        [Alerts yesNo:self.viewController
                title:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_title", @"Set Quick Launch?")
              message:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_message", @"Would you like to use this as your Quick Launch database? Quick Launch means you will get prompted immediately to unlock when you open Strongbox, saving you a precious tap.")
               action:^(BOOL response) {
            if(response) {
               SharedAppAndAutoFillSettings.sharedInstance.quickLaunchUuid = self.safe.uuid;
            }

            self.safe.hasBeenPromptedForQuickLaunch = YES;
            [SafesList.sharedInstance update:self.safe];

            [self onSuccessfulSafeOpen:openedSafe];
        }];
    }
}

- (void)enrolForBiometrics:(CompositeKeyFactors*)compositeKeyFactors {
    self.safe.isTouchIdEnabled = YES;

    self.safe.isEnrolledForConvenience = YES;
    self.safe.convenienceMasterPassword = compositeKeyFactors.password;
    self.safe.hasBeenPromptedForConvenience = YES;
    
    [SafesList.sharedInstance update:self.safe];
}

- (void)enrolForPinCodeUnlock:(NSString*)pin compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    self.safe.conveniencePin = pin;

    self.safe.isEnrolledForConvenience = YES;
    self.safe.convenienceMasterPassword = compositeKeyFactors.password;
    self.safe.hasBeenPromptedForConvenience = YES;

    [SafesList.sharedInstance update:self.safe];
}

- (void)unenrolFromConvenience {
    self.safe.isTouchIdEnabled = NO;
    self.safe.conveniencePin = nil;

    self.safe.isEnrolledForConvenience = NO;
    self.safe.convenienceMasterPassword = nil;
    self.safe.hasBeenPromptedForConvenience = YES;

    [SafesList.sharedInstance update:self.safe];
}

- (void)promptForConvenienceEnrolAndOpen:(BOOL)biometricPossible
                             pinPossible:(BOOL)pinPossible
                              openedSafe:(DatabaseModel*)openedSafe {
    NSString *title;
    NSString *message;
    
    if(biometricPossible && pinPossible) {
        title = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_both_title_fmt", @"Convenience Unlock: Use %@ or PIN Code in Future?"), self.biometricIdName];
        message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_both_message_fmt", @"You can use either %@ or a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use one of these methods, please select from below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password"), self.biometricIdName];
    }
    else if (biometricPossible) {
        title = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_bio_title_fmt", @"Convenience Unlock: Use %@ to Unlock in Future?"), self.biometricIdName];
        message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_bio_message_fmt", @"You can use %@ to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password"), self.biometricIdName];
    }
    else if (pinPossible) {
        title = NSLocalizedString(@"open_sequence_prompt_use_convenience_pin_title", @"Convenience Unlock: Use a PIN Code to Unlock in Future?");
        message = NSLocalizedString(@"open_sequence_prompt_use_convenience_pin_message", @"You can use a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password");
    }
    
    if (!SharedAppAndAutoFillSettings.sharedInstance.isPro) {
        message = [message stringByAppendingFormat:NSLocalizedString(@"open_sequence_append_convenience_pro_warning", @"\n\nNB: Convenience Unlock is a Pro feature")];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(biometricPossible) {
        UIAlertAction *biometricAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_bio_fmt", @"Use %@"), self.biometricIdName]
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *a) {
            [self enrolForBiometrics:openedSafe.compositeKeyFactors];
            [self onSuccessfulSafeOpen:openedSafe];
        }];
        
        [alertController addAction:biometricAction];
    }
    
    if (pinPossible) {
        UIAlertAction *pinCodeAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_pin", @"Use a PIN Code...")]
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction *a) {
            [self setupConveniencePinAndOpen:openedSafe];
        }];
        [alertController addAction:pinCodeAction];
    }
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"open_sequence_prompt_option_no", @"No")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *a) {
        [self unenrolFromConvenience];
        [self onSuccessfulSafeOpen:openedSafe];
    }];
    

    [alertController addAction:noAction];
    
    [self.viewController presentViewController:alertController animated:YES completion:nil];
}

- (void)setupConveniencePinAndOpen:(DatabaseModel*)openedSafe {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* pinEntryVc = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if(!(self.safe.duressPin != nil && [pin isEqualToString:self.safe.duressPin])) {
                    [self enrolForPinCodeUnlock:pin compositeKeyFactors:openedSafe.compositeKeyFactors];
                    [self onSuccessfulSafeOpen:openedSafe];
                }
                else {
                    [Alerts warn:self.viewController
                           title:NSLocalizedString(@"open_sequence_warn_pin_conflict_title", @"PIN Conflict")
                        message:NSLocalizedString(@"open_sequence_warn_pin_conflict_message", @"Your Convenience PIN conflicts with your Duress PIN. Please configure in Database Settings")
                    completion:^{
                        [self onSuccessfulSafeOpen:openedSafe];
                    }];
                }
            }
            else {
                [self onSuccessfulSafeOpen:openedSafe];
            }
        }];
    };

    [self.viewController presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)onSuccessfulSafeOpen:(DatabaseModel *)openedSafe {
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:self.safe
                                            forcedReadOnly:self.forcedReadOnly
                                                isAutoFill:self.isAutoFillOpen];
    
    if(self.safe.autoFillEnabled && !self.isAutoFillOpen) { 
        [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:openedSafe databaseUuid:self.safe.uuid];
    }

    NSLog(@"Setting likelyFormat to [%ld]", (long)openedSafe.format);
    
    if (!self.isAutoFillOpen) { 
        self.safe.likelyFormat = openedSafe.format;
        [SafesList.sharedInstance update:self.safe];
    }
    
    self.completion(kUnlockDatabaseResultSuccess, viewModel, nil);
}



NSData* getKeyFileDigest(NSString* keyFileBookmark, NSData* onceOffKeyFileData, DatabaseFormat format, NSError** error) {
    NSData* keyFileData = getKeyFileData(keyFileBookmark, onceOffKeyFileData, error);
    
    NSData *keyFileDigest = keyFileData ? [KeyFileParser getKeyFileDigestFromFileData:keyFileData checkForXml:format != kKeePass1] : nil;

    return keyFileDigest;
}

NSData* getKeyFileData(NSString* keyFileBookmark, NSData* onceOffKeyFileData, NSError** error) {
    NSData* keyFileData = nil;
    
    if (keyFileBookmark) {
        NSString* updated;
        NSURL* keyFileUrl = [BookmarksHelper getUrlFromBookmark:keyFileBookmark readOnly:YES updatedBookmark:&updated error:error];
        if (keyFileUrl) {
            keyFileData = [NSData dataWithContentsOfURL:keyFileUrl options:kNilOptions error:error];
        }
    }
    else if (onceOffKeyFileData) {
        keyFileData = onceOffKeyFileData;
    }
    
    return keyFileData;
}

+ (BOOL)isAutoFillLikelyToCrash:(NSURL*)url {
    DatabaseFormat format = [DatabaseModel getDatabaseFormat:url];
    
    if(format == kKeePass4) {     
        NSInputStream* inputStream = [NSInputStream inputStreamWithURL:url];
        CryptoParameters* params = [Kdbx4Serialization getCryptoParams:inputStream];
        
        if(params && params.kdfParameters && [params.kdfParameters.uuid isEqual:argon2CipherUuid()]) {
            static NSString* const kParameterMemory = @"M";
            static uint64_t const kMaxArgon2Memory =  64 * 1024 * 1024;
                        
            VariantObject* vo = params.kdfParameters.parameters[kParameterMemory];
            if(vo && vo.theObject) {
                uint64_t memory = ((NSNumber*)vo.theObject).longLongValue;
                if(memory > kMaxArgon2Memory) {
                    return YES;
                }
            }
        }
    }
    
    

    static const NSUInteger kProbablyTooLargeToOpenInAutoFillSizeBytes = 15 * 1024 * 1024; 

    NSError* error;
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:url.path error:&error];
    
    if (error == nil && attributes.fileSize > kProbablyTooLargeToOpenInAutoFillSizeBytes) {
        return YES;
    }

    return NO;
}
                    


static OpenSafeSequenceHelper *sharedInstance = nil;

- (void)onRelocateFilesBasedDatabase {
    
    
    sharedInstance = self;

    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeOpen];
    vc.delegate = sharedInstance;
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
   
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    sharedInstance = nil;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];

    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    [self documentPicker:controller didPickDocumentAtURL:url];
    #pragma GCC diagnostic pop
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-implementations"
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url { 
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
#pragma GCC diagnostic pop

- (void)readReselectedFilesDatabase:(BOOL)success data:(NSData*)data url:(NSURL*)url {
    if(!success || !data) {
        [Alerts warn:self.viewController
               title:@"Error Opening This Database"
             message:@"Could not access this file."];
        self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
    }
    else {
        NSError* error;
        
        if (![DatabaseModel isValidDatabaseWithPrefix:data error:&error]) {
            [Alerts error:self.viewController
                    title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_invalid_database_filename_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                    error:error];
            self.completion(kUnlockDatabaseResultUserCancelled, nil, nil);
            return;
        }
        
        if([url.lastPathComponent compare:self.safe.fileName] != NSOrderedSame) {
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

        self.safe.fileIdentifier = identifier;
        [SafesList.sharedInstance update:self.safe];
        
        [self syncAndUnlockLocalCopy]; 
    }
}




@end
