//
//  OpenSafeSequenceHelper.m
//  Strongbox-iOS
//
//  Created by Mark on 12/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "OpenSafeSequenceHelper.h"
#import "Settings.h"
#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "Alerts.h"
#import "SafeStorageProviderFactory.h"
#import "OfflineDetector.h"
#import "SVProgressHUD.h"
#import "KeyFileParser.h"
#import "Utils.h"
#import "PinEntryController.h"
#import "AppleICloudProvider.h"
#import "DuressDummyStorageProvider.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "AddNewSafeHelper.h"
#import "FileManager.h"
#import "CacheManager.h"
#import "LocalDeviceStorageProvider.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxUIDocument.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "BiometricsManager.h"
#import "BookmarksHelper.h"
#import "YubiManager.h"

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

@interface OpenSafeSequenceHelper () <UIDocumentPickerDelegate>

@property (nonatomic, strong) NSString* biometricIdName;
@property (nonnull) UIViewController* viewController;
@property (nonnull) SafeMetaData* safe;
@property BOOL canConvenienceEnrol;
@property BOOL openAutoFillCache;

@property (nonnull) CompletionBlock completion;

@property BOOL isConvenienceUnlock;
@property BOOL isAutoFillOpen;
@property BOOL manualOpenOfflineCache;

@property NSString* masterPassword;
@property NSData* undigestedKeyFileData; // We cannot digest Key File until after we discover the Database Format (because KeePass 2 allows for a special XML format of Key File)
@property NSData* keyFileDigest; // Or we may directly set the digest from the convenience secure store
@property NSString* yubikeySecret;
@property YubiKeyHardwareConfiguration* yubiKeyConfiguration;

@property BOOL biometricPreCleared; // App Lock has just authorized the user via Bio - No need to ask again

@property UIDocumentPickerViewController *documentPicker;

@end

