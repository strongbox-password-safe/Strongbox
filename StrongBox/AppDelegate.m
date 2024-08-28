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



#import "Strongbox-Swift.h"

@interface AppDelegate ()

@property AppLockViewController* lockScreenVc;
@property UIView* privacyScreen;
@property NSInteger privacyScreenPresentationIdentifier; 

@property (nonatomic, strong) NSDate *appLockEnteredBackgroundAtTime;

@property BOOL appIsLocked;
@property BOOL appLockHasDoneInitialActivation;
@property BOOL ignoreNextAppActiveDueToBiometrics;

@end

static NSString * const kSecureEnclavePreHeatKey = @"com.markmcguill.strongbox.preheat-secure-enclave";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG
    
    [[NSUserDefaults standardUserDefaults] setValue:@(NO) forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];

    slog(@"🚀 Documents Directory: [%@]", StrongboxFilesManager.sharedInstance.documentsDirectory);
    slog(@"🚀 Shared App Group Directory: [%@]", StrongboxFilesManager.sharedInstance.sharedAppGroupDirectory);
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
        
#ifndef NO_NETWORKING
    [self initializeCloudKit];
#endif
    
    AppAppearance appearance = AppPreferences.sharedInstance.appAppearance;
    if ( appearance != kAppAppearanceSystem ) {
        self.window.overrideUserInterfaceStyle = appearance == kAppAppearanceLight ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
    }
    
    return YES;
}

- (void)application:(UIApplication *)application userDidAcceptCloudKitShareWithMetadata:(CKShareMetadata *)cloudKitShareMetadata {
#ifndef NO_NETWORKING
    slog(@"userDidAcceptCloudKitShareWithMetadata: [%@]", cloudKitShareMetadata);
 
    [CloudKitDatabasesInteractor.shared acceptShareWithMetadata:cloudKitShareMetadata
                                              completionHandler:^(NSError * _Nullable error) {
        slog(@"acceptShareWithMetadata done with [%@]", error);
    }];
#endif
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



#ifndef NO_NETWORKING
- (void)initializeCloudKit {
    [CloudKitDatabasesInteractor.shared initializeWithCompletionHandler:^(NSError * _Nullable error ) {
        if ( error ) {
            slog(@"🔴 Error initializing CloudKit: [%@]", error); 
        }
        else {
            slog(@"🟢 CloudKit successfully initialized.");
        }
    }];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    slog(@"🟢 didRegisterForRemoteNotificationsWithDeviceToken [%@]", deviceToken.base64String);
    
    [CloudKitDatabasesInteractor.shared onRegisteredForRemoteNotifications:YES error:nil];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    slog(@"🔴 didFailToRegisterForRemoteNotificationsWithError - [%@]", error);
    
    [CloudKitDatabasesInteractor.shared onRegisteredForRemoteNotifications:NO error:error];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo 
fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler {
    [CloudKitDatabasesInteractor.shared onCloudKitDatabaseChangeNotification];
    
    completionHandler(UIBackgroundFetchResultNoData);
}
#endif



- (void)cleanupWorkingDirectories:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        
        
        
        [StrongboxFilesManager.sharedInstance deleteAllInboxItems];
        [StrongboxFilesManager.sharedInstance deleteAllTmpWorkingFiles];
    }
}

