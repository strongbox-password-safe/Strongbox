//
//  PrivacyViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 14/05/2019.
//  Copyright © 2014-2021 Mark McGuill. All rights reserved.
//

#import "AppLockViewController.h"
#import "PinEntryController.h"
#import "Alerts.h"
#import "DatabasePreferences.h"
#import "AutoFillManager.h"
#import "StrongboxiOSFilesManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "BiometricsManager.h"
#import "AppPreferences.h"
#import "Utils.h"

@interface AppLockViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonUnlock;
@property (weak, nonatomic) IBOutlet UILabel *labelUnlockAttemptsRemaining;
@property (weak, nonatomic) IBOutlet UIImageView *imageViewLogo;
@property BOOL firstAppearance;
@end

@implementation AppLockViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupImageView];
    
    [self updateFailedUnlockAttemptsUI];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(appWillEnterForeground)
                                               name:UIApplicationWillEnterForegroundNotification
                                             object:nil];
    
    self.firstAppearance = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ( self.firstAppearance ) {
        self.firstAppearance = NO;
        [self attemptBeginUnlockSequence:0];
    }
}

- (void)appWillEnterForeground { 
    slog(@"AppLockViewController::appWillEnterForeground");

    [self attemptBeginUnlockSequence:0];
}

- (void)attemptBeginUnlockSequence:(int)attemptCount {
    slog(@"AppLockViewController::attemptBeginUnlockSequence: %ld", attemptCount);
    
    if ( Utils.isAppInForeground ) {
        [self beginUnlockSequence]; 
    }
    else if ( attemptCount < 3 ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self attemptBeginUnlockSequence:attemptCount + 1];
        });
    }
}

- (void)setupImageView {
    self.imageViewLogo.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapGesture1 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onUnlock:)];
    tapGesture1.numberOfTapsRequired = 1;
    [self.imageViewLogo addGestureRecognizer:tapGesture1];
}

- (IBAction)onUnlock:(id)sender {
    [self beginUnlockSequence];
}

- (void)beginUnlockSequence {
    slog(@"beginUnlockSequence....");
    
    if(AppPreferences.sharedInstance.appLockMode == kBiometric || AppPreferences.sharedInstance.appLockMode == kBoth) {
        if(BiometricsManager.isBiometricIdAvailable) {
            [self requestBiometric];
        }
        else {
            [Alerts info:self
                   title:NSLocalizedString(@"privacy_vc_prompt_biometrics_unavailable_title", @"Biometrics Unavailable")
                 message:NSLocalizedString(@"privacy_vc_prompt_biometrics_unavailable_message", @"This application requires a biometric unlock but biometrics is unavailable on this device. You must re-enable biometrics to continue unlocking this application.")];
        }
    }
    else if (AppPreferences.sharedInstance.appLockMode == kPinCode || AppPreferences.sharedInstance.appLockMode == kBoth) {
        [self requestPin:NO];
    }
    else {
        AppPreferences.sharedInstance.failedUnlockAttempts = 0;
        [self onDone:NO];
    }
}

- (void)requestBiometric {
    [BiometricsManager.sharedInstance requestBiometricId:NSLocalizedString(@"privacy_vc_prompt_identify_to_open", @"Identify to Open Strongbox")
                                           fallbackTitle:AppPreferences.sharedInstance.appLockAllowDevicePasscodeFallbackForBio ? nil : @""
                                              completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (AppPreferences.sharedInstance.appLockMode == kPinCode || AppPreferences.sharedInstance.appLockMode == kBoth) {
                    [self requestPin:YES];
                }
                else {
                    AppPreferences.sharedInstance.failedUnlockAttempts = 0;
                    [self onDone:YES];
                }
            });
        }
        else {
            if (error.code == LAErrorUserCancel) {
                slog(@"User Cancelled - Not Incrementing Fail Count...");
            }
            else  if ( error.code == LAErrorUserFallback ) {
                slog(@"LAErrorUserFallback");
            }
            else {
                slog(@"Biometric Fail: [%@]", error);

            }
        }}];
}