@implementation OpenSafeSequenceHelper

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
                             completion:(CompletionBlock)completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController
                                                       safe:safe
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                     manualOpenOfflineCache:manualOpenOfflineCache
                                biometricAuthenticationDone:NO
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(CompletionBlock)completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController
                                                       safe:safe
                                          openAutoFillCache:NO
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                     manualOpenOfflineCache:manualOpenOfflineCache
                                biometricAuthenticationDone:biometricAuthenticationDone
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      openAutoFillCache:(BOOL)openAutoFillCache
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
            biometricAuthenticationDone:(BOOL)biometricAuthenticationDone
                             completion:(CompletionBlock)completion {
    OpenSafeSequenceHelper *helper = [[OpenSafeSequenceHelper alloc] initWithViewController:viewController
                                                                                       safe:safe
                                                                          openAutoFillCache:openAutoFillCache
                                                                        canConvenienceEnrol:canConvenienceEnrol
                                                                             isAutoFillOpen:isAutoFillOpen
                                                                     manualOpenOfflineCache:manualOpenOfflineCache
                                                                        biometricPreCleared:biometricAuthenticationDone
                                                                                 completion:completion];
    
    [helper beginSequenceWithAutoFillFilesCheck];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                                  safe:(SafeMetaData*)safe
                     openAutoFillCache:(BOOL)openAutoFillCache
                   canConvenienceEnrol:(BOOL)canConvenienceEnrol
                        isAutoFillOpen:(BOOL)isAutoFillOpen
                manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
                   biometricPreCleared:(BOOL)biometricPreCleared
                            completion:(CompletionBlock)completion {
    self = [super init];
    if (self) {
        self.biometricIdName = [BiometricsManager.sharedInstance getBiometricIdName];
        self.viewController = viewController;
        self.safe = safe;
        self.canConvenienceEnrol = canConvenienceEnrol;
        self.openAutoFillCache = openAutoFillCache;
        self.completion = completion;
        self.isAutoFillOpen = isAutoFillOpen;
        self.manualOpenOfflineCache = manualOpenOfflineCache;
        self.biometricPreCleared = biometricPreCleared;
    }
    
    return self;
}

- (void)beginSequenceWithAutoFillFilesCheck {
    if(self.isAutoFillOpen && self.safe.storageProvider == kFilesAppUrlBookmark) {
        // Special case - We can support the Files app provider in Auto Fill but we need to ask the
        // user to actively re-select the database via UIDocumentPicjer :(
        //
        // Sucks but it's only a one time deal so do it...
        
        FilesAppUrlBookmarkProvider* fp = [SafeStorageProviderFactory getStorageProviderFromProviderId:kFilesAppUrlBookmark];
        
        if(![fp autoFillBookMarkIsSet:self.safe]) {
            [Alerts info:self.viewController
                   title:NSLocalizedString(@"open_sequence_prompt_database_reselect_required_title", @"Database File Select Required")
                 message:NSLocalizedString(@"open_sequence_prompt_database_reselect_required_message", @"For technical reasons, you need to re-select your database file to enable Auto Fill. You will only need to do this once.\n\nThanks!\n-Mark")
              completion:^{
                  [self promptForAutofillBookmarkSelect];
              }];
            return;
        }
    }
    
    [self beginSeq];
}

- (void)clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState {
    NSArray<SafeMetaData*>* databases = SafesList.sharedInstance.snapshot;
    
    // Unenrol/Remove Convenience Unlock secrets for all DBs protected by Biometric ID...
    // All because if an attacker adds a dummy db and successfully Bio authenticates -
    // good state will change and allow access to previously enrolled dbs

    for (SafeMetaData* database in databases) {
        if(database.isTouchIdEnabled) {
            NSLog(@"Clearing Biometrics for Database: [%@]", database.nickName);
            
            database.isEnrolledForConvenience = NO;
            database.convenienceMasterPassword = nil;
            database.convenenienceYubikeySecret = nil;
            
            // database.conveniencePin = nil; // KEEP PIN for users who use both...
            
            database.hasBeenPromptedForConvenience = NO; // Ask if user wants to enrol on next successful manual open
            [SafesList.sharedInstance update:database];
        }
    }

    [BiometricsManager.sharedInstance clearBiometricRecordedDatabaseState];
}

- (void)beginSeq {
    if (self.safe.isEnrolledForConvenience && Settings.sharedInstance.isProOrFreeTrial) {
        BOOL biometricPossible = self.safe.isTouchIdEnabled && BiometricsManager.isBiometricIdAvailable;
        BOOL biometricAllowed = !Settings.sharedInstance.disallowAllBiometricId;
        
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
            else {
                [self showBiometricAuthentication];
            }
        }
        else if(!Settings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil) {
            [self promptForConveniencePin];
        }
        else {
            [self promptForManualCredentials];
        }
    }
    else {
        [self promptForManualCredentials];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
                    self.safe.failedPinAttempts = 0;
                    
                    [SafesList.sharedInstance update:self.safe];
                    
                    [self onGotCredentials:self.safe.convenienceMasterPassword
                                keyFileUrl:self.safe.keyFileUrl
                        oneTimeKeyFileData:nil
                                  readOnly:self.safe.readOnly
                         manualOpenOffline:self.manualOpenOfflineCache
                             yubikeySecret:self.safe.convenenienceYubikeySecret
                      yubikeyConfiguration:self.safe.yubiKeyConfig];
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
                        self.safe.convenenienceYubikeySecret = nil;
                        
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
                self.completion(nil, nil);
            }
        }];
    };
    
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)performDuressAction {
    if (self.safe.duressAction == kOpenDummy) {
        SafeMetaData* metadata = [DuressDummyStorageProvider.sharedInstance getSafeMetaData:self.safe.nickName filename:self.safe.fileName fileIdentifier:self.safe.fileIdentifier];
        
        [DuressDummyStorageProvider.sharedInstance database:^(DatabaseModel * _Nonnull model) {
            Model *viewModel = [[Model alloc] initWithSafeDatabase:model
                                             originalDataForBackup:nil
                                                          metaData:metadata
                                                   storageProvider:DuressDummyStorageProvider.sharedInstance
                                                         cacheMode:NO
                                                        isReadOnly:NO];
            
            self.completion(viewModel, nil);
        }];
    }
    else if (self.safe.duressAction == kPresentError) {
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message", @"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue")
                error:error completion:^{
            self.completion(nil, error);
        }];
    }
    else if (self.safe.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe];
        NSError *error = [Utils createNSError:NSLocalizedString(@"open_sequence_duress_technical_error_message",@"There was a technical error opening the database.") errorCode:-1729];
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_duress_technical_error_title",@"Technical Issue") error:error completion:^{
            self.completion(nil, error);
        }];
    }
    else {
        self.completion(nil, nil);
    }
}

