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
    self.privacyAndLockVc.onUnlockDone = ^{
        [weakSelf hidePrivacyScreen];
    };
    
    self.privacyAndLockVc.startupLockMode = startupLockMode;
    
    // Visible will be top most - usually the current nav top controller but can be another modal like Custom Fields editor
    
    UINavigationController* nav = [self selectedViewController];
    UIViewController* visible = nav.visibleViewController;
    
    NSLog(@"Presenting Privacy Screen on [%@]", [visible class]);
    
    self.privacyAndLockVc.modalPresentationStyle = UIModalPresentationOverFullScreen; // This stops the view controller interfering with UIAlertController if we happen to present on that. Less than Ideal?
    
    [visible presentViewController:self.privacyAndLockVc animated:NO completion:nil];
}

- (void)hidePrivacyScreen {
    if (self.privacyAndLockVc) {
        if ([self shouldLockSafes]) {
            UINavigationController* nav = [self selectedViewController];
            [nav popToRootViewControllerAnimated:NO];

            // This dismisses all modals including the privacy screen which is what we want
            [self dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed];
            }];
        }
        else {
            [self.privacyAndLockVc.presentingViewController dismissViewControllerAnimated:NO completion:^{
                [self onPrivacyScreenDismissed];
            }];
        }
        
        self.enterBackgroundTime = nil;
    }
}

