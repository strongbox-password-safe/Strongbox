//
//  iCloudMigrationOnboardingModule.m
//  Strongbox
//
//  Created by Strongbox on 01/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "iCloudMigrationOnboardingModule.h"
#import "GenericOnboardingViewController.h"
#import "iCloudSafesCoordinator.h"
#import "AppPreferences.h"
#import "DatabasePreferences.h"
#import "SVProgressHUD.h"

typedef NS_ENUM (NSUInteger, iCloudOnboardingMode) {
    kModeNone,
    kModeMigrateNewlySwitchedOn,
    kModeMigrateNewlySwitchedOff,
    kModeMigrateNoLongerAvailableAndHaveDatabases,
};

@interface iCloudMigrationOnboardingModule ()

@property iCloudOnboardingMode mode;

@end

@implementation iCloudMigrationOnboardingModule

- (nonnull instancetype)initWithModel:(Model * _Nullable)model {
    self = [super init];
    
    self.mode = kModeNone;
    
    return self;
}

- (BOOL)shouldDisplay {


    if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        return NO;
    }

    if ( iCloudSafesCoordinator.sharedInstance.fastAvailabilityTest ) {


        BOOL iCloudWasOn = AppPreferences.sharedInstance.iCloudWasOn;
     
        if ( AppPreferences.sharedInstance.iCloudOn ) {
            BOOL hasLocalDatabases = [self getLocalDeviceSafes].count != 0;

            if ( !iCloudWasOn && hasLocalDatabases ) { 
                NSLog(@"iCloudMigrationOnboardingModule::shouldDisplay - iCloud Available & iCloud Newly Switched ON...");

                self.mode = kModeMigrateNewlySwitchedOn;
            }
        }
        else {
            BOOL hasICloudDatabases = [self getICloudSafes].count != 0;

            if ( iCloudWasOn && hasICloudDatabases ) {        
                NSLog(@"iCloudMigrationOnboardingModule::shouldDisplay - iCloud Available & iCloud Newly Switched OFF...");

                self.mode = kModeMigrateNewlySwitchedOff;
            }
        }
        
        AppPreferences.sharedInstance.iCloudWasOn = AppPreferences.sharedInstance.iCloudOn;
        [[iCloudSafesCoordinator sharedInstance] startQuery]; 
    }
    else {
        NSLog(@"iCloudOnboardingModule::shouldDisplay - iCloud Not Available...");
        
        
        

        AppPreferences.sharedInstance.iCloudPrompted = NO;
    
        if ( AppPreferences.sharedInstance.iCloudWasOn &&  [self getICloudSafes].count) {
            self.mode = kModeMigrateNoLongerAvailableAndHaveDatabases;
        }
        
        AppPreferences.sharedInstance.iCloudOn = NO;
        AppPreferences.sharedInstance.iCloudWasOn = NO;
    }
    
    return self.mode != kModeNone;
}

- (UIViewController *)instantiateViewController:(nonnull OnboardingModuleDoneBlock)onDone {
    if ( self.mode == kModeMigrateNoLongerAvailableAndHaveDatabases ) {
        return [self noLongerAvailable:onDone];
    }
    else if ( self.mode == kModeMigrateNewlySwitchedOn ) {
        return [self newlySwitchedOn:onDone];
    }
    else {
        return [self newlySwitchedOff:onDone];
    }
}

- (nonnull UIViewController *)noLongerAvailable:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"GenericOnboardSlide" bundle:nil];
    GenericOnboardingViewController* vc = [storyboard instantiateInitialViewController];
    
    
    

    vc.header = NSLocalizedString(@"safesvc_icloud_no_longer_available_title", @"iCloud no longer available");
    vc.message = NSLocalizedString(@"safesvc_icloud_no_longer_available_message", @"iCloud has become unavailable. Your iCloud databases remain stored in iCloud but they will no longer sync to or from this device though you may still access them here.");
    vc.image = [UIImage imageNamed:@"iCloud-lock"];
    vc.onDone = onDone;
    vc.button1 = NSLocalizedString(@"alerts_ok", @"OK");

    vc.hideDismiss = YES;

    vc.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        NSLog(@"onButtonClicked: %ld", (long)buttonIdCancelIsZero);
        onDone(NO, NO);
    };

    return vc;
}

