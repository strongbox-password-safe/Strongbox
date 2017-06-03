//
//  AppDelegate.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "LockScreenViewController.h"
#import "RecordView.h"
#import "AdvancedRecordViewController.h"
#import "BrowseSafeView.h"
#import "SafesViewController.h"
#import "real-secrets.h"
#import <ObjectiveDropboxOfficial/ObjectiveDropboxOfficial.h>
#import "GoogleDriveManager.h"
#import "Alerts.h"

@implementation AppDelegate {
    NSDate *enterBackgroundTime;
    LockScreenViewController *lockView;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initializeGoogleDrive];

    [self initializeDropbox];

    [self incrementLaunchCount];

    [self promptToReviewAppIfAppropriate];

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

        [rootController importFromURL:url];

        return YES;
    }

    return NO;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    enterBackgroundTime = [[NSDate alloc] init];

    UINavigationController *nav = (UINavigationController *)self.window.rootViewController;

    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone"
                                                             bundle:nil];
    // Google Two Factor Auth is a problem here... We don't want the lock screen if user is in middle of google auth
    // as it messes up the flow when they come back...

    if ([nav.visibleViewController isKindOfClass:[RecordView class]] ||
        [nav.visibleViewController isKindOfClass:[AdvancedRecordViewController class]] ||
        [nav.visibleViewController isKindOfClass:[BrowseSafeView class]]) {
        lockView = (LockScreenViewController *)[mainStoryboard instantiateViewControllerWithIdentifier:@"LockScreen"];

        [nav pushViewController:lockView animated:NO];
    }
    else {
        lockView = nil;
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UINavigationController *nav = (UINavigationController *)self.window.rootViewController;

    if (enterBackgroundTime && lockView) {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:enterBackgroundTime];

        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSNumber *seconds = [userDefaults objectForKey:@"autoLockTimeSeconds"];

        if (!seconds) {
            seconds = @60;
        }

        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) { // -1 = never
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);

            [nav popToRootViewControllerAnimated:NO];
        }
    }

    if (lockView) {
        [nav popViewControllerAnimated:NO];
    }

    enterBackgroundTime = nil;
    lockView = nil;
}

- (void)openAppStoreForReview {
    // https://itunes.apple.com/us/app/strongbox-password-safe/id897283731

    NSString *appId = @"897283731";
    NSString *url = [NSString stringWithFormat:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=%@&pageNumber=0&sortOrdering=1&type=Purple+Software&mt=8", appId];

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url ]];
}

- (void)promptToReviewAppIfAppropriate {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    NSInteger promptedForReview = [prefs integerForKey:@"promptedForReview"];
    NSInteger launchCount = [prefs integerForKey:@"launchCount"];

    if ((launchCount % 3 == 0) && promptedForReview == 0) {
        [Alerts  threeOptions:self.window.rootViewController
                        title:@"Review StrongBox?"
                      message:@"Hi, I'm Mark. I'm the developer of StrongBox.\nI would really appreciate it if you could rate this app in the App Store for me.\n\nWould you be so kind?"
            defaultButtonText:@"Sure, take me there!"
             secondButtonText:@"Naah"
              thirdButtonText:@"Like, maybe later!"
                       action:^(int response) {
                           if (response == 0) {
                           [self openAppStoreForReview];

                           [prefs setInteger:1
                           forKey:@"promptedForReview"];
                           }
                           else if (response == 1)
                           {
                           [prefs setInteger:1
                           forKey:@"promptedForReview"];
                           }
                       }];
    }
}

- (void)initializeGoogleDrive {
    NSError *configureError;

    [[GGLContext sharedInstance] configureWithError:&configureError];
    NSAssert(!configureError, @"Error configuring Google services: %@", configureError);

    // Google - Try to sign in if we have a previous session. This allows us to display the Signout Button
    // state correctly. No need to popup sign in window at this stage, as user may not be using google drive at all

    [[GoogleDriveManager sharedInstance] initialize];
}

- (void)initializeDropbox {
    [DBClientsManager setupWithAppKey:DROPBOX_APP_KEY];
}

- (void)incrementLaunchCount {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger launchCount = [prefs integerForKey:@"launchCount"];

    launchCount++;
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    [prefs setInteger:launchCount forKey:@"launchCount"];
}

@end
