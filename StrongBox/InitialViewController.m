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
#import "AppleICloudProvider.h"
#import "LocalDeviceStorageProvider.h"
#import "SafesViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "GoogleDriveStorageProvider.h"
#import "OneDriveStorageProvider.h"
#import "DropboxV2StorageProvider.h"
#import "iCloudSafesCoordinator.h"
#import <StoreKit/StoreKit.h>
#import "OfflineDetector.h"
#import "SafeStorageProviderFactory.h"
#import "ISMessages/ISMessages.h"
#import "IOsUtils.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxUIDocument.h"
#import "QuickLaunchViewController.h"
#import "StorageBrowserTableViewController.h"
#import "LockViewController.h"

@interface InitialViewController ()

@property (nonatomic, strong) NSDate *enterBackgroundTime;
//@property (nonatomic, strong) LockViewController *privacyScreen;
@property BOOL privacyScreenSuppressedForBiometricAuth;

//@property BOOL hasAppearedOnce;
//@property BOOL isAppStartupLaunchOfPrivacyScreen;
@property UIImageView *imageView;

@end

@implementation InitialViewController

- (void)showPrivacyScreen {
    // TODO: Position this more in line with Splash Screen
    
    self.imageView = [[UIImageView alloc] initWithFrame:self.view.window.frame];
    self.imageView.image = [UIImage imageNamed:@"Strongbox-1024x1024-new"];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.opaque = NO;
    self.imageView.backgroundColor = [UIColor whiteColor];
    [self.view.window addSubview:self.imageView];
}

- (void)hidePrivacyScreen {
    if(self.imageView) {
        [self.imageView removeFromSuperview];
    }
    self.imageView = nil;
}

- (void)appResignActive {
    NSLog(@"appResignActive");

    self.privacyScreenSuppressedForBiometricAuth = NO;
    if(Settings.sharedInstance.biometricAuthInProgress)
    {
        NSLog(@"appResignActive biometricAuthInProgress... suppressing privacy and lock screens");
        self.privacyScreenSuppressedForBiometricAuth = YES;
        return;
    }

    self.enterBackgroundTime = [[NSDate alloc] init];
    
    [self showPrivacyScreen];
}

- (void)appBecameActive {
    NSLog(@"appBecameActive");
    
    // User may have just switched to our app after updating iCloud settings...
    [self checkICloudAvailability];
    
    if(self.privacyScreenSuppressedForBiometricAuth) {
        NSLog(@"App Active but Privacy Screen Suppressed... Nothing to do");
        self.privacyScreenSuppressedForBiometricAuth = NO;
        return;
    }

    [self lockAnyOpenSafesIfAppropriate];

    [self hidePrivacyScreen];
    
    self.enterBackgroundTime = nil;

    if([self isInQuickLaunchViewMode]) {
        [self openQuickLaunchPrimarySafe];
    }
}

- (void)openQuickLaunchPrimarySafe {
    UINavigationController* nav = [self selectedViewController];
    QuickLaunchViewController* quickLaunch = (QuickLaunchViewController*)nav.viewControllers[0];
    NSLog(@"Found Quick Launch = %@", quickLaunch);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [quickLaunch openPrimarySafe];
    });
}

- (void)lockAnyOpenSafesIfAppropriate {
    if (self.enterBackgroundTime) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.enterBackgroundTime];
        NSNumber *seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) // -1 = never
        {
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);
            
            UINavigationController* nav = [self selectedViewController];
            [nav popToRootViewControllerAnimated:NO];
        }
    }
}

- (void)showQuickLaunchView {
    self.selectedIndex = 1;
}

- (void)showSafesListView {
    self.selectedIndex = 0;
}

