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
#import "Settings.h"
#import "SharedAppAndAutoFillSettings.h"
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
#import "GoogleDriveManager.h"
#import "iCloudSafesCoordinator.h"
#import "SecretStore.h"
#import "Alerts.h"

@interface AppDelegate ()

@property NSDate* appLaunchTime;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self installTopLevelExceptionHandlers];
    
    [self initializeDropbox];

    [self performEarlyBasicICloudInitialization];
    
    [self initializeInstallSettingsAndLaunchCount];   
    
    [self initializeProFamilyEdition];
    
    [self performMigrations];
    
    // Do not backup local safes, caches or key files
    
    [FileManager.sharedInstance excludeDirectoriesFromBackup];
    
    [self cleanupInbox:launchOptions];
    
    [ClipboardManager.sharedInstance observeClipboardChangeNotifications];
    
    [ProUpgradeIAPManager.sharedInstance initialize]; // Be ready for any In-App Purchase messages
        
    [LocalDeviceStorageProvider.sharedInstance startMonitoringDocumentsDirectory]; // Watch for iTunes File Sharing or other local documents
        
    NSLog(@"STARTUP - Documents Directory: [%@]", FileManager.sharedInstance.documentsDirectory);
    NSLog(@"STARTUP - Shared App Group Directory: [%@]", FileManager.sharedInstance.sharedAppGroupDirectory);

    return YES;
}

- (void)performEarlyBasicICloudInitialization {
    // MMcG: 18-Dec-2019 - Doing this because app activation doesn't work well with iPadOS Split Screen - The
    // Initialization doesn't happen properly from a cold start if the app is launched via iPADOS split screen... If
    // this is not initialized then, the calls to the READ api will fail... This silent initialization should helps keep
    // the app ready for such a situation... H/T: Manuel!
    
    [iCloudSafesCoordinator.sharedInstance initializeiCloudAccessWithCompletion:^(BOOL available) {
        NSLog(@"Early iCloud Initialization Done: Available = [%d]", available);
        Settings.sharedInstance.iCloudAvailable = available;
    }];
}

- (void)initializeProFamilyEdition {
    if([ProUpgradeIAPManager isProFamilyEdition]) {
        NSLog(@"Pro Family Edition... setting Pro");
        [SharedAppAndAutoFillSettings.sharedInstance setPro:YES];
    }
}

- (void)performMigrations {    
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
    
    self.appLaunchTime = [NSDate date];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
//    NSLog(@"openURL: [%@] => [%@]", options, url);
    
    if ([url.absoluteString hasPrefix:@"db"]) {
        DBOAuthResult *authResult = [DBClientsManager handleRedirectURL:url];

        if (authResult != nil) {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"isDropboxLinked" object:authResult];
        }

        return YES;
    }
    else if ([url.absoluteString hasPrefix:@"com.googleusercontent.apps"]) {
        return [GoogleDriveManager.sharedInstance handleUrl:url];
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
    //    [OfflineDetector.sharedInstance stopMonitoringConnectivitity]; // Don't stop monitoring here as it will reset when Touch/Face ID happens :(
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance startMonitoringConnectivitity]; // Restart/Refresh our monitor
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

void uncaughtExceptionHandler(NSException *exception) {
    NSDictionary* jsonDict = @{
        @"name" : exception.name != nil ? exception.name : NSNull.null,
        @"reason" : exception.reason != nil ? exception.reason : NSNull.null,
        @"userInfo" : exception.userInfo != nil ? exception.userInfo : NSNull.null,
        @"callStackSymbols" : exception.callStackSymbols != nil ? exception.callStackSymbols : NSNull.null,
        @"callStackReturnAddresses" :  exception.callStackReturnAddresses != nil ? exception.callStackReturnAddresses : NSNull.null
    };
                
    //        NSData* crashFileData = [NSData dataWithContentsOfURL:FileManager.sharedInstance.archivedCrashFile];
    //        NSDictionary* jsonDict = [NSJSONSerialization JSONObjectWithData:crashFileData options:kNilOptions error:nil];
    //        NSString* reason = jsonDict[@"reason"];
    //        NSString* name = jsonDict[@"name"];
    //        NSDictionary* userInfo = jsonDict[@"userInfo"];
    //        NSArray* callStackReturnAddresses = jsonDict[@"callStackReturnAddresses"];
    //        NSArray* callStackSymbols = jsonDict[@"callStackSymbols"];

    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:nil];
    if (json) {
        [json writeToURL:FileManager.sharedInstance.crashFile options:kNilOptions error:nil];
    }
}

- (void)installTopLevelExceptionHandlers {
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    // MMcG: Sample code to cause a crash (based on a true story)... :/
    //
    //    NSURL* url = [NSURL URLWithString:@"https://www.strongboxsafe.com"];
    //    [NSJSONSerialization dataWithJSONObject:@{ @"url" : url } options:NSJSONWritingPrettyPrinted error:nil];

    // FUTURE?
//    signal(SIGABRT, SignalHandler);
//    signal(SIGILL, SignalHandler);
//    signal(SIGSEGV, SignalHandler);
//    signal(SIGFPE, SignalHandler);
//    signal(SIGBUS, SignalHandler);
//    signal(SIGPIPE, SignalHandler);
}

@end
