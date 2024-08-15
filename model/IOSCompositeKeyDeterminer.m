//
//  CompositeKeyDeterminer.m
//  Strongbox
//
//  Created by Strongbox on 06/01/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import <LocalAuthentication/LocalAuthentication.h>

#import "IOSCompositeKeyDeterminer.h"
#import "BiometricsManager.h"
#import "DatabasePreferences.h"
#import "AppPreferences.h"
#import "Alerts.h"
#import "PinEntryController.h"
#import "SyncManager.h"
#import "AutoFillManager.h"
#import "CASGTableViewController.h"
#import "BookmarksHelper.h"
#import "StrongboxiOSFilesManager.h"
#import "Serializator.h"
#import "KeyFileManagement.h"
#import "YubiManager.h"
#import "Utils.h"
#import "VirtualYubiKeys.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "SVProgressHUD.h"

static const int kMaxFailedPinAttempts = 3;

@interface IOSCompositeKeyDeterminer ()

@property (nonnull) UIViewController* viewController;
@property (nonnull) DatabasePreferences* database;
@property BOOL isAutoFillOpen;
@property BOOL transparentAutoFillBackgroundForBiometrics;
@property BOOL biometricPreCleared; 
@property BOOL noConvenienceUnlock;

@property (nonnull) CompositeKeyDeterminedBlock completion;

@end

@implementation IOSCompositeKeyDeterminer

+ (instancetype)determinerWithViewController:(UIViewController *)viewController
                                    database:(DatabasePreferences *)database
                              isAutoFillOpen:(BOOL)isAutoFillOpen
                     transparentAutoFillBackgroundForBiometrics:(BOOL)transparentAutoFillBackgroundForBiometrics
                         biometricPreCleared:(BOOL)biometricPreCleared
                         noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    return [[IOSCompositeKeyDeterminer alloc] initWithViewController:viewController
                                                         database:database
                                                   isAutoFillOpen:isAutoFillOpen
                                          transparentAutoFillBackgroundForBiometrics:transparentAutoFillBackgroundForBiometrics
                                              biometricPreCleared:biometricPreCleared
                                              noConvenienceUnlock:noConvenienceUnlock];
}

