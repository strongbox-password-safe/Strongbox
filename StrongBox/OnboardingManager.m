//
//  OnboardingManager.m
//  Strongbox
//
//  Created by Strongbox on 07/06/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "OnboardingManager.h"
#import "OnboardingModule.h"

#import "AppPreferences.h"
#import "StrongboxiOSFilesManager.h"
#import "FirstUnlockWelcomeModule.h"
#import "ConvenienceUnlockOnboardingModule.h"
#import "QuickLaunchOnboardingModule.h"
#import "ConvenienceExpiryOnboardingModule.h"
#import "AutoFillOnboardingModule.h"
#import "GenericOnboardingModule.h"
#import "FreeTrialOnboardingModule.h"
#import "AppAutoFillOnboardingModule.h"
#import "LastCrashReportModule.h"
#import "UpgradeToProOnboardingModule.h"
#import "UpgradeViewController.h"
#import "BiometricsManager.h"
#import "WorkingCopyManager.h"
#import "NSDate+Extensions.h"
#import "DatabasePreferences.h"
#import "EncryptionSettingsViewModel.h"
#import "BackupsManager.h"
#import "ProUpgradeIAPManager.h"
#import "BusinessActivationOnboardingModule.h"
#import "Strongbox-Swift.h"
#import "SaleScheduleManager.h"
#import "GenericOnboardingViewController.h"
#import "ExportHelper.h"
#import <UserNotifications/UserNotifications.h>

@interface OnboardingManager ()

@property BOOL appOnboardingInProcess;

@end

@implementation OnboardingManager

+ (instancetype)sharedInstance {
    static OnboardingManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[OnboardingManager alloc] init];
    });
    
    return sharedInstance;
}




- (void)startAppOnboarding:(VIEW_CONTROLLER_PTR)presentingViewController completion:(void (^ _Nullable)(void))completion {
    if ( self.appOnboardingInProcess ) {
        slog(@"Onboarding Already in Progress, ignoring repeated call");
        return;
    }
    



    self.appOnboardingInProcess = YES;

    id<OnboardingModule> businessActivation = [self getBusinessActivationModule];
    id<OnboardingModule> welcomeToStrongbox = [self getFirstRunWelcomeToStrongboxModule];

    id<OnboardingModule> freeTrial = [self getFreeTrialOnboardingModule];
    
    id<OnboardingModule> autoFill = [self getAutoFillOnboardingModule];
    id<OnboardingModule> backupSettings = [self getBackupSettingsModule];
    id<OnboardingModule> crashReportModule = [self getLastCrashReportModule];
    id<OnboardingModule> freeTrialEndingSoon = [self getFreeTrialEndingSoonModule];
    id<OnboardingModule> downgraded = [self getHasBeenDowngradedModule];
    id<OnboardingModule> upgradeToPro = [self getUpgradeToProModule];
    id<OnboardingModule> saleNowOn = [self getSaleNowOnModule];
    id<OnboardingModule> finalAllSetWelcomeToStrongbox = [self getFirstRunFinalWelcomeToStrongboxModule];
    
    NSArray<id<OnboardingModule>> *onboardingItems = @[businessActivation,
                                                       welcomeToStrongbox,
                                                       autoFill,
                                                       freeTrial,
                                                       backupSettings,
                                                       crashReportModule,
                                                       freeTrialEndingSoon,
                                                       downgraded,
                                                       upgradeToPro,
                                                       saleNowOn,
                                                       finalAllSetWelcomeToStrongbox];


    UINavigationController* nav = [[UINavigationController alloc] init];
    
    nav.navigationBarHidden = YES;
    
    
    
    
    
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.modalInPresentation = YES; 
    
    OnboardingManager *weakSelf = self;
    [self showNextOnboardingModule:presentingViewController model:nil onboardingItems:onboardingItems index:0 stopOnboarding:NO nav:nav completion:^{
        weakSelf.appOnboardingInProcess = NO;
        completion();
    }];
}

