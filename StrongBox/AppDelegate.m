//
//  AppDelegate.m
//  StrongBox
//
//  Created by Mark McGuill on 03/06/2014.
//  Copyright (c) 2014 Mark McGuill. All rights reserved.
//

#import "AppDelegate.h"
#import "BrowseSafeView.h"
#import "PasswordHistoryViewController.h"
#import "PreviousPasswordsTableViewController.h"
#import "AppPreferences.h"
#import "SafesViewController.h"
#import "SafesViewController.h"
#import "OfflineDetector.h"
#import "real-secrets.h"
#import "NSArray+Extensions.h"
#import "ProUpgradeIAPManager.h"
#import "StrongboxiOSFilesManager.h"
#import "SyncManager.h"
#import "ClipboardManager.h"
#import "iCloudSafesCoordinator.h"
#import "SecretStore.h"
#import "Alerts.h"
#import "DatabasePreferences.h"
#import "VirtualYubiKeys.h"
#import "AppLockViewController.h"
#import "CustomizationManager.h"
#import "MemoryOnlyURLProtocol.h"
#import "Strongbox-Swift.h"

#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS

#import "DropboxV2StorageProvider.h"
#import "GoogleDriveManager.h"
#import "MSAL/MSAL.h"

#endif



@interface AppDelegate ()

@property AppLockViewController* lockScreenVc;
@property UIImageView* privacyScreen;
@property NSInteger privacyScreenPresentationIdentifier; 
@property BOOL appIsLocked;

@property (nonatomic, strong) NSDate *enterBackgroundTime;

@property BOOL hasDoneInitialActivation;
@property BOOL appLockSuppressedForBiometricAuth;

@end

static NSString * const kSecureEnclavePreHeatKey = @"com.markmcguill.strongbox.preheat-secure-enclave";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG
    
    [[NSUserDefaults standardUserDefaults] setValue:@(NO) forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
#endif
    
    [self installTopLevelExceptionHandlers];
    
    
    
    [self initializeDropbox];
    
    [self performEarlyBasicICloudInitialization];
    
    [self initializeInstallSettingsAndLaunchCount];
    
    
    
    
    
    
    

    self.appIsLocked = AppPreferences.sharedInstance.appLockMode != kNoLock;
    
    [CustomizationManager applyCustomizations]; 
    
    [self markDirectoriesForBackupInclusion];
    
    [self cleanupWorkingDirectories:launchOptions];
    
    [ClipboardManager.sharedInstance observeClipboardChangeNotifications];
    
    if ( !CustomizationManager.isAProBundle ) {
        [ProUpgradeIAPManager.sharedInstance initialize]; 
    }
        
    [SyncManager.sharedInstance startMonitoringDocumentsDirectory]; 
        
#ifdef DEBUG
    NSLog(@"🚀 Documents Directory: [%@]", StrongboxFilesManager.sharedInstance.documentsDirectory);
    NSLog(@"🚀 Shared App Group Directory: [%@]", StrongboxFilesManager.sharedInstance.sharedAppGroupDirectory);
#endif
    
    return YES;
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    SafesViewController *safesViewController = [self getInitialViewController];
    [safesViewController performActionForShortcutItem:shortcutItem];

    completionHandler(YES);
}

- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(UIApplicationExtensionPointIdentifier)extensionPointIdentifier {
    if (extensionPointIdentifier == UIApplicationKeyboardExtensionPointIdentifier) {
        return AppPreferences.sharedInstance.allowThirdPartyKeyboards;
    }

    return YES;
}

- (void)markDirectoriesForBackupInclusion {
    [StrongboxFilesManager.sharedInstance setDirectoryInclusionFromBackup:AppPreferences.sharedInstance.backupFiles
                                               importedKeyFiles:AppPreferences.sharedInstance.backupIncludeImportedKeyFiles];
}

- (void)performEarlyBasicICloudInitialization {
    
    
    
    
    
    
    
    [iCloudSafesCoordinator.sharedInstance initializeiCloudAccess];
}