- (void)removeOrDeleteSafe {
    if (self.safe.storageProvider == kLocalDevice) {
        [[LocalDeviceStorageProvider sharedInstance] delete:self.safe completion:nil];
    }
    else if (self.safe.storageProvider == kiCloud) {
        [[AppleICloudProvider sharedInstance] delete:self.safe completion:nil];
    }
    
    [[CacheManager sharedInstance] deleteOfflineCachedSafe:self.safe completion:nil];
    [[CacheManager sharedInstance] deleteAutoFillCache:self.safe completion:nil];
    
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    [[SafesList sharedInstance] remove:self.safe.uuid];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showBiometricAuthentication {
    //NSLog(@"REQUEST-BIOMETRIC: Open Safe");
    
    if(self.biometricPreCleared) {
        NSLog(@"BIOMETRIC has been PRE-CLEARED - Coalescing Auths - Proceeding without prompting for auth");
        [self onBiometricAuthenticationDone:YES error:nil];
    }
    else {
        BOOL ret = [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                                          fallbackTitle:NSLocalizedString(@"open_sequence_biometric_unlock_fallback", @"Unlock Manually...")
                                                             completion:^(BOOL success, NSError * _Nullable error) {
            [self onBiometricAuthenticationDone:success error:error];
        }];
        
        if(!ret) {
            [Alerts info:self.viewController
                   title:@"iOS13 Biometric Bug"
                 message:@"Please try shaking your device to make the Biometric dialog appear. This is expected to be fixed in iOS13.2. Tap OK now and then shake.\nThanks,\n-Mark"];
        }
    }
}

- (void)onBiometricAuthenticationDone:(BOOL)success
                                error:(NSError *)error {
    if (success) {
        if(![BiometricsManager.sharedInstance isBiometricDatabaseStateRecorded:self.isAutoFillOpen]) {
            [BiometricsManager.sharedInstance recordBiometricDatabaseState:self.isAutoFillOpen]; // Successful Auth and no good previous state recorded, record Biometrics database state now...
        }

        self.isConvenienceUnlock = YES;
        if(!Settings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForConveniencePin];
            });
        }
        else {
            [self onGotCredentials:self.safe.convenienceMasterPassword
                        keyFileUrl:self.safe.keyFileUrl
                oneTimeKeyFileData:nil
                          readOnly:self.safe.readOnly
                 manualOpenOffline:self.manualOpenOfflineCache
                     yubikeySecret:self.safe.convenenienceYubikeySecret
              yubikeyConfiguration:self.safe.yubiKeyConfig];
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
            self.completion(nil, nil);
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

- (NSURL*)getAutoDetectedKeyFileUrl {
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
            return [directory URLByAppendingPathComponent:file];
        }
    }
    
    return nil;
}

- (void)promptForPasswordAndOrKeyFile {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CreateDatabaseOrSetCredentials" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    CASGTableViewController *scVc = (CASGTableViewController*)nav.topViewController;
    
    scVc.mode = kCASGModeGetCredentials;
    scVc.initialKeyFileUrl = self.safe.keyFileUrl;
    scVc.initialReadOnly = self.safe.readOnly;
    scVc.initialOfflineCache = self.manualOpenOfflineCache;
    scVc.initialYubiKeyConfig = self.safe.yubiKeyConfig;
    
    // Less than perfect but helpful
    
    BOOL probablyPasswordSafe = [self.safe.fileName.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; // Not Ideal
    
    scVc.initialFormat = self.safe.likelyFormat != kFormatUnknown ? self.safe.likelyFormat : heuristicFormat;
    
    if (self.safe.offlineCacheEnabled && self.safe.offlineCacheAvailable) {
        scVc.offlineCacheDate = [[CacheManager sharedInstance] getOfflineCacheFileModificationDate:self.safe];
    }
    
    // Auto Detect Key File if there's none explicitly set...
    
    if(!self.safe.keyFileUrl) {
        NSURL* autoDetectedKeyFileUrl = [self getAutoDetectedKeyFileUrl];
        if(autoDetectedKeyFileUrl) {
            scVc.autoDetectedKeyFileUrl = YES;
            scVc.initialKeyFileUrl = autoDetectedKeyFileUrl;
        }
    }
    
    scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [self onGotCredentials:creds.password
                            keyFileUrl:creds.keyFileUrl
                    oneTimeKeyFileData:creds.oneTimeKeyFileData
                              readOnly:creds.readOnly
                     manualOpenOffline:creds.offlineCache
                         yubikeySecret:creds.yubiKeySecret
                  yubikeyConfiguration:creds.yubiKeyConfig];
            }
            else {
                self.completion(nil, nil);
            }
        }];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onGotCredentials:(NSString*)password
              keyFileUrl:(NSURL*)keyFileUrl
      oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                readOnly:(BOOL)readOnly
       manualOpenOffline:(BOOL)manualOpenOffline
           yubikeySecret:(NSString*)yubikeySecret
    yubikeyConfiguration:(YubiKeyHardwareConfiguration*)yubikeyConfiguration {
    if(keyFileUrl || oneTimeKeyFileData) {
        NSError *error;
        self.undigestedKeyFileData = getKeyFileData(keyFileUrl, oneTimeKeyFileData, &error);

        if(self.undigestedKeyFileData == nil) {
            // Clear convenience unlock settings if we fail to read Key File - Force manual reselection.
            
            if(self.isConvenienceUnlock) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.convenenienceYubikeySecret = nil;
                self.safe.conveniencePin = nil;
                self.safe.isTouchIdEnabled = NO;
                self.safe.hasBeenPromptedForConvenience = NO; // Ask if user wants to enrol on next successful open
                
                [SafesList.sharedInstance update:self.safe];
            }

            if(keyFileUrl && self.isAutoFillOpen) {
                    [Alerts error:self.viewController
                            title:NSLocalizedString(@"open_sequence_error_reading_key_file_autofill_context", @"Could not read Key File. Has it been imported properly? Check Key Files Management in Preferences")
                            error:error
                       completion:^{
                        self.completion(nil, error);
                    }];
                    return;
            }
            else {
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"open_sequence_error_reading_key_file", @"Error Reading Key File")
                        error:error
                   completion:^{
                    self.completion(nil, error);
                }];
                return;
            }
        }
    }

    if(yubikeyConfiguration && yubikeyConfiguration.mode != kNoYubiKey) {
        self.yubiKeyConfiguration = yubikeyConfiguration;
    }
    else { // Only use the secret workaround if we're not directly using an actual YubiKey
        self.yubikeySecret = yubikeySecret;
    }
    
    // Change in Read-Only or Key File Setting or Yubikey setting? Save
    
    if(self.safe.readOnly != readOnly ||
       ![self.safe.keyFileUrl isEqual:keyFileUrl] ||
       ![self.safe.yubiKeyConfig isEqual:yubikeyConfiguration]) {
        self.safe.readOnly = readOnly;
        self.safe.keyFileUrl = keyFileUrl;
        self.safe.yubiKeyConfig = yubikeyConfiguration;
        
        [SafesList.sharedInstance update:self.safe];
    }
    
    self.manualOpenOfflineCache = manualOpenOffline;
    self.masterPassword = password;
    
    [self openSafe];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)openSafe {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:self.safe.storageProvider];
        
        if(self.openAutoFillCache) {
            [[CacheManager sharedInstance] readAutoFillCache:self.safe
                                                  completion:^(NSData *data, NSError *error) {
                [self onProviderReadDone:provider data:data error:error cacheMode:YES];
            }];
        }
        else if (self.manualOpenOfflineCache) {
            if(self.safe.offlineCacheEnabled && self.safe.offlineCacheAvailable) {
                [[CacheManager sharedInstance] readOfflineCachedSafe:self.safe
                                                          completion:^(NSData *data, NSError *error)
                 {
                     if(data != nil) {
                         [self onProviderReadDone:nil data:data error:error cacheMode:YES];
                     }
                 }];
            }
            else {
                [Alerts warn:self.viewController
                       title:NSLocalizedString(@"open_sequence_couldnt_open_offline_title", @"Could Not Open Offline")
                     message:NSLocalizedString(@"open_sequence_couldnt_open_offline_message", @"Could not open this database in offline mode. Does the Offline Cache exist?")];
                self.completion(nil, nil);
            }
            return;
        }
        else if (OfflineDetector.sharedInstance.isOffline && providerCanFallbackToOfflineCache(provider, self.safe)) {
            NSString * modDateStr = getLastCachedDate(self.safe);
            NSString* message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_user_looks_offline_open_offline_instead_fmt", @"Could not reach %@, it looks like you may be offline, would you like to use a read-only offline cache version of this database instead?\n\nLast Cached: %@"), provider.displayName, modDateStr];
            
            [self openWithOfflineCacheFile:message];
        }
        else {
            [provider read:self.safe
            viewController:self.viewController
                isAutoFill:self.isAutoFillOpen
                completion:^(NSData *data, NSError *error) {
                [self onProviderReadDone:provider data:data error:error cacheMode:NO];
             }];
        }
    });
}