- (instancetype)initWithViewController:(UIViewController *)viewController
                              database:(DatabasePreferences *)database
                        isAutoFillOpen:(BOOL)isAutoFillOpen
               transparentAutoFillBackgroundForBiometrics:(BOOL)transparentAutoFillBackgroundForBiometrics
                   biometricPreCleared:(BOOL)biometricPreCleared
                   noConvenienceUnlock:(BOOL)noConvenienceUnlock {
    self = [super init];
    if (self) {
        self.viewController = viewController;
        self.database = database;
        self.isAutoFillOpen = isAutoFillOpen;
        self.transparentAutoFillBackgroundForBiometrics = transparentAutoFillBackgroundForBiometrics;
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

- (BOOL)isAutoFillConvenienceAutoLockPossible {
    BOOL isWithinAutoFillConvenienceAutoUnlockTime = NO;
    
    if ( self.isAutoFillOpen &&
        self.database.autoFillLastUnlockedAt != nil &&
        self.database.autoFillConvenienceAutoUnlockTimeout > 0 ) {
        isWithinAutoFillConvenienceAutoUnlockTime = ![self.database.autoFillLastUnlockedAt isMoreThanXSecondsAgo:self.database.autoFillConvenienceAutoUnlockTimeout];
    }
    

    
    return isWithinAutoFillConvenienceAutoUnlockTime && self.database.autoFillConvenienceAutoUnlockPassword != nil;
}

- (void)innerGetCredentials:(CompositeKeyDeterminedBlock)completion {
    self.completion = completion;

    if ( self.isAutoFillConvenienceAutoLockPossible ) {
        slog(@"AutoFill and within convenience auto unlock timeout. Will auto open...");
        
        [self onGotCredentials:self.database.autoFillConvenienceAutoUnlockPassword
               keyFileBookmark:self.database.keyFileBookmark
               keyFileFileName:self.database.keyFileFileName
            oneTimeKeyFileData:nil
                      readOnly:self.database.readOnly
          yubikeyConfiguration:self.database.contextAwareYubiKeyConfig
               usedConvenience:YES];
        
        return;
    }

    BOOL convenienceUnlockIsDesirable = !self.noConvenienceUnlock &&
                                        self.database.conveniencePasswordHasBeenStored &&
                                        AppPreferences.sharedInstance.isPro &&
                                        !( self.isAutoFillOpen && self.database.mainAppAndAutoFillYubiKeyConfigsIncoherent ); 
        
    
    
    BOOL askForBio = NO;
    BOOL askForPin = NO;
    BOOL bioDbHasChanged = NO;

    if ( convenienceUnlockIsDesirable ) {
        BOOL biometricPossible = self.database.isTouchIdEnabled && BiometricsManager.isBiometricIdAvailable;
        
        if ( biometricPossible ) {
            bioDbHasChanged = [BiometricsManager.sharedInstance isBiometricDatabaseStateHasChanged:self.isAutoFillOpen];

            if( !bioDbHasChanged) {
                askForBio = YES;
            }
        }

        if( self.database.conveniencePin != nil ) {
            askForPin = YES;
        }
    }

    if ( bioDbHasChanged ) {
        [self clearBioDbAndPrompManual];
    }
    else {
        if ( askForPin || askForBio ) {
            [self.database triggerPasswordExpiry]; 
            
            if ( self.database.conveniencePasswordHasExpired ) {
                [self displayConvenienceExpiryMessage];
            }
            else {
                [self beginConvenienceUnlock:self.database.convenienceMasterPassword askForBio:askForBio askForPin:askForPin];
            }
        }
        else {
            [self promptForManualCredentials];
        }
    }
}

- (void)beginConvenienceUnlock:(NSString*)password askForBio:(BOOL)askForBio askForPin:(BOOL)askForPin {
    
    

    dispatch_async(dispatch_get_main_queue(), ^{
        if ( askForBio ) {
            [self showBiometricAuthentication:password];
        }
        else if ( askForPin ) {
            [self promptForConveniencePin:password];
        }
        else {
            [self promptForManualCredentials];
        }
    });
}

- (void)displayConvenienceExpiryMessage {
    slog(@"displayConvenienceExpiryMessage");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.database.showConvenienceExpiryMessage ) {
            [Alerts twoOptionsWithCancel:self.viewController
                                   title:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_expired", @"Master Password Required")
                                 message:NSLocalizedString(@"composite_key_determiner_convenience_expired_message", @"It's time now to re-enter your Master Password manually. You can change this master password expiry interval in Database Settings.")
                       defaultButtonText:NSLocalizedString(@"alerts_ok", @"OK")
                        secondButtonText:NSLocalizedString(@"generic_ok_dont_remind_me_again", @"OK, Don't Remind Me Again")
                                  action:^(int response) {
                if ( response == 0 ) { 
                    [self promptForManualCredentials];
                }
                else if ( response == 1 ) {
                    self.database.showConvenienceExpiryMessage = NO;
                    [self promptForManualCredentials];
                }
                else {
                    self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
                }
            }];
        }
        else {
            [self promptForManualCredentials];
        }
    });
}

- (void)clearBioDbAndPrompManual {
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

- (void)clearAllBiometricConvenienceSecretsAndResetBiometricsDatabaseGoodState {
    NSArray<DatabasePreferences*>* databases = DatabasePreferences.allDatabases;
    
    
    
    

    for (DatabasePreferences* database in databases) {
        if(database.isTouchIdEnabled) {
            slog(@"Clearing Biometrics for Database: [%@]", database.nickName);
            
            database.conveniencePasswordHasBeenStored = NO;
            database.convenienceMasterPassword = nil;
        }
    }

    [BiometricsManager.sharedInstance clearBiometricRecordedDatabaseState];
}



- (void)promptForConveniencePin:(NSString*)password {
    PinEntryController* vc = PinEntryController.newControllerForDatabaseUnlock;
    
    vc.pinLength = self.database.conveniencePin.length;
    vc.showFallbackOption = YES;
    
    if(self.database.failedPinAttempts > 0) {
        vc.warning = [NSString stringWithFormat:
                      NSLocalizedString(@"open_sequence_pin_attempts_remaining_fmt",@"%d attempts remaining"), kMaxFailedPinAttempts - self.database.failedPinAttempts];
    }
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self onPinEntered:password response:response pin:pin];
    };
    
    vc.modalPresentationStyle = Utils.isiPad ? UIModalPresentationFormSheet : UIModalPresentationFullScreen;
    [self.viewController presentViewController:vc animated:YES completion:nil];
}

