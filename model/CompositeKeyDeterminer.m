//
//  CompositeKeyDeterminer.m
//  Strongbox
//
//  Created by Strongbox on 06/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <LocalAuthentication/LocalAuthentication.h>

#import "CompositeKeyDeterminer.h"
#import "BiometricsManager.h"
#import "SafesList.h"
#import "SharedAppAndAutoFillSettings.h"
#import "Alerts.h"
#import "PinEntryController.h"
#import "SyncManager.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "BookmarksHelper.h"
#import "FileManager.h"
#import "KeyFileHelper.h"
#import "Serializator.h"
#import "KeyFileParser.h"
#import "YubiManager.h"
#import "Utils.h"
#import "VirtualYubiKeys.h"
#import "WorkingCopyManager.h"

static const int kMaxFailedPinAttempts = 3;

@interface CompositeKeyDeterminer ()

@property (nonnull) UIViewController* viewController;
@property (nonnull) SafeMetaData* database;
@property BOOL isAutoFillOpen;
@property BOOL isAutoFillQuickTypeOpen;
@property BOOL biometricPreCleared; 
@property BOOL noConvenienceUnlock;

@property (nonnull) CompositeKeyDeterminedBlock completion;

@end

@implementation CompositeKeyDeterminer

+ (instancetype)determinerWithViewController:(UIViewController *)viewController
                                    database:(SafeMetaData *)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                         biometricPreCleared:(BOOL)biometricPreCleared
                         noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    return [[CompositeKeyDeterminer alloc] initWithViewController:viewController
                                                             database:database
                                                   isAutoFillOpen:isAutoFillOpen
                                          isAutoFillQuickTypeOpen:isAutoFillQuickTypeOpen
                                              biometricPreCleared:biometricPreCleared
                                              noConvenienceUnlock:noConvenienceUnlock];
}

- (instancetype)initWithViewController:(UIViewController *)viewController
                              database:(SafeMetaData *)database
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               isAutoFillQuickTypeOpen:(BOOL)isAutoFillQuickTypeOpen
                   biometricPreCleared:(BOOL)biometricPreCleared
                   noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.database = database;
        self.isAutoFillOpen = isAutoFillOpen;
        self.isAutoFillQuickTypeOpen = isAutoFillQuickTypeOpen;
        self.biometricPreCleared = biometricPreCleared;
        self.noConvenienceUnlock = noConvenienceUnlock;
    }
    
    return self;
}

- (void)getCredentials:(CompositeKeyDeterminedBlock)completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self innerGetCredentials:completion];
    });
}