- (void)startDatabaseOnboarding:(VIEW_CONTROLLER_PTR)presentingViewController model:(Model*)model completion:(void (^ _Nullable)(void))completion {
    
    
    
    
    
    
    
    
    
    
    FirstUnlockWelcomeModule* firstUnlock = [[FirstUnlockWelcomeModule alloc] initWithModel:model];
    ConvenienceUnlockOnboardingModule* convenienceUnlock = [[ConvenienceUnlockOnboardingModule alloc] initWithModel:model];
    ConvenienceExpiryOnboardingModule* expiry = [[ConvenienceExpiryOnboardingModule alloc] initWithModel:model];
    

    AutoFillOnboardingModule* autoFill = [[AutoFillOnboardingModule alloc] initWithModel:model];
    
    id<OnboardingModule> scheduledExportOnboardingModule = [self getScheduledExportOnboardingModule:model];
    id<OnboardingModule> scheduledExportModule = [self getScheduledExportModule:model];
    id<OnboardingModule> quickLaunchAppLockWarning = [self getQuickLaunchAppLockWarningModule:model];

#ifndef NO_NETWORKING
    id<OnboardingModule> notifications = [self getRequestNotificationPermissionModule:model];
    id<OnboardingModule> oneDrivePro = [self getWarnBusinessOneDriveNoneProModule:model];
#endif
    
    id<OnboardingModule> argon2MemReduction = [self getArgon2ReductionOnboardingModule:model];
    id<OnboardingModule> kdbxUpgrade = [self getKdbxUpgradeOnboardingModule:model];
    
    id<OnboardingModule> hardwareKeyCaching = [self getHardwareKeyCachingModule:model];
    
    id<OnboardingModule> allDoneWelcomeModule = [self getAllDoneWelcomeModule:model];
    

    NSArray<id<OnboardingModule>> *onboardingItems = @[firstUnlock,
                                                       convenienceUnlock,
#ifndef NO_NETWORKING
                                                       notifications,
                                                       oneDrivePro,
#endif
                                                       expiry,
                                                       autoFill,
                                                       scheduledExportOnboardingModule,
                                                       scheduledExportModule,
                                                       quickLaunchAppLockWarning,
                                                       argon2MemReduction,
                                                       kdbxUpgrade,
                                                       hardwareKeyCaching,
                                                       allDoneWelcomeModule];
    
    
    
    if ( model.isDuressDummyDatabase ) {
        onboardingItems = @[];
    }

    
    
    UINavigationController* nav = [[UINavigationController alloc] init];
    
    
    
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    nav.modalInPresentation = YES; 
    
    [self showNextOnboardingModule:presentingViewController model:model onboardingItems:onboardingItems index:0 stopOnboarding:NO nav:nav completion:completion];
}



- (void)showNextOnboardingModule:(VIEW_CONTROLLER_PTR)presentingViewController
                           model:(Model*)model
                 onboardingItems:(NSArray<id<OnboardingModule>>*)onboardingItems
                           index:(NSUInteger)index
                  stopOnboarding:(BOOL)stopOnboarding
                             nav:(UINavigationController*)nav
                      completion:(void (^ _Nullable)(void))completion {

    
    if ( index >= onboardingItems.count || stopOnboarding ) { 
        if ( nav.presentingViewController ) {
            [nav.presentingViewController dismissViewControllerAnimated:YES completion:^{
                if ( completion ) {
                    completion();
                }
            }];
        }
        else {
            if ( completion ) {
                completion();
            }
        }
    }
    else {
        id<OnboardingModule> module = onboardingItems[index];
        
        if ( [module shouldDisplay] ) {
            __weak OnboardingManager* weakSelf = self;
            VIEW_CONTROLLER_PTR vc = [module instantiateViewController:^(BOOL databaseModified, BOOL stopOnboarding) {
                
                [weakSelf showNextOnboardingModule:presentingViewController model:model onboardingItems:onboardingItems index:(index + 1) stopOnboarding:stopOnboarding nav:nav completion:completion];
            }];
            
            if ( vc ) {
                [nav pushViewController:vc animated:YES]; 

                if ( !nav.presentingViewController ) {
                    [presentingViewController presentViewController:nav animated:YES completion:nil];
                }
            }
            else {
                slog(@"WARNWARN: Could not instantiate view controller for onboarding module");
                [self showNextOnboardingModule:presentingViewController model:model onboardingItems:onboardingItems index:(index + 1) stopOnboarding:stopOnboarding nav:nav completion:completion];
            }
        }
        else {
            [self showNextOnboardingModule:presentingViewController model:model onboardingItems:onboardingItems index:(index + 1) stopOnboarding:stopOnboarding nav:nav completion:completion];
        }
    }
}



- (id<OnboardingModule>)getBusinessActivationModule {
    return [[BusinessActivationOnboardingModule alloc] initWithModel:nil];
}

- (id<OnboardingModule>)getFirstRunWelcomeToStrongboxModule {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:nil];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        return !AppPreferences.sharedInstance.hasShownFirstRunWelcome && !StrongboxProductBundle.isBusinessBundle;
    };

    module.image = [UIImage imageNamed:@"welcome-business"];

    module.header = NSLocalizedString(@"onboarding_welcome_to_strongbox_first_run_title", @"Welcome Aboard");

    NSString* msg = NSLocalizedString(@"onboarding_welcome_to_strongbox_first_run_message", @"Hi there, and welcome to Strongbox 😎\n\nI'm sure you're excited to get started, but first there are a few steps we should take initially, so that everything runs smoothly...");
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_lets_go", @"Let's Go");
    module.hideDismiss = YES;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        AppPreferences.sharedInstance.hasShownFirstRunWelcome = YES;
    
        onDone(NO, buttonIdCancelIsZero == 0 );
    };

    return module;
}

- (id<OnboardingModule>)getSaleNowOnModule {
    SaleNowOnOnboardingModule *module = [[SaleNowOnOnboardingModule alloc] initWithModel:nil];
    return module;    
}

