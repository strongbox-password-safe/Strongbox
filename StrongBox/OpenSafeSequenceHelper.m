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

#ifndef IS_APP_EXTENSION
#import "ISMessages/ISMessages.h"
#endif

@interface OpenSafeSequenceHelper ()

@property (nonatomic, strong) NSString* biometricIdName;

@end

@implementation OpenSafeSequenceHelper

+ (instancetype)sharedInstance {
    static OpenSafeSequenceHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OpenSafeSequenceHelper alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    }
    
    return self;
}

- (void)beginOpenSafeSequence:(UIViewController*)viewController
                         safe:(SafeMetaData*)safe
askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate
                   completion:(void (^)(Model* model))completion {
    [self beginOpenSafeSequence:viewController
                           safe:safe
              openAutoFillCache:NO
askAboutTouchIdEnrolIfAppropriate:askAboutTouchIdEnrolIfAppropriate
                     completion:completion];
}

- (void)beginOpenSafeSequence:(UIViewController*)viewController
                         safe:(SafeMetaData*)safe
            openAutoFillCache:(BOOL)openAutoFillCache
askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate
                   completion:(void (^)(Model* model))completion {
    if (!Settings.sharedInstance.disallowAllBiometricId &&
        safe.isTouchIdEnabled &&
        [IOsUtils isTouchIDAvailable] &&
        safe.isEnrolledForTouchId &&
        ([[Settings sharedInstance] isProOrFreeTrial])) {
        [self showTouchIDAuthentication:viewController safe:safe openAutoFillCache:openAutoFillCache completion:completion];
    }
    else {
        [self promptForSafePassword:viewController
                               safe:safe
                  openAutoFillCache:openAutoFillCache
  askAboutTouchIdEnrolIfAppropriate:askAboutTouchIdEnrolIfAppropriate
                         completion:completion];
    }
}

- (void)showTouchIDAuthentication:(UIViewController*)viewController
                             safe:(SafeMetaData *)safe
                openAutoFillCache:(BOOL)openAutoFillCache
                       completion:(void (^)(Model* model))completion {
    LAContext *localAuthContext = [[LAContext alloc] init];
    localAuthContext.localizedFallbackTitle = @"Enter Master Password";
    
    [localAuthContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
                     localizedReason:@"Identify to login"
                               reply:^(BOOL success, NSError *error) {
                                   [self  onTouchIdDone:viewController
                                      openAutoFillCache:openAutoFillCache
                                                success:success
                                                  error:error
                                                   safe:safe
                                             completion:completion];
                               } ];
}

- (void)onTouchIdDone:(UIViewController*)viewController
    openAutoFillCache:(BOOL)openAutoFillCache
              success:(BOOL)success
                error:(NSError *)error safe:(SafeMetaData *)safe completion:(void (^)(Model* model))completion {
    if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self openSafe:viewController
                      safe:safe
         openAutoFillCache:openAutoFillCache
             isTouchIdOpen:YES
            masterPassword:safe.touchIdPassword
      askAboutTouchIdEnrol:NO
                completion:completion];
        });
    }
    else {
        if (error.code == LAErrorAuthenticationFailed) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:viewController
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ Authentication Failed. You must now enter your password manually to open the safe.", self.biometricIdName]
                    completion:^{
                        [self promptForSafePassword:viewController safe:safe openAutoFillCache:openAutoFillCache askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
                    }];
            });
        }
        else if (error.code == LAErrorUserFallback)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self promptForSafePassword:viewController safe:safe openAutoFillCache:openAutoFillCache askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
            });
        }
        else if (error.code != LAErrorUserCancel)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [Alerts   warn:viewController
                         title:[NSString stringWithFormat:@"%@ Failed", self.biometricIdName]
                       message:[NSString stringWithFormat:@"%@ has not been setup or system has cancelled. You must now enter your password manually to open the safe.", self.biometricIdName]
                    completion:^{
                        [self promptForSafePassword:viewController safe:safe openAutoFillCache:openAutoFillCache askAboutTouchIdEnrolIfAppropriate:NO completion:completion];
                    }];
            });
        }
    }
}

- (void)promptForSafePassword:(UIViewController*)viewController
                         safe:(SafeMetaData *)safe
            openAutoFillCache:(BOOL)openAutoFillCache
