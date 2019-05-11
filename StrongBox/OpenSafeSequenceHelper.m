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
#import <MobileCoreServices/MobileCoreServices.h>
#import "KeyFileParser.h"
#import "Utils.h"
#import "PinEntryController.h"
#import "AppleICloudProvider.h"
#import "DuressDummyStorageProvider.h"
#import "AutoFillManager.h"

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

@interface OpenSafeSequenceHelper () <UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) NSString* biometricIdName;
@property (nonatomic, strong) UIAlertController *alertController;
@property (nonatomic, strong) UITextField* textFieldPassword;
@property (nonnull) UIViewController* viewController;
@property (nonnull) SafeMetaData* safe;
@property BOOL canConvenienceEnrol;
@property BOOL openAutoFillCache;
@property (nonnull) CompletionBlock completion;
@property BOOL isConvenienceUnlock;
@property NSString* masterPassword;
@property NSData* keyFileDigest;
@property BOOL keyFileSelectionModeAskForPasswordBeforeOpen;
@property BOOL isAutoFillOpen;
@property BOOL manualOpenOfflineCache;

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
                                          openAutoFillCache:NO
                                        canConvenienceEnrol:canConvenienceEnrol
                                             isAutoFillOpen:isAutoFillOpen
                                     manualOpenOfflineCache:manualOpenOfflineCache
                                                 completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      openAutoFillCache:(BOOL)openAutoFillCache
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                         isAutoFillOpen:(BOOL)isAutoFillOpen
                 manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
                             completion:(CompletionBlock)completion {
    OpenSafeSequenceHelper *helper = [[OpenSafeSequenceHelper alloc] initWithViewController:viewController
                                                                                       safe:safe
                                                                          openAutoFillCache:openAutoFillCache
                                                                        canConvenienceEnrol:canConvenienceEnrol
                                                                             isAutoFillOpen:isAutoFillOpen
                                                                     manualOpenOfflineCache:manualOpenOfflineCache
                                                                                 completion:completion];
    
    [helper beginSequence];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                                  safe:(SafeMetaData*)safe
                     openAutoFillCache:(BOOL)openAutoFillCache
                   canConvenienceEnrol:(BOOL)canConvenienceEnrol
                        isAutoFillOpen:(BOOL)isAutoFillOpen
                manualOpenOfflineCache:(BOOL)manualOpenOfflineCache
                            completion:(CompletionBlock)completion {
    self = [super init];
    if (self) {
        self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
        self.viewController = viewController;
        self.safe = safe;
        self.canConvenienceEnrol = canConvenienceEnrol;
        self.openAutoFillCache = openAutoFillCache;
        self.completion = completion;
        self.keyFileSelectionModeAskForPasswordBeforeOpen = NO;
        self.isAutoFillOpen = isAutoFillOpen;
        self.manualOpenOfflineCache = manualOpenOfflineCache;
    }
    
    return self;
}

- (void)beginSequence {
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
    
    PinEntryController *vc = [[PinEntryController alloc] init];
    vc.pinLength = self.safe.conveniencePin.length;
    vc.info = @"Please enter your PIN to Unlock Database";
    vc.showFallbackOption = YES;
    
    if(self.safe.failedPinAttempts > 0) {
        vc.warning = [NSString stringWithFormat:@"%d attempts remaining before PIN is disabled", maxFailedPinAttempts - self.safe.failedPinAttempts];
    }
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if([pin isEqualToString:self.safe.conveniencePin]) {
                    self.isConvenienceUnlock = YES;
                    self.masterPassword = self.safe.convenienceMasterPassword;
                    self.keyFileDigest = self.safe.convenenienceKeyFileDigest;
                    self.safe.failedPinAttempts = 0;
                    
                    [SafesList.sharedInstance update:self.safe];
                    
                    [self openSafe];
                }
                else if (self.safe.duressPin != nil && [pin isEqualToString:self.safe.duressPin]) {
                    [self performDuressAction];
                }
                else {
                    self.safe.failedPinAttempts++;
                    [SafesList.sharedInstance update:self.safe];

                    if (self.safe.failedPinAttempts >= maxFailedPinAttempts) {
                        self.safe.failedPinAttempts = 0;
                        self.safe.isTouchIdEnabled = NO;
                        self.safe.conveniencePin = nil;
                        self.safe.isEnrolledForConvenience = NO;
                        self.safe.convenienceMasterPassword = nil;
                        self.safe.convenenienceKeyFileDigest = nil;
                        
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
    
    if (self.safe.offlineCacheEnabled && self.safe.offlineCacheAvailable)
    {
        [[LocalDeviceStorageProvider sharedInstance] deleteOfflineCachedSafe:self.safe
                                                                  completion:nil];
    }
    
    if (self.safe.autoFillCacheEnabled && self.safe.autoFillCacheAvailable)
    {
        [[LocalDeviceStorageProvider sharedInstance] deleteAutoFillCache:self.safe completion:nil];
    }
    
    [[SafesList sharedInstance] remove:self.safe.uuid];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showBiometricAuthentication {
    [Settings.sharedInstance requestBiometricId:@"Identify to Login"
                                  fallbackTitle:@"Manual Authentication..."
                                     completion:^(BOOL success, NSError * _Nullable error) {
        [self onBiometricAuthenticationDone:success error:error];
    }];
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
    }
}

- (void)promptForManualCredentials {
    self.isConvenienceUnlock = NO;
    [self promptForPasswordAndOrKeyFile];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString*)getExpectedAssociatedLocalKeyFileName:(NSString*)filename {
    NSString* veryLastFilename = [filename lastPathComponent];
    NSString* filenameOnly = [veryLastFilename stringByDeletingPathExtension];
    NSString* expectedKeyFileName = [filenameOnly stringByAppendingPathExtension:@"key"];

    return  expectedKeyFileName;
}

+ (NSData*)findAssociatedLocalKeyFile:(NSString*)filename {
    if(Settings.sharedInstance.doNotAutoDetectKeyFiles) {
        return nil;
    }
    
    NSString* expectedKeyFileName = [OpenSafeSequenceHelper getExpectedAssociatedLocalKeyFileName:filename];

    NSLog(@"Looking for key file: [%@] in local documents directory:", expectedKeyFileName);
    
    NSData* fileData = [LocalDeviceStorageProvider.sharedInstance readWithCaseInsensitiveFilename:expectedKeyFileName];

    return [KeyFileParser getKeyFileDigestFromFileData:fileData];
}

- (UIAlertController*)getAlertControllerWithPasswordField {
    NSString *title = [NSString stringWithFormat:@"Password for %@", self.safe.nickName];
    
    UIAlertController* ret = [UIAlertController alertControllerWithTitle:title
                                        message:@"Please Provide Credentials"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    __weak OpenSafeSequenceHelper *weakSelf = self;
    
    [ret addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        weakSelf.textFieldPassword = textField;
        
        // Create button
        UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
        [checkbox setFrame:CGRectMake(2 , 2, 18, 18)];  // Not sure about size
        [checkbox setTag:1];
        [checkbox addTarget:weakSelf action:@selector(toggleShowHidePasswordText:) forControlEvents:UIControlEventTouchUpInside];
        
        // Setup image for button
        [checkbox.imageView setContentMode:UIViewContentModeScaleAspectFit];
        [checkbox setImage:[UIImage imageNamed:@"show.png"] forState:UIControlStateNormal];
        [checkbox setImage:[UIImage imageNamed:@"hide.png"] forState:UIControlStateSelected];
        [checkbox setImage:[UIImage imageNamed:@"hide.png"] forState:UIControlStateHighlighted];
        [checkbox setAdjustsImageWhenHighlighted:TRUE];
        
        // Setup the right view in the text field
        [textField setClearButtonMode:UITextFieldViewModeAlways];
        [textField setRightViewMode:UITextFieldViewModeAlways];
        [textField setRightView:checkbox];
        
        // Setup Tag so the textfield can be identified
        [textField setTag:-1];
        textField.secureTextEntry = YES;
    }];

    return ret;
}

- (void)promptForPasswordAndOrKeyFile {
    NSData* autoDetectedKeyFileDigest = [OpenSafeSequenceHelper findAssociatedLocalKeyFile:self.safe.fileName];
    
    self.alertController = [self getAlertControllerWithPasswordField];
    self.alertController.message = autoDetectedKeyFileDigest == nil ? @"Please Provide Credentials" : @"Please Provide Credentials\n\n(*Key File has been auto-detected)";
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Unlock"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = self.alertController.textFields[0].text;
                                                              self.keyFileDigest = autoDetectedKeyFileDigest;
                                                              [self openSafe];
                                                          }];
    
    UIAlertAction *keyFileOnlyAction = [UIAlertAction actionWithTitle:autoDetectedKeyFileDigest ? @"No Password (Use Key File Only)" : @"Advanced Options..."
                                                            style:kNilOptions
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = nil;
                                                              if(autoDetectedKeyFileDigest) {
                                                                  self.keyFileDigest = autoDetectedKeyFileDigest;
                                                                  [self openSafe];
                                                              }
                                                              else {
                                                                  __weak OpenSafeSequenceHelper *weakSelf = self;
                                                                  
                                                                  [Alerts twoOptionsWithCancel:weakSelf.viewController
                                                                                         title:@"Advanced Unlock"
                                                                                       message:@"Select an advanced Unlock method"
                                                                             defaultButtonText:@"Password & Key File..."
                                                                              secondButtonText:@"No Password, Just a Key File..."
                                                                                        action:^(int response) {
                                                                                            if(response == 0) {
                                                                                                self.keyFileSelectionModeAskForPasswordBeforeOpen = YES;
                                                                                                [self onUseKeyFile:weakSelf.viewController];
                                                                                            }
                                                                                            else if(response == 1) {
                                                                                                [self onUseKeyFile:weakSelf.viewController];
                                                                                            }
                                                                                            else {
                                                                                                weakSelf.completion(nil, nil);
                                                                                            }
                                                                                        }];
                                                              }
                                                          }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             self.completion(nil, nil);
                                                         }];
    
    [self.alertController addAction:defaultAction];
    [self.alertController addAction:keyFileOnlyAction];
    [self.alertController addAction:cancelAction];
    
    self.alertController.preferredAction = defaultAction; // Return leads to the default action
    
    [self.viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (IBAction)toggleShowHidePasswordText:(UIButton*)sender {
    if(sender.selected){
        [sender setSelected:FALSE];
    } else {
        [sender setSelected:TRUE];
    }
    
    self.textFieldPassword.secureTextEntry = !sender.selected;
}

- (void)onUseKeyFile:(UIViewController*)parentVc {
    [Alerts threeOptions:self.viewController
                   title:@"Key File Source"
                 message:@"Select where you would like to choose your Key File from"
       defaultButtonText:@"Files..."
        secondButtonText:@"Photo Library..."
         thirdButtonText:@"Cancel"
                  action:^(int response) {
                     if(response == 0) {
                         UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
                         vc.delegate = self;
                         [parentVc presentViewController:vc animated:YES completion:nil];
                     }
                     else if (response == 1) {
                         UIImagePickerController *vc = [[UIImagePickerController alloc] init];
                         vc.videoQuality = UIImagePickerControllerQualityTypeHigh;
                         vc.delegate = self;
                         BOOL available = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                         
                         if(!available) {
                             [Alerts info:self.viewController title:@"Photo Library Unavailable" message:@"Could not access Photo Library. Does Strongbox have Permission?"]; // TODO: Not an NSError
                             self.completion(nil, nil);
                             return;
                         }
                         
                         vc.mediaTypes = @[(NSString*)kUTTypeImage];
                         vc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                         
                         [self.viewController presentViewController:vc animated:YES completion:nil];
                     }
                     else {
                         self.completion(nil, nil);
                     }
                 }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
         NSError* error;
         NSData* data = [Utils getImageDataFromPickedImage:info error:&error];

         if(!data) {
             NSLog(@"Error: %@", error);
             [Alerts error:self.viewController title:@"Error Reading Image" error:error];
             self.completion(nil, error);
         }
         else {
             self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data];
             [self openSafe];
         }
     }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^
     {
         self.completion(nil, nil);
     }];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.completion(nil, nil);
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    //NSLog(@"didPickDocumentsAtURLs: %@", urls);
    
    NSURL* url = [urls objectAtIndex:0];
    // NSString *filename = [url.absoluteString lastPathComponent];
    
    NSError* error;
    NSData* data = [NSData dataWithContentsOfURL:url options:kNilOptions error:&error];
    
    if(!data) {
        NSLog(@"Error: %@", error);
        [Alerts error:self.viewController title:@"There was an error reading the Key File" error:error completion:^{
            self.completion(nil, nil);
        }];
    }
    else {
        self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data];
        [self openSafe];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)openSafe {
    if(self.keyFileSelectionModeAskForPasswordBeforeOpen) {
        [self requestPasswordAfterKeySelectionAndOpenSafe];
    }
    else {
        [self actuallyOpenSafe];
    }
}

