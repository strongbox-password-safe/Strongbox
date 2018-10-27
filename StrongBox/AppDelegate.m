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
#import "QuickLaunchViewController.h"
#import "StorageBrowserTableViewController.h"
#import "UpgradeViewController.h"
#import "OfflineDetector.h"
#import "real-secrets.h"
#import "NSArray+Extensions.h"
#import "OfflineCacheNameDetector.h"

@interface AppDelegate ()

@property (nonatomic, strong) NSDate *enterBackgroundTime;
@property (nonatomic, strong) UIViewController *lockView;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self migrateUserDefaultsToAppGroup]; // iOS Credentials Extension needs access to user settings/safes etc... migrate
    
    [self initializeDropbox];

    [OfflineDetector.sharedInstance startMonitoringConnectivitity];

    [[Settings sharedInstance] incrementLaunchCount];

    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
 
    // TODO: Remove me after a while. 27-Oct-2018
    
    [self cleanupOldOfflineCacheFiles];
    
    return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)cleanupOldOfflineCacheFiles {
    NSUserDefaults *groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupName];
    static NSString* const kDidCleanUpOldOfflineCacheFiles = @"DidCleanUpOldOfflineCacheFiles";
    
    if(groupDefaults != nil) {
        if (![groupDefaults boolForKey:kDidCleanUpOldOfflineCacheFiles]) {
            [groupDefaults setBool:YES forKey:kDidCleanUpOldOfflineCacheFiles];
            [groupDefaults synchronize];
            
            NSLog(@"Try once to cleanup offline cache files...");
            
            NSArray<SafeMetaData*> *oldOfflineCacheFiles = [SafesList.sharedInstance.snapshot filter:^BOOL(SafeMetaData * _Nonnull obj) {
                if(obj.storageProvider == kLocalDevice) {
                    BOOL result = [OfflineCacheNameDetector nickNameMatchesOldOfflineCache:obj.nickName];
                
                    NSLog(@"Local Safe Nickname [%@] Matches Old Offline Cache: [%d]", obj.nickName, result);
                    
                    return result;
                }
                return NO;
            }];
            
            for (SafeMetaData* oldCacheFile in oldOfflineCacheFiles) {
                NSLog(@"Found Old Offline Cache File in Safes Collection: [%@]", oldCacheFile);
                
                [LocalDeviceStorageProvider.sharedInstance delete:oldCacheFile completion:^(NSError *error) {
                    if(!error) {
                        NSLog(@"Successfully removed Old Offline Cache File Safe. [%@]", oldCacheFile);
                    }
                    else {
                        NSLog(@"Error Removing Old Offline Cache File: %@", error);
                    }
                }];
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)migrateUserDefaultsToAppGroup {
    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    
    NSUserDefaults *groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupName];
    
    static NSString* const kDidMigrateSafesToAppGroups = @"DidMigrateToAppGroups";
    
    if(groupDefaults != nil) {
        if (![groupDefaults boolForKey:kDidMigrateSafesToAppGroups]) {
            for(NSString *key in [[userDefaults dictionaryRepresentation] allKeys]) {
                NSLog(@"Migrating Setting: %@", key);
                [groupDefaults setObject:[userDefaults objectForKey:key] forKey:key];
            }
            
            [groupDefaults setBool:YES forKey:kDidMigrateSafesToAppGroups];
            [groupDefaults synchronize];
            
            NSLog(@"Successfully migrated defaults");
        }
        else {
            NSLog(@"No need to migrate defaults, already done.");
        }
    }
    else {
        NSLog(@"Unable to create NSUserDefaults with given app group");
    }
}

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

        [tabController importFromUrlOrEmailAttachment:url];

        return YES;
    }

    return NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UITabBarController *tab = (UITabBarController*)self.window.rootViewController;
    UINavigationController *nav = tab.selectedViewController;

    NSString* className = NSStringFromClass([nav.visibleViewController class]);
    
    NSLog(@"Presenting Lockview over: [%@]", className);
    
    if (![nav.visibleViewController isKindOfClass:[SafesViewController class]] && // Don't show lock screen for these two initial screens as Touch ID/Face ID causes a weird effect of present lock screen while waiting authentication
        ![nav.visibleViewController isKindOfClass:[QuickLaunchViewController class]] &&
        ![nav.visibleViewController isKindOfClass:[UpgradeViewController class]] &&
        ![nav.visibleViewController isKindOfClass:[StorageBrowserTableViewController class]] && // Google Sign In Broken without this... sigh
        ![className isEqualToString:@"SFAuthenticationViewController"] && // Google Sign In Broken without this... sigh. This is kinda brittle but I see no other way around it.
        ![className isEqualToString:@"ODAuthenticationViewController"] &&
        ![className isEqualToString:@"DBMobileSafariViewController"]) // OneDrive too
    {
        self.enterBackgroundTime = [[NSDate alloc] init];

        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        self.lockView = [mainStoryboard instantiateViewControllerWithIdentifier:@"LockScreen"];

        [self.lockView.view layoutIfNeeded];
        [tab presentViewController:self.lockView animated:NO completion:nil];
    }
    else {
        self.lockView = nil;
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.lockView) {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        self.lockView = nil;
    }
    
    if (self.enterBackgroundTime) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:self.enterBackgroundTime];
        NSNumber *seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];

        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) { // -1 = never
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);

            UITabBarController *tabController = (UITabBarController *)self.window.rootViewController;
            UINavigationController* nav = [tabController selectedViewController];
            [nav popToRootViewControllerAnimated:NO];
        }
        
        self.enterBackgroundTime = nil;
    }
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

@end