- (void)onProviderReadDone:(id<SafeStorageProvider>)provider
                      data:(NSData *)data
                     error:(NSError *)error
                 cacheMode:(BOOL)cacheMode {
    dispatch_async(dispatch_get_main_queue(), ^{
//        [SVProgressHUD dismiss];
        
        if (error != nil || data == nil) {
            NSLog(@"Error: %@", error);
            if(providerCanFallbackToOfflineCache(provider, self.safe)) {
                NSString * modDateStr = getLastCachedDate(self.safe);
                NSString* message = [NSString stringWithFormat:NSLocalizedString(@"open_sequence_storage_unreachable_open_offline_instead_fmt", @"There was a problem reading the database on %@. If this happens repeatedly you should try removing and re-adding your database. Would you like to use a read-only offline cache version of this database instead?\n\nLast Cached: %@"), provider.displayName, modDateStr];
                
                [self openWithOfflineCacheFile:message];
            }
            else {
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                        error:error
                                                completion:^{
                    self.completion(nil, error);
                }];
            }
        }
        else {
            if(self.isAutoFillOpen &&
               !Settings.sharedInstance.haveWarnedAboutAutoFillCrash &&
               [DatabaseModel isAutoFillLikelyToCrash:data]) {
                [Alerts warn:self.viewController
                       title:NSLocalizedString(@"open_sequence_autofill_creash_likely_title", @"AutoFill Crash Likely")
                     message:NSLocalizedString(@"open_sequence_autofill_creash_likely_message", @"Your database has encryption settings that may cause iOS Password Auto Fill extensions to be terminated due to excessive resource consumption. This will mean Auto Fill appears not to work. Unfortunately this is an Apple imposed limit. You could consider reducing the amount of resources consumed by your encryption settings (Memory in particular with Argon2 to below 64MB).")
                completion:^{
                    Settings.sharedInstance.haveWarnedAboutAutoFillCrash = YES;
                    [self openSafeWithData:data provider:provider cacheMode:cacheMode];
                }];
            }
            else {
                [self openSafeWithData:data provider:provider cacheMode:cacheMode];
            }
        }
    });
}