askAboutTouchIdEnrolIfAppropriate:(BOOL)askAboutTouchIdEnrolIfAppropriate
                   completion:(void (^)(Model* model))completion {
    [Alerts OkCancelWithPassword:viewController
                           title:[NSString stringWithFormat:@"Password for %@", safe.nickName]
                         message:@"Enter Master Password"
                      completion:^(NSString *password, BOOL response) {
                          if (response) {
                              [self openSafe:viewController
                                        safe:safe
                           openAutoFillCache:openAutoFillCache
                               isTouchIdOpen:NO
                              masterPassword:password
                        askAboutTouchIdEnrol:askAboutTouchIdEnrolIfAppropriate
                                  completion:completion];
                          }
                      }];
}

- (void)  openSafe:(UIViewController*)viewController
              safe:(SafeMetaData *)safe
 openAutoFillCache:(BOOL)openAutoFillCache
     isTouchIdOpen:(BOOL)isTouchIdOpen
    masterPassword:(NSString *)masterPassword
askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
        completion:(void (^)(Model* model))completion {
    id <SafeStorageProvider> provider = [SafeStorageProviderFactory getStorageProviderFromProviderId:safe.storageProvider];
    
    // Are we offline for cloud based providers?
    if(openAutoFillCache) {
        [[LocalDeviceStorageProvider sharedInstance] readAutoFillCache:safe
                                                        viewController:viewController
                                                            completion:^(NSData *data, NSError *error)
         {
             if(data != nil) {
                 [self onProviderReadDone:provider
                            isTouchIdOpen:isTouchIdOpen
                           viewController:viewController
                                     safe:safe
                           masterPassword:masterPassword
                                     data:data
                                    error:error
                                cacheMode:YES
                     askAboutTouchIdEnrol:NO
                               completion:completion]; // RO!
             }
         }];
    }
    else if (provider.cloudBased &&
        !(provider.storageId == kiCloud && Settings.sharedInstance.iCloudOn) &&
        OfflineDetector.sharedInstance.isOffline &&
        safe.offlineCacheEnabled &&
        safe.offlineCacheAvailable) {
        NSDate *modDate = [[LocalDeviceStorageProvider sharedInstance] getOfflineCacheFileModificationDate:safe];
        
        if(modDate == nil) {
            [Alerts info:viewController
                   title:@"No Internet Connectivity"
                 message:@"It looks like you are offline, and no offline cache is available. Please try when back online."];
            safe.offlineCacheAvailable = NO;
            [SafesList.sharedInstance update:safe];
            
            completion(nil);
            return;
        }
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.timeStyle = NSDateFormatterShortStyle;
        df.dateStyle = NSDateFormatterShortStyle;
        df.doesRelativeDateFormatting = YES;
        df.locale = NSLocale.currentLocale;
        
        NSString *modDateStr = [df stringFromDate:modDate];
        
        NSString *message = [NSString stringWithFormat:@"It looks like you are offline. Would you like to use a read-only offline cache version of this safe instead?\n\nLast Cached: %@", modDateStr];
        
        [Alerts yesNo:viewController
                title:@"No Internet Connectivity"
              message:message
               action:^(BOOL response) {
                   if (response) {
                       [[LocalDeviceStorageProvider sharedInstance] readOfflineCachedSafe:safe
                                                                           viewController:viewController
                                                                               completion:^(NSData *data, NSError *error)
                        {
                            if(data != nil) {
                                [self onProviderReadDone:provider
                                           isTouchIdOpen:isTouchIdOpen
                                          viewController:viewController
                                                    safe:safe
                                          masterPassword:masterPassword
                                                    data:data
                                                   error:error
                                               cacheMode:YES
                                    askAboutTouchIdEnrol:NO
                                              completion:completion]; // RO!
                            }
                        }];
                   }
                   else {
                       completion(nil);
                   }
               }];
    }
    else {
        [provider read:safe
        viewController:viewController
            completion:^(NSData *data, NSError *error)
         {
             [self onProviderReadDone:provider
                        isTouchIdOpen:isTouchIdOpen
                       viewController:viewController
                                 safe:safe
                       masterPassword:masterPassword
                                 data:data
                                error:error
                            cacheMode:NO
                 askAboutTouchIdEnrol:askAboutTouchIdEnrol
                           completion:completion];
         }];
    }
}

- (void)onProviderReadDone:(id)provider
             isTouchIdOpen:(BOOL)isTouchIdOpen
            viewController:(UIViewController*)viewController
                      safe:(SafeMetaData *)safe
            masterPassword:(NSString *)masterPassword
                      data:(NSData *)data error:(NSError *)error
                 cacheMode:(BOOL)cacheMode
      askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
                completion:(void (^)(Model* model))completion  {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error != nil || data == nil) {
            NSLog(@"Error: %@", error);
            [Alerts error:viewController title:@"There was a problem opening the password safe file." error:error completion:^{
                completion(nil);
            }];
        }
        else {
            [self openSafeWithData:data
                    masterPassword:masterPassword
                    viewController:viewController
                              safe:safe
                     isTouchIdOpen:isTouchIdOpen
                          provider:provider
                         cacheMode:cacheMode
              askAboutTouchIdEnrol:askAboutTouchIdEnrol
                        completion:completion];
        }
    });
}

