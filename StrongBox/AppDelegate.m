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
#import "ProUpgradeIAPManager.h"
#import "FileManager.h"
#import "SyncManager.h"
#import "ClipboardManager.h"
#import "GoogleDriveManager.h"
#import "iCloudSafesCoordinator.h"
#import "SecretStore.h"
#import "Alerts.h"
#import "SafesList.h"
#import "VirtualYubiKeys.h"

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
        
    [self markDirectoriesForBackupInclusion];
    
    [self cleanupWorkingDirectories:launchOptions];
        
    [ClipboardManager.sharedInstance observeClipboardChangeNotifications];
    
    [ProUpgradeIAPManager.sharedInstance initialize]; 
        
    [SyncManager.sharedInstance startMonitoringDocumentsDirectory]; 
        
    NSLog(@"STARTUP - Documents Directory: [%@]", FileManager.sharedInstance.documentsDirectory);
    NSLog(@"STARTUP - Shared App Group Directory: [%@]", FileManager.sharedInstance.sharedAppGroupDirectory);

    return YES;
}

- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(UIApplicationExtensionPointIdentifier)extensionPointIdentifier {
    if (extensionPointIdentifier == UIApplicationKeyboardExtensionPointIdentifier) {
        return Settings.sharedInstance.allowThirdPartyKeyboards;
    }

    return YES;
}

- (void)markDirectoriesForBackupInclusion {
    [FileManager.sharedInstance setDirectoryInclusionFromBackup:Settings.sharedInstance.backupFiles
                                               importedKeyFiles:Settings.sharedInstance.backupIncludeImportedKeyFiles];
}

- (void)performEarlyBasicICloudInitialization {
    
    
    
    
    
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

- (void)cleanupWorkingDirectories:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        
        
        
        [FileManager.sharedInstance deleteAllInboxItems];
         
        [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
        [FileManager.sharedInstance deleteAllTmpEncryptedAttachmentFiles];
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    [[Settings sharedInstance] incrementLaunchCount];
    
    if(Settings.sharedInstance.installDate == nil) {
        Settings.sharedInstance.installDate = [NSDate date];
    }
    
    self.appLaunchTime = [NSDate date];
}



- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSLog(@"openURL: [%@] => [%@] - Source App: [%@]", options, url, options[UIApplicationOpenURLOptionsSourceApplicationKey]);
    
    if ([url.scheme isEqualToString:@"strongbox"]) {
        NSLog(@"Strongbox URL Scheme: NOP - [%@]", url);
        return YES;
    }
    else if ([url.absoluteString hasPrefix:@"db"]) {
        [DBClientsManager handleRedirectURL:url completion:^(DBOAuthResult * _Nullable authResult) {
            if (authResult != nil) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"isDropboxLinked" object:authResult];
            }
        }];

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
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [OfflineDetector.sharedInstance startMonitoringConnectivitity]; 
    [self performedScheduledEntitlementsCheck];
}

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;
    double hoursSinceLaunch = minutes / 60;

    if(hoursSinceLaunch > 2) { 
        
        NSInteger launchCount = [[Settings sharedInstance] getLaunchCount];

        if (launchCount > 30) { 
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
        @"callStackSymbols" : exception.callStackSymbols != nil ? exception.callStackSymbols : NSNull.null,
        @"callStackReturnAddresses" :  exception.callStackReturnAddresses != nil ? exception.callStackReturnAddresses : NSNull.null
    };
                
    
    
    
    
    
    

    NSData* json = [NSJSONSerialization dataWithJSONObject:jsonDict options:NSJSONWritingPrettyPrinted error:nil];
    if (json) {
        [json writeToURL:FileManager.sharedInstance.crashFile options:kNilOptions error:nil];
    }
}

- (void)installTopLevelExceptionHandlers {
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    
    
    



    






}

@end