- (void)innerGetCredentials:(CompositeKeyDeterminedBlock)completion {
    self.completion = completion;

    if (!self.noConvenienceUnlock && self.database.isEnrolledForConvenience && SharedAppAndAutoFillSettings.sharedInstance.isProOrFreeTrial) {
        BOOL biometricPossible = self.database.isTouchIdEnabled && BiometricsManager.isBiometricIdAvailable;
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
            else if (self.isAutoFillOpen && self.database.mainAppAndAutoFillYubiKeyConfigsIncoherent) { 
                [self promptForManualCredentials];
            }
            else {
                [self showBiometricAuthentication];
            }
        }
        else if(!SharedAppAndAutoFillSettings.sharedInstance.disallowAllPinCodeOpens && self.database.conveniencePin != nil) {
            if (self.isAutoFillOpen && self.database.mainAppAndAutoFillYubiKeyConfigsIncoherent) { 
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



- (void)promptForConveniencePin {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"PinEntry" bundle:nil];
    PinEntryController* vc = (PinEntryController*)[storyboard instantiateInitialViewController];
    
    vc.pinLength = self.database.conveniencePin.length;
    vc.showFallbackOption = YES;
    vc.isDatabasePIN = YES;
    
    if(self.database.failedPinAttempts > 0) {
        vc.warning = [NSString stringWithFormat:
                      NSLocalizedString(@"open_sequence_pin_attempts_remaining_fmt",@"%d attempts remaining"), kMaxFailedPinAttempts - self.database.failedPinAttempts];
    }
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            [self onPinEntered:response pin:pin];
        }];
    };
    
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)onPinEntered:(PinEntryResponse)response pin:(NSString*)pin {
    if(response == kOk) {
        if([pin isEqualToString:self.database.conveniencePin]) {
            if (self.database.failedPinAttempts != 0) { 
                self.database.failedPinAttempts = 0;
                [SafesList.sharedInstance update:self.database];
            }
            
            [self onGotCredentials:self.database.convenienceMasterPassword
                   keyFileBookmark:self.database.keyFileBookmark
                oneTimeKeyFileData:nil
                          readOnly:self.database.readOnly
              yubikeyConfiguration:self.database.contextAwareYubiKeyConfig
                   usedConvenience:YES];
        }
        else if (self.database.duressPin != nil && [pin isEqualToString:self.database.duressPin]) {
            UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
            [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

            self.completion(kGetCompositeKeyResultDuressIndicated, nil, YES, nil);
            return;
        }
        else {
            self.database.failedPinAttempts++;
            [SafesList.sharedInstance update:self.database];
            
            UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
            [gen notificationOccurred:UINotificationFeedbackTypeError];

            if (self.database.failedPinAttempts >= kMaxFailedPinAttempts) {
                self.database.failedPinAttempts = 0;
                self.database.isTouchIdEnabled = NO;
                self.database.conveniencePin = nil;
                self.database.isEnrolledForConvenience = NO;
                self.database.convenienceMasterPassword = nil;
                
                [SafesList.sharedInstance update:self.database];
                
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
        self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
    }
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
    NSString* biometricIdName = BiometricsManager.sharedInstance.biometricIdName;
    
    if (success) {
        if(![BiometricsManager.sharedInstance isBiometricDatabaseStateRecorded:self.isAutoFillOpen]) {
            [BiometricsManager.sharedInstance recordBiometricDatabaseState:self.isAutoFillOpen]; 
        }

        if(!SharedAppAndAutoFillSettings.sharedInstance.disallowAllPinCodeOpens && self.database.conveniencePin != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForConveniencePin];
            });
        }
        else {
            [self onGotCredentials:self.database.convenienceMasterPassword
                   keyFileBookmark:self.database.keyFileBookmark
                oneTimeKeyFileData:nil
                          readOnly:self.database.readOnly
              yubikeyConfiguration:self.database.contextAwareYubiKeyConfig
                   usedConvenience:YES];
        }
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self.viewController
                         title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), biometricIdName]
                       message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_message_fmt", @"%@ Authentication Failed. You must now enter your password manually to open the database."), biometricIdName]
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
                         title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), biometricIdName]
                       message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_not_configured_fmt", @"%@ has failed: %@. You must now enter your password manually to open the database."), biometricIdName, error]
                    completion:^{
                        [self promptForManualCredentials];
                    }];
            });
        }
        else {
            self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
        }
    }
}



- (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:@"key"];
    
    return  expectedKeyFileName;
}

