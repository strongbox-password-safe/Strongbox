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

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeDropbox];

    [OfflineDetector.sharedInstance startMonitoringConnectivitity];

    [[Settings sharedInstance] incrementLaunchCount];

    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
 
    [LocalDeviceStorageProvider.sharedInstance excludeDirectoriesFromBackup]; // Do not backup local safes, caches or key files

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
    NSLog(@"openURL: [%@] => [%@]", options, url);
    
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
        InitialViewController *tabController = (InitialViewController *)self.window.rootViewController;

        NSNumber* num = [options objectForKey:UIApplicationOpenURLOptionsOpenInPlaceKey];
        
        [tabController import:url canOpenInPlace:num ? num.boolValue : NO];

        return YES;
    }

    return NO;
}

- (InitialViewController *)getInitialViewController {
    InitialViewController *ivc = (InitialViewController*)self.window.rootViewController;
    return ivc;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[self getInitialViewController] appResignActive];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[self getInitialViewController] appBecameActive];
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
