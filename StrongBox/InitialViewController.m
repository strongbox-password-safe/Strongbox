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
#import "StorageBrowserTableViewController.h"
#import "PrivacyViewController.h"
#import "CASGTableViewController.h"
#import "FileManager.h"

@interface InitialViewController ()

@property (nonatomic, strong) NSDate *enterBackgroundTime;
@property BOOL privacyScreenSuppressedForBiometricAuth;
@property PrivacyViewController* privacyAndLockVc;
@property BOOL hasAppearedOnce; // Used for App Lock initial load

@property NSURL* enqueuedImportUrl;
@property BOOL enqueuedImportCanOpenInPlace;

@end

@implementation InitialViewController

- (void)showPrivacyScreen:(BOOL)startupLockMode {
    if(self.privacyAndLockVc) {
        NSLog(@"Privacy Screen Already Up... No need to re show");
        return;
    }
    
    self.enterBackgroundTime = [[NSDate alloc] init];

    __weak InitialViewController* weakSelf = self;
    self.privacyAndLockVc = [[PrivacyViewController alloc] initWithNibName:@"PrivacyViewController" bundle:nil];
    self.privacyAndLockVc.onUnlockDone = ^(BOOL userJustCompletedBiometricAuthentication) {
        [weakSelf hidePrivacyScreen:userJustCompletedBiometricAuthentication];
    };
    
    self.privacyAndLockVc.startupLockMode = startupLockMode;
    
    // Visible will be top most - usually the current nav top controller but can be another modal like Custom Fields editor
    
    UINavigationController* nav = [self selectedViewController];
    UIViewController* visible = nav.visibleViewController;
    
    NSLog(@"Presenting Privacy Screen on [%@]", [visible class]);
    
    self.privacyAndLockVc.modalPresentationStyle = UIModalPresentationOverFullScreen; // This stops the view controller interfering with UIAlertController if we happen to present on that. Less than Ideal?
    
    [visible presentViewController:self.privacyAndLockVc animated:NO completion:nil];
}

- (void)hidePrivacyScreen:(BOOL)userJustCompletedBiometricAuthentication {
    if (self.privacyAndLockVc) {
        if ([self shouldLockSafes]) {
            UINavigationController* nav = [self selectedViewController];
            [nav popToRootViewControllerAnimated:NO];

            // This dismisses all modals including the privacy screen which is what we want
            [self dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        else {
            [self.privacyAndLockVc.presentingViewController dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        
        self.enterBackgroundTime = nil;
    }
}

- (void)onPrivacyScreenDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    self.privacyAndLockVc = nil;

//    NSLog(@"XXXXXXXXXXXXXXXXXX - On Privacy Screen Dismissed");
    
    if(!self.enqueuedImportUrl) {
        if([self shouldQuickLaunch]) {
            [self openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
        }

        [self checkICloudAvailability];
    }
    else {
        [self processEnqueuedImport];
    }
}

- (void)appResignActive {
    NSLog(@"appResignActive");

    self.privacyScreenSuppressedForBiometricAuth = NO;
    if(Settings.sharedInstance.suppressPrivacyScreen)
    {
        NSLog(@"appResignActive suppressPrivacyScreen... suppressing privacy and lock screen");
        self.privacyScreenSuppressedForBiometricAuth = YES;
        return;
    }
    
    [self showPrivacyScreen:NO];
}

- (void)appBecameActive {
    NSLog(@"appBecameActive");
    
    if(self.privacyScreenSuppressedForBiometricAuth) {
        NSLog(@"App Active but Privacy Screen Suppressed... Nothing to do");
        self.privacyScreenSuppressedForBiometricAuth = NO;
        return;
    }
    
    if(self.privacyAndLockVc) {
        [self.privacyAndLockVc onAppBecameActive];
    }
}

- (void)openQuickLaunchDatabase:(BOOL)userJustCompletedBiometricAuthentication {
    UINavigationController* nav = [self selectedViewController];
    SafesViewController* safesController = (SafesViewController*)nav.viewControllers[0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [safesController openQuickLaunchDatabase:userJustCompletedBiometricAuthentication];
    });
}

- (BOOL)shouldLockSafes {
    if (self.enterBackgroundTime) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.enterBackgroundTime];
        NSNumber *seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) // -1 = never
        {
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);
            return YES;
        }
    }
    
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tabBar.hidden = YES;
}

