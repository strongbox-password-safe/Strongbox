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
#import "PasswordSettingsTableViewController.h"
#import "PreviousPasswordsTableViewController.h"
#import "SafesViewController.h"
#import "real-secrets.h"
#import "ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h"
#import "GoogleDriveManager.h"
#import "Settings.h"

@implementation AppDelegate {
    NSDate *enterBackgroundTime;
    UIViewController *lockView;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeGoogleDrive];

    [self initializeDropbox];

    [[Settings sharedInstance] incrementLaunchCount];

    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
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
        UINavigationController *nav = (UINavigationController *)self.window.rootViewController;

        SafesViewController *rootController = (SafesViewController *)(nav.viewControllers)[0];

        [rootController importFromUrlOrEmailAttachment:url];

        return YES;
    }

    return NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UINavigationController *nav = (UINavigationController *)self.window.rootViewController;

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];

    if ([nav.visibleViewController isKindOfClass:[RecordView class]] ||
        [nav.visibleViewController isKindOfClass:[BrowseSafeView class]] ||
        [nav.visibleViewController isKindOfClass:[PasswordSettingsTableViewController class]] ||
        [nav.visibleViewController isKindOfClass:[PreviousPasswordsTableViewController class]]) {
        enterBackgroundTime = [[NSDate alloc] init];
        lockView = [mainStoryboard instantiateViewControllerWithIdentifier:@"LockScreen"];
        [self.window.rootViewController presentViewController:lockView animated:NO completion:nil];
    }
    else {
        lockView = nil;
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (lockView) {
        [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
        lockView = nil;
    }
    
    if (enterBackgroundTime) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:enterBackgroundTime];
        NSNumber *seconds = [[Settings sharedInstance] getAutoLockTimeoutSeconds];

        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) { // -1 = never
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);

            UINavigationController *nav = (UINavigationController *)self.window.rootViewController;
            [nav popToRootViewControllerAnimated:NO];
        }
        
        enterBackgroundTime = nil;
    }
}

- (void)initializeGoogleDrive {
    // Google - Try to sign in if we have a previous session. This allows us to display the Signout Button
    // state correctly. No need to popup sign in window at this stage, as user may not be using google drive at all

    [GIDSignIn sharedInstance].clientID = GOOGLE_CLIENT_ID;
    [[GoogleDriveManager sharedInstance] initialize];
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

@end