- (id<OnboardingModule>)getAutoFillOnboardingModule {
    return [[AppAutoFillOnboardingModule alloc] initWithModel:nil];
}

- (id<OnboardingModule>)getFreeTrialOnboardingModule {
    return [[FreeTrialOnboardingModule alloc] initWithModel:nil];
}

- (id<OnboardingModule>)getBackupSettingsModule {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:nil];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        BOOL userHasAnyBackupFiles = [BackupsManager.sharedInstance getAvailableBackups:nil all:NO].count;
        BOOL userHasLocalDatabases = [self getLocalDeviceSafes].firstObject != nil;
        BOOL hasImportedKeyFiles = StrongboxFilesManager.sharedInstance.importedKeyFiles.firstObject != nil;
    
        return !AppPreferences.sharedInstance.haveAskedAboutBackupSettings && (userHasLocalDatabases || hasImportedKeyFiles || userHasAnyBackupFiles);
    };
    
    module.image = [UIImage imageNamed:@"backup"];

    module.header = NSLocalizedString(@"backup_settings_prompt_title", @"Backup Settings");
    module.message = NSLocalizedString(@"backup_settings_prompt_message", @"By Default Strongbox includes all local files (including database backups) and local device databases in Apple backups of this device. However imported Key Files are explicitly not included for security reasons.\n\nYou can change these settings at any time in Settings > Advanced.\n\nDoes this sound ok?");

    module.button1 = NSLocalizedString(@"backup_settings_prompt_option_yes_looks_good", @"Yes, the defaults sound good");
    module.button2 = NSLocalizedString(@"backup_settings_prompt_yes_but_include_key_files", @"Yes, but also backup imported Key Files");
    module.button3 = NSLocalizedString(@"backup_settings_prompt_no_dont_backup_anything", @"No, do NOT include anything in Apple device backups");

    module.button3Color = UIColor.systemOrangeColor;
    module.buttonWidth = @(275.0f);
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
                
        if ( buttonIdCancelIsZero == 1 ) {
            AppPreferences.sharedInstance.backupFiles = YES;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            AppPreferences.sharedInstance.backupFiles = YES;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = YES;
        }
        else if ( buttonIdCancelIsZero == 3 ) {
            AppPreferences.sharedInstance.backupFiles = NO;
            AppPreferences.sharedInstance.backupIncludeImportedKeyFiles = NO;
        }

        if ( buttonIdCancelIsZero != 0 ) {
            [StrongboxFilesManager.sharedInstance setDirectoryInclusionFromBackup:AppPreferences.sharedInstance.backupFiles
                                                       importedKeyFiles:AppPreferences.sharedInstance.backupIncludeImportedKeyFiles];

            AppPreferences.sharedInstance.haveAskedAboutBackupSettings = YES;
            
            onDone(NO, NO);
        }
        else {
            onDone(NO, YES);
        }
    };

    return module;
}

- (id<OnboardingModule>)getLastCrashReportModule {
    return [[LastCrashReportModule alloc] initWithModel:nil];
}

- (id<OnboardingModule>)getFirstRunFinalWelcomeToStrongboxModule {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:nil];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        return !AppPreferences.sharedInstance.hasShownFirstRunFinalWelcome && AppPreferences.sharedInstance.launchCount == 1;
    };

    module.image = [UIImage imageNamed:@"rocket-launch"];

    module.header = NSLocalizedString(@"generic_youre_all_set", @"You're All Set!");

    NSString* msg = NSLocalizedString(@"onboarding_welcome_to_strongbox_first_run_final_message", @"Next up, we'll take you to your regular Databases screen.\n\nFrom here, we'll help you add your first password database.\n\n❤️ The Strongbox Team ❤️");
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_lets_go", @"Let's Go");
    module.hideDismiss = YES;
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        AppPreferences.sharedInstance.hasShownFirstRunFinalWelcome = YES;
        onDone(NO, buttonIdCancelIsZero == 0 );
    };

    return module;
}

- (id<OnboardingModule>)getUpgradeToProModule {
    return [[UpgradeToProOnboardingModule alloc] initWithModel:nil];
}