- (BOOL)shouldQuickLaunch {
    UINavigationController* quickLaunchNav = self.viewControllers[0];
    
    BOOL quickLaunchVisible = quickLaunchNav.visibleViewController == quickLaunchNav.viewControllers.firstObject;
    
    return quickLaunchVisible;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tabBar.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if(!self.hasAppearedOnce) {
        if (Settings.sharedInstance.appLockMode != kNoLock) {
            [self showPrivacyScreen:YES];
        }
        else {
            if(self.enqueuedImportUrl) {
                [self processEnqueuedImport];
            }
            else {
                if([self shouldQuickLaunch]) {
                    [self openQuickLaunchDatabase:NO];
                }
                else {
                    [self checkICloudAvailability];
                }
            }
        }
    }
    else {
        if(self.enqueuedImportUrl) {
            [self processEnqueuedImport];
        }
        else {
            [self checkICloudAvailability];
        }
    }
    self.hasAppearedOnce = YES;
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
}

- (void)checkICloudAvailability {
    [[iCloudSafesCoordinator sharedInstance] initializeiCloudAccessWithCompletion:^(BOOL available) {
        Settings.sharedInstance.iCloudAvailable = available;
        
        if (!Settings.sharedInstance.iCloudAvailable) {
            [self onICloudNotAvailable];
        }
        else {
            [self onICloudAvailable];
        }
        
        if(![[Settings sharedInstance] isPro]) {
            if(![[Settings sharedInstance] isHavePromptedAboutFreeTrial]) {
                if([Settings.sharedInstance getLaunchCount] > 5 || Settings.sharedInstance.daysInstalled > 2) {
                    [self performSegueWithIdentifier:@"segueToProExplanation" sender:nil];
                    [[Settings sharedInstance] setHavePromptedAboutFreeTrial:YES];
                }
            }
            else {
                [self segueToNagScreenIfAppropriate];
            }
        }
    }];
}

- (void)onICloudNotAvailable {
    // If iCloud isn't available, set promoted to no (so we can ask them next time it becomes available)
    [Settings sharedInstance].iCloudPrompted = NO;
    
    if ([[Settings sharedInstance] iCloudWasOn] &&  [self getICloudSafes].count) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_icloud_no_longer_available_title", @"iCloud no longer available")
             message:NSLocalizedString(@"safesvc_icloud_no_longer_available_message", @"Some databases were removed from this device because iCloud has become unavailable, but they remain stored in iCloud.")];
        
        [self removeAllICloudSafes];
    }
    
    // No matter what, iCloud isn't available so switch it to off.???
    [Settings sharedInstance].iCloudOn = NO;
    [Settings sharedInstance].iCloudWasOn = NO;
}