- (NSData*)getDummyYubikeyResponse:(NSData*)challenge {
    // Some people program the Yubikey with Fixed Length "Fixed 64 byte input" and others with "Variable Input"
    // To cover both cases the KeePassXC model appears to be to always send 64 bytes with extraneous bytes above
    // and beyond the actual challenge padded PKCS#7 style-ish... MMcG - 1-Mar-2020
    //
    // Further Reading: https://github.com/Yubico/yubikey-personalization-gui/issues/86
    
    // May need to pad challenge
    
    const NSInteger kChallengeSize = 64;
    const NSInteger paddingLengthAndCharacter = kChallengeSize - challenge.length;
    uint8_t challengeBuffer[kChallengeSize];
    for(int i=0;i<kChallengeSize;i++) {
        challengeBuffer[i] = paddingLengthAndCharacter;
    }
    [challenge getBytes:challengeBuffer length:challenge.length];
    NSData* paddedChallenge = [NSData dataWithBytes:challengeBuffer length:kChallengeSize];
    
    // Get actual secret
    
    BOOL paddingRequired = [self.yubikeySecret hasPrefix:@"P"];
    NSString* sec = self.yubikeySecret;
    if (paddingRequired) {
        sec = [sec substringFromIndex:1];
    }
    NSData* yubikeySecretData = [Utils dataFromHexString:sec];
    
    NSData *actualChallenge = paddingRequired ? paddedChallenge : challenge;
    
    NSData* challengeResponse = hmacSha1(actualChallenge, yubikeySecretData);
    
    return challengeResponse;
}

- (void)openSafeWithData:(NSData *)data
                provider:(id)provider
               cacheMode:(BOOL)cacheMode {
    NSError* error;
    if(![DatabaseModel isAValidSafe:data error:&error]) {
        [self openSafeWithDataDone:error
                        openedSafe:nil
                         cacheMode:cacheMode
                          provider:provider
                              data:data];
        return;
    }
    
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    if (self.undigestedKeyFileData) {
        self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:self.undigestedKeyFileData checkForXml:format != kKeePass1];
    }

    // Yubikey?
  
    if (self.yubiKeyConfiguration && self.yubiKeyConfiguration != kNoYubiKey) {
        [self unlockValidDatabaseWithAllCompositeKeyFactors:data
                                                   provider:provider
                                                  cacheMode:cacheMode
                                                     format:format
                                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [self getYubiKeyChallengeResponse:challenge completion:completion];
        }];
    }
    else if (self.yubikeySecret.length) {
        [self unlockValidDatabaseWithAllCompositeKeyFactors:data
                                                   provider:provider
                                                  cacheMode:cacheMode
                                                     format:format
                                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            NSData* yubikeyResponse = [self getDummyYubikeyResponse:challenge];
            completion(NO, yubikeyResponse, nil);
        }];
    }
    else {
        [self unlockValidDatabaseWithAllCompositeKeyFactors:data provider:provider cacheMode:cacheMode format:format yubiKeyCR:nil];
    }
}

- (void)getYubiKeyChallengeResponse:(NSData*)challenge completion:(YubiKeyCRResponseBlock)completion {
#ifndef IS_APP_EXTENSION
    if([Settings.sharedInstance isProOrFreeTrial]) {
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
    // FUTURE: Is this true for the 5Ci MFI?
    NSString* loc = NSLocalizedString(@"open_sequence_cannot_use_yubikey_in_autofill_mode", @"YubiKey Unlock is not supported in Auto Fill mode");
    NSError* error = [Utils createNSError:loc errorCode:-1];
    completion(NO, nil, error);
#endif
}

- (void)unlockValidDatabaseWithAllCompositeKeyFactors:(NSData *)data
                                             provider:(id)provider
                                            cacheMode:(BOOL)cacheMode
                                               format:(DatabaseFormat)format
                                            yubiKeyCR:(YubiKeyCRHandlerBlock)yubiKeyCR {
    [SVProgressHUD showWithStatus:NSLocalizedString(@"open_sequence_progress_decrypting", @"Decrypting...")];

    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        CompositeKeyFactors* cpf = [CompositeKeyFactors password:self.masterPassword
                                                   keyFileDigest:self.keyFileDigest
                                                       yubiKeyCR:yubiKeyCR];

        if(!self.isConvenienceUnlock &&
           (format == kKeePass || format == kKeePass4) &&
           self.masterPassword.length == 0 &&
           (self.keyFileDigest || yubiKeyCR)) {
            // KeePass 2 allows empty and nil/none...
            // we need to try both to figure out what the user meant.
            // We will try empty first which is what will have come from the View Controller and then nil.
            
            // NB: We can't do this with Yubikey because it will require at least 2 scans, so we explicitly ask
            // NB: self.masterPassword will be @"" initially just due to the way CASG handles things

            if (!yubiKeyCR) { // Auto Figure it out
                [DatabaseModel fromData:data
                                    ckf:cpf
                             completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
                    if(model == nil && error && error.code == kStrongboxErrorCodeIncorrectCredentials) {
                        CompositeKeyFactors* ckf = [CompositeKeyFactors password:nil
                                                                   keyFileDigest:self.keyFileDigest
                                                                       yubiKeyCR:yubiKeyCR];
                        
                        // FUTURE: For Yubikey users this is an issue because they will be asked twice... maybe explicitly ask them if they mean nil or empty
                        
                        [DatabaseModel fromData:data
                                            ckf:ckf
                                     completion:^(BOOL userCancelled, DatabaseModel * _Nonnull model, NSError * _Nonnull error) {
                            if(model) {
                                self.masterPassword = nil;
                            }
                            
                            [self onGotDatabaseModelFromData:userCancelled model:model cacheMode:cacheMode provider:provider data:data error:error];
                        }];
                    }
                    else {
                        [self onGotDatabaseModelFromData:userCancelled model:model cacheMode:cacheMode provider:provider data:data error:error];
                    }
                }];
            }
            else { // YubiKey open - Just ask
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
                    [DatabaseModel fromData:data ckf:cpf completion:^(BOOL userCancelled, DatabaseModel* model, NSError* error) {
                        [self onGotDatabaseModelFromData:userCancelled model:model cacheMode:cacheMode provider:provider data:data error:error];
                    }];
                }];
            }
        }
        else {
            [DatabaseModel fromData:data
                                ckf:cpf
                         completion:^(BOOL userCancelled, DatabaseModel* model, NSError* error) {
                [self onGotDatabaseModelFromData:userCancelled model:model cacheMode:cacheMode provider:provider data:data error:error];
            }];
        }
    });
}