- (void)cleanupWorkingDirectories:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        
        
        
        [StrongboxFilesManager.sharedInstance deleteAllInboxItems];
         
        [StrongboxFilesManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
        [StrongboxFilesManager.sharedInstance deleteAllTmpWorkingFiles];
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    [AppPreferences.sharedInstance incrementLaunchCount];
    
    if(AppPreferences.sharedInstance.installDate == nil) {
        AppPreferences.sharedInstance.installDate = [NSDate date];
        

    }
    else if ( !AppPreferences.sharedInstance.scheduledTipsCheckDone ) {
        NSTimeInterval interval = [NSDate.date timeIntervalSinceDate:AppPreferences.sharedInstance.installDate];
        if ( interval > 60 * 24 * 60 * 60 ) { 
            AppPreferences.sharedInstance.scheduledTipsCheckDone = YES;
            AppPreferences.sharedInstance.hideTips = YES;
        }
    }
    
    self.appLaunchTime = [NSDate date];
}



- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    NSLog(@"openURL: [%@] => [%@] - Source App: [%@]", options, url, options[UIApplicationOpenURLOptionsSourceApplicationKey]);
    
    if ([url.scheme isEqualToString:@"strongbox"]) {
        SafesViewController *safesViewController = [self getInitialViewController];
        [safesViewController handleUrlSchemeNavigationRequest:url];
        return YES;
    }
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    else if ([url.absoluteString hasPrefix:@"db"]) {
        return [DropboxV2StorageProvider.sharedInstance handleAuthRedirectUrl:url];
    }
    else if ([url.absoluteString hasPrefix:@"com.googleusercontent.apps"]) {
        return [GoogleDriveManager.sharedInstance handleUrl:url];
    }
    else if ([url.scheme isEqualToString:@"strongbox-twodrive"]) {
        return [MSALPublicClientApplication handleMSALResponse:url sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
    }
#endif
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

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"AppDelegate::applicationDidBecomeActive- %@]", self.window.rootViewController);

    if( self.appLockSuppressedForBiometricAuth ) {
        NSLog(@"App Active but Lock Screen Suppressed... Nothing to do");
        self.appLockSuppressedForBiometricAuth = NO;
        return;
    }

    

    BOOL startupAppLock = !self.hasDoneInitialActivation && AppPreferences.sharedInstance.appLockMode != kNoLock;

    if ( [self shouldRequireAppLockTime] || startupAppLock) {
        self.appIsLocked = YES;
        
        [self showLockScreen];
    }
    else {
        NSInteger foo = self.privacyScreenPresentationIdentifier;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self hidePrivacyShield:foo]; 
        });
    }

    [[iCloudSafesCoordinator sharedInstance] initializeiCloudAccess];
    
#ifndef NO_OFFLINE_DETECTION
    [OfflineDetector.sharedInstance startMonitoringConnectivitity]; 
#endif
    
    [self performedScheduledEntitlementsCheck];

    
    
    self.hasDoneInitialActivation = YES;
    
    self.enterBackgroundTime = nil;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    self.appLockSuppressedForBiometricAuth = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        NSLog(@"AppDelegate::applicationWillResignActive - suppressAppBackgroundTriggers = YES");
        self.appLockSuppressedForBiometricAuth = YES;
        return;
    }

    NSLog(@"AppDelegate::applicationWillResignActive");
    
    [self showPrivacyShieldView];
    
    self.enterBackgroundTime = NSDate.date;
}

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;

    if( minutes > 30 ) {
        [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate];
    }    
}

- (void)initializeDropbox {
#ifndef NO_3RD_PARTY_STORAGE_PROVIDERS
    [DropboxV2StorageProvider.sharedInstance initialize:AppPreferences.sharedInstance.useIsolatedDropbox];
#endif
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
        [json writeToURL:StrongboxFilesManager.sharedInstance.crashFile options:kNilOptions error:nil];
    }
}

- (void)installTopLevelExceptionHandlers {
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
    
    
    
    



    






}