- (void)showConfiguredInitialView {
    if(Settings.sharedInstance.useQuickLaunchAsRootView) {
        [self showQuickLaunchView];
    }
    else {
        [self showSafesListView];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tabBar.hidden = YES;
    
    [self showConfiguredInitialView];
    
    // Pro or Free?
    
    if(![[Settings sharedInstance] isPro]) {
        if([[Settings sharedInstance] getEndFreeTrialDate] == nil) {
            NSCalendar *cal = [NSCalendar currentCalendar];
            NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:3 toDate:[NSDate date] options:0];
            [[Settings sharedInstance] setEndFreeTrialDate:date];
        }
        
        if([Settings.sharedInstance getLaunchCount] == 1) {
            [Alerts info:self title:@"Welcome!"
                 message:@"Hi, Welcome to Strongbox Pro!\n\nI hope you will enjoy the app!\n-Mark"];
        }
        else if([Settings.sharedInstance getLaunchCount] > 5 || Settings.sharedInstance.daysInstalled > 6) {
            if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
                [Alerts info:self title:@"Strongbox Pro"
                     message:@"Hi there!\nYou are currently using Strongbox Pro. You can evaluate this version over the next three months. I hope you like it.\n\nAfter this I would ask you to contribute to its development. If you choose not to support the app, you will then be transitioned to a little bit more limited version. You won't lose any of your databases or passwords.\n\nTo find out more you can tap the Upgrade button at anytime below. I hope you enjoy the app, and will choose to support it!\n-Mark"];
                
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
}

- (BOOL)isInQuickLaunchViewMode { 
    return self.selectedIndex == 1;
}

- (void)updateCurrentRootSafesView {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        if(self.selectedIndex == 0) {
            UINavigationController* nav = [self selectedViewController];
            SafesViewController* safesList = (SafesViewController*)nav.viewControllers[0];
            [safesList reloadSafes];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tabBar.hidden = YES;
    
    [self checkICloudAvailability];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//    if(!self.hasAppearedOnce) {
//        if (Settings.sharedInstance.appLockMode != kNoLock)
//        {
//            self.isAppStartupLaunchOfPrivacyScreen = YES;
//            [self showPrivacyScreen];
//        }
//        else {
//            if([self isInQuickLaunchViewMode]) {
//                [self openQuickLaunchPrimarySafe];
//            }
//        }
//    }
    
//    self.hasAppearedOnce = YES;
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
                    message:@"Some databases were removed from this device because iCloud has become unavailable, but they remain stored in iCloud."];
               
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
               (hasOtherCloudSafes ? @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices? (NB: Your existing cloud databases will not be affected)" :
                @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices?") :
               (hasOtherCloudSafes ? @"Would you like the option to use iCloud with Strongbox? (NB: Your existing cloud databases will not be affected)" : @"You can now use iCloud with Strongbox. Would you like to have your databases available on all your devices?");
               
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
       [Alerts twoOptions:self title:@"iCloud Available" message:@"Would you like to migrate your current local device databases to iCloud?"
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
                    message:@"What would you like to do with the databases currently on this device?"
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

- (void)importFromManualUiUrl:(NSURL *)importURL {
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    NSError* error;
    if (![DatabaseModel isAValidSafe:importedData error:&error]) {
        [Alerts error:self
                title:@"Invalid Database"
                error:error];
        
        return;
    }
    
    [self checkForLocalFileOverwriteOrGetNickname:importedData url:importURL editInPlace:NO];
}

- (void)import:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace {
    UINavigationController* nav = [self selectedViewController];
    [nav popToRootViewControllerAnimated:YES];
    
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        if(!success) {
            [Alerts warn:self title:@"Error Opening" message:@"Could not access this file."];
            return;
        }
        
        if([url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame) {
            [self importKey:document url:url];
        }
        else {
            [self importSafe:document url:url canOpenInPlace:canOpenInPlace];
        }
    }];
}

- (void)importKey:(StrongboxUIDocument*)document url:(NSURL*)url  {
    NSString* filename = url.lastPathComponent;
    NSString* path = [[IOsUtils applicationDocumentsDirectory].path stringByAppendingPathComponent:filename];
    
    NSError *error;
    [document.data writeToFile:path options:kNilOptions error:&error];
    
    if(!error) {
        [Alerts info:self title:@"Key File Copied" message:@"This key file has been copied to Strongbox's local documents directory"];
    }
    else {
        [Alerts error:self title:@"Problem Copying Key File" error:error];
    }
    
    [document closeWithCompletionHandler:nil];
    [LocalDeviceStorageProvider.sharedInstance deleteAllInboxItems];
}

-(void)importSafe:(StrongboxUIDocument*)document url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace {
    NSError* error;
    if (![DatabaseModel isAValidSafe:document.data error:&error]) {
        [Alerts error:self
                title:[NSString stringWithFormat:@"Invalid Database - [%@]", url.lastPathComponent]
                error:error];

        [document closeWithCompletionHandler:nil];
        [LocalDeviceStorageProvider.sharedInstance deleteAllInboxItems];

        return;
    }
    
    if(canOpenInPlace) {
        [Alerts threeOptions:self title:@"Edit or Copy?"
                     message:@"Strongbox can attempt to edit this document in its current location and keep a reference or, if you'd prefer, Strongbox can just make a copy of this file for itself.\n\nWhich option would you like?"
           defaultButtonText:@"Edit in Place"
            secondButtonText:@"Make a Copy"
             thirdButtonText:@"Cancel"
                      action:^(int response) {
                          [document closeWithCompletionHandler:^(BOOL success) {
                              if(response != 2) {
                                  [self checkForLocalFileOverwriteOrGetNickname:document.data url:url editInPlace:response == 0];
                              }
                              [document closeWithCompletionHandler:nil];
                              [LocalDeviceStorageProvider.sharedInstance deleteAllInboxItems];
                          }];
                      }];
    }
    else {
        [document closeWithCompletionHandler:^(BOOL success) {
            [self checkForLocalFileOverwriteOrGetNickname:document.data url:url editInPlace:NO];
            
            [document closeWithCompletionHandler:nil];
            [LocalDeviceStorageProvider.sharedInstance deleteAllInboxItems];
        }];
    }
}

- (void)checkForLocalFileOverwriteOrGetNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    if(editInPlace == NO) {
        NSString* filename = url.lastPathComponent;
        if([LocalDeviceStorageProvider.sharedInstance fileNameExists:filename] && Settings.sharedInstance.iCloudOn == NO) {
            [Alerts twoOptionsWithCancel:self
                                   title:@"Update Existing Database?"
                                 message:@"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?"
                       defaultButtonText:@"Update Existing Database"
                        secondButtonText:@"Create a New Database"
                                  action:^(int response) {
                            if(response == 0) {
                                NSString *suggestedFilename = url.lastPathComponent;
                                BOOL updated = [LocalDeviceStorageProvider.sharedInstance writeWithFilename:suggestedFilename overwrite:YES data:data];
                                
                                if(!updated) {
                                    [Alerts warn:self title:@"Error updating file." message:@"Could not update local file."];
                                }
                                else {
                                    NSLog(@"Updated...");
                                }
                            }
                            else if (response == 1){
                                [self promptForNickname:data url:url editInPlace:editInPlace];
                            }
                        }];
        }
        else {
            [self promptForNickname:data url:url editInPlace:editInPlace];
        }
    }
    else {
        [self promptForNickname:data url:url editInPlace:editInPlace];
    }
}

- (void)promptForNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Database Name"
                            title:@"Enter a Name"
                          message:@"What would you like to call this database?"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [SafesList sanitizeSafeNickName:text];
                               
                               if (![[SafesList sharedInstance] isValidNickName:nickName]) {
                                   [Alerts   info:self
                                            title:@"Invalid Nickname"
                                          message:@"That nickname may already exist, or is invalid, please try a different nickname."
                                       completion:^{
                                           [self promptForNickname:data url:url editInPlace:editInPlace];
                                       }];
                               }
                               else {
                                   if(editInPlace) {
                                       [self addExternalFileReferenceSafe:nickName url:url];
                                   }
                                   else {
                                       [self copyAndAddImportedSafe:nickName data:data url:url];
                                   }
                               }
                           }
                       }];
}

