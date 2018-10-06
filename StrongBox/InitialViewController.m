//
//  InitialViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 06/10/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "InitialViewController.h"
#import "Alerts.h"
#import "DatabaseModel.h"
#import "SafesList.h"
#import "Settings.h"
#import "SafeStorageProvider.h"
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesViewController.h"
#import "IOsUtils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "ISMessages/ISMessages.h"
#import "GoogleDriveStorageProvider.h"
#import "OneDriveForBusinessStorageProvider.h"
#import "OneDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"

@interface InitialViewController ()

@property (nonatomic, strong) NSString* biometricIdName;

@end

@implementation InitialViewController

- (void)showQuickLaunchView {
    self.selectedIndex = 1;
}

- (void)showSafesListView {
    self.selectedIndex = 0;
}

- (BOOL)isInQuickLaunchViewMode {
    return self.selectedIndex == 1;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tabBar.hidden = YES;
    self.selectedIndex = Settings.sharedInstance.useQuickLaunchAsRootView ? 1 : 0;
    
    self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
}

- (void)importFromUrlOrEmailAttachment:(NSURL *)importURL {
    [self.navigationController popToRootViewControllerAnimated:YES];
    
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    if (![DatabaseModel isAValidSafe:importedData]) {
        [Alerts warn:self
               title:@"Invalid Safe"
             message:@"This is not a valid Strongbox password safe database file."];
        
        return;
    }
    
    [self promptForImportedSafeNickName:importedData];
}

- (void)promptForImportedSafeNickName:(NSData *)data {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Nickname"
                            title:@"You are about to import a safe. What nickname would you like to use for it?"
                          message:@"Please Enter the URL of the Safe File."
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [SafesList sanitizeSafeNickName:text];
                               
                               if (![[SafesList sharedInstance] isValidNickName:nickName]) {
                                   [Alerts   info:self
                                            title:@"Invalid Nickname"
                                          message:@"That nickname may already exist, or is invalid, please try a different nickname."
                                       completion:^{
                                           [self promptForImportedSafeNickName:data];
                                       }];
                               }
                               else {
                                   [self addImportedSafe:nickName data:data];
                               }
                           }
                       }];
}

- (void)addImportedSafe:(NSString *)nickName data:(NSData *)data {
    id<SafeStorageProvider> provider;
    
    if(Settings.sharedInstance.iCloudOn) {
        provider = AppleICloudProvider.sharedInstance;
    }
    else {
        provider = LocalDeviceStorageProvider.sharedInstance;
    }
    
    [provider create:nickName
                data:data
        parentFolder:nil
      viewController:self
          completion:^(SafeMetaData *metadata, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^(void)
                        {
                            if (error == nil) {
                                [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
                                if(self.selectedIndex == 0) {
                                    UINavigationController* navController = self.selectedViewController;
                                    SafesViewController* safesList = (SafesViewController*)navController.viewControllers[0];
                                    [safesList reloadSafes];
                                }
                            }
                            else {
                                [Alerts error:self title:@"Error Importing Safe" error:error];
                            }
                        });
     }];
}

//////////////////////////////////////////////////////////////////

- (void)beginOpenSafeSequence:(SafeMetaData*)safe completion:(void (^)(Model* model))completion {
    if (!Settings.sharedInstance.disallowAllBiometricId &&
        safe.isTouchIdEnabled &&
        [IOsUtils isTouchIDAvailable] &&
        safe.isEnrolledForTouchId &&
        ([[Settings sharedInstance] isProOrFreeTrial])) {
        [self showTouchIDAuthentication:safe completion:completion];
    }
    else {
        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:YES completion:completion];
    }
}

- (void)showTouchIDAuthentication:(SafeMetaData *)safe completion:(void (^)(Model* model))completion {
    LAContext *localAuthContext = [[LAContext alloc] init];
    localAuthContext.localizedFallbackTitle = @"Enter Master Password";
    
    [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:@"Identify to login"
                               reply:^(BOOL success, NSError *error) {
                                   [self  onTouchIdDone:success
                                                  error:error
                                                   safe:safe
                                             completion:completion];
                               } ];
}

- (void)onTouchIdDone:(BOOL)success error:(NSError *)error safe:(SafeMetaData *)safe completion:(void (^)(Model* model))completion {
    if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openSafe:safe
             isTouchIdOpen:YES
            masterPassword:safe.touchIdPassword
      askAboutTouchIdEnrol:NO
                completion:completion];
        });
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ Authentication Failed. You must now enter your password manually to open the safe.", self.biometricIdName]
                    completion:^{
                        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
                    }];
            });
        }
        else if (error.code == LAErrorUserFallback)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
            });
        }
        else if (error.code != LAErrorUserCancel)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:self
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ has not been setup or system has cancelled. You must now enter your password manually to open the safe.", self.biometricIdName]
                    completion:^{
                        [self promptForSafePassword:safe askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
                    }];
            });
        }
    }
}

