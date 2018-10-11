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
#import "GoogleDriveStorageProvider.h"
#import "OneDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "iCloudSafesCoordinator.h"
#import <StoreKit/StoreKit.h>
#import "ISMessages/ISMessages.h"
#import <PopupDialog/PopupDialog-Swift.h>

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

- (void)updateCurrentRootSafesView {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if(self.selectedIndex == 0) {
            UINavigationController* navController = self.selectedViewController;
            SafesViewController* safesList = (SafesViewController*)navController.viewControllers[0];
            [safesList reloadSafes];
        }
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.tabBar.hidden = YES;
    self.selectedIndex = Settings.sharedInstance.useQuickLaunchAsRootView ? 1 : 0;
    self.biometricIdName = [[Settings sharedInstance] getBiometricIdName];
    
    // Pro or Free?
    
    if(![[Settings sharedInstance] isPro]) {
        if([[Settings sharedInstance] getEndFreeTrialDate] == nil) {
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:2 toDate:[NSDate date] options:0];
            [[Settings sharedInstance] setEndFreeTrialDate:date];
        }
        
        if([Settings.sharedInstance getLaunchCount] == 1) {
            [Alerts info:self title:@"Welcome!"
                 message:@"Hi, Welcome to Strongbox Pro!\n\nI hope you will enjoy the app!\n-Mark"];
        }
        else if([Settings.sharedInstance getLaunchCount] > 5 || Settings.sharedInstance.daysInstalled > 6) {
            if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
                [Alerts info:self title:@"Strongbox Pro"
                     message:@"Hi there!\nYou are currently using Strongbox Pro. You can evaluate this version over the next two months. I hope you like it.\n\nAfter this I would ask you to contribute to its development. If you choose not to support the app, you will then be transitioned to a little bit more limited version. You won't lose any of your safes or passwords.\n\nTo find out more you can tap the Upgrade button at anytime below. I hope you enjoy the app, and will choose to support it!\n-Mark"];
                
                [[Settings sharedInstance] setHavePromptedAboutFreeTrial:YES];
            }
            else {
                [self showStartupMessaging];
            }
        }
    }
    else {
        [self showStartupMessaging];
    }
    
    //
    
    [iCloudSafesCoordinator sharedInstance].onSafesCollectionUpdated = ^{
        [self updateCurrentRootSafesView];
    };

    // User may have just switched to our app after updating iCloud settings...
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self checkICloudAvailability];    
}

- (void)didBecomeActive:(NSNotification *)notification {
    [self checkICloudAvailability];
}

- (BOOL)hasSafesOtherThanLocalAndiCloud {
    return SafesList.sharedInstance.snapshot.count - ([self getICloudSafes].count + [self getLocalDeviceSafes].count) > 0;
}

- (NSArray<SafeMetaData*>*)getLocalDeviceSafes {
    return [SafesList.sharedInstance getSafesOfProvider:kLocalDevice];
}

- (NSArray<SafeMetaData*>*)getICloudSafes {
    return [SafesList.sharedInstance getSafesOfProvider:kiCloud];
}

- (void)removeAllICloudSafes {
    NSArray<SafeMetaData*> *icloudSafesToRemove = [self getICloudSafes];
    
    for (SafeMetaData *item in icloudSafesToRemove) {
        [SafesList.sharedInstance remove:item.uuid];
    }
    
    [self updateCurrentRootSafesView];
}