- (id<OnboardingModule>)getFreeTrialEndingSoonModule {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:nil];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( AppPreferences.sharedInstance.isPro ) {
            return NO;
        }
        
        
        

        return NO;





    };

    module.image = [UIImage imageNamed:@"timer"];

    module.header = NSLocalizedString(@"upgrade_onboarding_free_trial_ending_soon_title", @"Free Trial Ending Soon");

    NSString* msg = NSLocalizedString(@"upgrade_onboarding_free_trial_ending_soon_message", @"Your free trial of Strongbox Pro will end next week, and we wouldn't want you to lose any of the cool Pro features.\n\nWould you like to support Strongbox and take a look at some of the Upgrade options?");

    module.message = msg;

    module.button1 = NSLocalizedString(@"safes_vc_upgrade_info_button_title", @"Upgrade Info");
    module.button2 = NSLocalizedString(@"generic_dont_tell_again", @"Don't Tell Me Again");

    module.button2Color = UIColor.orangeColor;
    module.imageSize = 80;
    
    module.hideDismiss = YES;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 1 ) {
            UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Upgrade" bundle:nil];
            UpgradeViewController* vc = [storyboard instantiateInitialViewController];

            vc.onDone = ^{
                onDone(NO, NO);
            };

            [viewController presentViewController:vc animated:YES completion:nil];
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            AppPreferences.sharedInstance.hasPromptedThatFreeTrialWillEndSoon = YES;
            onDone( NO, NO );
        }
        else {
            onDone( NO, NO );
        }
    };

    return module;
}

- (id<OnboardingModule>)getHasBeenDowngradedModule {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:nil];
    
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( AppPreferences.sharedInstance.isPro ) {
            return NO;
        }
        
        return AppPreferences.sharedInstance.appHasBeenDowngradedToFreeEdition && !AppPreferences.sharedInstance.hasPromptedThatAppHasBeenDowngradedToFreeEdition;
    };

    module.image = [UIImage imageNamed:@"cry-emoji"];

    module.header = NSLocalizedString(@"upgrade_mgr_downgrade_title", @"Strongbox Downgrade");

    NSString* fmt = NSLocalizedString(@"generic_biometric_unlock_fmt", @"%@ Unlock");
    NSString* bioFeature = [NSString stringWithFormat:fmt, BiometricsManager.sharedInstance.biometricIdName];

    NSString* msgFmt = NSLocalizedString(@"upgrade_mgr_downgrade_message", @"Strongbox has been downgraded from Pro.\n\nDon't worry, all your databases are still available, but some convenient features (e.g. %@) will no longer work.\n\nThis is probably because your trial or subscription has just ended.\n\nWe'd love if you could support us by upgrading to Pro.\n\nWould you like to do that now?");
    
    NSString* msg = [NSString stringWithFormat:msgFmt, bioFeature];
    
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_upgrade_ellipsis", @"Upgrade...");
    module.button2 = NSLocalizedString(@"generic_dont_tell_again", @"Don't Tell Me Again");

    module.button2Color = UIColor.orangeColor;
    module.imageSize = 80;
    
    module.hideDismiss = YES;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 1 ) {
            UIStoryboard* storyboard = [UIStoryboard storyboardWithName:@"Upgrade" bundle:nil];
            UpgradeViewController* vc = [storyboard instantiateInitialViewController];

            vc.onDone = ^{
                onDone(NO, NO);
            };

            [viewController presentViewController:vc animated:YES completion:nil];
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            AppPreferences.sharedInstance.hasPromptedThatAppHasBeenDowngradedToFreeEdition = YES;
            onDone( NO, NO );
        }
        else {
            onDone( NO, NO );
        }
    };

    return module;
}



- (id<OnboardingModule>)getScheduledExportOnboardingModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( model.metadata.scheduledExportOnboardingDone || AppPreferences.sharedInstance.disableExport ) {
            return NO;
        }
        
        BOOL createdAWeekAgo = [model.metadata.databaseCreated isMoreThanXDaysAgo:7];
        
        return createdAWeekAgo;
    };

    module.image = [UIImage imageNamed:@"delivery"];
    module.imageSize = 64;
    
    module.header = NSLocalizedString(@"onboarding_scheduled_export_title", @"Scheduled Export");
    
    NSString* msg = NSLocalizedString(@"onboarding_scheduled_export_message", @"It's always a good idea to keep backups, especially external ones. Strongbox can remind you to export your database every so often.\n\nWould you like Strongbox to prompt you to export your database if it has been a while?");
    module.message = msg;

    module.button1 = NSLocalizedString(@"onboarding_scheduled_export_onboarding_remind_2_weeks", @"Remind me after 2 weeks");
    module.button2 = NSLocalizedString(@"onboarding_scheduled_export_onboarding_remind_4_weeks", @"Remind me after 4 weeks");
    module.button3 = NSLocalizedString(@"generic_dont_remind_me", @"Don't Remind Me");

    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
            return;
        }
        else if ( buttonIdCancelIsZero == 1 ) {
            model.metadata.scheduledExportOnboardingDone = YES;
            model.metadata.scheduleExportIntervalDays = 14;
            model.metadata.scheduledExport = YES;
            model.metadata.nextScheduledExport = [NSDate.date dateByAddingTimeInterval:14 * 24 * 60 * 60];
            model.metadata.lastScheduledExportModDate = nil;
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            model.metadata.scheduledExportOnboardingDone = YES;
            model.metadata.scheduleExportIntervalDays = 28;
            model.metadata.scheduledExport = YES;
            model.metadata.nextScheduledExport = [NSDate.date dateByAddingTimeInterval:28 * 24 * 60 * 60];
            model.metadata.lastScheduledExportModDate = nil;
        }
        else if ( buttonIdCancelIsZero == 3 ) {
            model.metadata.scheduledExportOnboardingDone = YES;
            model.metadata.scheduledExport = NO;
        }
        
        onDone(NO, NO);
    };

    return module;
}