- (void)requestPasswordAfterKeySelectionAndOpenSafe {
    self.alertController = [self getAlertControllerWithPasswordField];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Unlock"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = self.alertController.textFields[0].text;
                                                              [self actuallyOpenSafe];
                                                          }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             self.completion(nil, nil);
                                                         }];
    
    [self.alertController addAction:defaultAction];
    [self.alertController addAction:cancelAction];
    
    [self.viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (void)actuallyOpenSafe {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:self.safe.storageProvider];
        
        if(self.openAutoFillCache) {
            [[LocalDeviceStorageProvider sharedInstance] readAutoFillCache:self.safe viewController:self.viewController
                                                                completion:^(NSData *data, NSError *error) {
                [self onProviderReadDone:provider data:data error:error cacheMode:YES];
            }];
        }
        else if (self.manualOpenOfflineCache) {
            if(self.safe.offlineCacheEnabled && self.safe.offlineCacheAvailable) {
                [[LocalDeviceStorageProvider sharedInstance] readOfflineCachedSafe:self.safe
                                                                    viewController:self.viewController
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
            [provider read:self.safe viewController:self.viewController completion:^(NSData *data, NSError *error) {
                [self onProviderReadDone:provider data:data error:error cacheMode:NO];
             }];
        }
    });
}