- (void)onGotDatabaseModelFromData:(BOOL)userCancelled
                             model:(DatabaseModel*)model
                         cacheMode:(BOOL)cacheMode
                          provider:(id)provider
                              data:(NSData*)data
                             error:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [SVProgressHUD dismiss];
        
        if (userCancelled) {
            self.completion(nil, nil);
        }
        else {
            [self openSafeWithDataDone:error openedSafe:model cacheMode:cacheMode provider:provider data:data];
        }
    });
}

- (void)openSafeWithDataDone:(NSError*)error
                  openedSafe:(DatabaseModel*)openedSafe
                   cacheMode:(BOOL)cacheMode
                    provider:(id)provider
                        data:(NSData *)data {
    [SVProgressHUD dismiss];
    
    if (openedSafe == nil) {
        if(!error) {
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
            self.completion(nil, error);
            return;
        }
        else if (error.code == kStrongboxErrorCodeIncorrectCredentials) {
            if(self.isConvenienceUnlock) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.convenenienceYubikeySecret = nil;
                self.safe.conveniencePin = nil;
                self.safe.isTouchIdEnabled = NO;
                self.safe.hasBeenPromptedForConvenience = NO; // Ask if user wants to enrol on next successful open
                
                [SafesList.sharedInstance update:self.safe];
                
                [Alerts info:self.viewController
                       title:NSLocalizedString(@"open_sequence_problem_opening_title", @"Could not open database")
                     message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_problem_opening_convenience_incorrect_message", @"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled.")]] ;
            }
            else {
                [Alerts info:self.viewController
                       title:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                     message:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.")];
            }
        }
        else {
            [Alerts error:self.viewController
                    title:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                    error:error];
        }
        
        self.completion(nil, error);
    }
    else {
        BOOL biometricPossible = BiometricsManager.isBiometricIdAvailable && !Settings.sharedInstance.disallowAllBiometricId;
        BOOL pinPossible = !Settings.sharedInstance.disallowAllPinCodeOpens;

        BOOL conveniencePossible = self.canConvenienceEnrol && !cacheMode && [Settings.sharedInstance isProOrFreeTrial] && (biometricPossible || pinPossible);
        BOOL convenienceNotYetPrompted = !self.safe.hasBeenPromptedForConvenience;
        
        BOOL quickLaunchPossible = !self.isAutoFillOpen && Settings.sharedInstance.quickLaunchUuid == nil;
        BOOL quickLaunchNotYetPrompted = !self.safe.hasBeenPromptedForQuickLaunch;
        
        if (conveniencePossible && convenienceNotYetPrompted) {
             [self promptForConvenienceEnrolAndOpen:biometricPossible pinPossible:pinPossible openedSafe:openedSafe cacheMode:cacheMode provider:provider data:data];
        }
        else if (quickLaunchPossible && quickLaunchNotYetPrompted) {
             [self promptForQuickLaunch:openedSafe cacheMode:cacheMode provider:provider data:data];
        }
        else {
            [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
        }
    }
}

- (void)promptForQuickLaunch:(DatabaseModel*)openedSafe
                   cacheMode:(BOOL)cacheMode
                    provider:(id)provider
                        data:(NSData *)data {
    if(!self.isAutoFillOpen && Settings.sharedInstance.quickLaunchUuid == nil && !self.safe.hasBeenPromptedForQuickLaunch) {
        [Alerts yesNo:self.viewController
                title:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_title", @"Set Quick Launch?")
              message:NSLocalizedString(@"open_sequence_yesno_set_quick_launch_message", @"Would you like to use this as your Quick Launch database? Quick Launch means you will get prompted immediately to unlock when you open Strongbox, saving you a precious click.")
               action:^(BOOL response) {
                   if(response) {
                       Settings.sharedInstance.quickLaunchUuid = self.safe.uuid;
                   }
                   
                   self.safe.hasBeenPromptedForQuickLaunch = YES;
                   [SafesList.sharedInstance update:self.safe];
                   [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
               }];
    }
}

- (void)enrolForBiometrics:(CompositeKeyFactors*)compositeKeyFactors {
    self.safe.isTouchIdEnabled = YES;

    self.safe.isEnrolledForConvenience = YES;
    self.safe.convenienceMasterPassword = compositeKeyFactors.password;
    self.safe.convenenienceYubikeySecret = self.yubikeySecret;
    self.safe.hasBeenPromptedForConvenience = YES;
    
    [SafesList.sharedInstance update:self.safe];
}

- (void)enrolForPinCodeUnlock:(NSString*)pin compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors {
    self.safe.conveniencePin = pin;

    self.safe.isEnrolledForConvenience = YES;
    self.safe.convenienceMasterPassword = compositeKeyFactors.password;
    self.safe.convenenienceYubikeySecret = self.yubikeySecret;
    self.safe.hasBeenPromptedForConvenience = YES;

    [SafesList.sharedInstance update:self.safe];
}

- (void)unenrolFromConvenience {
    self.safe.isTouchIdEnabled = NO;
    self.safe.conveniencePin = nil;

    self.safe.isEnrolledForConvenience = NO;
    self.safe.convenienceMasterPassword = nil;
    self.safe.convenenienceYubikeySecret = nil;
    self.safe.hasBeenPromptedForConvenience = YES;

    [SafesList.sharedInstance update:self.safe];
}

- (void)promptForConvenienceEnrolAndOpen:(BOOL)biometricPossible
                             pinPossible:(BOOL)pinPossible
                              openedSafe:(DatabaseModel*)openedSafe
                               cacheMode:(BOOL)cacheMode
                                provider:(id)provider
                                    data:(NSData *)data {
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
    
    if (!Settings.sharedInstance.isPro) {
        message = [message stringByAppendingFormat:NSLocalizedString(@"open_sequence_append_convenience_pro_warning", @"\n\nNB: Convenience Unlock is a Pro feature")];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(biometricPossible) {
        UIAlertAction *biometricAction = [UIAlertAction actionWithTitle:
                                          [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_bio_fmt", @"Use %@"), self.biometricIdName]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) {
                                                                [self enrolForBiometrics:openedSafe.compositeKeyFactors];
                                                                [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                                                            }];
        [alertController addAction:biometricAction];
    }
    
    if (pinPossible) {
        UIAlertAction *pinCodeAction = [UIAlertAction actionWithTitle:
                                        [NSString stringWithFormat:NSLocalizedString(@"open_sequence_prompt_use_convenience_use_pin", @"Use a PIN Code...")]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self setupConveniencePinAndOpen:openedSafe cacheMode:cacheMode provider:provider data:data];
                                                          }];
        [alertController addAction:pinCodeAction];
    }
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"open_sequence_prompt_option_no", @"No")
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *a) {
                                                         [self unenrolFromConvenience];
                                                         [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                                                     }];
    

    [alertController addAction:noAction];
    
    [self.viewController presentViewController:alertController animated:YES completion:nil];
}

- (void)setupConveniencePinAndOpen:(DatabaseModel*)openedSafe
                         cacheMode:(BOOL)cacheMode
                          provider:(id)provider
                              data:(NSData *)data {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* pinEntryVc = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if(!(self.safe.duressPin != nil && [pin isEqualToString:self.safe.duressPin])) {
                    [self enrolForPinCodeUnlock:pin compositeKeyFactors:openedSafe.compositeKeyFactors];
                    [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                }
                else {
                    [Alerts warn:self.viewController
                           title:NSLocalizedString(@"open_sequence_warn_pin_conflict_title", @"PIN Conflict")
                        message:NSLocalizedString(@"open_sequence_warn_pin_conflict_message", @"Your Convenience PIN conflicts with your Duress PIN. Please configure in Database Settings")
                    completion:^{
                        [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                    }];
                }
            }
            else {
                [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
            }
        }];
    };

    [self.viewController presentViewController:pinEntryVc animated:YES completion:nil];
}