- (void)showPrivacyShieldView {
    NSLog(@"showPrivacyShieldView - [%@]", self.privacyScreen);

    if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeNone ) {
        return;
    }

    UIImage* cover = nil;
    if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeBlur ) {
        UIImage* screenshot = [self screenShot];
        cover = [self blur:screenshot];
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModePixellate ) {
        UIImage* screenshot = [self screenShot];
        cover = [self pixellate:screenshot];
    }

    UIImageView* tmp = [[UIImageView alloc] init];
    tmp.frame = self.window.frame;
    tmp.contentMode = UIViewContentModeScaleToFill;
    tmp.backgroundColor = UIColor.systemBlueColor;
    
    if ( !self.privacyScreen ) {
        if ( self.lockScreenVc != nil ) {
            NSLog(@"Lock Screen is up, privacy screen inappropriate, likely initial launch and switch back...");
            return;
        }
        
        self.privacyScreen = tmp;
        self.privacyScreenPresentationIdentifier++;

        [self.window addSubview:self.privacyScreen];

        if ( cover ) {
            self.privacyScreen.image = cover;
        }
    }
    else {
        NSLog(@"Privacy Screen Already in Place... NOP");
        self.privacyScreenPresentationIdentifier++;
    }
}

- (void)hidePrivacyShield:(NSInteger)identifier {
    NSLog(@"hidePrivacyShield - [%ld]-[%ld]", (long)self.privacyScreenPresentationIdentifier, (long)identifier);

    if ( self.privacyScreen && identifier == self.privacyScreenPresentationIdentifier ) {
        UIView* tmp = self.privacyScreen;
        self.privacyScreen = nil;
        [tmp removeFromSuperview];
    }
    else {
        if ( identifier == self.privacyScreenPresentationIdentifier ) {
            NSLog(@"hidePrivacyShield - Privacy Screen not around to hide... NOP");
        }
        else {
            NSLog(@"hidePrivacyShield- Privacy Screen - Will Not Hide because presentation id mismatch [%ld]-[%ld]", (long)self.privacyScreenPresentationIdentifier, (long)identifier);
        }
    }
}

- (UIImage*)screenShot {
    if ( !UIApplication.sharedApplication.keyWindow ) {
        NSLog(@"screenShot::keyWindow is nil");
        return [UIImage new];
    }
    if ( !UIApplication.sharedApplication.keyWindow.layer ) {
        NSLog(@"screenShot::keyWindow.layer is nil");
        return [UIImage new];
    }
    if ( !self.window ) {
        NSLog(@"screenShot::window is nil");
        return [UIImage new];
    }
    
    CALayer *layer = UIApplication.sharedApplication.keyWindow.layer;
    UIGraphicsBeginImageContext(self.window.frame.size);
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (UIImage*)pixellate:(UIImage*)image {
    CIImage* ciImage = [[CIImage alloc] initWithImage:image];
    
    CIFilter *clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
    [clampFilter setDefaults];
    [clampFilter setValue:ciImage forKey:kCIInputImageKey];
    
    CIFilter* pixellateFilter = [CIFilter filterWithName:@"CIPixellate"];
    
    const CGFloat pixellateScale = 10.0f;
    [pixellateFilter setValue:@(pixellateScale) forKey:@"inputScale"];
    [pixellateFilter setValue:clampFilter.outputImage forKey:@"inputImage"];
    
    CIImage *pixellatedImage = pixellateFilter.outputImage;
        
    CIContext *context = [CIContext contextWithOptions:nil];

    CGImageRef cgImage = [context createCGImage:pixellatedImage fromRect:[ciImage extent]];
    UIImage *cover = [[UIImage alloc] initWithCGImage:cgImage scale:image.scale orientation:UIImageOrientationUp];

    CGImageRelease(cgImage);
    
    return cover;
}

- (UIImage*)blur:(UIImage*)image {
    CIImage* ciImage = [[CIImage alloc] initWithImage:image];
    
    CIFilter *clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
    [clampFilter setDefaults];
    [clampFilter setValue:ciImage forKey:kCIInputImageKey];
    
    const CGFloat blurRadius = 10.0f;
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setDefaults];
    [blurFilter setValue:@(blurRadius) forKey:@"inputRadius"];
    [blurFilter setValue:clampFilter.outputImage forKey:kCIInputImageKey];

    CIImage *blurredImage = blurFilter.outputImage;
    
    CIContext *context = [CIContext contextWithOptions:nil];

    CGImageRef cgImage = [context createCGImage:blurredImage fromRect:[ciImage extent]];
    UIImage *cover = [[UIImage alloc] initWithCGImage:cgImage scale:image.scale orientation:UIImageOrientationUp];

    CGImageRelease(cgImage);
    
    return cover;
}