- (void)onProviderReadDone:(id<SafeStorageProvider>)provider
                      data:(NSData *)data error:(NSError *)error
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

- (void)openSafeWithData:(NSData *)data
                provider:(id)provider
               cacheMode:(BOOL)cacheMode {
    [SVProgressHUD showWithStatus:@"Decrypting..."];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error;
        DatabaseModel *openedSafe = [[DatabaseModel alloc] initExistingWithDataAndPassword:data
                                                                                  password:self.masterPassword
                                                                             keyFileDigest:self.keyFileDigest
                                                                                     error:&error];
        
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
        if (!self.canConvenienceEnrol || cacheMode || self.safe.isEnrolledForConvenience || ![[Settings sharedInstance] isProOrFreeTrial] || self.safe.hasBeenPromptedForConvenience) {
            // Can't or shouldn't Convenience Enrol...
            [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
        }
        else {
            BOOL biometricPossible = Settings.isBiometricIdAvailable && !Settings.sharedInstance.disallowAllBiometricId;
            BOOL pinPossible = !Settings.sharedInstance.disallowAllPinCodeOpens;

            if(!biometricPossible && !pinPossible) {
                // Can enrol but no methods possible
                [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
            }
            else {
                // Convenience Enrol!
                [self promptForConvenienceEnrolAndOpen:biometricPossible pinPossible:pinPossible openedSafe:openedSafe cacheMode:cacheMode provider:provider data:data];
            }
        }
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
                                                                self.safe.convenienceMasterPassword = openedSafe.masterPassword;
                                                                self.safe.convenenienceKeyFileDigest = openedSafe.keyFileDigest;
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
    PinEntryController *vc1 = [[PinEntryController alloc] init];
    vc1.info = @"Please Enter a Convenience PIN";
    vc1.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        [self.viewController dismissViewControllerAnimated:YES completion:^{
            if(response == kOk) {
                if(!(self.safe.duressPin != nil && [pin isEqualToString:self.safe.duressPin])) {
                    self.safe.conveniencePin = pin;
                    self.safe.isEnrolledForConvenience = YES;
                    self.safe.convenienceMasterPassword = openedSafe.masterPassword;
                    self.safe.convenenienceKeyFileDigest = openedSafe.keyFileDigest;
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

    [self.viewController presentViewController:vc1 animated:YES completion:nil];
}

-(void)onSuccessfulSafeOpen:(BOOL)cacheMode
                   provider:(id)provider
                 openedSafe:(DatabaseModel *)openedSafe
                       data:(NSData *)data {
    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:self.safe
                                           storageProvider:cacheMode ? nil : provider // Guarantee nothing can be written!
                                                 cacheMode:cacheMode
                                                isReadOnly:NO]; 
    
    if (!cacheMode) {
        if(self.safe.offlineCacheEnabled) {
            [viewModel updateOfflineCacheWithData:data];
        }
        if(self.safe.autoFillCacheEnabled) {
            [viewModel updateAutoFillCacheWithData:data];
        }

        if(!Settings.sharedInstance.doNotUseQuickTypeAutoFill && self.safe.useQuickTypeAutoFill) {
            [AutoFillManager.sharedInstance updateAutoFillQuickTypeDatabase:openedSafe databaseUuid:self.safe.uuid];
        }
    }
    
    self.completion(viewModel, nil);
}

- (void)openWithOfflineCacheFile:(NSString *)message {
    [Alerts yesNo:self.viewController
            title:@"Use Offline Cache?"
          message:message
           action:^(BOOL response) {
               if (response) {
                   [[LocalDeviceStorageProvider sharedInstance] readOfflineCachedSafe:self.safe
                                                                       viewController:self.viewController
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
    NSDate *modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:safe];
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.timeStyle = NSDateFormatterShortStyle;
    df.dateStyle = NSDateFormatterShortStyle;
    df.doesRelativeDateFormatting = YES;
    df.locale = NSLocale.currentLocale;
    
    NSString *modDateStr = [df stringFromDate:modDate];
    return modDateStr;
}

BOOL providerCanFallbackToOfflineCache(id<SafeStorageProvider> provider, SafeMetaData* safe) {
    BOOL basic = provider && provider.cloudBased &&
    !(provider.storageId == kiCloud && Settings.sharedInstance.iCloudOn) &&
    safe.offlineCacheEnabled && safe.offlineCacheAvailable;
    
    if(basic) {
        NSDate *modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:safe];
        
        return modDate != nil;
    }
    
    return NO;
}

@end