- (void)onPinEntered:(NSString*)password response:(PinEntryResponse)response pin:(NSString*)pin {
    if(response == kPinEntryResponseOk) {
        if( [pin isEqualToString:self.database.conveniencePin] ) {
            if (self.database.failedPinAttempts != 0) { 
                self.database.failedPinAttempts = 0;
            }
            
            [self onConvenienceMethodsSucceeded:password
                                keyFileBookmark:self.database.keyFileBookmark
                                keyFileFileName:self.database.keyFileFileName
                             oneTimeKeyFileData:nil
                                       readOnly:self.database.readOnly
                           yubikeyConfiguration:self.database.contextAwareYubiKeyConfig];
        }
        else if (self.database.duressPin != nil && [pin isEqualToString:self.database.duressPin]) {
            UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
            [gen notificationOccurred:UINotificationFeedbackTypeSuccess];

            self.completion(kGetCompositeKeyResultDuressIndicated, nil, YES, nil);
            return;
        }
        else {
            self.database.failedPinAttempts++;
            
            UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
            [gen notificationOccurred:UINotificationFeedbackTypeError];

            if (self.database.failedPinAttempts >= kMaxFailedPinAttempts) {
                self.database.failedPinAttempts = 0;
                self.database.conveniencePasswordHasBeenStored = NO;
                self.database.convenienceMasterPassword = nil;
                
                

                self.database.isTouchIdEnabled = NO;
                self.database.conveniencePin = nil;
                
                [Alerts warn:self.viewController
                       title:NSLocalizedString(@"open_sequence_prompt_too_many_incorrect_pins_title",@"Too Many Incorrect PINs")
                     message:NSLocalizedString(@"open_sequence_prompt_too_many_incorrect_pins_message",@"You have entered the wrong PIN too many times. PIN Unlock is now disabled, and you must enter the master password to unlock this database.")];
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self promptForConveniencePin:password];
                });
            }
        }
    }
    else if (response == kPinEntryResponseFallback) {
        [self promptForManualCredentials];
    }
    else {
        self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
    }
}



- (void)showBiometricAuthentication:(NSString*)password {
    if(self.biometricPreCleared) {
        slog(@"BIOMETRIC has been PRE-CLEARED - Coalescing Auths - Proceeding without prompting for auth");
        [self onBiometricAuthenticationDone:password success:YES error:nil];
    }
    else {

        
        CGFloat delay = 0.0;
        if (self.transparentAutoFillBackgroundForBiometrics) {  
            self.viewController.view.alpha = 0.0f;
            delay = 0.35;
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            BOOL ret = [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"open_sequence_biometric_unlock_prompt_title", @"Identify to Unlock Database")
                                                   fallbackTitle:NSLocalizedString(@"open_sequence_biometric_unlock_fallback", @"Unlock Manually...")
                                                      completion:^(BOOL success, NSError * _Nullable error) {
                    [self onBiometricAuthenticationDone:password success:success error:error];
                    
                
                







            }];

            if(!ret) {
                self.completion(kGetCompositeKeyResultError, nil, NO, [Utils createNSError:@"Could not complete biometric request" errorCode:-1234]);
            }
        });
    }
}

