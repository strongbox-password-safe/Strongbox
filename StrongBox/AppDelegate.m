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
#import "InitialViewController.h"
#import "SafesViewController.h"
#import "OfflineDetector.h"
#import "real-secrets.h"
#import "NSArray+Extensions.h"
#import "OfflineCacheNameDetector.h"
#import "ProUpgradeIAPManager.h"

@interface AppDelegate ()

@property NSDate* appLaunchTime;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeDropbox];

    [[Settings sharedInstance] incrementLaunchCount];

    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
    self.appLaunchTime = [NSDate date];

    [LocalDeviceStorageProvider.sharedInstance excludeDirectoriesFromBackup]; // Do not backup local safes, caches or key files

    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        // Inbox should be empty whenever possible so that we can detect the
        // re-importation of a certain file and ask if user wants to create a
        // new copy or just update an old one...
        [LocalDeviceStorageProvider.sharedInstance deleteAllInboxItems];        
    }
    
    [self registerForClipboardClearingNotifications];
    
    [ProUpgradeIAPManager.sharedInstance initialize]; // Be ready for any In-App Purchase messages
    
    return YES;
}

- (void)registerForClipboardClearingNotifications {
    [NSNotificationCenter.defaultCenter addObserverForName:UIPasteboardChangedNotification object:nil queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
        [self startClearClipboardBackgroundTask];
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    NSLog(@"openURL: [%@] => [%@]", options, url);
    NSLog(@"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX");
    
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
        InitialViewController *initialViewController = [self getInitialViewController];

        NSNumber* num = [options objectForKey:UIApplicationOpenURLOptionsOpenInPlaceKey];

        [initialViewController enqueueImport:url canOpenInPlace:num ? num.boolValue : NO];

        return YES;
    }

    return NO;
}

- (InitialViewController *)getInitialViewController {
    InitialViewController *ivc = (InitialViewController*)self.window.rootViewController;
    return ivc;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance stopMonitoringConnectivitity];

    [[self getInitialViewController] appResignActive];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance startMonitoringConnectivitity];

    [[self getInitialViewController] appBecameActive];
    
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

            //                NSCalendar *cal = [NSCalendar currentCalendar];
            //                NSDate *date = [cal dateByAddingUnit:NSCalendarUnitDay value:-2 toDate:[NSDate date] options:0];
            //    Settings.sharedInstance.lastEntitlementCheckAttempt = date;
            //    Settings.sharedInstance.numberOfEntitlementCheckFails = 1;
            //    NSDate *d2 = [cal dateByAddingUnit:NSCalendarUnitDay value:90 toDate:[NSDate date] options:0];
            //    [[Settings sharedInstance] setEndFreeTrialDate:d2];
            
            [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate:self.window.rootViewController];
        }
    }
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

- (void)startClearClipboardBackgroundTask {
    if(Settings.sharedInstance.clearClipboardEnabled)
    {
        if(![UIPasteboard.generalPasteboard hasStrings] &&
           ![UIPasteboard.generalPasteboard hasImages] &&
           ![UIPasteboard.generalPasteboard hasURLs]) {
            return;
        }
        
        NSInteger clipboardChangeCount = UIPasteboard.generalPasteboard.changeCount;
        
        UIApplication* app = [UIApplication sharedApplication];
        __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithExpirationHandler:^{
            [app endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(Settings.sharedInstance.clearClipboardAfterSeconds * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0L), ^{
           if(clipboardChangeCount == UIPasteboard.generalPasteboard.changeCount) {
               [UIPasteboard.generalPasteboard setStrings:@[]];
               [UIPasteboard.generalPasteboard setImages:@[]];
               [UIPasteboard.generalPasteboard setURLs:@[]];
           }
           
           [app endBackgroundTask:task];
           task = UIBackgroundTaskInvalid;
       });
    }
}

@end