- (void)updateFailedUnlockAttemptsUI {
    NSUInteger failed = AppPreferences.sharedInstance.failedUnlockAttempts;
    
    if (failed > 0 ) {
        if(AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount > 0) {
            NSInteger remaining = AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount - failed;
            
            if(remaining > 0) {
                self.labelUnlockAttemptsRemaining.text = [NSString stringWithFormat:NSLocalizedString(@"privacy_vc_label_unlock_attempts_fmt", @"Unlock Attempts Remaining: %ld"), (long)remaining];
            }
            else {
                self.labelUnlockAttemptsRemaining.text = NSLocalizedString(@"privacy_vc_label_unlock_attempts_exceeded", @"Unlock Attempts Exceeded");
            }
            
            self.labelUnlockAttemptsRemaining.hidden = NO;
            self.labelUnlockAttemptsRemaining.textColor = UIColor.systemRedColor;
        }
        else {
            self.labelUnlockAttemptsRemaining.text = [NSString stringWithFormat:NSLocalizedString(@"privacy_vc_label_number_of_failed_unlock_attempts_fmt", @"%@ Failed Unlock Attempts"), @(failed)];
            self.labelUnlockAttemptsRemaining.hidden = NO;
            self.labelUnlockAttemptsRemaining.textColor = UIColor.systemOrangeColor;
        }
    }
    else {
        self.labelUnlockAttemptsRemaining.hidden = YES;
    }
}

- (void)requestPin:(BOOL)afterSuccessfulBiometricAuthentication {
    PinEntryController* pinEntryVc = PinEntryController.newControllerForAppLock;

    pinEntryVc.pinLength = AppPreferences.sharedInstance.appLockPin.length;
    
    if(AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount > 0 && AppPreferences.sharedInstance.failedUnlockAttempts > 0) {
        NSInteger remaining = AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount - AppPreferences.sharedInstance.failedUnlockAttempts;
        
        if(remaining > 0) {
            pinEntryVc.warning = [NSString stringWithFormat:NSLocalizedString(@"privacy_vc_prompt_pin_attempts_remaining_fmt", @"%ld Attempts Remaining"), (long)remaining];
        }
    }
    
    pinEntryVc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if( response == kPinEntryResponseOk ) {
            if([pin isEqualToString:AppPreferences.sharedInstance.appLockPin]) {
                AppPreferences.sharedInstance.failedUnlockAttempts = 0;
                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
                [self onDone:afterSuccessfulBiometricAuthentication];
            }
            else {
                [self incrementFailedUnlockCount];

                UINotificationFeedbackGenerator* gen = [[UINotificationFeedbackGenerator alloc] init];
                [gen notificationOccurred:UINotificationFeedbackTypeError];
            }
        }
    };

    [self presentViewController:pinEntryVc animated:YES completion:nil];
}

- (void)incrementFailedUnlockCount {
    dispatch_async(dispatch_get_main_queue(), ^{
        AppPreferences.sharedInstance.failedUnlockAttempts = AppPreferences.sharedInstance.failedUnlockAttempts + 1;
        slog(@"Failed Unlocks: %lu", (unsigned long)AppPreferences.sharedInstance.failedUnlockAttempts);
        [self updateFailedUnlockAttemptsUI];

        if(AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount > 0) {
            if(AppPreferences.sharedInstance.failedUnlockAttempts >= AppPreferences.sharedInstance.deleteDataAfterFailedUnlockCount) {
                [self deleteAllData];
            }
        }
    });
}

- (void)deleteAllData {
    [AutoFillManager.sharedInstance clearAutoFillQuickTypeDatabase];
    
    [StrongboxFilesManager.sharedInstance deleteAllLocalAndAppGroupFiles]; 

    [DatabasePreferences nukeAllDeleteUnderlyingIfPossible]; 
}

- (void)onDone:(BOOL)userJustCompletedBiometricAuthentication {
    if ( self.onUnlockDone ) {
        self.onUnlockDone (userJustCompletedBiometricAuthentication);
    }
}

@end
