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
#import <SVProgressHUD/SVProgressHUD.h>
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
        self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
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
                   title:@"Database File Select Required"
                 message:@"For technical reasons, you need to re-select your database file to enable Auto Fill. You will only need to do this once.\n\nThanks!\n-Mark"
              completion:^{
                  [self promptForAutofillBookmarkSelect];
              }];
            return;
        }
    }
    
    [self beginSeq];
}

- (void)beginSeq {
    if (self.safe.isEnrolledForConvenience && Settings.sharedInstance.isProOrFreeTrial) {
        BOOL biometricPossible = self.safe.isTouchIdEnabled && Settings.isBiometricIdAvailable;
        BOOL biometricAllowed = !Settings.sharedInstance.disallowAllBiometricId;
        
        NSLog(@"Open Database: Biometric Possible [%d] - Biometric Available [%d]", biometricPossible, biometricAllowed);
        
        if(biometricPossible && biometricAllowed) {
            [self showBiometricAuthentication];
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
        vc.warning = [NSString stringWithFormat:@"%d attempts remaining", maxFailedPinAttempts - self.safe.failedPinAttempts];
    }
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if([pin isEqualToString:self.safe.conveniencePin]) {
                    self.isConvenienceUnlock = YES;
                    self.masterPassword = self.safe.convenienceMasterPassword;
                    self.keyFileDigest = self.safe.convenenienceKeyFileDigest;
                    self.yubikeySecret = self.safe.convenenienceYubikeySecret;
                    
                    self.safe.failedPinAttempts = 0;
                    
                    [SafesList.sharedInstance update:self.safe];
                    
                    [self openSafe];
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
                        self.safe.convenenienceKeyFileDigest = nil;
                        self.safe.convenenienceYubikeySecret = nil;
                        
                        [SafesList.sharedInstance update:self.safe];

                        [Alerts warn:self.viewController
                               title:@"Too Many Incorrect PINs"
                             message:@"You have entered the wrong PIN too many times. PIN Unlock is now disabled, and you must enter the master password to unlock this database."];
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

-(void)performDuressAction {
    if (self.safe.duressAction == kOpenDummy) {
        SafeMetaData* metadata = [DuressDummyStorageProvider.sharedInstance getSafeMetaData:self.safe.nickName filename:self.safe.fileName fileIdentifier:self.safe.fileIdentifier];
        
        Model *viewModel = [[Model alloc] initWithSafeDatabase:DuressDummyStorageProvider.sharedInstance.database
                                                      metaData:metadata
                                               storageProvider:DuressDummyStorageProvider.sharedInstance
                                                     cacheMode:NO
                                                    isReadOnly:NO];
        
        self.completion(viewModel, nil);
    }
    else if (self.safe.duressAction == kPresentError) {
        NSError *error = [Utils createNSError:@"There was a technical error opening the database." errorCode:-1729];
        [Alerts error:self.viewController title:@"Technical Issue" error:error completion:^{
            self.completion(nil, error);
        }];
    }
    else if (self.safe.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe];
        NSError *error = [Utils createNSError:@"There was a technical error opening the database." errorCode:-1729];
        [Alerts error:self.viewController title:@"Technical Issue" error:error completion:^{
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
    
    if(self.biometricPreCleared && Settings.sharedInstance.coalesceAppLockAndQuickLaunchBiometricAuths) {
        NSLog(@"BIOMETRIC has been PRE-CLEARED - Coalescing Auths - Proceeding without prompting for auth");
        [self onBiometricAuthenticationDone:YES error:nil];
    }
    else {
        [Settings.sharedInstance requestBiometricId:@"Identify to Login"
                                      fallbackTitle:@"Unlock Manually..."
                                         completion:^(BOOL success, NSError * _Nullable error) {
            [self onBiometricAuthenticationDone:success error:error];
        }];
    }
}

- (void)onBiometricAuthenticationDone:(BOOL)success
                error:(NSError *)error {
    if (success) {
        self.isConvenienceUnlock = YES;
        
        // Do we also have a PIN?
        
        if(!Settings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForConveniencePin];
            });
        }
        else {
            self.masterPassword = self.safe.convenienceMasterPassword;
            self.keyFileDigest = self.safe.convenenienceKeyFileDigest;
            self.yubikeySecret = self.safe.convenenienceYubikeySecret;
            [self openSafe];
        }
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self.viewController
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ Authentication Failed. You must now enter your password manually to open the database.", self.biometricIdName]
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
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ has not been setup or system has cancelled. You must now enter your password manually to open the database.", self.biometricIdName]
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
    
    // Less than perfect but helpful
    
    BOOL probablyPasswordSafe = [self.safe.fileName.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; // Not Ideal
    
    scVc.initialFormat = self.safe.likelyFormat != kFormatUnknown ? self.safe.likelyFormat : heuristicFormat;
    
    if (self.safe.offlineCacheEnabled && self.safe.offlineCacheAvailable) {
        scVc.offlineCacheDate = [[CacheManager sharedInstance] getOfflineCacheFileModificationDate:self.safe];
    }
    
    // Auto Detect Key File?
    
    if(!self.safe.keyFileUrl) {
        if(!Settings.sharedInstance.doNotAutoDetectKeyFiles) {
            NSURL* autoDetectedKeyFileUrl = [self getAutoDetectedKeyFileUrl];
            if(autoDetectedKeyFileUrl) {
                scVc.autoDetectedKeyFileUrl = YES;
                scVc.initialKeyFileUrl = autoDetectedKeyFileUrl;
            }
        }
    }
    
    scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(success) {
                [self onGotManualCredentials:creds.password
                                  keyFileUrl:creds.keyFileUrl
                          oneTimeKeyFileData:creds.oneTimeKeyFileData
                                    readOnly:creds.readOnly
                                 openOffline:creds.offlineCache
                               yubikeySecret:creds.yubiKeySecret];
            }
            else {
                self.completion(nil, nil);
            }
        }];
    };

    [self.viewController presentViewController:nav animated:YES completion:nil];
}

- (void)onGotManualCredentials:(NSString*)password
                    keyFileUrl:(NSURL*)keyFileUrl
            oneTimeKeyFileData:(NSData*)oneTimeKeyFileData
                      readOnly:(BOOL)readOnly
                   openOffline:(BOOL)openOffline
                 yubikeySecret:(NSString*)yubikeySecret {
    if(keyFileUrl || oneTimeKeyFileData) {
        NSError *error;
        self.undigestedKeyFileData = getKeyFileData(keyFileUrl, oneTimeKeyFileData, &error);

        if(self.undigestedKeyFileData == nil) {
            // TODO: Move error messaging out of here
            [Alerts error:self.viewController
                    title:@"Error Reading Key File"
                    error:error
               completion:^{
                self.completion(nil, error);
            }];
            return;
        }
    }

    self.yubikeySecret = yubikeySecret;
    if(yubikeySecret.length) {
        readOnly = YES;
    }
    
    // Change in Read-Only or Key File Setting? Save
    
    if(self.safe.readOnly != readOnly || ![self.safe.keyFileUrl isEqual:keyFileUrl]) {
        self.safe.readOnly = readOnly;
        self.safe.keyFileUrl = keyFileUrl;
        [SafesList.sharedInstance update:self.safe];
    }
    
    
    self.manualOpenOfflineCache = openOffline;
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
                [Alerts warn:self.viewController title:@"Could Not Open Offline" message:@"Could not open this database in offline mode. Does the Offline Cache exist?"];
                self.completion(nil, nil);
            }
            return;
        }
        else if (OfflineDetector.sharedInstance.isOffline && providerCanFallbackToOfflineCache(provider, self.safe)) {
            NSString * modDateStr = getLastCachedDate(self.safe);
            NSString* message = [NSString stringWithFormat:@"Could not reach %@, it looks like you may be offline, would you like to use a read-only offline cache version of this database instead?\n\nLast Cached: %@", provider.displayName, modDateStr];
            
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
        if (error != nil || data == nil) {
            NSLog(@"Error: %@", error);
            if(providerCanFallbackToOfflineCache(provider, self.safe)) {
                NSString * modDateStr = getLastCachedDate(self.safe);
                NSString* message = [NSString stringWithFormat:@"There was a problem reading the database on %@. would you like to use a read-only offline cache version of this database instead?\n\nLast Cached: %@", provider.displayName, modDateStr];
                
                [self openWithOfflineCacheFile:message];
            }
            else {
                [Alerts error:self.viewController title:@"There was a problem opening the database." error:error completion:^{
                    self.completion(nil, error);
                }];
            }
        }
        else {
            if(self.isAutoFillOpen && !Settings.sharedInstance.haveWarnedAboutAutoFillCrash && [DatabaseModel isAutoFillLikelyToCrash:data]) {
                [Alerts warn:self.viewController title:@"AutoFill Crash Likely" message:@"Your database has encryption settings that may cause iOS Password Auto Fill extensions to be terminated due to excessive resource consumption. This will mean Auto Fill appears not to work. Unfortunately this is an Apple imposed limit. You could consider reducing the amount of resources consumed by your encryption settings (Memory in particular with Argon2 to below 64MB)." completion:^{
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

- (NSData*)getYubikeyResponse:(NSData*)database error:(NSError**)error {
    NSData* challenge = [DatabaseModel getYubikeyChallenge:database error:error];
    
    if(!challenge || !self.yubikeySecret.length) {
        return nil;
    }
    
    //NSLog(@"Got Yubikey Challenge: [%@]", challenge);
    
    NSData* yubikeySecretData = [Utils dataFromHexString:self.yubikeySecret];
    NSData* challengeResponse = hmacSha1(challenge, yubikeySecretData);
    
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
    
    [SVProgressHUD showWithStatus:@"Decrypting..."];

    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    if (self.undigestedKeyFileData) {
        self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:self.undigestedKeyFileData checkForXml:format != kKeePass1];
    }

    // Yubikey?
    
    NSData* yubikeyResponse = self.yubikeySecret.length ? [self getYubikeyResponse:data error:&error] : nil;
    if(error) {
        NSLog(@"Yubikey secret provided but error getting challenge or response.");
        [self openSafeWithDataDone:error
                        openedSafe:nil
                         cacheMode:cacheMode
                          provider:provider
                              data:data];
        return;
    }
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error;
        DatabaseModel *openedSafe = nil;

        CompositeKeyFactors* cpf = [CompositeKeyFactors password:self.masterPassword keyFileDigest:self.keyFileDigest yubiKeyResponse:yubikeyResponse];

        if(!self.isConvenienceUnlock && (format == kKeePass || format == kKeePass4) &&
           self.masterPassword.length == 0 && (self.keyFileDigest || yubikeyResponse)) {
            // KeePass 2 allows empty and nil/none... we need to try both to figure out what the user meant.
            // We will try empty first which is what will have come from the View Controller and then nil.
            
            // self.masterPassword // Will be @""
        
            openedSafe = [[DatabaseModel alloc] initExisting:data compositeKeyFactors:cpf error:&error];
            
            if(openedSafe == nil && error && error.code == kStrongboxErrorCodeIncorrectCredentials) {
                cpf = [CompositeKeyFactors password:nil keyFileDigest:self.keyFileDigest yubiKeyResponse:yubikeyResponse];
                openedSafe = [[DatabaseModel alloc] initExisting:data compositeKeyFactors:cpf error:&error];
                
                if(openedSafe) {
                    self.masterPassword = nil;
                }
            }
        }
        else {
            openedSafe = [[DatabaseModel alloc] initExisting:data compositeKeyFactors:cpf error:&error];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self openSafeWithDataDone:error
                            openedSafe:openedSafe
                             cacheMode:cacheMode
                              provider:provider
                                  data:data];
        });
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
            [Alerts error:self.viewController title:@"There was a problem opening the database." error:error];
            self.completion(nil, error);
            return;
        }
        else if (error.code == kStrongboxErrorCodeIncorrectCredentials) { // TODO: This interpretation of the error blocks us from moving Alerts out of here...
            if(self.isConvenienceUnlock) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.convenenienceKeyFileDigest = nil;
                self.safe.convenenienceYubikeySecret = nil;
                self.safe.conveniencePin = nil;
                self.safe.isTouchIdEnabled = NO;
                self.safe.hasBeenPromptedForConvenience = NO; // Ask if user wants to enrol on next successful open
                
                [SafesList.sharedInstance update:self.safe];
                
                [Alerts info:self.viewController
                       title:@"Could not open database"
                     message:[NSString stringWithFormat:@"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled."]] ;
            }
            else {
                [Alerts info:self.viewController
                       title:@"Incorrect Credentials"
                     message:@"The credentials were incorrect for this database."];
            }
        }
        else {
            [Alerts error:self.viewController title:@"There was a problem opening the database." error:error];
        }
        
        self.completion(nil, error);
    }
    else {
        // SAFETY: Guarantee no writes with old yubikey response in some kind of unthinkable scenario when we have opened
        // using the Yubikey secret workaround
        
        openedSafe.compositeKeyFactors.yubiKeyResponse = nil; // TODO: Eventually allow this when we allow writeable yubikey dbs

        BOOL biometricPossible = Settings.isBiometricIdAvailable && !Settings.sharedInstance.disallowAllBiometricId;
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
                title:@"Set Quick Launch?"
              message:@"Would you like to use this as your Quick Launch database? Quick Launch means you will get prompted immediately to unlock when you open Strongbox, saving you a precious click."
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

- (void)promptForConvenienceEnrolAndOpen:(BOOL)biometricPossible
                             pinPossible:(BOOL)pinPossible
                              openedSafe:(DatabaseModel*)openedSafe
                               cacheMode:(BOOL)cacheMode
                                provider:(id)provider
                                    data:(NSData *)data {
    NSString *title;
    NSString *message;
    
    if(biometricPossible && pinPossible) {
        title = [NSString stringWithFormat:@"Convenience Unlock: Use %@ or PIN Code in Future?", self.biometricIdName];
        message = [NSString stringWithFormat:@"You can use either %@ or a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use one of these methods, please select from below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password", self.biometricIdName];
    }
    else if (biometricPossible) {
        title = [NSString stringWithFormat:@"Convenience Unlock: Use %@ to Unlock in Future?", self.biometricIdName];
        message = [NSString stringWithFormat:@"You can use %@ to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password", self.biometricIdName];
    }
    else if (pinPossible) {
        title = @"Convenience Unlock: Use a PIN Code to Unlock in Future?";
        message = @"You can use a convenience PIN Code to unlock this database. While this is convenient, it may reduce the security of the database on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password";
    }
    
    
    if (!Settings.sharedInstance.isPro) {
        message = [message stringByAppendingFormat:@"\n\nNB: Convenience Unlock is a Pro feature"];
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    if(biometricPossible) {
        UIAlertAction *biometricAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Use %@", self.biometricIdName]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *a) {
                                                                self.safe.isTouchIdEnabled = YES;
                                                                self.safe.isEnrolledForConvenience = YES;
                                                                self.safe.convenienceMasterPassword = openedSafe.compositeKeyFactors.password;
                                                                self.safe.convenenienceKeyFileDigest = openedSafe.compositeKeyFactors.keyFileDigest;
                                                                
                                                                self.safe.convenenienceYubikeySecret = self.yubikeySecret;
                                                                
                                                                self.safe.hasBeenPromptedForConvenience = YES;
                                                                
                                                                [SafesList.sharedInstance update:self.safe];
                                                                
                                                                [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                                                            }];
        [alertController addAction:biometricAction];
    }
    
    if (pinPossible) {
        UIAlertAction *pinCodeAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Use a PIN Code..."]
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              [self setupConveniencePinAndOpen:openedSafe cacheMode:cacheMode provider:provider data:data];
                                                          }];
        [alertController addAction:pinCodeAction];
    }
    
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:@"No"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction *a) {
                                                         self.safe.isTouchIdEnabled = NO;
                                                         self.safe.conveniencePin = nil;
                                                         
                                                         self.safe.convenienceMasterPassword = nil;
                                                         self.safe.convenenienceKeyFileDigest = nil;
                                                         self.safe.convenenienceYubikeySecret = nil;
                                                         
                                                         self.safe.isEnrolledForConvenience = NO;
                                                         self.safe.hasBeenPromptedForConvenience = YES;
                                                         
                                                         [SafesList.sharedInstance update:self.safe];
                                                         
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
                    self.safe.conveniencePin = pin;
                    self.safe.isEnrolledForConvenience = YES;
                    
                    self.safe.convenienceMasterPassword = openedSafe.compositeKeyFactors.password;
                    self.safe.convenenienceKeyFileDigest = openedSafe.compositeKeyFactors.keyFileDigest;
                    self.safe.convenenienceYubikeySecret = self.yubikeySecret;
                    
                    self.safe.hasBeenPromptedForConvenience = YES;
                    
                    [SafesList.sharedInstance update:self.safe];
                    
                    [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                }
                else {
                    [Alerts warn:self.viewController title:@"PIN Conflict" message:@"Your Convenience PIN conflicts with your Duress PIN. Please configure in the Database Settings" completion:^{
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
                                                  metaData:self.safe
                                           storageProvider:cacheMode ? nil : provider // Guarantee nothing can be written!
                                                 cacheMode:cacheMode
                                                isReadOnly:self.yubikeySecret.length];
    
    viewModel.openedWithYubiKeySecret = self.yubikeySecret;
    
    if (!cacheMode) {
        if(self.safe.offlineCacheEnabled) {
            [viewModel updateOfflineCacheWithData:data];
        }
        
        if(self.safe.autoFillEnabled) {
            [viewModel updateAutoFillCacheWithData:data];
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:openedSafe databaseUuid:self.safe.uuid];
        }

        NSLog(@"Setting likelyFormat to [%u]", openedSafe.format);
        self.safe.likelyFormat = openedSafe.format;
        [SafesList.sharedInstance update:self.safe];
    }
    
    self.completion(viewModel, nil);
}

- (void)openWithOfflineCacheFile:(NSString *)message {
    [Alerts yesNo:self.viewController
            title:@"Use Offline Cache?"
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
        [Alerts warn:self.viewController title:@"Error Opening This Database" message:@"Could not access this file."];
    }
    else {
        NSError* error;
        
        if (![DatabaseModel isAValidSafe:data error:&error]) {
            [Alerts error:self.viewController
                    title:[NSString stringWithFormat:@"Invalid Database - [%@]", url.lastPathComponent]
                    error:error];
            return;
        }
        
        if(![url.lastPathComponent isEqualToString:self.safe.fileName]) {
            [Alerts yesNo:self.viewController title:@"Different Filename"
                  message:@"This doesn't look like it's the right file because the filename looks different than the one you originally added. Do you want to continue?"
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
    
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        NSLog(@"Could not access secure scoped resource!");
        return;
    }
    
    NSURLBookmarkCreationOptions options = 0;
    NSData* bookMark = [url bookmarkDataWithOptions:options includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    
    [url stopAccessingSecurityScopedResource];
    
    if (error) {
        [Alerts error:self.viewController title:@"Could not bookmark this file" error:error];
        return;
    }
    
    NSLog(@"Setting Auto Fill Bookmark: %@", bookMark);
    
    FilesAppUrlBookmarkProvider* fp = [SafeStorageProviderFactory getStorageProviderFromProviderId:kFilesAppUrlBookmark];
    
    self.safe = [fp setAutoFillBookmark:bookMark metadata:self.safe];
    [SafesList.sharedInstance update:self.safe];
    
    [self beginSeq];
}

@end