- (nonnull UIViewController *)newlySwitchedOn:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"GenericOnboardSlide" bundle:nil];
    GenericOnboardingViewController* vc = [storyboard instantiateInitialViewController];

    vc.header = NSLocalizedString(@"safesvc_icloud_available_title", @"iCloud Available");
    vc.message = NSLocalizedString(@"safesvc_question_migrate_local_to_icloud", @"Would you like to migrate your current local device databases to iCloud?");
    vc.image = [UIImage imageNamed:@"iCloud-lock"];
    vc.onDone = onDone;
    vc.button1 = NSLocalizedString(@"safesvc_option_migrate_to_icloud", @"Migrate to iCloud");
    vc.button2 = NSLocalizedString(@"safesvc_option_keep_local", @"Keep Local");

    vc.hideDismiss = YES;
    
    vc.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        NSLog(@"onButtonClicked: %ld", (long)buttonIdCancelIsZero);
        if ( buttonIdCancelIsZero == 1 ) { 
            [[iCloudSafesCoordinator sharedInstance] migrateLocalToiCloud:^(BOOL show) {
                [self showiCloudMigrationUi:show];
            }];
        }
        
        onDone(NO, NO);
    };

    return vc;
}

- (nonnull UIViewController *)newlySwitchedOff:(nonnull OnboardingModuleDoneBlock)onDone {
    UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"GenericOnboardSlide" bundle:nil];
    GenericOnboardingViewController* vc = [storyboard instantiateInitialViewController];

    vc.header = NSLocalizedString(@"safesvc_icloud_unavailable_title", @"iCloud Unavailable");
    vc.message = NSLocalizedString(@"safesvc_icloud_unavailable_question", @"What would you like to do with the databases currently on this device?");
    vc.image = [UIImage imageNamed:@"iCloud-lock"];
    vc.onDone = onDone;
    vc.button1 = NSLocalizedString(@"safesvc_icloud_unavailable_option_remove", @"Remove them, Keep on iCloud Only");
    vc.button2 = NSLocalizedString(@"safesvc_icloud_unavailable_option_make_local", @"Make Local Copies");
    vc.button3 = NSLocalizedString(@"safesvc_icloud_unavailable_option_icloud_on", @"Switch iCloud Back On");

    vc.buttonWidth = @(300.0f);
    
    vc.hideDismiss = NO;
    vc.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        NSLog(@"onButtonClicked: %ld", (long)buttonIdCancelIsZero);
        
        if ( buttonIdCancelIsZero == 1) { 
            [self removeAllICloudSafes];
            onDone(NO, NO);
        }
        else if ( buttonIdCancelIsZero == 2 ) { 
            [[iCloudSafesCoordinator sharedInstance] migrateiCloudToLocal:^(BOOL show) {
                [self showiCloudMigrationUi:show];
            }];
            onDone(NO, NO);
        }
        else if ( buttonIdCancelIsZero == 3 ) { 
            AppPreferences.sharedInstance.iCloudOn = YES;
            AppPreferences.sharedInstance.iCloudWasOn = YES;
            onDone(NO, NO);
        }
        else {
            onDone(NO, YES); 
        }
    };

    return vc;
}

- (NSArray<DatabasePreferences*>*)getICloudSafes {
    return [DatabasePreferences forAllDatabasesOfProvider:kiCloud];
}

- (void)removeAllICloudSafes {
    NSArray<DatabasePreferences*> *icloudSafesToRemove = [self getICloudSafes];
    
    for (DatabasePreferences *item in icloudSafesToRemove) {
        NSLog(@"Removing...");
        [item removeFromDatabasesList];
    }
}

- (NSArray<DatabasePreferences*>*)getLocalDeviceSafes {
    return [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
}

- (void)showiCloudMigrationUi:(BOOL)show {
    if(show) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:NSLocalizedString(@"safesvc_icloud_migration_progress_title_migrating", @"Migrating...")];
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    }
}

@end