#ifndef NO_NETWORKING
- (id<OnboardingModule>)getRequestNotificationPermissionModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
            return NO;
        }
        if ( model.metadata.storageProvider != kCloudKit ) {
            return NO;
        }
        if ( AppPreferences.sharedInstance.hasGotUserNotificationsPermissions ) {
            return NO;
        }
        if ( AppPreferences.sharedInstance.lastAskToEnableNotifications != nil &&
            ![AppPreferences.sharedInstance.lastAskToEnableNotifications isMoreThanXDaysAgo:7] ) {
            return NO;
        }
        
        return [self isUserNotificationsNotDetermined];
    };
    
    if (@available(iOS 17.0, *)) {
        module.symbolEffect = [[[[NSSymbolVariableColorEffect effect] effectWithIterative] effectWithDimInactiveLayers] effectWithNonReversing];
    }

    module.image = [UIImage systemImageNamed:@"iphone.radiowaves.left.and.right"];
    
    module.imageSize = 120;
    
    module.header = NSLocalizedString(@"enable_notifications_onboarding_title", @"Stay In Sync");
    
    NSString* msg = NSLocalizedString(@"enable_notifications_onboarding_message", @"To stay current and keep your databases up to date, please allow Strongbox to receive notifications.");
    module.message = msg;

    module.button1 = NSLocalizedString(@"enable_notifications_onboarding_sounds_good_allow", @"Sounds Good, Allow");
    module.button2 = NSLocalizedString(@"generic_not_right_now", @"Not Right Now");
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        AppPreferences.sharedInstance.lastAskToEnableNotifications = NSDate.date;
        
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
            return;
        }
        else if ( buttonIdCancelIsZero == 1 ) {
            [CloudKitDatabasesInteractor.shared requestUserNotificationPermissionsWithCompletionHandler:^(BOOL granted, NSError * _Nullable error) {
                if ( error ) {
                    slog(@"🔴 Error request permissions [%@]", error);

                    [Alerts error:viewController error:error];
                }
                else {
                    AppPreferences.sharedInstance.hasGotUserNotificationsPermissions = granted;
                    onDone(NO, NO);
                }
            }];
        }
        else {
            onDone(NO, NO);
        }
    };

    return module;
}
#endif

- (BOOL)isUserNotificationsNotDetermined {
    __block BOOL ret = NO;
    
    dispatch_group_t g = dispatch_group_create();
    dispatch_group_enter(g);
    
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        ret = settings.authorizationStatus == UNAuthorizationStatusNotDetermined;
        dispatch_group_leave(g);
    }];
    
    dispatch_group_wait(g, DISPATCH_TIME_FOREVER);
    
    return ret;
}


- (id<OnboardingModule>)getScheduledExportModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    
    NSDate* modDate = nil;
    [WorkingCopyManager.sharedInstance getLocalWorkingCache:model.metadata.uuid modified:&modDate];

    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        BOOL modified = modDate ? ![modDate isEqualToDateWithinEpsilon:model.metadata.lastScheduledExportModDate] : YES;
        BOOL due = [model.metadata.nextScheduledExport isEarlierThan:NSDate.date];
        
        return model.metadata.scheduledExport && modified && due && !AppPreferences.sharedInstance.disableExport;
    };
    
    module.image = [UIImage imageNamed:@"delivery"];
    module.imageSize = 64;
    
    module.header = NSLocalizedString(@"onboarding_scheduled_export_title", @"Scheduled Export");
    
    NSString* msg = NSLocalizedString(@"scheduled_export_message", @"It's time again to export a backup copy of your database somewhere safe.\n\nWould you like do that now?");
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_lets_go", @"Let's Go");
    module.button2 = NSLocalizedString(@"generic_postpone", @"Postpone");
    module.button3 = NSLocalizedString(@"generic_dont_remind_me", @"Don't Remind Me");
    module.button3Color = UIColor.systemOrangeColor;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
        }
        else if ( buttonIdCancelIsZero == 1 ) { 
            [self onShare:(GenericOnboardingViewController*)viewController database:model.metadata onDone:onDone];
            
            NSUInteger days = model.metadata.scheduleExportIntervalDays;
            model.metadata.nextScheduledExport = [NSDate.date dateByAddingTimeInterval:days * 24 * 60 * 60];
            model.metadata.lastScheduledExportModDate = modDate;
        }
        else if ( buttonIdCancelIsZero == 2) { 
            NSUInteger days = model.metadata.scheduleExportIntervalDays;
            model.metadata.nextScheduledExport = [model.metadata.nextScheduledExport dateByAddingTimeInterval:days * 24 * 60 * 60];
            
            onDone(NO, NO);
        }
        else if ( buttonIdCancelIsZero == 3 ) {
            model.metadata.scheduledExport = NO;
            onDone(NO, NO);
        }
    };

    return module;
}