- (void)initializeInstallSettingsAndLaunchCount {
    UIApplication.sharedApplication.applicationIconBadgeNumber = 0;
    
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
    slog(@"openURL: [%@] => [%@] - Source App: [%@]", options, url, options[UIApplicationOpenURLOptionsSourceApplicationKey]);
    
    if ([url.scheme isEqualToString:@"strongbox"]) {


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

#ifndef NO_NETWORKING
- (void)startOrStopWiFiSyncServer {
    NSError* error;
    if (! [WiFiSyncServer.shared startOrStopWiFiSyncServerAccordingToSettingsAndReturnError:&error] ) {
        slog(@"🔴 Could not start WiFi Sync Server: [%@]", error);
    }
}

- (void)stopWiFiSyncServer {
    [WiFiSyncServer.shared stopWith:nil]; 
}
#endif

- (void)performedScheduledEntitlementsCheck {
    NSTimeInterval timeDifference = [NSDate.date timeIntervalSinceDate:self.appLaunchTime];
    double minutes = timeDifference / 60;

    if( minutes > 30 ) {
        if ( StrongboxProductBundle.isBusinessBundle ) {
            [BusinessActivation regularEntitlementCheckWithCompletionHandler:^(NSError * _Nullable error) { }];
        }
        else {
            [ProUpgradeIAPManager.sharedInstance performScheduledProEntitlementsCheckIfAppropriate];
        }
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
    slog(@"showPrivacyShieldView - [%@]", self.privacyScreen);
    
    if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeNone ) {
        return;
    }
    
    if ( self.privacyScreen ) {
        slog(@"Privacy Screen Already in Place... NOP");
        self.privacyScreenPresentationIdentifier++;
        return;
    }
    
    if ( self.lockScreenVc != nil ) {
        slog(@"Lock Screen is up, privacy screen inappropriate, likely initial launch and switch back...");
        return;
    }

    self.privacyScreen = [self createPrivacyScreenView];
    self.privacyScreenPresentationIdentifier++;
    
    [self.window addSubview:self.privacyScreen];
}

- (UIView*)createPrivacyScreenView {
    UIImageView* tmp = [[UIImageView alloc] init];
    tmp.frame = self.window.frame;
    UIImage* cover = nil;
    
    if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeBlur ) {
        UIImage* screenshot = [self screenShot];
        cover = [self blur:screenshot];
        tmp.contentMode = UIViewContentModeScaleToFill;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModePixellate ) {
        UIImage* screenshot = [self screenShot];
        cover = [self pixellate:screenshot];
        tmp.contentMode = UIViewContentModeScaleToFill;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeBlueScreen ) {
        tmp.backgroundColor = UIColor.systemBlueColor;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeBlackScreen ) {
        tmp.backgroundColor = UIColor.blackColor;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeDarkLogo ) {
        cover = [self createPrivacyShieldLogo];

        tmp.backgroundColor = [UIColor colorWithWhite:0.075 alpha:1.0];
        tmp.contentMode = UIViewContentModeCenter;
        tmp.tintColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeRed ) {
        tmp.backgroundColor = UIColor.systemRedColor;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeGreen ) {
        tmp.backgroundColor = UIColor.systemGreenColor;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeLightLogo ) {
        cover = [self createPrivacyShieldLogo];
        
        tmp.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        tmp.contentMode = UIViewContentModeCenter;
        tmp.tintColor = UIColor.systemGrayColor;
    }
    else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeWhite ) {
        tmp.backgroundColor = UIColor.whiteColor;
    }
    else {
        slog(@"🔴 Unknown privacy shield mode!");
    }
    
    if ( cover ) {
        tmp.image = cover;
    }

    return tmp;
}

- (UIImage*)createPrivacyShieldLogo {
    UIImage* cover = [UIImage imageNamed:@"AppIcon-2019-Glyph-Shadow"];
    
    CGFloat divisor = cover.size.width / 128;
    
    CGSize newSize = CGSizeMake(cover.size.width / divisor, cover.size.height / divisor);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:newSize];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext*_Nonnull myContext) {
        [cover drawInRect:(CGRect) {.origin = CGPointZero, .size = newSize}];
    }];
    cover = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    return cover;
}

- (void)hidePrivacyShield:(NSInteger)identifier {


    if ( self.privacyScreen && identifier == self.privacyScreenPresentationIdentifier ) {
        UIView* tmp = self.privacyScreen;
        self.privacyScreen = nil;
        [tmp removeFromSuperview];
    }
    else {
        if ( identifier == self.privacyScreenPresentationIdentifier ) {

        }
        else {

        }
    }
}

