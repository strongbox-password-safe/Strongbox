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
#import <PopupDialog/PopupDialog-Swift.h>
#import "IOsUtils.h"
#import "FilesAppUrlBookmarkProvider.h"
#import "StrongboxUIDocument.h"

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

- (void)import:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace {
    [self.navigationController popToRootViewControllerAnimated:YES];
    
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
}

-(void)importSafe:(StrongboxUIDocument*)document url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace {
    if (![DatabaseModel isAValidSafe:document.data]) {
        [Alerts warn:self
               title:@"Invalid Safe"
             message:@"This is not a valid Strongbox password safe database file."];
        
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
                                  [self promptForImportedSafeNickName:document.data url:url editInPlace:response == 0];
                              }
                          }];
                      }];
    }
    else {
        [document closeWithCompletionHandler:^(BOOL success) {
            [self promptForImportedSafeNickName:document.data url:url editInPlace:NO];
        }];
    }
}

- (void)promptForImportedSafeNickName:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    [Alerts OkCancelWithTextField:self
             textFieldPlaceHolder:@"Safe Name"
                            title:@"Enter a Name"
                          message:@"What would you like to call this safe?"
                       completion:^(NSString *text, BOOL response) {
                           if (response) {
                               NSString *nickName = [SafesList sanitizeSafeNickName:text];
                               
                               if (![[SafesList sharedInstance] isValidNickName:nickName]) {
                                   [Alerts   info:self
                                            title:@"Invalid Nickname"
                                          message:@"That nickname may already exist, or is invalid, please try a different nickname."
                                       completion:^{
                                           [self promptForImportedSafeNickName:data url:url editInPlace:editInPlace];
                                       }];
                               }
                               else {
                                   if(editInPlace) {
                                       [self addExternalFileReferenceSafe:nickName url:url];
                                   }
                                   else {
                                       [self copyAndAddImportedSafe:nickName data:data];
                                   }
                               }
                           }
                       }];
}

- (void)copyAndAddImportedSafe:(NSString *)nickName data:(NSData *)data {
    id<SafeStorageProvider> provider;
    
    if(Settings.sharedInstance.iCloudOn) {
        provider = AppleICloudProvider.sharedInstance;
    }
    else {
        provider = LocalDeviceStorageProvider.sharedInstance;
    }
    
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];

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
                                [Alerts error:self title:@"Error Importing Safe" error:error];
                            }
                        });
     }];
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