- (void)promptForSafePassword:(SafeMetaData *)safe
askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate
                   completion:(void (^)(Model* model))completion {
    [Alerts OkCancelWithPassword:self
                           title:[NSString stringWithFormat:@"Password for %@", safe.nickName]
                         message:@"Enter Master Password"
                      completion:^(NSString *password, BOOL response) {
                          if (response) {
                              [self openSafe:safe
                               isTouchIdOpen:NO
                              masterPassword:password
                        askAboutTouchIdEnrol:askAboutTouchIdEnrolIfAppropriate
                                  completion:completion];
                          }
                      }];
}

- (void)  openSafe:(SafeMetaData *)safe
     isTouchIdOpen:(BOOL)isTouchIdOpen
    masterPassword:(NSString *)masterPassword
askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
        completion:(void (^)(Model* model))completion {
    id <SafeStorageProvider> provider = [self getStorageProviderFromProviderId:safe.storageProvider];
    
    // Are we offline for cloud based providers?
    
    if (provider.cloudBased &&
        !(provider.storageId == kiCloud &&
          [Settings sharedInstance].iCloudOn) &&
        [[Settings sharedInstance] isOffline] &&
        safe.offlineCacheEnabled &&
        safe.offlineCacheAvailable) {
        NSDate *modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:safe];
        
        if(modDate == nil) {
            [Alerts info:self title:@"No Internet Connectivity" message:@"It looks like you are offline, and no offline cache is available. Please try when back online."];
            safe.offlineCacheAvailable = NO;
            [SafesList.sharedInstance update:safe];
            return;
        }
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"dd-MMM-yyyy HH:mm:ss";
        NSString *modDateStr = [df stringFromDate:modDate];
        NSString *message = [NSString stringWithFormat:@"It looks like you are offline. Would you like to use a read-only cached version of this safe instead?\n\nLast Cached at: %@", modDateStr];
        
        [Alerts yesNo:self
                title:@"No Internet Connectivity"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       [[LocalDeviceStorageProvider sharedInstance] readOfflineCachedSafe:safe
                                                                           viewController:self
                                                                               completion:^(NSData *data, NSError *error)
                        {
                            if(data != nil) {
                                [self onProviderReadDone:provider
                                           isTouchIdOpen:isTouchIdOpen
                                                    safe:safe
                                          masterPassword:masterPassword
                                                    data:data
                                                   error:error
                                      isOfflineCacheMode:YES
                                    askAboutTouchIdEnrol:NO
                                              completion:completion]; // RO!
                            }
                        }];
                   }
               }];
    }
    else {
        [provider read:safe
        viewController:self
            completion:^(NSData *data, NSError *error)
         {
             [self onProviderReadDone:provider
                        isTouchIdOpen:isTouchIdOpen
                                 safe:safe
                       masterPassword:masterPassword
                                 data:data
                                error:error
                   isOfflineCacheMode:NO
                 askAboutTouchIdEnrol:askAboutTouchIdEnrol
                           completion:completion];
         }];
    }
}

- (void)onProviderReadDone:(id)provider
             isTouchIdOpen:(BOOL)isTouchIdOpen
                      safe:(SafeMetaData *)safe
            masterPassword:(NSString *)masterPassword
                      data:(NSData *)data error:(NSError *)error
        isOfflineCacheMode:(BOOL)isOfflineCacheMode
      askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
                completion:(void (^)(Model* model))completion  {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error != nil || data == nil) {
            NSLog(@"Error: %@", error);
            [Alerts error:self title:@"There was a problem opening the password safe file." error:error];
        }
        else {
            [self openSafeWithData:data
                    masterPassword:masterPassword
                              safe:safe
                     isTouchIdOpen:isTouchIdOpen
                          provider:provider
                isOfflineCacheMode:isOfflineCacheMode
              askAboutTouchIdEnrol:askAboutTouchIdEnrol
                        completion:completion];
        }
    });
}

- (void)openSafeWithData:(NSData *)data
          masterPassword:(NSString *)masterPassword
                    safe:(SafeMetaData *)safe
           isTouchIdOpen:(BOOL)isTouchIdOpen
                provider:(id)provider
      isOfflineCacheMode:(BOOL)isOfflineCacheMode
    askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
              completion:(void (^)(Model* model))completion{
    [SVProgressHUD showWithStatus:@"Decrypting..."];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSError *error;
        DatabaseModel *openedSafe = [[DatabaseModel alloc] initExistingWithDataAndPassword:data password:masterPassword error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self openSafeWithDataDone:error
                            openedSafe:openedSafe
                         isTouchIdOpen:isTouchIdOpen
                                  safe:safe
                    isOfflineCacheMode:isOfflineCacheMode
                  askAboutTouchIdEnrol:askAboutTouchIdEnrol
                              provider:provider
                                  data:data
                            completion:completion];
        });
    });
}