-(void)onSuccessfulSafeOpen:(BOOL)cacheMode
                   provider:(id)provider
                 openedSafe:(DatabaseModel *)openedSafe
                       data:(NSData *)data {
    UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
    [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                     originalDataForBackup:data
                                                  metaData:self.safe
                                           storageProvider:cacheMode ? nil : provider // Guarantee nothing can be written!
                                                 cacheMode:cacheMode
                                                isReadOnly:NO];
    
    viewModel.openedWithYubiKeySecret = self.yubikeySecret;
    
    if (!cacheMode) {
        if(self.safe.offlineCacheEnabled) {
            [viewModel updateOfflineCacheWithData:data];
        }
        
        if(self.safe.autoFillEnabled && !self.isAutoFillOpen) { // This is memory heavy ... don't blow it in Auto Fill
            [viewModel updateAutoFillCacheWithData:data];
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:openedSafe databaseUuid:self.safe.uuid];
        }

        NSLog(@"Setting likelyFormat to [%ld]", (long)openedSafe.format);
        self.safe.likelyFormat = openedSafe.format;
        [SafesList.sharedInstance update:self.safe];
    }
    
    self.completion(viewModel, nil);
}

- (void)openWithOfflineCacheFile:(NSString *)message {
    [Alerts yesNo:self.viewController
            title:NSLocalizedString(@"open_sequence_yesno_use_offline_cache_title", @"Use Offline Cache?")
          message:message
           action:^(BOOL response) {
               if (response) {
                   [[CacheManager sharedInstance] readOfflineCachedSafe:self.safe
                                                             completion:^(NSData *data, NSError *error)
                    {
                        if(data != nil) {
                            [self onProviderReadDone:nil
                                                data:data
                                               error:error
                                           cacheMode:YES];
                        }
                    }];
               }
               else {
                   self.completion(nil, nil);
               }
           }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static NSString *getLastCachedDate(SafeMetaData *safe) {
    NSDate *modDate = [[CacheManager sharedInstance] getOfflineCacheFileModificationDate:safe];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;
    
    NSString *modDateStr = [df stringFromDate:modDate];
    return modDateStr;
}

BOOL providerCanFallbackToOfflineCache(id<SafeStorageProvider> provider, SafeMetaData* safe) {
    BOOL basic =    provider &&
                    provider.allowOfflineCache &&
    !(provider.storageId == kiCloud && Settings.sharedInstance.iCloudOn) &&
    safe.offlineCacheEnabled && safe.offlineCacheAvailable;
    
    if(basic) {
        NSDate *modDate = [[CacheManager sharedInstance] getOfflineCacheFileModificationDate:safe];
        
        return modDate != nil;
    }
    
    return NO;
}

//////////

static OpenSafeSequenceHelper *sharedInstance = nil;

- (void)promptForAutofillBookmarkSelect {
    self.documentPicker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeOpen];
    self.documentPicker.delegate = self;
    self.documentPicker.modalPresentationStyle = UIModalPresentationFormSheet;
    
    
    // Some Voodoo to keep this instance around otherwise the delegate never gets called... Only
    // done in Auto Fill context but it would be nice to find a better way to do this?
    
    sharedInstance = self;
    
    [self.viewController presentViewController:self.documentPicker animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.completion(nil, nil);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"AutoFill: didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        NSData* data = document.data;
        
        [document closeWithCompletionHandler:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self readReselectedFilesDatabase:success data:data url:url];
        });
    }];
}

