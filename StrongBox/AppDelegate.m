//
//  AppDelegate.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "RecordView.h"
#import "BrowseSafeView.h"
#import "PasswordHistoryViewController.h"
#import "PreviousPasswordsTableViewController.h"
#import "ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h"
#import "GoogleDriveManager.h"
#import "Settings.h"
#import "SafesViewController.h"
#import "SafesViewController.h"
#import "OfflineDetector.h"
#import "real-secrets.h"
#import "NSArray+Extensions.h"
#import "OfflineCacheNameDetector.h"
#import "ProUpgradeIAPManager.h"
#import "FileManager.h"
#import "LocalDeviceStorageProvider.h"
#import "ClipboardManager.h"

@interface AppDelegate ()

@property NSDate* appLaunchTime;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeDropbox];

    [self initializeInstallSettingsAndLaunchCount];   
    
    [self initializeProFamilyEdition];
    
    [self performMigrations];
    
    // Do not backup local safes, caches or key files

    [FileManager.sharedInstance excludeDirectoriesFromBackup];
    
    [self cleanupInbox:launchOptions];
    
    [ClipboardManager.sharedInstance observeClipboardChangeNotifications];
    
    [ProUpgradeIAPManager.sharedInstance initialize]; // Be ready for any In-App Purchase messages
    
    [LocalDeviceStorageProvider.sharedInstance startMonitoringDocumentsDirectory]; // Watch for iTunes File Sharing or other local documents
        
    // NSLog(@"XXXXX - Documents Directory: [%@]", FileManager.sharedInstance.documentsDirectory);
    // NSLog(@"Shared App Group Directory: [%@]", FileManager.sharedInstance.sharedAppGroupDirectory);

    return YES;
}

- (void)initializeProFamilyEdition {
    if(!Settings.sharedInstance.hasDoneProFamilyCheck && [ProUpgradeIAPManager isProFamilyEdition]) {
        NSLog(@"Initial launch of Pro Family Edition... setting Pro");
        Settings.sharedInstance.hasDoneProFamilyCheck = YES;
        [Settings.sharedInstance setPro:YES];
    }
}

- (void)performMigrations {
    // 17-Jun-2019
    if(!Settings.sharedInstance.migratedLocalDatabasesToNewSystem) {
        [LocalDeviceStorageProvider.sharedInstance migrateLocalDatabasesToNewSystem];
    }
    
    // 2-Jul-2019
    if(!Settings.sharedInstance.migratedToNewPasswordGenerator) {
        [self migrateToNewPasswordGenerator];
    }
    
    // 29-Jul-2019
    
    if(!Settings.sharedInstance.migratedToNewQuickLaunchSystem) {
        [self migrateToNewQuickLaunchSystem];
    }
}

- (void)migrateToNewQuickLaunchSystem {
    NSLog(@"Migrating to new migrateToNewQuickLaunchSystem...");
    
    if(Settings.sharedInstance.useQuickLaunchAsRootView && SafesList.sharedInstance.snapshot.count) {
        SafeMetaData* first = SafesList.sharedInstance.snapshot.firstObject;
        NSString* quickLaunchUuid = first.uuid;
        Settings.sharedInstance.quickLaunchUuid = quickLaunchUuid;
        NSLog(@"Setting [%@] to configured quick launch database", first.nickName);
    }
    
    Settings.sharedInstance.migratedToNewQuickLaunchSystem = YES;
}

- (void)migrateToNewPasswordGenerator {
    NSLog(@"Migrating to new Password Generation System...");
    
    PasswordGenerationConfig* newConfig = Settings.sharedInstance.passwordGenerationConfig;
    PasswordGenerationParameters* oldConfig = Settings.sharedInstance.passwordGenerationParameters;
    
    newConfig.algorithm = oldConfig.algorithm == kBasic ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;

    newConfig.basicLength = oldConfig.maximumLength;
    
    NSMutableArray<NSNumber*>* characterGroups = @[].mutableCopy;
    if(oldConfig.useLower) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolLower)];
    }
    if(oldConfig.useUpper) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolUpper)];
    }
    if(oldConfig.useDigits) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolNumeric)];
    }
    if(oldConfig.useSymbols) {
        [characterGroups addObject:@(kPasswordGenerationCharacterPoolSymbols)];
    }
    
    newConfig.useCharacterGroups = characterGroups.copy;
    newConfig.easyReadCharactersOnly = oldConfig.easyReadOnly;
    newConfig.nonAmbiguousOnly = YES;
    newConfig.pickFromEveryGroup = NO;
    
    newConfig.wordCount = oldConfig.xkcdWordCount;
    newConfig.wordSeparator = oldConfig.wordSeparator;
    newConfig.hackerify = NO;
    
    Settings.sharedInstance.passwordGenerationConfig = newConfig;
    Settings.sharedInstance.migratedToNewPasswordGenerator = YES;
}

- (void)cleanupInbox:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [FileManager.sharedInstance deleteAllInboxItems];
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    [[Settings sharedInstance] incrementLaunchCount];
    
    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
    
    if([Settings.sharedInstance getEndFreeTrialDate] == nil) {
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *date = [cal dateByAddingUnit:NSCalendarUnitMonth value:3 toDate:[NSDate date] options:0];
        [Settings.sharedInstance setEndFreeTrialDate:date];
    }
    
    self.appLaunchTime = [NSDate date];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    //NSLog(@"openURL: [%@] => [%@]", options, url);
    
    if ([url.absoluteString hasPrefix:@"db"]) {
        DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];

        if (authResult != nil) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"isDropboxLinked" object:authResult];
        }

        return YES;
    }
    else if ([url.absoluteString hasPrefix:@"com.googleusercontent.apps"])
    {
        return [[GIDSignIn sharedInstance] handleURL:url
                                   sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]
                                          annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
    }
    else {
        SafesViewController *safesViewController = [self getInitialViewController];

        NSNumber* num = [options objectForKey:UIApplicationOpenURLOptionsOpenInPlaceKey];

        [safesViewController enqueueImport:url canOpenInPlace:num ? num.boolValue : NO];

        return YES;
    }

    return NO;
}

- (SafesViewController *)getInitialViewController {
    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
    SafesViewController *ivc = (SafesViewController*)nav.viewControllers.firstObject;
    return ivc;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance stopMonitoringConnectivitity];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance startMonitoringConnectivitity];    
    [self performedScheduledEntitlementsCheck];
}

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;
    double hoursSinceLaunch = minutes / 60;

    if(hoursSinceLaunch > 2) { // Stuff we'd like to do, but definitely not immediately on first launch...
        // Do not request review immediately on launch but after a while and after user has used app for a bit
        NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];

        if (launchCount > 30) { // Don't bother any new / recent users - no need for entitlements check until user is regular user
            if (@available( iOS 10.3,*)) {
                [SKStoreReviewController requestReview];
            }

            [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate:self.window.rootViewController];
        }
    }
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

@end
