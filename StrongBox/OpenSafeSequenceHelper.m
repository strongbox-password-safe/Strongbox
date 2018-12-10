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
@property BOOL canBiometricEnrol;
@property BOOL openAutoFillCache;
@property (nonnull) CompletionBlock completion;
@property BOOL isTouchIdOpen;
@property NSString* masterPassword;
@property NSData* keyFileDigest;

@end

@implementation OpenSafeSequenceHelper


+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      canBiometricEnrol:(BOOL)canBiometricEnrol
                             completion:(void (^)(Model* model))completion {
    [OpenSafeSequenceHelper beginSequenceWithViewController:viewController safe:safe openAutoFillCache:NO canBiometricEnrol:canBiometricEnrol completion:completion];
}

+ (void)beginSequenceWithViewController:(UIViewController*)viewController
                                   safe:(SafeMetaData*)safe
                      openAutoFillCache:(BOOL)openAutoFillCache
      canBiometricEnrol:(BOOL)canBiometricEnrol
                             completion:(void (^)(Model* model))completion {
    OpenSafeSequenceHelper *helper = [[OpenSafeSequenceHelper alloc] initWithViewController:viewController
                                                      safe:safe
                                         openAutoFillCache:openAutoFillCache
                                         canBiometricEnrol:canBiometricEnrol
                                                completion:completion];
    
    [helper beginSequence];
}

- (instancetype)initWithViewController:(UIViewController*)viewController
                          safe:(SafeMetaData*)safe
             openAutoFillCache:(BOOL)openAutoFillCache
             canBiometricEnrol:(BOOL)canBiometricEnrol
                    completion:(void (^)(Model* model))completion {
    self = [super init];
    if (self) {
        self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
        self.viewController = viewController;
        self.safe = safe;
        self.canBiometricEnrol = canBiometricEnrol;
        self.openAutoFillCache = openAutoFillCache;
        self.completion = completion;
    }
    
    return self;
}

- (void)beginSequence {
    if (!Settings.sharedInstance.disallowAllBiometricId &&
        self.safe.isTouchIdEnabled &&
        [IOsUtils isTouchIDAvailable] &&
        self.safe.isEnrolledForTouchId &&
        ([[Settings sharedInstance] isProOrFreeTrial])) {
        [self showTouchIDAuthentication];
    }
    else {
        [self promptForManualCredentials];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showTouchIDAuthentication {
    LAContext *localAuthContext = [[LAContext alloc] init];
    localAuthContext.localizedFallbackTitle = @"Manual Authentication...";
    
    [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:@"Identify to login"
                               reply:^(BOOL success, NSError *error) {
                                   [self  onTouchIdDone:success error:error];
                               } ];
}

- (void)onTouchIdDone:(BOOL)success
                error:(NSError *)error {
    if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isTouchIdOpen = YES;
            self.masterPassword = self.safe.touchIdPassword;
            self.keyFileDigest = self.safe.touchIdKeyFileDigest;
            
            [self openSafe];
        });
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
    self.isTouchIdOpen = NO;
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
            if(self.isTouchIdOpen) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                self.safe.isEnrolledForTouchId = NO;
                self.safe.touchIdPassword = nil;
                self.safe.touchIdKeyFileDigest = nil;
                
                [SafesList.sharedInstance update:self.safe];
                
                [Alerts info:self.viewController
                       title:@"Could not open safe"
                     message:[NSString stringWithFormat:@"The %@ Password or Key File were incorrect for this safe. This safe has been unlinked from %@.", self.biometricIdName, self.biometricIdName]] ;
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
        if (self.canBiometricEnrol && !cacheMode && self.safe.isTouchIdEnabled && !self.safe.isEnrolledForTouchId &&
            [IOsUtils isTouchIDAvailable] && [[Settings sharedInstance] isProOrFreeTrial]) {
            
            [Alerts yesNo:self.viewController
                    title:[NSString stringWithFormat:@"Use %@ to Open Safe?", self.biometricIdName]
                  message:[NSString stringWithFormat:@"Would you like to use %@ to open this safe?", self.biometricIdName]
                   action:^(BOOL response) {
                       if (response) {
                           self.safe.isEnrolledForTouchId = YES;
                           [self.safe setTouchIdPassword:openedSafe.masterPassword];
                           [self.safe setTouchIdKeyFileDigest:openedSafe.keyFileDigest];
                           
                           [SafesList.sharedInstance update:self.safe];

#ifndef IS_APP_EXTENSION
                           [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Enrol Successful", self.biometricIdName]
                                                      message:[NSString stringWithFormat:@"You can now use %@ with this safe. Opening...", self.biometricIdName]
                                                     duration:0.75f
                                                  hideOnSwipe:YES
                                                    hideOnTap:YES
                                                    alertType:ISAlertTypeSuccess
                                                alertPosition:ISAlertPositionTop
                                                      didHide:^(BOOL finished) {
                                                          [self onSuccessfulSafeOpen:cacheMode
                                                                            provider:provider
                                                                          openedSafe:openedSafe
                                                                                data:data];
                                                      }];
#else
                           [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
#endif
                       }
                       else{
                           self.safe.isTouchIdEnabled = NO;
                           self.safe.touchIdKeyFileDigest = nil;
                           self.safe.touchIdPassword = nil;
                           
                           [SafesList.sharedInstance update:self.safe];
                           
                           [self onSuccessfulSafeOpen:cacheMode
                                             provider:provider
                                           openedSafe:openedSafe
                                                 data:data];
                       }
                   }];
        }
        else {
            [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe data:data];
        }
    }
}

-(void)onSuccessfulSafeOpen:(BOOL)cacheMode
                   provider:(id)provider
                 openedSafe:(DatabaseModel *)openedSafe
                       data:(NSData *)data {
    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:self.safe
                                           storageProvider:cacheMode ? nil : provider // Guarantee nothing can be written!
                                                 cacheMode:cacheMode
                                                isReadOnly:NO]; // ![[Settings sharedInstance] isProOrFreeTrial]
    
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