- (void)openSafeWithDataDone:(NSError*)error
                  openedSafe:(DatabaseModel*)openedSafe
               isTouchIdOpen:(BOOL)isTouchIdOpen
                        safe:(SafeMetaData *)safe
          isOfflineCacheMode:(BOOL)isOfflineCacheMode
        askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
                    provider:(id)provider
                        data:(NSData *)data
                  completion:(void (^)(Model* model))completion {
    [SVProgressHUD dismiss];
    
    if (error) {
        if (error.code == -2) {
            if(isTouchIdOpen) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                safe.isEnrolledForTouchId = NO;
                [safe removeTouchIdPassword];
                [SafesList.sharedInstance update:safe];
                
                [Alerts info:self
                       title:@"Could not open safe"
                     message:[NSString stringWithFormat:@"The linked password was incorrect for this safe. This safe has been unlinked from %@.", self.biometricIdName]] ;
            }
            else {
                [Alerts info:self
                       title:@"Incorrect Password"
                     message:@"The password was incorrect for this safe."];
            }
        }
        else {
            [Alerts error:self title:@"There was a problem opening the safe." error:error];
        }
    }
    else {
        if (askAboutTouchIdEnrol &&
            safe.isTouchIdEnabled &&
            !safe.isEnrolledForTouchId &&
            [IOsUtils isTouchIDAvailable] &&
            [[Settings sharedInstance] isProOrFreeTrial]) {
            [Alerts yesNo:self
                    title:[NSString stringWithFormat:@"Use %@ to Open Safe?", self.biometricIdName]
                  message:[NSString stringWithFormat:@"Would you like to use %@ to open this safe?", self.biometricIdName]
                   action:^(BOOL response) {
                       if (response) {
                           safe.isEnrolledForTouchId = YES;
                           [safe setTouchIdPassword:openedSafe.masterPassword];
                           [SafesList.sharedInstance update:safe];
                           
                           [ISMessages showCardAlertWithTitle:[NSString stringWithFormat:@"%@ Enrol Successful", self.biometricIdName]
                                                      message:[NSString stringWithFormat:@"You can now use %@ with this safe. Opening...", self.biometricIdName]
                                                     duration:0.75f
                                                  hideOnSwipe:YES
                                                    hideOnTap:YES
                                                    alertType:ISAlertTypeSuccess
                                                alertPosition:ISAlertPositionTop
                                                      didHide:^(BOOL finished) {
                                                          [self onSuccessfulSafeOpen:isOfflineCacheMode
                                                                            provider:provider
                                                                          openedSafe:openedSafe
                                                                                safe:safe
                                                                                data:data
                                                                          completion:completion];
                                                      }];
                       }
                       else{
                           safe.isTouchIdEnabled = NO;
                           [safe setTouchIdPassword:openedSafe.masterPassword];
                           [SafesList.sharedInstance update:safe];
                           
                           [self onSuccessfulSafeOpen:isOfflineCacheMode
                                             provider:provider
                                           openedSafe:openedSafe
                                                 safe:safe
                                                 data:data
                                           completion:completion];
                       }
                   }];
        }
        else {
            [self onSuccessfulSafeOpen:isOfflineCacheMode provider:provider openedSafe:openedSafe safe:safe data:data completion:completion];
        }
    }
}

-(void)onSuccessfulSafeOpen:(BOOL)isOfflineCacheMode
                   provider:(id)provider
                 openedSafe:(DatabaseModel *)openedSafe
                       safe:(SafeMetaData *)safe
                       data:(NSData *)data
                 completion:(void (^)(Model* model))completion {
    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:safe
                                           storageProvider:isOfflineCacheMode ? nil : provider // Guarantee nothing can be written!
                                         usingOfflineCache:isOfflineCacheMode
                                                isReadOnly:NO]; // ![[Settings sharedInstance] isProOrFreeTrial]
    
    if (safe.offlineCacheEnabled) {
        [viewModel updateOfflineCacheWithData:data];
    }
    
    completion(viewModel);
}

- (id<SafeStorageProvider>)getStorageProviderFromProviderId:(StorageProvider)providerId {
    if (providerId == kGoogleDrive) {
        return [GoogleDriveStorageProvider sharedInstance];
    }
    else if (providerId == kDropbox)
    {
        return [DropboxV2StorageProvider sharedInstance];
    }
    else if (providerId == kiCloud) {
        return [AppleICloudProvider sharedInstance];
    }
    else if (providerId == kLocalDevice)
    {
        return [LocalDeviceStorageProvider sharedInstance];
    }
    else if(providerId == kOneDrive) {
        return [OneDriveStorageProvider sharedInstance];
    }
    else if(providerId == kOneDriveForBusiness) {
        return [OneDriveForBusinessStorageProvider sharedInstance];
    }
    
    [NSException raise:@"Unknown Storage Provider!" format:@"New One, Mark?"];

    return [LocalDeviceStorageProvider sharedInstance];
}

@end
