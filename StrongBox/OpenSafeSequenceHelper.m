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

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

typedef void(^CompletionBlock)(Model* model);

@interface OpenSafeSequenceHelper () <UIDocumentPickerDelegate>

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

@end

@implementation OpenSafeSequenceHelper


+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                             completion:(void (^)(Model* model))completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController safe:safe openAutoFillCache:NO canConvenienceEnrol:canConvenienceEnrol completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      openAutoFillCache:(BOOL)openAutoFillCache
                    canConvenienceEnrol:(BOOL)canConvenienceEnrol
                             completion:(void (^)(Model* model))completion {
    OpenSafeSequenceHelper *helper = [[OpenSafeSequenceHelper alloc] initWithViewController:viewController
                                                      safe:safe
                                         openAutoFillCache:openAutoFillCache
                                         canConvenienceEnrol:canConvenienceEnrol
                                                completion:completion];
    
    [helper beginSequence];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                          safe:(SafeMetaData*)safe
             openAutoFillCache:(BOOL)openAutoFillCache
             canConvenienceEnrol:(BOOL)canConvenienceEnrol
                    completion:(void (^)(Model* model))completion {
    self = [super init];
    if (self) {
        self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
        self.viewController = viewController;
        self.safe = safe;
        self.canConvenienceEnrol = canConvenienceEnrol;
        self.openAutoFillCache = openAutoFillCache;
        self.completion = completion;
    }
    
    return self;
}

- (void)beginSequence {
    if (self.safe.isEnrolledForConvenience && Settings.sharedInstance.isProOrFreeTrial) {
        BOOL biometricPossible = !Settings.sharedInstance.disallowAllBiometricId && self.safe.isTouchIdEnabled && Settings.isBiometricIdAvailable;
        
        // Show biometric if possible... unless BOTH Bio & PIN are configured but PIN has been disabled, then fall back to full master credentials
        if(biometricPossible && !(self.safe.conveniencePin != nil && Settings.sharedInstance.disallowAllPinCodeOpens)) {
            [self showBiometricAuthentication];
        }
        // Only show PIN code now if it is enabled exclusively (i.e. not also with Touch ID) because if for some
        // other reason biometric is disabled we want to fallback to master credentials
        else if(!Settings.sharedInstance.disallowAllPinCodeOpens && self.safe.conveniencePin != nil && !self.safe.isTouchIdEnabled) {
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
    vc.info = @"Please enter your PIN to Unlock Safe";
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
                        self.safe.conveniencePin = nil;
                        [SafesList.sharedInstance update:self.safe];

                        [Alerts warn:self.viewController
                               title:@"Too Many Incorrect PINs"
                             message:@"You have entered the wrong PIN too many times. PIN Unlock is now disabled, and you must enter the master password to unlock this safe."];
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
                self.completion(nil);
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
        
        self.completion(viewModel);
    }
    else if (self.safe.duressAction == kPresentError) {
        NSError *error = [Utils createNSError:@"There was a technical error opening the safe." errorCode:-1729];
        [Alerts error:self.viewController title:@"Technical Issue" error:error completion:^{
            self.completion(nil);
        }];
    }
    else if (self.safe.duressAction == kRemoveDatabase) {
        [self removeOrDeleteSafe];
        NSError *error = [Utils createNSError:@"There was a technical error opening the safe." errorCode:-1729];
        [Alerts error:self.viewController title:@"Technical Issue" error:error completion:^{
            self.completion(nil);
        }];
    }
    else {
        self.completion(nil);
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
                       message:[NSString stringWithFormat:@"%@ Authentication Failed. You must now enter your password manually to open the safe.", self.biometricIdName]
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
                       message:[NSString stringWithFormat:@"%@ has not been setup or system has cancelled. You must now enter your password manually to open the safe.", self.biometricIdName]
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

- (void)promptForPasswordAndOrKeyFile {
    NSString *title = [NSString stringWithFormat:@"Password for %@", self.safe.nickName];
    
    self.alertController = [UIAlertController alertControllerWithTitle:title
                                                               message:@"Please Provide Credentials"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    
    // Establish the weak self reference
    __weak OpenSafeSequenceHelper *weakSelf = self;

    [self.alertController addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
        weakSelf.textFieldPassword = textField;
        
        ///////////////////
        
        // Create button
        UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
        [checkbox setFrame:CGRectMake(2 , 2, 18, 18)];  // Not sure about size
        [checkbox setTag:1];
        [checkbox addTarget:weakSelf action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
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
        //[textField setDelegate:weakSelf];
        
        // Setup textfield
        //[textField setText:@"Essential"];  // Could be place holder text

        textField.secureTextEntry = YES;
    }];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = self.alertController.textFields[0].text;
                                                              [self openSafe];
                                                          }];
    
    UIAlertAction *keyFileAction = [UIAlertAction actionWithTitle:@"Use a Key File & Password..."
                                                            style:kNilOptions
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = self.alertController.textFields[0].text;
                                                              [self onUseKeyFile:self.viewController];
                                                          }];

    UIAlertAction *keyFileOnlyAction = [UIAlertAction actionWithTitle:@"Use a Key File only..."
                                                            style:kNilOptions
                                                          handler:^(UIAlertAction *a) {
                                                              self.masterPassword = nil;
                                                              [self onUseKeyFile:self.viewController];
                                                          }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *a) {
                                                             self.completion(nil);
                                                         }];
    
    [self.alertController addAction:defaultAction];
    [self.alertController addAction:keyFileAction];
    [self.alertController addAction:keyFileOnlyAction];
    [self.alertController addAction:cancelAction];
    
    [self.viewController presentViewController:self.alertController animated:YES completion:nil];
}

- (IBAction)buttonPressed:(UIButton*)sender {
    if(sender.selected){
        [sender setSelected:FALSE];
    } else {
        [sender setSelected:TRUE];
    }
    
    self.textFieldPassword.secureTextEntry = !sender.selected;
}

- (void)onUseKeyFile:(UIViewController*)parentVc {
    UIDocumentPickerViewController *vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[(NSString*)kUTTypeItem] inMode:UIDocumentPickerModeImport];
    vc.delegate = self;
    
    [parentVc presentViewController:vc animated:YES completion:nil];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    self.completion(nil);
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
            self.completion(nil);
        }];
    }
    else {
        self.keyFileDigest = [KeyFileParser getKeyFileDigestFromFileData:data];
        [self openSafe];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)openSafe {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:self.safe.storageProvider];
        
        if(self.openAutoFillCache) {
            [[LocalDeviceStorageProvider sharedInstance] readAutoFillCache:self.safe viewController:self.viewController
                                                                completion:^(NSData *data, NSError *error) {
                [self onProviderReadDone:provider data:data error:error cacheMode:YES];
            }];
        }
        else if (OfflineDetector.sharedInstance.isOffline && providerCanFallbackToOfflineCache(provider, self.safe)) {
            NSString * modDateStr = getLastCachedDate(self.safe);
            NSString* message = [NSString stringWithFormat:@"Could not reach %@, it looks like you may be offline, would you like to use a read-only offline cache version of this safe instead?\n\nLast Cached: %@", provider.displayName, modDateStr];
            
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
                NSString* message = [NSString stringWithFormat:@"There was a problem reading the safe on %@. would you like to use a read-only offline cache version of this safe instead?\n\nLast Cached: %@", provider.displayName, modDateStr];
                
                [self openWithOfflineCacheFile:message];
            }
            else {
                [Alerts error:self.viewController title:@"There was a problem opening the safe." error:error completion:^{
                    self.completion(nil);
                }];
            }
        }
        else {
            [self openSafeWithData:data
                          provider:provider
                         cacheMode:cacheMode];
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
            [Alerts error:self.viewController title:@"There was a problem opening the safe." error:error];
            self.completion(nil);
            return;
        }
        else if (error.code == kStrongboxErrorCodeIncorrectCredentials) {
            if(self.isConvenienceUnlock) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                self.safe.isEnrolledForConvenience = NO;
                self.safe.convenienceMasterPassword = nil;
                self.safe.convenenienceKeyFileDigest = nil;
                
                [SafesList.sharedInstance update:self.safe];
                
                [Alerts info:self.viewController
                       title:@"Could not open safe"
                     message:[NSString stringWithFormat:@"The Convenience Password or Key File were incorrect for this safe. Convenience Unlock Disabled."]] ;
            }
            else {
                [Alerts info:self.viewController
                       title:@"Incorrect Credentials"
                     message:@"The credentials were incorrect for this safe."];
            }
        }
        else {
            [Alerts error:self.viewController title:@"There was a problem opening the safe." error:error];
        }
        
        self.completion(nil);
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
        message = [NSString stringWithFormat:@"You can use either %@ or a convenience PIN Code to unlock this safe. While this is convenient, it may reduce the security of the safe on this device. If you would like to use one of these methods, please select from below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password", self.biometricIdName];
    }
    else if (biometricPossible) {
        title = [NSString stringWithFormat:@"Convenience Unlock: Use %@ to Unlock in Future?", self.biometricIdName];
        message = [NSString stringWithFormat:@"You can use %@ to unlock this safe. While this is convenient, it may reduce the security of the safe on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password", self.biometricIdName];
    }
    else if (pinPossible) {
        title = @"Convenience Unlock: Use a PIN Code to Unlock in Future?";
        message = @"You can use a convenience PIN Code to unlock this safe. While this is convenient, it may reduce the security of the safe on this device. If you would like to use this then please select it below or select No to continue using your master password.\n\n*Important: You must ALWAYS remember your master password";
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
                PinEntryController *vc2 = [[PinEntryController alloc] init];
                vc2.info = @"Please Confirm Your New Convenience PIN";
                vc2.onDone = ^(PinEntryResponse response2, NSString * _Nullable confirmPin) {
                    [self.viewController dismissViewControllerAnimated:YES completion:^{
                        if(response2 == kOk) {
                            if ([pin isEqualToString:confirmPin]) {
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
                                    [Alerts warn:self.viewController title:@"PIN Conflict" message:@"Your Convenience PIN conflicts with your Duress PIN. Please configure in the Safe Settings" completion:^{
                                        [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                                    }];
                                }
                            }
                            else {
                                [Alerts warn:self.viewController title:@"PINs do not match" message:@"Your PINs do not match. You can try again from Safe Settings." completion:^{
                                    [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                                }];
                            }
                        }
                        else {
                            [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
                        }
                    }];
                };
                
                [self.viewController presentViewController:vc2 animated:YES completion:nil];
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
    }
    
    self.completion(viewModel);
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
                   self.completion(nil);
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