- (void)copyAndAddImportedSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url  {
    id<SafeStorageProvider> provider;
    
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];

    if(Settings.sharedInstance.iCloudOn) {
        provider = AppleICloudProvider.sharedInstance;

        [provider create:nickName
               extension:extension
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
                                    [Alerts error:self title:@"Error Importing Database" error:error];
                                }
                            });
         }];
    }
    else {
        // Try to keep the filename the same... but don't overwrite any existing, will have asked previously above if the user wanted to
        
        NSString *suggestedFilename = url.lastPathComponent;
        [LocalDeviceStorageProvider.sharedInstance create:nickName
                                                extension:extension
                                                     data:data
                                        suggestedFilename:suggestedFilename
                                               completion:^(SafeMetaData *metadata, NSError *error) {
                                                   dispatch_async(dispatch_get_main_queue(), ^(void) {
                if (error == nil) {
                    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
                    [self updateCurrentRootSafesView];
                }
                else {
                    [Alerts error:self title:@"Error Importing Database" error:error];
                }
            });
        }];
    }
}

- (void)addExternalFileReferenceSafe:(NSString *)nickName url:(NSURL*)url {
    BOOL securitySucceeded = [url startAccessingSecurityScopedResource];
    if (!securitySucceeded) {
        NSLog(@"Could not access secure scoped resource!");
        return;
    }
    
    NSURLBookmarkCreationOptions options = 0;
#ifdef NSURLBookmarkCreationWithSecurityScope
    options |= NSURLBookmarkCreationWithSecurityScope;
#endif
    
    NSError* error;
    NSData* bookMark = [url bookmarkDataWithOptions:options includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    
    [url stopAccessingSecurityScopedResource];
    
    if (error) {
        [Alerts error:self title:@"Could not bookmark this file" error:error];
    }
    
    NSString* filename = [url lastPathComponent];
    
    SafeMetaData* metadata = [FilesAppUrlBookmarkProvider.sharedInstance getSafeMetaData:nickName fileName:filename providerData:bookMark];
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self updateCurrentRootSafesView];
    });
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
    [self maybeAskForReview];
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

@end