- (void)onBiometricAuthenticationDone:(NSString*)password
                              success:(BOOL)success
                                error:(NSError *)error {
    NSString* biometricIdName = BiometricsManager.sharedInstance.biometricIdName;
    
    if (success) {
        if(![BiometricsManager.sharedInstance isBiometricDatabaseStateRecorded:self.isAutoFillOpen]) {
            [BiometricsManager.sharedInstance recordBiometricDatabaseState:self.isAutoFillOpen]; 
        }

        if( self.database.conveniencePin != nil ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForConveniencePin:password];
            });
        }
        else {
            [self onConvenienceMethodsSucceeded:password
                                keyFileBookmark:self.database.keyFileBookmark
                                keyFileFileName:self.database.keyFileFileName
                             oneTimeKeyFileData:nil
                                       readOnly:self.database.readOnly
                           yubikeyConfiguration:self.database.contextAwareYubiKeyConfig];
        }
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts oneOptionsWithCancel:self.viewController
                                       title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), biometricIdName]
                                     message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_message_fmt", @"%@ Authentication Failed. You must now enter your password manually to open the database."), biometricIdName]
                                  buttonText:NSLocalizedString(@"open_sequence_biometric_unlock_fallback", @"Unlock Manually...")
                                      action:^(BOOL response) {
                    if ( response ) {
                        [self promptForManualCredentials];
                    }
                    else {
                        self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
                    }
                }];
            });
        }
        else if (error.code == LAErrorUserFallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForManualCredentials];
            });
        }
        else if ( error.code != LAErrorUserCancel ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts oneOptionsWithCancel:self.viewController
                                       title:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_failed_title_fmt", @"%@ Failed"), biometricIdName]
                                     message:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_biometric_unlock_warn_not_configured_fmt", @"%@ has failed: %@. You must now enter your password manually to open the database."), biometricIdName, error]
                                  buttonText:NSLocalizedString(@"open_sequence_biometric_unlock_fallback", @"Unlock Manually...")
                                      action:^(BOOL response) {
                    if ( response ) {
                        [self promptForManualCredentials];
                    }
                    else {
                        self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
                    }
                }];
            });
        }
        else {
            self.completion(kGetCompositeKeyResultUserCancelled, nil, NO, nil);
        }
    }
}



- (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename keyFileExtension:(NSString*)keyFileExtension {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:keyFileExtension];
    
    return  expectedKeyFileName;
}