- (NSString*)getAutoDetectedKeyFileUrl {
    NSURL *directory = FileManager.sharedInstance.documentsDirectory;
    NSString* expectedKeyFileName = [self getExpectedAssociatedLocalKeyFileName:self.database.fileName];
 
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

- (void)promptForManualCredentials {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"CreateDatabaseOrSetCredentials" bundle:nil];
    UINavigationController* nav = (UINavigationController*)[storyboard instantiateInitialViewController];
    CASGTableViewController *scVc = (CASGTableViewController*)nav.topViewController;
    
    scVc.mode = kCASGModeGetCredentials;
    
    scVc.initialKeyFileBookmark = self.database.keyFileBookmark;
    scVc.initialReadOnly = self.database.readOnly;
    
    scVc.initialYubiKeyConfig = self.database.contextAwareYubiKeyConfig;
    
    scVc.validateCommonKeyFileMistakes = self.database.keyFileBookmark == nil; 
    
    
    
    BOOL probablyPasswordSafe = [self.database.fileName.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; 
    
    scVc.initialFormat = self.database.likelyFormat != kFormatUnknown ? self.database.likelyFormat : heuristicFormat;
    
    
    
    if(!self.database.keyFileBookmark) {
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
                  yubikeyConfiguration:creds.yubiKeyConfig
                       usedConvenience:NO];
            }
            else {
                self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
            }
        }];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)onGotCredentials:(NSString*)password
         keyFileBookmark:(NSString*)keyFileBookmark
      oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                readOnly:(BOOL)readOnly
    yubikeyConfiguration:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration
         usedConvenience:(BOOL)usedConvenience {
    NSData* undigestedKeyFileData;
    
    if(keyFileBookmark || oneTimeKeyFileData) {
        NSError *error;
        undigestedKeyFileData = getKeyFileData(keyFileBookmark, oneTimeKeyFileData, &error);

        if( undigestedKeyFileData == nil ) {
            
            
            if( usedConvenience ) {
                self.database.isEnrolledForConvenience = NO;
                self.database.convenienceMasterPassword = nil;
                self.database.conveniencePin = nil;
                self.database.isTouchIdEnabled = NO;
                self.database.hasBeenPromptedForConvenience = NO; 
                
                [SafesList.sharedInstance update:self.database];
            }

            if(keyFileBookmark && self.isAutoFillOpen) {
                    [Alerts error:self.viewController
                            title:NSLocalizedString(@"open_sequence_error_reading_key_file_autofill_context", @"Could not read Key File. Has it been imported properly? Check Key Files Management in Preferences")
                            error:error
                       completion:^{
                        self.completion(kGetCompositeKeyResultError, nil, NO, error);
                    }];
                    return;
            }
            else {
                [Alerts error:self.viewController
                        title:NSLocalizedString(@"open_sequence_error_reading_key_file", @"Error Reading Key File")
                        error:error
                   completion:^{
                    self.completion(kGetCompositeKeyResultError, nil, NO, error);
                }];
                return;
            }
        }
    }
    
    

    BOOL readOnlyChanged = self.database.readOnly != readOnly;
    BOOL keyFileChanged = (!(self.database.keyFileBookmark == nil && keyFileBookmark == nil)) && (![self.database.keyFileBookmark isEqual:keyFileBookmark]);
    BOOL yubikeyChanged = (!(self.database.contextAwareYubiKeyConfig == nil && yubiKeyConfiguration == nil)) && (![self.database.contextAwareYubiKeyConfig isEqual:yubiKeyConfiguration]);
    
    if(readOnlyChanged || keyFileChanged || yubikeyChanged) {
        self.database.readOnly = readOnly;
        self.database.keyFileBookmark = keyFileBookmark;
        self.database.contextAwareYubiKeyConfig = yubiKeyConfiguration;
        [SafesList.sharedInstance update:self.database];
    }
    
    [self completeRequestWithCredentials:password undigestedKeyFileData:undigestedKeyFileData yubiKeyConfiguration:yubiKeyConfiguration usedConvenience:usedConvenience];
}

- (void)completeRequestWithCredentials:(NSString*)password undigestedKeyFileData:(NSData*)undigestedKeyFileData yubiKeyConfiguration:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration usedConvenience:(BOOL)usedConvenience {
    NSData* keyFileDigest = nil;
    if (undigestedKeyFileData) {
        BOOL checkForXml = YES;

        NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.database];
        if (url) {
            DatabaseFormat format = [Serializator getDatabaseFormat:url];
            checkForXml = format != kKeePass1;
        }
        
        keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:undigestedKeyFileData checkForXml:checkForXml];
    }

    CompositeKeyFactors* ret;
    if (yubiKeyConfiguration && yubiKeyConfiguration.mode != kNoYubiKey) {
        ret = [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest
                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [self getYubiKeyChallengeResponse:yubiKeyConfiguration challenge:challenge completion:completion];
        }];
    }
    else {
        ret = [CompositeKeyFactors password:password keyFileDigest:keyFileDigest];
    }

    self.completion(kGetCompositeKeyResultSuccess, ret, usedConvenience, nil);
}



- (void)getYubiKeyChallengeResponse:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration challenge:(NSData*)challenge completion:(YubiKeyCRResponseBlock)completion {
#ifndef IS_APP_EXTENSION
    if([SharedAppAndAutoFillSettings.sharedInstance isProOrFreeTrial] || yubiKeyConfiguration.mode == kVirtual) {
        [YubiManager.sharedInstance getResponse:yubiKeyConfiguration
                                      challenge:challenge
                                     completion:completion];
    }
    else {
        NSString* loc = NSLocalizedString(@"open_sequence_yubikey_only_available_in_pro", @"YubiKey Unlock is only available in the Pro edition of Strongbox");
        NSError* error = [Utils createNSError:loc errorCode:-1];
        completion(NO, nil, error);
    }
#else
    if(yubiKeyConfiguration.mode == kVirtual) {
        VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:yubiKeyConfiguration.virtualKeyIdentifier];
        
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

@end