- (void)openSafeWithData:(NSData *)data
          masterPassword:(NSString *)masterPassword
          viewController:(UIViewController*)viewController
                    safe:(SafeMetaData *)safe
           isTouchIdOpen:(BOOL)isTouchIdOpen
                provider:(id)provider
               cacheMode:(BOOL)cacheMode
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
                        viewController:viewController
                                  safe:safe
                    cacheMode:cacheMode
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
              viewController:(UIViewController*)viewController
                        safe:(SafeMetaData *)safe
                   cacheMode:(BOOL)cacheMode
        askAboutTouchIdEnrol:(BOOL)askAboutTouchIdEnrol
                    provider:(id)provider
                        data:(NSData *)data
                  completion:(void (^)(Model* model))completion {
    [SVProgressHUD dismiss];
    
    if(openedSafe == nil) {
        [Alerts error:viewController title:@"There was a problem opening the safe." error:error];
        completion(nil);
    }
    if (error) {
        if (error.code == -2) {
            if(isTouchIdOpen) { // Password incorrect - Either in our Keychain or on initial entry. Remove safe from Touch ID enrol.
                safe.isEnrolledForTouchId = NO;
                [safe removeTouchIdPassword];
                [SafesList.sharedInstance update:safe];
                
                [Alerts info:viewController
                       title:@"Could not open safe"
                     message:[NSString stringWithFormat:@"The linked password was incorrect for this safe. This safe has been unlinked from %@.", self.biometricIdName]] ;
            }
            else {
                [Alerts info:viewController
                       title:@"Incorrect Password"
                     message:@"The password was incorrect for this safe."];
            }
        }
        else {
            [Alerts error:viewController title:@"There was a problem opening the safe." error:error];
        }
        
        completion(nil);
    }
    else {
        if (askAboutTouchIdEnrol &&
            safe.isTouchIdEnabled &&
            !safe.isEnrolledForTouchId &&
            [IOsUtils isTouchIDAvailable] &&
            [[Settings sharedInstance] isProOrFreeTrial]) {
            [Alerts yesNo:viewController
                    title:[NSString stringWithFormat:@"Use %@ to Open Safe?", self.biometricIdName]
                  message:[NSString stringWithFormat:@"Would you like to use %@ to open this safe?", self.biometricIdName]
                   action:^(BOOL response) {
                       if (response) {
                           safe.isEnrolledForTouchId = YES;
                           [safe setTouchIdPassword:openedSafe.masterPassword];
                           [SafesList.sharedInstance update:safe];

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
                                                                                safe:safe
                                                                                data:data
                                                                          completion:completion];
                                                      }];
#else
                           [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe safe:safe data:data completion:completion];
#endif
                       }
                       else{
                           safe.isTouchIdEnabled = NO;
                           [safe setTouchIdPassword:openedSafe.masterPassword];
                           [SafesList.sharedInstance update:safe];
                           
                           [self onSuccessfulSafeOpen:cacheMode
                                             provider:provider
                                           openedSafe:openedSafe
                                                 safe:safe
                                                 data:data
                                           completion:completion];
                       }
                   }];
        }
        else {
            [self onSuccessfulSafeOpen:cacheMode provider:provider openedSafe:openedSafe safe:safe data:data completion:completion];
        }
    }
}

-(void)onSuccessfulSafeOpen:(BOOL)cacheMode
                   provider:(id)provider
                 openedSafe:(DatabaseModel *)openedSafe
                       safe:(SafeMetaData *)safe
                       data:(NSData *)data
                 completion:(void (^)(Model* model))completion {
    Model *viewModel = [[Model alloc] initWithSafeDatabase:openedSafe
                                                  metaData:safe
                                           storageProvider:cacheMode ? nil : provider // Guarantee nothing can be written!
                                                 cacheMode:cacheMode
                                                isReadOnly:NO]; // ![[Settings sharedInstance] isProOrFreeTrial]
    
    if (!cacheMode)
    {
        if(safe.offlineCacheEnabled) {
            [viewModel updateOfflineCacheWithData:data];
        }
        if(safe.autoFillCacheEnabled) {
            [viewModel updateAutoFillCacheWithData:data];
        }
    }
    
    completion(viewModel);
}

@end
