//
//  AppDelegate.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "LockScreenViewController.h"
#import "RecordViewController.h"
#import "AdvancedRecordViewController.h"
#import "BrowseSafeView.h"
#import <DropboxSDK/DropboxSDK.h>
#import "SafesViewController.h"
#import "UIAlertView+Blocks.h"
#import "secrets.h"

@implementation AppDelegate

{
    NSDate* enterBackgroundTime;
    LockScreenViewController *lockView;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Dropbox Setup
    
    NSString* appKey = DROPBOX_APP_KEY;
    NSString *as = DROPBOX_APP_SECRET;
    
    DBSession *dbSession = [[DBSession alloc]
                            initWithAppKey:appKey
                            appSecret:as
                            root:kDBRootDropbox]; // either kDBRootAppFolder or kDBRootDropbox
    
    [DBSession setSharedSession:dbSession];
    
    // Launch Count
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger launchCount = [prefs integerForKey:@"launchCount"];
    launchCount++;
    NSLog(@"Application has been launched %ld times", (long)launchCount);
    [prefs setInteger:launchCount  forKey:@"launchCount"];
    
    // Prompted for review
    
    NSInteger promptedForReview = [prefs integerForKey:@"promptedForReview"];

    if((launchCount % 3 == 0) && promptedForReview == 0)
    {
        [UIAlertView showWithTitle:@"Review StrongBox?" message:@"Hi, I'm Mark, I'm the developer of StrongBox.\nI would really appreciate it if you could rate this app in the App Store for me.\n\nWould you be so kind?" cancelButtonTitle:@"Sure, take me there!" otherButtonTitles:@[@"Naah", @"Like, maybe later!"] tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
            if(buttonIndex == 0)
            {
                // Go to app store
                
                // https://itunes.apple.com/us/app/strongbox-password-safe/id897283731
                
                NSString* appId = @"897283731";
                NSString* url = [NSString stringWithFormat:  @"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=%@&pageNumber=0&sortOrdering=1&type=Purple+Software&mt=8", appId];
                
                [[UIApplication sharedApplication] openURL: [NSURL URLWithString: url ]];
                
                [prefs setInteger:1  forKey:@"promptedForReview"];
            }
            if(buttonIndex == 1)
            {
                [prefs setInteger:1  forKey:@"promptedForReview"];
            }
        }];
    }
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
  sourceApplication:(NSString *)source annotation:(id)annotation
{
    // Dropbox...
    
    if([url.absoluteString hasPrefix:@"db"])
    {
        if ([[DBSession sharedSession] handleOpenURL:url])
        {
            NSLog(@"Dropbox App Link: %@", [[DBSession sharedSession] isLinked] ? @"YES" : @"NO");
            
            // At this point you can start making API calls
            
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"isDropboxLinked"
             object:nil];
            
            return YES;
        }
    }
    else
    {
        UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
        
        SafesViewController *rootController = (SafesViewController *) [nav.viewControllers objectAtIndex:0];
        
        [rootController importFromURL:url];
        
        return YES;
    }
    
    return NO;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    enterBackgroundTime = [[NSDate alloc] init];
    
    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
    
    UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone"
                                                             bundle: nil];
    // Google Two Factor Auth is a problem here... We don't want the lock screen if user is in middle of google auth
    // as it messes up the flow when they come back...
    
    if([nav.visibleViewController isKindOfClass:[RecordViewController class]] ||
       [nav.visibleViewController isKindOfClass:[AdvancedRecordViewController class]] ||
       [nav.visibleViewController isKindOfClass:[BrowseSafeView class]])
    {
        lockView = (LockScreenViewController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"LockScreen"];
        
        [nav pushViewController:lockView animated:NO];
    }
    else
    {
        lockView = nil;
    }
}

-(void)applicationDidBecomeActive:(UIApplication *)application
{
    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
    
    if(enterBackgroundTime && lockView)
    {
        NSTimeInterval secondsBetween = [[[NSDate alloc]init] timeIntervalSinceDate:enterBackgroundTime];
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSNumber *seconds = [userDefaults objectForKey:@"autoLockTimeSeconds"];
        
        if(!seconds)
        {
            seconds = @60;
        }
        
        if (seconds.longValue != -1  && secondsBetween > seconds.longValue) // -1 = never
        {
            NSLog(@"Autolock Time [%@s] exceeded, locking safe.", seconds);
            
            [nav popToRootViewControllerAnimated:NO];
        }
    }
    
    if(lockView)
    {
        [nav popViewControllerAnimated:NO];
    }
    
    enterBackgroundTime = nil;
    lockView = nil;
}


@end