- (void)checkICloudAvailability {
   [[iCloudSafesCoordinator sharedInstance] initializeiCloudAccessWithCompletion:^(BOOL available) {
       Settings.sharedInstance.iCloudAvailable = available;
       
       if (!Settings.sharedInstance.iCloudAvailable) {
           // If iCloud isn't available, set promoted to no (so we can ask them next time it becomes available)
           [Settings sharedInstance].iCloudPrompted = NO;
           
           if ([[Settings sharedInstance] iCloudWasOn] &&  [self getICloudSafes].count) {
               [Alerts warn:self
                      title:@"iCloud no longer available"
                    message:@"Some safes were removed from this device because iCloud has become unavailable, but they remain stored in iCloud."];
               
               [self removeAllICloudSafes];
           }
           
           // No matter what, iCloud isn't available so switch it to off.???
           [Settings sharedInstance].iCloudOn = NO;
           [Settings sharedInstance].iCloudWasOn = NO;
       }
       else {
           // Ask user if want to turn on iCloud if it's available and we haven't asked already and we're not already presenting a view controller
           if (![Settings sharedInstance].iCloudOn && ![Settings sharedInstance].iCloudPrompted && self.presentedViewController == nil) {
               [Settings sharedInstance].iCloudPrompted = YES;
               
               BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
               BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
               
               NSString *message = existingLocalDeviceSafes ?
               (hasOtherCloudSafes ? @"You can now use iCloud with Strongbox. Should your current local safes be migrated to iCloud and available on all your devices? (NB: Your existing cloud safes will not be affected)" :
                @"You can now use iCloud with Strongbox. Should your current local safes be migrated to iCloud and available on all your devices?") :
               (hasOtherCloudSafes ? @"Would you like the option to use iCloud with Strongbox? (NB: Your existing cloud safes will not be affected)" : @"You can now use iCloud with Strongbox. Would you like to have your safes available on all your devices?");
               
               [Alerts twoOptions:self
                            title:@"iCloud is Now Available"
                          message:message
                defaultButtonText:@"Use iCloud"
                 secondButtonText:@"Local Only" action:^(BOOL response) {
                     if(response) {
                         [Settings sharedInstance].iCloudOn = YES;
                     }
                     [self continueICloudAvailableProcedure];
                 }];
           }
           else {
               [self continueICloudAvailableProcedure];
           }
       }
   }];
}

- (void)showiCloudMigrationUi:(BOOL)show {
   if(show) {
       dispatch_async(dispatch_get_main_queue(), ^{
           [SVProgressHUD showWithStatus:@"Migrating..."];
       });
   }
   else {
       dispatch_async(dispatch_get_main_queue(), ^{
           [SVProgressHUD dismiss];
       });
   }
}

- (void)continueICloudAvailableProcedure {
   // If iCloud newly switched on, move local docs to iCloud
   if ([Settings sharedInstance].iCloudOn && ![Settings sharedInstance].iCloudWasOn && [self getLocalDeviceSafes].count) {
       [Alerts twoOptions:self title:@"iCloud Available" message:@"Would you like to migrate your current local device safes to iCloud?"
        defaultButtonText:@"Migrate to iCloud"
         secondButtonText:@"Keep Local" action:^(BOOL response) {
             if(response) {
                 [[iCloudSafesCoordinator sharedInstance] migrateLocalToiCloud:^(BOOL show) {
                     [self showiCloudMigrationUi:show];
                 }];
             }
         }];
   }
   
   // If iCloud newly switched off, move iCloud docs to local
   if (![Settings sharedInstance].iCloudOn && [Settings sharedInstance].iCloudWasOn && [self getICloudSafes].count) {
       [Alerts threeOptions:self
                      title:@"iCloud Unavailable"
                    message:@"What would you like to do with the safes currently on this device?"
          defaultButtonText:@"Remove them, Keep on iCloud Only"
           secondButtonText:@"Make Local Copies"
            thirdButtonText:@"Switch iCloud Back On"
                     action:^(int response) {
                         if(response == 2) {           // @"Switch iCloud Back On"
                             [Settings sharedInstance].iCloudOn = YES;
                             [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
                             
                             [self updateCurrentRootSafesView];
                         }
                         else if(response == 1) {      // @"Keep a Local Copy"
                             [[iCloudSafesCoordinator sharedInstance] migrateiCloudToLocal:^(BOOL show) {
                                 [self showiCloudMigrationUi:show];
                             }];
                         }
                         else if(response == 0) {
                             [self removeAllICloudSafes];
                         }
                     }];
   }
   
   [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
   [[iCloudSafesCoordinator sharedInstance] startQuery];
}

/////////////////////////////////////////////////////////////////////////////////////

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
                                [self updateCurrentRootSafesView];
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
    
    [NSException raise:@"Unknown Storage Provider!" format:@"New One, Mark?"];

    return [LocalDeviceStorageProvider sharedInstance];
}

- (SafeMetaData*)getPrimarySafe {
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstObject];
    
    //NSLog(@"Primary Safe: [%@]", safe);

    return safe.hasUnresolvedConflicts ? nil : safe;
}