- (void)onICloudAvailable {
    if (!Settings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudPrompted) {
        BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
        BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
        
        if (!existingLocalDeviceSafes && !hasOtherCloudSafes) { // Empty Databases - Possibly first time user - onboarding will ask
            //Settings.sharedInstance.iCloudOn = YES; // Empty
            [self onICloudAvailableContinuation];
            return;
        }
        else if (self.presentedViewController == nil) {
            NSString* strA = NSLocalizedString(@"safesvc_migrate_local_existing", @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices? (NB: Your existing cloud databases will not be affected)");
            NSString* strB = NSLocalizedString(@"safesvc_migrate_local_no_existing", @"You can now use iCloud with Strongbox. Should your current local databases be migrated to iCloud and available on all your devices?");
            NSString* str1 = NSLocalizedString(@"safesvc_use_icloud_question_existing", @"Would you like the option to use iCloud with Strongbox? (NB: Your existing cloud databases will not be affected)");
            NSString* str2 = NSLocalizedString(@"safesvc_use_icloud_question_no_existing", @"You can now use iCloud with Strongbox. Would you like to have your databases available on all your devices?");

            NSString *message = existingLocalDeviceSafes ? (hasOtherCloudSafes ? strA : strB) : (hasOtherCloudSafes ? str1 : str2);
            
            [Alerts twoOptions:self
                         title:NSLocalizedString(@"safesvc_icloud_now_available_title", @"iCloud is Now Available")
                       message:message
             defaultButtonText:NSLocalizedString(@"safesvc_option_use_icloud", @"Use iCloud")
              secondButtonText:NSLocalizedString(@"safesvc_option_local_only", @"Local Only")
                        action:^(BOOL response) {
                  if(response) {
                      Settings.sharedInstance.iCloudOn = YES;
                  }
                  [Settings sharedInstance].iCloudPrompted = YES;
                  [self onICloudAvailableContinuation];
              }];
        }
    }
    else {
        [self onICloudAvailableContinuation];
    }
}

- (void)onICloudAvailableContinuation {
   // If iCloud newly switched on, move local docs to iCloud
   if (Settings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudWasOn && [self getLocalDeviceSafes].count) {
       [Alerts twoOptions:self
                    title:NSLocalizedString(@"safesvc_icloud_available_title", @"iCloud Available")
                  message:NSLocalizedString(@"safesvc_question_migrate_local_to_icloud", @"Would you like to migrate your current local device databases to iCloud?")
        defaultButtonText:NSLocalizedString(@"safesvc_option_migrate_to_icloud", @"Migrate to iCloud")
         secondButtonText:NSLocalizedString(@"safesvc_option_keep_local", @"Keep Local")
                   action:^(BOOL response) {
             if(response) {
                 [[iCloudSafesCoordinator sharedInstance] migrateLocalToiCloud:^(BOOL show) {
                     [self showiCloudMigrationUi:show];
                 }];
             }
         }];
   }
   
   // If iCloud newly switched off, move iCloud docs to local
   if (!Settings.sharedInstance.iCloudOn && Settings.sharedInstance.iCloudWasOn && [self getICloudSafes].count) {
       [Alerts threeOptions:self
                      title:NSLocalizedString(@"safesvc_icloud_unavailable_title", @"iCloud Unavailable")
                    message:NSLocalizedString(@"safesvc_icloud_unavailable_question", @"What would you like to do with the databases currently on this device?")
          defaultButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_remove", @"Remove them, Keep on iCloud Only")
           secondButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_make_local", @"Make Local Copies")
            thirdButtonText:NSLocalizedString(@"safesvc_icloud_unavailable_option_icloud_on", @"Switch iCloud Back On")
                     action:^(int response) {
                         if(response == 2) {           // @"Switch iCloud Back On"
                             [Settings sharedInstance].iCloudOn = YES;
                             [Settings sharedInstance].iCloudWasOn = [Settings sharedInstance].iCloudOn;
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
   
   Settings.sharedInstance.iCloudWasOn = Settings.sharedInstance.iCloudOn;
   [[iCloudSafesCoordinator sharedInstance] startQuery];
}

- (void)showiCloudMigrationUi:(BOOL)show {
    if(show) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"safesvc_icloud_migration_progress_title_migrating", @"Migrating...")];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    }
}

//////////////////////////////////////////////////////////////////////////////////////

- (void)importFromManualUiUrl:(NSURL *)importURL {
    NSData *importedData = [NSData dataWithContentsOfURL:importURL];
    
    NSError* error;
    if (![DatabaseModel isAValidSafe:importedData error:&error]) {
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_import_manual_url_invalid", @"Invalid Database")
                error:error];
        
        return;
    }
    
    [self checkForLocalFileOverwriteOrGetNickname:importedData url:importURL editInPlace:NO];
}

- (void)enqueueImport:(NSURL *)url canOpenInPlace:(BOOL)canOpenInPlace {
    self.enqueuedImportUrl = url;
    self.enqueuedImportCanOpenInPlace = canOpenInPlace;
}

- (void)processEnqueuedImport {
    if(!self.enqueuedImportUrl) {
        return;
    }
    
    NSURL* copy = self.enqueuedImportUrl;
    self.enqueuedImportUrl = nil;
    
    [self import:copy canOpenInPlace:self.enqueuedImportCanOpenInPlace forceOpenInPlace:NO];
}

- (void)import:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        NSData* data = document.data;
        
        [document closeWithCompletionHandler:nil];
        
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [FileManager.sharedInstance deleteAllInboxItems];

        [self onReadImportedFile:success data:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace];
    }];
}