- (id<OnboardingModule>)getQuickLaunchAppLockWarningModule:(Model*)model {
    GenericOnboardingModule* quickLaunchAppLockWarning = [[GenericOnboardingModule alloc] initWithModel:model];
    quickLaunchAppLockWarning.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if (model.metadata.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue) {
            return NO;
        }
        
        BOOL isQuickLaunch = [AppPreferences.sharedInstance.quickLaunchUuid isEqualToString:model.metadata.uuid];
        BOOL isAppLockBioOn = AppPreferences.sharedInstance.appLockMode == kBiometric;
        BOOL passcodeFallbackOn = AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio;
        BOOL isCoalesced = AppPreferences.sharedInstance.coalesceAppLockAndQuickLaunchBiometrics;

        if (!(isQuickLaunch && isAppLockBioOn && passcodeFallbackOn && isCoalesced)) {
            return NO;
        }
        
        BOOL convenienceUnlockIsPossible = model.metadata.conveniencePasswordHasBeenStored && AppPreferences.sharedInstance.isPro && model.metadata.isTouchIdEnabled && BiometricsManager.isBiometricIdAvailable;
        BOOL isDbBioOnlyUnlockOn = convenienceUnlockIsPossible && model.metadata.conveniencePin == nil; 

        return isDbBioOnlyUnlockOn;
    };
    
    quickLaunchAppLockWarning.button1 = NSLocalizedString(@"alerts_ok", @"OK");
    quickLaunchAppLockWarning.button2 = NSLocalizedString(@"generic_dont_tell_again", @"Don't Tell me Again");
    quickLaunchAppLockWarning.header = NSLocalizedString(@"onboarding_configuration_issue_title", @"Configuration Issue");
    
    NSString *fmt = NSLocalizedString(@"app_lock_coalescing_with_quick_launch_warning", @"There is a configuration issue you should be aware of. You are using %@ for both App Lock and Quick Launch. In addition you allow device passcode fallback for App Lock.\n\nThis leads to a situation where you can unlock your database using only your device passcode.\n\nIf you do not want this you can do any of the following: Disable App Lock passcode fallback, or Quick Launch, or %@ Database Unlock, or coalescing of unlocks.");

    NSString* msg = [NSString stringWithFormat:fmt, BiometricsManager.sharedInstance.biometricIdName, BiometricsManager.sharedInstance.biometricIdName, BiometricsManager.sharedInstance.biometricIdName];
    quickLaunchAppLockWarning.message = msg;
    quickLaunchAppLockWarning.image = [UIImage imageNamed:@"info-bubble"];
    quickLaunchAppLockWarning.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
        }
        else if ( buttonIdCancelIsZero == 1 ) { 
            onDone(NO, NO);
        }
        else if ( buttonIdCancelIsZero == 2 ) { 
            model.metadata.hasAcknowledgedAppLockBiometricQuickLaunchCoalesceIssue = YES;
            onDone(NO, NO);
        }
    };

    return quickLaunchAppLockWarning;
}

#ifndef NO_NETWORKING
- (id<OnboardingModule>)getWarnBusinessOneDriveNoneProModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( AppPreferences.sharedInstance.isPro ) { 
            return NO;
        }
        
        if ( model.metadata.storageProvider != kOneDrive ) {
            return NO;
        }
        
        if (! [OneDriveStorageProvider.sharedInstance isBusinessDriveWithMetadata:model.metadata] ) {
            return NO;
        }
        
        BOOL showRandomly = arc4random_uniform(100) < 5;
        
        return model.metadata.unlockCount < 2 || showRandomly || [model.metadata.databaseCreated isMoreThanXDaysAgo:90]; 
    };
    
    
    module.header = NSLocalizedString(@"unlicensed_commercial_use_title", @"Unlicensed Commercial Use");
    NSString* msg = NSLocalizedString(@"unlicensed_commercial_use_message", @"Well, this is awkward. It looks like you're using Strongbox for commercial purposes without a license.\n\nWe're a small business and we need to ask you to license Strongbox. This is so that we can keep making it great and get out of your way. Continued unlicensed use may lead to loss of functionality.\n\nGet in touch\nbusiness@phoebecode.com");
    
    module.message = msg;

    if (@available(iOS 17.0, *)) {
        module.symbolEffect = [[NSSymbolPulseEffect effect] effectWithByLayer];
    }
    
    UIImage* image = [UIImage systemImageNamed:@"briefcase.circle"];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPaletteColors:@[UIColor.systemBlueColor, UIColor.systemRedColor]];
    UIImage* coloured = [image imageByApplyingSymbolConfiguration:config];
    
    module.image = coloured;

    module.button1 = NSLocalizedString(@"generic_lets_go", @"Let's Go");
    
    module.hideDismiss = YES;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        model.metadata.onboardingDoneHasBeenShown = YES;
        onDone(NO, YES); 
    };

    return module;
}
#endif