- (BOOL)isAppLocked {
    return self.appIsLocked;
}

- (BOOL)isPresentingLockScreen {
    return self.lockScreenVc != nil; 
}

- (void)showLockScreen {
    NSLog(@"AppDelegate::showLockScreen");
    
    if ( self.isPresentingLockScreen ) {
        NSLog(@"Lock Screen Already Up... No need to re show");
        return;
    }

    __weak AppDelegate* weakSelf = self;
    AppLockViewController* appLockViewController = [[AppLockViewController alloc] initWithNibName:@"PrivacyViewController" bundle:nil];
    appLockViewController.onUnlockDone = ^(BOOL userJustCompletedBiometricAuthentication) {
        [weakSelf onLockScreenUnlocked:userJustCompletedBiometricAuthentication];
    };
    appLockViewController.modalPresentationStyle = UIModalPresentationOverFullScreen; 

    

    UIViewController* visible = [self getVisibleViewController];
    NSLog(@"Presenting Lock Screen on [%@]", [visible class]);
    
    if ( visible ) {
        [visible presentViewController:appLockViewController animated:NO completion:^{
            NSLog(@"Presented Lock Screen Successfully...");
            self.lockScreenVc = appLockViewController; 
        }];
    }
    else {
        NSLog(@"WARNWARN - Could not present Lock Screen [%@]", visible);
        self.appIsLocked = NO;
        self.lockScreenVc = nil;
    }
}

- (void)onLockScreenUnlocked:(BOOL)userJustCompletedBiometricAuthentication {
    NSLog(@"onLockScreenUnlocked: %hhd", userJustCompletedBiometricAuthentication);
    
    self.appIsLocked = NO;
    
    
    
    SafesViewController* databasesListVc = [self getInitialViewController];
    [databasesListVc onAppLockScreenWillBeDismissed:^{
        NSLog(@"Database List onAppLockWillBeDismissed Done! - [%@]", self.lockScreenVc.presentingViewController);
        
        if ( self.lockScreenVc.presentingViewController ) {
            [self.lockScreenVc.presentingViewController dismissViewControllerAnimated:YES completion:^{
                NSLog(@"Dismissing Lock Screen Done!");
                [self onLockScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        else {
            NSLog(@"App Lock Screen is not being presented. Assumed because it was already dismissed by Database Auto Lock locking to dismiss all... Continuing dismissal process");
            [self onLockScreenDismissed:userJustCompletedBiometricAuthentication];
        }
    }];
}

- (void)onLockScreenDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    NSInteger foo = self.privacyScreenPresentationIdentifier;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hidePrivacyShield:foo]; 
    });

    SafesViewController* databasesListVc = [self getInitialViewController];
    
    [databasesListVc onAppLockScreenWasDismissed:userJustCompletedBiometricAuthentication];
    
    self.lockScreenVc = nil;
}

- (BOOL)shouldRequireAppLockTime {
    if ( AppPreferences.sharedInstance.appLockMode == kNoLock ) {
        return NO;
    }
        
    NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:self.enterBackgroundTime];
    NSInteger seconds = AppPreferences.sharedInstance.appLockDelay;
    
    if ( seconds == 0 || secondsBetween > seconds ) {
        NSLog(@"shouldRequireAppLock [YES] %ld - %f", (long)seconds, secondsBetween);
        return YES;
    }
    
    NSLog(@"shouldRequireAppLock [NO] %f", secondsBetween);
    
    return NO;
}

- (UIViewController*)getVisibleViewController {
    UINavigationController* nav = (UINavigationController*)self.window.rootViewController;
    UIViewController* visibleSoFar = nav;
    int attempts = 10;
    do {
        if ([visibleSoFar isKindOfClass:UINavigationController.class]) {
            UINavigationController* nav = (UINavigationController*)visibleSoFar;
            
            

            if (nav.visibleViewController) {
                visibleSoFar = nav.visibleViewController;
            }
            else {
                break;
            }
        }
        else {
            

            if (visibleSoFar.presentedViewController) {
                visibleSoFar = visibleSoFar.presentedViewController;
            }
            else {
                break;
            }
        }
    } while (--attempts); 

    NSLog(@"VISIBLE: [%@]", visibleSoFar);
    
    return visibleSoFar;
}

@end
