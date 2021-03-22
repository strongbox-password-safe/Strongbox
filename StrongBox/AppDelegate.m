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
#import "AppPreferences.h"
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
#import "AppLockViewController.h"

@interface AppDelegate ()

@property NSDate* appLaunchTime;
@property AppLockViewController* lockScreenVc;
@property UIImageView* privacyScreen;
@property BOOL appIsLocked;

@property (nonatomic, strong) NSDate *enterBackgroundTime;

@property BOOL hasDoneInitialActivation;
@property BOOL appLockSuppressedForBiometricAuth;

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
        [AppPreferences.sharedInstance setPro:YES];
    }
}

- (void)cleanupWorkingDirectories:(NSDictionary *)launchOptions {
    if(!launchOptions || launchOptions[UIApplicationLaunchOptionsURLKey] == nil) {
        
        
        
        [FileManager.sharedInstance deleteAllInboxItems];
         
        [FileManager.sharedInstance deleteAllTmpAttachmentPreviewFiles];
        [FileManager.sharedInstance deleteAllTmpWorkingFiles];
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

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if( self.appLockSuppressedForBiometricAuth ) {
        NSLog(@"App Active but Lock Screen Suppressed... Nothing to do");
        self.appLockSuppressedForBiometricAuth = NO;
        return;
    }

    NSLog(@"XXXXXXXXXX - applicationDidBecomeActive- %@]", self.window.rootViewController);

    [OfflineDetector.sharedInstance startMonitoringConnectivitity]; 
    
    [self performedScheduledEntitlementsCheck];
        
    

    BOOL startupAppLock = !self.hasDoneInitialActivation && Settings.sharedInstance.appLockMode != kNoLock;

    if ( [self shouldRequireAppLockTime] || startupAppLock) {
        [self showLockScreen];
    }
    else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self hidePrivacyShield]; 
        });
    }

    self.hasDoneInitialActivation = YES;
    self.enterBackgroundTime = nil;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    self.appLockSuppressedForBiometricAuth = NO;
    if( AppPreferences.sharedInstance.suppressAppBackgroundTriggers ) {
        NSLog(@"appResignActive... suppressAppBackgroundTriggers");
        self.appLockSuppressedForBiometricAuth = YES;
        return;
    }

    NSLog(@"XXXXXXXXXX - applicationWillResignActive");
    
    [self showPrivacyShieldView];
    
    self.enterBackgroundTime = NSDate.date;
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



- (void)showPrivacyShieldView {
    NSLog(@"showPrivacyShieldView - [%@]", self.privacyScreen);

    if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeNone ) {
        return;
    }
    
    if ( !self.privacyScreen ) {
        UIImage* cover = nil;
        if (@available(iOS 13.0, *)) {
            if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModeBlur ) {
                UIImage* screenshot = [self screenShot];
                cover = [self blur:screenshot];
            }
            else if ( AppPreferences.sharedInstance.appPrivacyShieldMode == kAppPrivacyShieldModePixellate ) {
                UIImage* screenshot = [self screenShot];
                cover = [self pixellate:screenshot];
            }
        }

        self.privacyScreen = [[UIImageView alloc] init];
        self.privacyScreen.frame = self.window.frame;
        self.privacyScreen.contentMode = UIViewContentModeScaleToFill;
        self.privacyScreen.backgroundColor = UIColor.systemBlueColor;
        [self.window addSubview:self.privacyScreen];

        if (@available(iOS 13.0, *)) {
            if ( cover ) {
                self.privacyScreen.image = cover;
            }
        }
    }
    else {
        NSLog(@"Privacy Screen Already in Place... NOP");
    }
}

- (void)hidePrivacyShield {
    NSLog(@"hidePrivacyShield - [%@]", self.privacyScreen);

    if ( self.privacyScreen ) {





        




        [self.privacyScreen removeFromSuperview];
        self.privacyScreen = nil;
    }
    else {
        NSLog(@"Privacy Screen not around to hide... NOP");
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

- (UIImage*)pixellate:(UIImage*)image API_AVAILABLE(ios(13.0)) {
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

- (UIImage*)blur:(UIImage*)image API_AVAILABLE(ios(13.0)) {
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

- (void)showLockScreen {
    if ( self.isAppLocked ) {
        NSLog(@"Lock Screen Already Up... No need to re show");
        return;
    }
    self.appIsLocked = YES;

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
            NSLog(@"App Lock Screen was already dismissed by Database Auto Lock... Continuing dismissal [%@]", self.lockScreenVc.presentingViewController);
            [self onLockScreenDismissed:NO];
        }
    }];
}

- (void)onLockScreenDismissed:(BOOL)userJustCompletedBiometricAuthentication {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hidePrivacyShield]; 
    });

    SafesViewController* databasesListVc = [self getInitialViewController];
    [databasesListVc onAppLockScreenWasDismissed:userJustCompletedBiometricAuthentication];
    self.lockScreenVc = nil;
}

- (BOOL)shouldRequireAppLockTime {
    if ( Settings.sharedInstance.appLockMode == kNoLock ) {
        return NO;
    }
    
    NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:self.enterBackgroundTime];
    NSInteger seconds = Settings.sharedInstance.appLockDelay;
    
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