- (id<OnboardingModule>)getAllDoneWelcomeModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        return !model.metadata.onboardingDoneHasBeenShown;
    };
    
    module.button1 = NSLocalizedString(@"generic_lets_go", @"Let's Go");
    module.header = NSLocalizedString(@"onboarding_ready_to_launch_title", @"Ready to Launch");
    NSString* msg = NSLocalizedString(@"onboarding_ready_to_launch_message", @"You're all set to get the best out of Strongbox.\n\nDon't forget you can always tweak these settings at any time.");
    
    module.message = msg;
    module.image = [UIImage imageNamed:@"rocket-launch"];
    module.hideDismiss = YES;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        model.metadata.onboardingDoneHasBeenShown = YES;
        onDone(NO, YES); 
    };

    return module;
}

- (id<OnboardingModule>)getHardwareKeyCachingModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        return !model.metadata.hasOnboardedHardwareKeyCaching &&
        model.originalFormat == kKeePass4 &&
        model.ckfs.yubiKeyCR != nil &&
        model.metadata.nextGenPrimaryYubiKeyConfig &&
        model.metadata.nextGenPrimaryYubiKeyConfig.mode != kVirtual &&
        AppPreferences.sharedInstance.hardwareKeyCachingBeta &&
        !model.metadata.hardwareKeyCRCaching;
    };
    
    module.header = NSLocalizedString(@"feature_hardware_key_caching", @"Hardware Key Caching");
    NSString* msg = NSLocalizedString(@"hardware_key_caching_onboarding_msg", @"Using a hardware key is a great security choice but it can be a little inconvenient.\n\nWould you like to enable our caching feature?\n\nWith this enabled Strongbox will do things like remember the last challenge response for a period of time. This means you don't need to use your key so often.\n\nFull configuration is available in settings. For more details see online.");
    
    module.message = msg;
    module.image = [UIImage imageNamed:@"yubikey"];
    module.imageSize = 70;
    module.hideDismiss = YES;
    
    module.button1 = NSLocalizedString(@"backup_settings_prompt_option_yes_looks_good", @"Yes, Sounds Great!");
    module.button2 = NSLocalizedString(@"generic_no_thanks", @"No Thanks");
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        if ( buttonIdCancelIsZero == 1 ){ 
            model.metadata.hardwareKeyCRCaching = YES;
            model.metadata.challengeRefreshIntervalSecs = 1800; 
            model.metadata.cacheChallengeDurationSecs = 8 * 3600; 
            model.metadata.doNotRefreshChallengeInAF = YES;
            
            if ( model.ckfs.lastChallengeResponse ) {
                [model.metadata addCachedChallengeResponse:model.ckfs.lastChallengeResponse];
                model.metadata.lastChallengeRefreshAt = NSDate.now;
            }
        }
        else {
            model.metadata.hardwareKeyCRCaching = NO;
        }
        
        model.metadata.hasOnboardedHardwareKeyCaching = YES;
        onDone(NO, NO); 
    };

    return module;
}

- (id<OnboardingModule>)getArgon2ReductionOnboardingModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( model.metadata.argon2MemReductionDontAskAgain ||
            !model.metadata.autoFillEnabled ||
            model.metadata.unlockCount < 2 ||
            model.isReadOnly ) {
            return NO;
        }
        
        EncryptionSettingsViewModel* enc = [EncryptionSettingsViewModel fromDatabaseModel:model.database];
        if ( !enc.shouldReduceArgon2Memory ) {
            return NO;
        }

        if ( model.metadata.lastAskedAboutArgon2MemReduction != nil ) {
            if ( ![model.metadata.lastAskedAboutArgon2MemReduction isMoreThanXDaysAgo:1] ) {
                slog(@"Not asking about Argon2 as last asked less than 1 day ago.");
                return NO;
            }
        }

        return YES;
    };

    module.image = [UIImage systemImageNamed:@"function"];
    module.imageSize = 64;
    
    module.header = NSLocalizedString(@"autofill_argon2_onboarding_issue_title", @"AutoFill Issue");
    
    NSString* msg = NSLocalizedString(@"autofill_argon2_onboarding_issue_message", @"Your database has a very high Argon2 memory setting that will cause it to crash when used in AutoFill mode.\n\nWould you like Strongbox to automatically adjust this so that you can safely use AutoFill?");
    
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_yes_great_idea_bang", @"Yes, Great Idea!");
    module.button2 = NSLocalizedString(@"autofill_argon2_onboarding_no_use_autofill", @"No, I don't use AutoFill");
    module.button3 = NSLocalizedString(@"generic_dont_ask_again", @"Dont't Ask Again");
                                       
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        model.metadata.lastAskedAboutArgon2MemReduction = NSDate.date;
        
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
            return;
        }
        else if ( buttonIdCancelIsZero == 1 ) {
            if ( model.onboardingDatabaseChangeRequests == nil) {
                model.onboardingDatabaseChangeRequests = [[OnboardingDatabaseChangeRequests alloc] init];
            }
            model.onboardingDatabaseChangeRequests.reduceArgon2MemoryOnLoad = YES;
        }
        else if ( buttonIdCancelIsZero == 2 ) {
            model.metadata.autoFillEnabled = NO;
        }
        else if ( buttonIdCancelIsZero == 3 ) {
            model.metadata.argon2MemReductionDontAskAgain = YES;
        }

        onDone(NO, NO);
    };

    return module;
}