- (void)onReadImportedFile:(BOOL)success data:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    if(!success || !data) {
        [Alerts warn:self
               title:NSLocalizedString(@"safesvc_error_title_import_file_error_opening", @"Error Opening")
             message:NSLocalizedString(@"safesvc_error_message_import_file_error_opening", @"Could not access this file.")];
    }
    else {
        if([url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame) {
            [self importKey:data url:url];
        }
        else {
            [self importSafe:data url:url canOpenInPlace:canOpenInPlace forceOpenInPlace:forceOpenInPlace];
        }
    }
}

- (void)importKey:(NSData*)data url:(NSURL*)url  {
    NSString* filename = url.lastPathComponent;
    NSString* path = [FileManager.sharedInstance.keyFilesDirectory.path stringByAppendingPathComponent:filename];
    
    NSError *error;
    [data writeToFile:path options:kNilOptions error:&error];
    
    if(!error) {
        [Alerts info:self
               title:NSLocalizedString(@"safesvc_info_title_key_file_imported", @"Key File Imported")
             message:NSLocalizedString(@"safesvc_info_message_key_file_imported", @"This key file has been imported successfully.")];
    }
    else {
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_error_title_error_importing_key_file", @"Problem Importing Key File") error:error];
    }
}

-(void)importSafe:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace forceOpenInPlace:(BOOL)forceOpenInPlace {
    NSError* error;
    
    if (![DatabaseModel isAValidSafe:data error:&error]) {
        [Alerts error:self
                title:[NSString stringWithFormat:NSLocalizedString(@"safesvc_error_title_import_database_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                error:error];
        return;
    }
    
    if(canOpenInPlace) {
        if(forceOpenInPlace) {
            [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:YES];
        }
        else {
            [Alerts threeOptions:self
                           title:NSLocalizedString(@"safesvc_import_database_prompt_title_edit_copy", @"Edit or Copy?")
                         message:NSLocalizedString(@"safesvc_import_database_prompt_message", @"Strongbox can attempt to edit this document in its current location and keep a reference or, if you'd prefer, Strongbox can just make a copy of this file for itself.\n\nWhich option would you like?")
               defaultButtonText:NSLocalizedString(@"safesvc_option_edit_in_place", @"Edit in Place")
                secondButtonText:NSLocalizedString(@"safesvc_option_make_a_copy", @"Make a Copy")
                 thirdButtonText:NSLocalizedString(@"safes_vc_cancel", @"Cancel Option Button Title")
                          action:^(int response) {
                              if(response != 2) {
                                  [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:response == 0];
                              }
                          }];
        }
    }
    else {
        [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:NO];
    }
}

- (void)checkForLocalFileOverwriteOrGetNickname:(NSData *)data url:(NSURL*)url editInPlace:(BOOL)editInPlace {
    if(editInPlace == NO) {
        NSString* filename = url.lastPathComponent;
        if([LocalDeviceStorageProvider.sharedInstance fileNameExistsInDefaultStorage:filename] && Settings.sharedInstance.iCloudOn == NO) {
            [Alerts twoOptionsWithCancel:self
                                   title:NSLocalizedString(@"safesvc_update_existing_database_title", @"Update Existing Database?")
                                 message:NSLocalizedString(@"safesvc_update_existing_question", @"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?")
                       defaultButtonText:NSLocalizedString(@"safesvc_update_existing_option_update", @"Update Existing Database")
                        secondButtonText:NSLocalizedString(@"safesvc_update_existing_option_create", @"Create a New Database")
                                  action:^(int response) {
                            if(response == 0) {
                                NSString *suggestedFilename = url.lastPathComponent;
                                BOOL updated = [LocalDeviceStorageProvider.sharedInstance writeToDefaultStorageWithFilename:suggestedFilename overwrite:YES data:data];
                                
                                if(!updated) {
                                    [Alerts warn:self
                                           title:NSLocalizedString(@"safesvc_error_updating_title", @"Error updating file.")
                                         message:NSLocalizedString(@"safesvc_error_updating_message", @"Could not update local file.")];
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
    [self performSegueWithIdentifier:@"segueFromInitialToAddDatabase"
                              sender:@{ @"editInPlace" : @(editInPlace),
                                                @"url" : url,
                                               @"data" : data }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"segueFromInitialToAddDatabase"]) {
        UINavigationController* nav = (UINavigationController*)segue.destinationViewController;
        CASGTableViewController* scVc = (CASGTableViewController*)nav.topViewController;
        scVc.mode = kCASGModeAddExisting;
        
        NSDictionary<NSString*, id> *params = (NSDictionary<NSString*, id> *)sender;
        NSURL* url = params[@"url"];
        NSData* data = params[@"data"];
        NSNumber* numEIP = params[@"editInPlace"];
        BOOL editInPlace = numEIP.boolValue;
        
        scVc.onDone = ^(BOOL success, CASGParams * _Nullable creds) {
            [self dismissViewControllerAnimated:YES completion:^{
                if(success) {
                    if(editInPlace) {
                        [self addExternalFileReferenceSafe:creds.name data:data url:url];
                    }
                    else {
                        [self copyAndAddImportedSafe:creds.name data:data url:url];
                    }
                }
            }];
        };
    }
}

- (void)copyAndAddImportedSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url  {
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    
    if(Settings.sharedInstance.iCloudOn) {
        [Alerts twoOptionsWithCancel:self
                               title:NSLocalizedString(@"safesvc_copy_database_to_location_title", @"Copy to iCloud or Local?")
                             message:NSLocalizedString(@"safesvc_copy_database_to_location_message", @"iCloud is currently enabled. Would you like to copy this database to iCloud now, or would you prefer to keep on your local device only?")
                   defaultButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_local", @"Copy to Local Device Only")
                    secondButtonText:NSLocalizedString(@"safesvc_copy_database_option_to_icloud", @"Copy to iCloud")
                              action:^(int response) {
                                  if(response == 0) {
                                      [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data];
                                  }
                                  else if(response == 1) {
                                      [self importToICloud:url format:format nickName:nickName extension:extension data:data];
                                  }
                    }];
    }
    else {
        [self importToLocalDevice:url format:format nickName:nickName extension:extension data:data];
    }
}
    
- (void)importToICloud:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data {
    NSString *suggestedFilename = url.lastPathComponent;

    [AppleICloudProvider.sharedInstance create:nickName
           extension:extension
                data:data
   suggestedFilename:suggestedFilename
        parentFolder:nil
      viewController:self
          completion:^(SafeMetaData *metadata, NSError *error)
     {
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                        error:error];
            }
        });
     }];
}

- (void)importToLocalDevice:(NSURL*)url format:(DatabaseFormat)format nickName:(NSString*)nickName extension:(NSString*)extension data:(NSData*)data {
    // Try to keep the filename the same... but don't overwrite any existing, will have asked previously above if the user wanted to
    
    NSString *suggestedFilename = url.lastPathComponent;
    [LocalDeviceStorageProvider.sharedInstance create:nickName
                                            extension:extension
                                                 data:data
                                    suggestedFilename:suggestedFilename
                                           completion:^(SafeMetaData *metadata, NSError *error) {
                                               dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (error == nil) {
                metadata.likelyFormat = format;
                [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
            }
            else {
                [Alerts error:self
                        title:NSLocalizedString(@"safesvc_error_importing_title", @"Error Importing Database")
                        error:error];
            }
        });
    }];
}

- (void)addExternalFileReferenceSafe:(NSString *)nickName data:(NSData *)data url:(NSURL*)url {
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
        [Alerts error:self
                title:NSLocalizedString(@"safesvc_error_title_could_not_bookmark", @"Could not bookmark this file")
                error:error];
        return;
    }
    
    NSString* filename = [url lastPathComponent];
    
    SafeMetaData* metadata = [FilesAppUrlBookmarkProvider.sharedInstance getSafeMetaData:nickName fileName:filename providerData:bookMark];
    
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    metadata.likelyFormat = format;
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
}

- (void)segueToNagScreenIfAppropriate {
    if(Settings.sharedInstance.isProOrFreeTrial) {
        return;
    }

    NSInteger random = arc4random_uniform(100);

    //NSLog(@"Random: %ld", (long)random);

    if(random < 5) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"segueToUpgrade" sender:nil];
        });
    }
}

@end