///////////////////////////////////////////////////////////////////////////////////////////////

- (void)openAppStoreForOldReview {
    int appId = 897283731;
    
    static NSString *const iOS7AppStoreURLFormat = @"itms-apps://itunes.apple.com/app/id%d?action=write-review";
    static NSString *const iOSAppStoreURLFormat = @"itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?type=Purple+Software&id=%d&action=write-review";
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:([[UIDevice currentDevice].systemVersion floatValue] >= 7.0f)? iOS7AppStoreURLFormat: iOSAppStoreURLFormat, appId]];
    
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
        else {
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    else {
        [Alerts info:self title:@"Cannot open App Store" message:@"Please find Strongbox in the App Store and you can write a review there. Much appreciated! -Mark"];
    }
}

- (void)showStartupMessaging {
    NSUInteger random = arc4random_uniform(2);
    
    if(random == 0) {
        [self maybeMessageAboutMacApp];
    }
    else {
        [self maybeAskForReview];
    }
}

- (void)maybeAskForReview {
    NSInteger promptedForReview = [[Settings sharedInstance] isUserHasBeenPromptedForReview];
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    
    if (launchCount > 20) {
        if (@available( iOS 10.3,*)) {
            [SKStoreReviewController requestReview];
        }
        else if(launchCount % 10 == 0 && promptedForReview == 0) {
            [self oldAskForReview];
        }
    }
}

- (void)maybeMessageAboutMacApp {
    NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];
    BOOL neverShow = [Settings sharedInstance].neverShowForMacAppMessage;
    
    if (launchCount > 20 && (launchCount % 5 == 0) && !neverShow) {
        [self showMacAppMessage];
    }
}

- (void)oldAskForReview {
    [Alerts  threeOptions:self
                    title:@"Review Strongbox?"
                  message:@"Hi, I'm Mark, the developer of Strongbox.\nI would really appreciate it if you could rate this app in the App Store for me.\n\nWould you be so kind?"
        defaultButtonText:@"Sure, take me there!"
         secondButtonText:@"Naah"
          thirdButtonText:@"Like, maybe later!"
                   action:^(int response) {
                       if (response == 0) {
                           [self openAppStoreForOldReview];
                           [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                       }
                       else if (response == 1) {
                           [[Settings sharedInstance] setUserHasBeenPromptedForReview:1];
                       }
                   }];
}

- (void) showMacAppMessage {
    PopupDialog *popup = [[PopupDialog alloc] initWithTitle:@"Available Now"
                                                    message:@"Strongbox is now available in the Mac App Store. I hope you'll find it just as useful there!\n\nSearch 'Strongbox Password Safe' on the Mac App Store."
                                                      image:[UIImage imageNamed:@"strongbox-for-mac-promo"]
                                            buttonAlignment:UILayoutConstraintAxisVertical
                                            transitionStyle:PopupDialogTransitionStyleBounceUp
                                             preferredWidth:340
                                        tapGestureDismissal:YES
                                        panGestureDismissal:YES
                                              hideStatusBar:NO
                                                 completion:nil];
    
    DefaultButton *ok = [[DefaultButton alloc] initWithTitle:@"Cool!" height:50 dismissOnTap:YES action:nil];
    
    CancelButton *later = [[CancelButton alloc] initWithTitle:@"Got It! Never Remind Me Again!" height:50 dismissOnTap:YES action:^{
        [[Settings sharedInstance] setNeverShowForMacAppMessage:YES];
    }];
    
    [popup addButtons: @[ok, later]];
    
    [self presentViewController:popup animated:YES completion:nil];
}

@end