- (id<OnboardingModule>)getKdbxUpgradeOnboardingModule:(Model*)model {
    GenericOnboardingModule* module = [[GenericOnboardingModule alloc] initWithModel:model];
    
    module.onShouldDisplay = ^BOOL(Model * _Nonnull model) {
        if ( model.metadata.kdbx4UpgradeDontAskAgain ||
            model.metadata.lazySyncMode ||
            model.metadata.unlockCount < 10 ||
            model.isReadOnly ) {
            return NO;
        }
        
        if ( model.database.originalFormat != kKeePass ) {
            return NO;
        }

        if ( model.metadata.lastAskedAboutKdbx4Upgrade != nil ) {
            if ( ![model.metadata.lastAskedAboutKdbx4Upgrade isMoreThanXDaysAgo:7] ) {
                slog(@"Not asking about KDBX4 as last asked less than 7 days ago.");
                return NO;
            }
        }
        
        return YES;
    };

    module.image = [UIImage systemImageNamed:@"wand.and.stars"];
    module.imageSize = 64;
    
    module.header = NSLocalizedString(@"kdbx4_upgrade_onboarding_issue_title", @"Database Upgrade");
    
    NSString* msg = NSLocalizedString(@"kdbx4_upgrade_onboarding_issue_message", @"Your database is using an old format (KDBX 3.1). The new format (KDBX 4.x) offers security improvements, performance enhancements and should also reduce the size of your database.\n\nWould you like Strongbox to automatically upgrade your database now?");
        
    module.message = msg;

    module.button1 = NSLocalizedString(@"generic_yes_great_idea_bang", @"Yes, Great Idea!");
    
    module.button2 = NSLocalizedString(@"generic_not_right_now", @"Not Right Now");
    module.button2Color = UIColor.systemGrayColor;
    
    module.button3 = NSLocalizedString(@"generic_dont_ask_again", @"Dont't Ask Again");
    module.button3Color = UIColor.systemGrayColor;
    
    module.onButtonClicked = ^(NSInteger buttonIdCancelIsZero, UIViewController * _Nonnull viewController, OnboardingModuleDoneBlock  _Nonnull onDone) {
        model.metadata.lastAskedAboutKdbx4Upgrade = NSDate.date;
        
        if ( buttonIdCancelIsZero == 0 ) {
            onDone(NO, YES); 
            return;
        }
        else if ( buttonIdCancelIsZero == 1 ) {
            if ( model.onboardingDatabaseChangeRequests == nil) {
                model.onboardingDatabaseChangeRequests = [[OnboardingDatabaseChangeRequests alloc] init];
            }
            model.onboardingDatabaseChangeRequests.updateDatabaseToV4OnLoad = YES;
        }
        else if ( buttonIdCancelIsZero == 2 ) {         }
        else if ( buttonIdCancelIsZero == 3 ) {
            model.metadata.kdbx4UpgradeDontAskAgain = YES;
        }

        onDone(NO, NO);
    };

    return module;
}

- (NSArray<DatabasePreferences*>*)getLocalDeviceSafes {
    return [DatabasePreferences forAllDatabasesOfProvider:kLocalDevice];
}

- (BOOL)hasSafesOtherThanLocalAndiCloud {
    return DatabasePreferences.allDatabases.count - ([self getICloudSafes].count + [self getLocalDeviceSafes].count) > 0;
}

- (NSArray<DatabasePreferences*>*)getICloudSafes {
    return [DatabasePreferences forAllDatabasesOfProvider:kiCloud];
}

- (void)onShare:(GenericOnboardingViewController*)viewController
       database:(DatabasePreferences*)database
         onDone:(OnboardingModuleDoneBlock)onDone {
    NSError* error;
    NSURL* url = [ExportHelper getExportFile:database error:&error];
    if ( !url || error ) {
        [Alerts error:viewController error:error];
        return;
    }

    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    
    
    activityViewController.popoverPresentationController.sourceView = viewController.labelButton1;
    activityViewController.popoverPresentationController.sourceRect = viewController.labelButton1.bounds;
    activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    
    [activityViewController setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        [ExportHelper cleanupExportFiles:url];

        onDone(NO, NO);
    }];
    
    [viewController presentViewController:activityViewController animated:YES completion:nil];
}

@end