- (UIImage*)screenShot {
    if ( !UIApplication.sharedApplication.keyWindow ) {
        slog(@"screenShot::keyWindow is nil");
        return [UIImage new];
    }
    if ( !UIApplication.sharedApplication.keyWindow.layer ) {
        slog(@"screenShot::keyWindow.layer is nil");
        return [UIImage new];
    }
    if ( !self.window ) {
        slog(@"screenShot::window is nil");
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
    slog(@"AppDelegate::showLockScreen");
    
    if ( self.isPresentingLockScreen ) {
        slog(@"Lock Screen Already Up... No need to re show");
        return;
    }

    __weak AppDelegate* weakSelf = self;
    AppLockViewController* appLockViewController = [[AppLockViewController alloc] initWithNibName:@"PrivacyViewController" bundle:nil];
    appLockViewController.onUnlockDone = ^(BOOL userJustCompletedBiometricAuthentication) {
        [weakSelf onLockScreenUnlocked:userJustCompletedBiometricAuthentication];
    };
    appLockViewController.modalPresentationStyle = UIModalPresentationOverFullScreen; 

    

    UIViewController* visible = [self getVisibleViewController];
    slog(@"Presenting Lock Screen on [%@]", [visible class]);
    
    if ( visible ) {
        [visible presentViewController:appLockViewController animated:NO completion:^{
            slog(@"Presented Lock Screen Successfully...");
            self.lockScreenVc = appLockViewController; 
        }];
    }
    else {
        slog(@"WARNWARN - Could not present Lock Screen [%@]", visible);
        self.appIsLocked = NO;
        self.lockScreenVc = nil;
    }
}

- (void)onLockScreenUnlocked:(BOOL)userJustCompletedBiometricAuthentication {
    slog(@"onLockScreenUnlocked: %hhd", userJustCompletedBiometricAuthentication);
    
    self.appIsLocked = NO;
    
    
    
    SafesViewController* databasesListVc = [self getInitialViewController];
    [databasesListVc onAppLockScreenWillBeDismissed:^{
        slog(@"Database List onAppLockWillBeDismissed Done! - [%@]", self.lockScreenVc.presentingViewController);
        
        if ( self.lockScreenVc.presentingViewController ) {
            [self.lockScreenVc.presentingViewController dismissViewControllerAnimated:YES completion:^{
                slog(@"Dismissing Lock Screen Done!");
                [self onLockScreenDismissed:userJustCompletedBiometricAuthentication];
            }];
        }
        else {
            slog(@"App Lock Screen is not being presented. Assumed because it was already dismissed by Database Auto Lock locking to dismiss all... Continuing dismissal process");
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
        
    NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:self.appLockEnteredBackgroundAtTime];
    NSInteger seconds = AppPreferences.sharedInstance.appLockDelay;
    
    if ( seconds == 0 || secondsBetween > seconds ) {
        slog(@"shouldRequireAppLock [YES] %ld - %f", (long)seconds, secondsBetween);
        return YES;
    }
    
    slog(@"shouldRequireAppLock [NO] %f", secondsBetween);
    
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

    slog(@"VISIBLE: [%@]", visibleSoFar);
    
    return visibleSoFar;
}



- (void)applicationWillResignActive:(UIApplication *)application {
    slog(@"AppDelegate::applicationWillResignActive");
    
    self.ignoreNextAppActiveDueToBiometrics = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        slog(@"AppDelegate::applicationWillResignActive - suppressAppBackgroundTriggers = YES");
        self.ignoreNextAppActiveDueToBiometrics = YES;
        return;
    }
  
    [self showPrivacyShieldView];
    
    self.appLockEnteredBackgroundAtTime = NSDate.date;
    
#ifndef NO_NETWORKING
    [self stopWiFiSyncServer];
#endif
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    slog(@"🐞 AppDelegate::applicationDidBecomeActive- %@]", self.window.rootViewController);
    
    if( self.ignoreNextAppActiveDueToBiometrics ) {
        slog(@"applicationDidBecomeActive ignored due to biometrics request. Ignoring...");
        self.ignoreNextAppActiveDueToBiometrics = NO;
        return;
    }
    
    BOOL startupAppLock = !self.appLockHasDoneInitialActivation && AppPreferences.sharedInstance.appLockMode != kNoLock;
    self.appLockHasDoneInitialActivation = YES;
    
    if ( startupAppLock || [self shouldRequireAppLockTime] ) {
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
    
#ifndef NO_NETWORKING
    if ( !AppPreferences.sharedInstance.disableNetworkBasedFeatures ) {
        [self startOrStopWiFiSyncServer];
    }
#endif
    
    self.appLockEnteredBackgroundAtTime = nil;
}





- (void)applicationDidEnterBackground:(UIApplication *)application {
    slog(@"AppDelegate::applicationDidEnterBackground");

    [self showPrivacyShieldView];

    if ( [self shouldRequireAppLockTime] ) {
        self.appIsLocked = YES;
        [self showLockScreen];
    }

    self.ignoreNextAppActiveDueToBiometrics = NO; 
    
    self.appLockEnteredBackgroundAtTime = NSDate.date;
    
#ifndef NO_NETWORKING
    [self stopWiFiSyncServer];
#endif
}

@end