- (void)onPrivacyScreenDismissed {
    self.privacyAndLockVc = nil;

//    NSLog(@"XXXXXXXXXXXXXXXXXX - On Privacy Screen Dismissed");
    
    if(!self.enqueuedImportUrl) {
        if([self isInQuickLaunchViewMode]) {
            [self openQuickLaunchPrimarySafe];
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

- (void)openQuickLaunchPrimarySafe {
    UINavigationController* nav = [self selectedViewController];
    QuickLaunchViewController* quickLaunch = (QuickLaunchViewController*)nav.viewControllers[0];
    NSLog(@"Found Quick Launch = %@", quickLaunch);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [quickLaunch openPrimarySafe];
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
}

- (BOOL)isInQuickLaunchViewMode { 
    return self.selectedIndex == 1;
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
                if([self isInQuickLaunchViewMode]) {
                    [self openQuickLaunchPrimarySafe];
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
               title:@"iCloud no longer available"
             message:@"Some databases were removed from this device because iCloud has become unavailable, but they remain stored in iCloud."];
        
        [self removeAllICloudSafes];
    }
    
    // No matter what, iCloud isn't available so switch it to off.???
    [Settings sharedInstance].iCloudOn = NO;
    [Settings sharedInstance].iCloudWasOn = NO;
}

- (void)onICloudAvailable {
    if (!Settings.sharedInstance.iCloudOn && !Settings.sharedInstance.iCloudPrompted) {
        [Settings sharedInstance].iCloudPrompted = YES;

        BOOL existingLocalDeviceSafes = [self getLocalDeviceSafes].count > 0;
        BOOL hasOtherCloudSafes = [self hasSafesOtherThanLocalAndiCloud];
        
        if (!existingLocalDeviceSafes && !hasOtherCloudSafes) { // Empty Databases - Assume user wants iCloud on
            Settings.sharedInstance.iCloudOn = YES; // Empty
            [self onICloudAvailableContinuation];
            return;
        }
        else if(self.presentedViewController == nil) {
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
                      Settings.sharedInstance.iCloudOn = YES;
                  }
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
   if (!Settings.sharedInstance.iCloudOn && Settings.sharedInstance.iCloudWasOn && [self getICloudSafes].count) {
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
            [SVProgressHUD showWithStatus:@"Migrating..."];
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
                title:@"Invalid Database"
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
    
    [self import:copy canOpenInPlace:self.enqueuedImportCanOpenInPlace];
}

- (void)import:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace {
    StrongboxUIDocument *document = [[StrongboxUIDocument alloc] initWithFileURL:url];
    [document openWithCompletionHandler:^(BOOL success) {
        NSData* data = document.data;
        
        [document closeWithCompletionHandler:nil];
        
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [FileManager.sharedInstance deleteAllInboxItems];

        [self onReadImportedFile:success data:data url:url canOpenInPlace:canOpenInPlace];
    }];
}

- (void)onReadImportedFile:(BOOL)success data:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace {
    if(!success || !data) {
        [Alerts warn:self title:@"Error Opening" message:@"Could not access this file."];
    }
    else {
        if([url.pathExtension caseInsensitiveCompare:@"key"] ==  NSOrderedSame) {
            [self importKey:data url:url];
        }
        else {
            [self importSafe:data url:url canOpenInPlace:canOpenInPlace];
        }
    }
}

- (void)importKey:(NSData*)data url:(NSURL*)url  {
    NSString* filename = url.lastPathComponent;
    NSString* path = [FileManager.sharedInstance.keyFilesDirectory.path stringByAppendingPathComponent:filename];
    
    NSError *error;
    [data writeToFile:path options:kNilOptions error:&error];
    
    if(!error) {
        [Alerts info:self title:@"Key File Copied" message:@"This key file has been imported successfully."];
    }
    else {
        [Alerts error:self title:@"Problem Copying Key File" error:error];
    }
}

-(void)importSafe:(NSData*)data url:(NSURL*)url canOpenInPlace:(BOOL)canOpenInPlace {
    NSError* error;
    
    if (![DatabaseModel isAValidSafe:data error:&error]) {
        [Alerts error:self
                title:[NSString stringWithFormat:@"Invalid Database - [%@]", url.lastPathComponent]
                error:error];
        return;
    }
    
    if(canOpenInPlace) {
        [Alerts threeOptions:self
                       title:@"Edit or Copy?"
                     message:@"Strongbox can attempt to edit this document in its current location and keep a reference or, if you'd prefer, Strongbox can just make a copy of this file for itself.\n\nWhich option would you like?"
           defaultButtonText:@"Edit in Place"
            secondButtonText:@"Make a Copy"
             thirdButtonText:@"Cancel"
                      action:^(int response) {
                          if(response != 2) {
                              [self checkForLocalFileOverwriteOrGetNickname:data url:url editInPlace:response == 0];
                          }
                      }];
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
                                   title:@"Update Existing Database?"
                                 message:@"A database using this file name was found in Strongbox. Should Strongbox update that database to use this file, or would you like to create a new database using this file?"
                       defaultButtonText:@"Update Existing Database"
                        secondButtonText:@"Create a New Database"
                                  action:^(int response) {
                            if(response == 0) {
                                NSString *suggestedFilename = url.lastPathComponent;
                                BOOL updated = [LocalDeviceStorageProvider.sharedInstance writeToDefaultStorageWithFilename:suggestedFilename overwrite:YES data:data];
                                
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
    id<SafeStorageProvider> provider;
    
    NSString* extension = [DatabaseModel getLikelyFileExtension:data];
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    
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
                                    metadata.likelyFormat = format;
                                    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
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
                    metadata.likelyFormat = format;
                    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
                }
                else {
                    [Alerts error:self title:@"Error Importing Database" error:error];
                }
            });
        }];
    }
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
        [Alerts error:self title:@"Could not bookmark this file" error:error];
    }
    
    NSString* filename = [url lastPathComponent];
    
    SafeMetaData* metadata = [FilesAppUrlBookmarkProvider.sharedInstance getSafeMetaData:nickName fileName:filename providerData:bookMark];
    
    DatabaseFormat format = [DatabaseModel getLikelyDatabaseFormat:data];
    metadata.likelyFormat = format;
    
    [[SafesList sharedInstance] addWithDuplicateCheck:metadata];
}

- (SafeMetaData*)getPrimarySafe {
    SafeMetaData* safe = [SafesList.sharedInstance.snapshot firstObject];
    
    //NSLog(@"Primary Safe: [%@]", safe);
    
    return safe.hasUnresolvedConflicts ? nil : safe;
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