- (void)readReselectedFilesDatabase:(BOOL)success data:(NSData*)data url:(NSURL*)url {
    if(!success || !data) {
        [Alerts warn:self.viewController
               title:@"Error Opening This Database"
             message:@"Could not access this file."];
    }
    else {
        NSError* error;
        
        if (![DatabaseModel isAValidSafe:data error:&error]) {
            [Alerts error:self.viewController
                    title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_invalid_database_filename_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                    error:error];
            return;
        }
        
        if(![url.lastPathComponent isEqualToString:self.safe.fileName]) {
            [Alerts yesNo:self.viewController
                    title:NSLocalizedString(@"open_sequence_database_different_filename_title",@"Different Filename")
                  message:NSLocalizedString(@"open_sequence_database_different_filename_message",@"This doesn't look like it's the right file because the filename looks different than the one you originally added. Do you want to continue?")
                   action:^(BOOL response) {
                       if(response) {
                           [self setAutoFillBookmark:url];
                       }
                   }];
        }
        else {
            [self setAutoFillBookmark:url];
        }
    }
}

- (void)setAutoFillBookmark:(NSURL*)url {
    NSError* error;
    NSData* bookMark = [BookmarksHelper getBookmarkDataFromUrl:url error:&error];
    
    if (error) {
        [Alerts error:self.viewController
                title:NSLocalizedString(@"open_sequence_error_could_not_bookmark_file", @"Could not bookmark this file")
                error:error];
        return;
    }
    
    NSLog(@"Setting Auto Fill Bookmark: %@", bookMark);
    
    FilesAppUrlBookmarkProvider* fp = [SafeStorageProviderFactory getStorageProviderFromProviderId:kFilesAppUrlBookmark];
    
    self.safe = [fp setAutoFillBookmark:bookMark metadata:self.safe];
    [SafesList.sharedInstance update:self.safe];
    
    [self beginSeq];
}

@end