- (NSString*)getAutoDetectedKeyFileUrl {
    NSURL *directory = StrongboxFilesManager.sharedInstance.documentsDirectory;

    NSError* error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString*>* files = [fm contentsOfDirectoryAtPath:directory.path error:&error];
    
    if(!files) {
        slog(@"Error looking for auto detected key file url: %@", error);
        return nil;
    }

    NSString* expectedKeyFileName = [self getExpectedAssociatedLocalKeyFileName:self.database.fileName keyFileExtension:@"key"];
    NSString* expectedKeyFileName2 = [self getExpectedAssociatedLocalKeyFileName:self.database.fileName keyFileExtension:@"keyx"];

    for (NSString *file in files) {
        if([file caseInsensitiveCompare:expectedKeyFileName] == NSOrderedSame ||
           [file caseInsensitiveCompare:expectedKeyFileName2] == NSOrderedSame ) {
            NSURL* found = [directory URLByAppendingPathComponent:file];
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:found readOnly:YES error:&error];
            
            if (error) {
                slog(@"Error while getting auto-detected bookmark -> [%@]", error);
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
    scVc.initialName = self.database.nickName;
    
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
                       keyFileFileName:creds.keyFileFileName
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



- (void)onConvenienceMethodsSucceeded:(NSString*)password
                      keyFileBookmark:(NSString*)keyFileBookmark
                      keyFileFileName:(NSString*)keyFileFileName
                   oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                             readOnly:(BOOL)readOnly
                 yubikeyConfiguration:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration {

    
    NSString* pw = password;
    
    [self onGotCredentials:pw
           keyFileBookmark:self.database.keyFileBookmark
           keyFileFileName:keyFileFileName
        oneTimeKeyFileData:nil
                  readOnly:self.database.readOnly
      yubikeyConfiguration:self.database.contextAwareYubiKeyConfig
           usedConvenience:YES];
}

- (void)onGotCredentials:(NSString*)password
         keyFileBookmark:(NSString*)keyFileBookmark
         keyFileFileName:(NSString*)keyFileFileName
      oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                readOnly:(BOOL)readOnly
    yubikeyConfiguration:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration
         usedConvenience:(BOOL)usedConvenience {
    NSData* keyFileDigest = nil;
    
    BOOL usingImportedKeyFile = keyFileBookmark || keyFileFileName;
    BOOL keyFileInvolved = usingImportedKeyFile || oneTimeKeyFileData;
    
    if( keyFileInvolved ) {
        NSError *error;
        DatabaseFormat format = kKeePass4;
        
        NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.database.uuid];
        if (url) {
            format = [Serializator getDatabaseFormat:url];
        }

        keyFileDigest = [KeyFileManagement getDigestFromSources:keyFileBookmark
                                            keyFileFileName:keyFileFileName
                                         onceOffKeyFileData:oneTimeKeyFileData
                                                     format:format
                                                      error:&error];
                
        if( keyFileDigest == nil ) {
            slog(@"WARNWARN: Could not read Key File [%@]", error);
            
            
            
            if( usedConvenience ) {
                self.database.conveniencePasswordHasBeenStored = NO;
                self.database.convenienceMasterPassword = nil;
                self.database.autoFillConvenienceAutoUnlockPassword = nil;
                self.database.hasBeenPromptedForConvenience = NO; 
            }

            if ( usingImportedKeyFile && self.isAutoFillOpen ) {
                    [Alerts error:self.viewController
                            title:NSLocalizedString(@"open_sequence_error_reading_key_file_autofill_context", @"Could not read Key File. Has it been imported properly? Check Key Files Management in Settings")
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
        else if ( keyFileFileName == nil && keyFileBookmark != nil) {
            
            
            NSURL* keyFileUrl = [BookmarksHelper getExpressReadOnlyUrlFromBookmark:keyFileBookmark];
            
            if ( keyFileUrl ) {
                [self.database setKeyFile:keyFileBookmark keyFileFileName:keyFileUrl.lastPathComponent];
            }
        }
    }
    
    

    BOOL readOnlyChanged = self.database.readOnly != readOnly;
    BOOL keyFileBookMarkChanged = (!(self.database.keyFileBookmark == nil && keyFileBookmark == nil)) && (![self.database.keyFileBookmark isEqual:keyFileBookmark]);
    BOOL keyFileFileNameChanged = (!(self.database.keyFileFileName == nil && keyFileFileName == nil)) && (![self.database.keyFileFileName isEqual:keyFileFileName]);
    BOOL keyFileChanged = keyFileBookMarkChanged || keyFileFileNameChanged;
    
    BOOL yubikeyChanged = (!(self.database.nextGenPrimaryYubiKeyConfig == nil && yubiKeyConfiguration == nil)) && (![self.database.nextGenPrimaryYubiKeyConfig isEqual:yubiKeyConfiguration]);
    
    if(readOnlyChanged || keyFileChanged || yubikeyChanged) {
        self.database.readOnly = readOnly;
        [self.database setKeyFile:keyFileBookmark keyFileFileName:keyFileFileName];
        
#ifndef IS_APP_EXTENSION
        self.database.nextGenPrimaryYubiKeyConfig = yubiKeyConfiguration;
#else
        self.database.contextAwareYubiKeyConfig = yubiKeyConfiguration; 
#endif
    }
    
    [self completeRequestWithCredentials:password
                           keyFileDigest:keyFileDigest
                    yubiKeyConfiguration:yubiKeyConfiguration
                         usedConvenience:usedConvenience];
}

- (void)completeRequestWithCredentials:(NSString*)password
                         keyFileDigest:(NSData*)keyFileDigest
                  yubiKeyConfiguration:(YubiKeyHardwareConfiguration*)yubiKeyConfiguration
                       usedConvenience:(BOOL)usedConvenience {
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
    if([AppPreferences.sharedInstance isPro] || yubiKeyConfiguration.mode == kVirtual) {
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
    if ( yubiKeyConfiguration.mode == kVirtual ) {
        VirtualYubiKey* key = [VirtualYubiKeys.sharedInstance getById:yubiKeyConfiguration.virtualKeyIdentifier];
        
        if (!key) {
            NSError* error = [Utils createNSError:@"Could not find Virtual Hardware Key!" errorCode:-1];
            completion(NO, nil, error);
        }
        else {
            slog(@"Doing Virtual Challenge Response...");
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
