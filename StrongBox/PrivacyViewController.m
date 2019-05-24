//
//  PrivacyViewController.m
//  Strongbox-iOS
//
//  Created by Mark on 14/05/2019.
//  Copyright © 2019 Mark McGuill. All rights reserved.
//

#import "PrivacyViewController.h"
#import "PinEntryController.h"
#import "Settings.h"
#import "Alerts.h"
#import "SafesList.h"
#import "LocalDeviceStorageProvider.h"

@interface PrivacyViewController ()

@property (weak, nonatomic) IBOutlet UIButton *buttonUnlock;
@property NSDate* startTime;
@property (weak, nonatomic) IBOutlet UILabel *labelUnlockAttemptsRemaining;

@end

@implementation PrivacyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.startTime = [[NSDate alloc] init];
    
    if(!self.startupLockMode) {
        self.buttonUnlock.hidden = YES; // Will be show on re-activation
    }
    else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self beginUnlockSequence]; // Face ID / TOuch ID seems to require a little delay
        });
    }
    
    [self updateUnlockAttemptsRemainingLabel];
}

- (void)updateUnlockAttemptsRemainingLabel {
    if(Settings.sharedInstance.deleteDataAfterFailedUnlockCount > 0 && Settings.sharedInstance.failedUnlockAttempts > 0) {
        NSInteger remaining = Settings.sharedInstance.deleteDataAfterFailedUnlockCount - Settings.sharedInstance.failedUnlockAttempts;
        
        if(remaining > 0) {
            self.labelUnlockAttemptsRemaining.text = [NSString stringWithFormat:@"Unlock Attempts Remaining: %ld", (long)remaining];
        }
        else {
            self.labelUnlockAttemptsRemaining.text = @"Unlock Attempts Exceeded";
        }
        
        self.labelUnlockAttemptsRemaining.hidden = NO;
        self.labelUnlockAttemptsRemaining.textColor = UIColor.redColor;
    }
    else {
        self.labelUnlockAttemptsRemaining.hidden = YES;
    }
}

- (void)onAppBecameActive {
    if(self.startupLockMode) {
        return; // Ignore App Active events for startup lock screen
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.buttonUnlock.hidden = NO; // Unhide the fallback button
    });

    [self beginUnlockSequence];
}

- (IBAction)onUnlock:(id)sender { // Manual Initiation / Fallback
    [self beginUnlockSequence];
}

- (void)beginUnlockSequence {
    if (Settings.sharedInstance.appLockMode == kNoLock || ![self shouldLock]) {
        Settings.sharedInstance.failedUnlockAttempts = 0;
        self.onUnlockDone();
        return;
    }

    if((Settings.sharedInstance.appLockMode == kBiometric || Settings.sharedInstance.appLockMode == kBoth) && Settings.isBiometricIdAvailable) {
        [self requestBiometric];
    }
    else if (Settings.sharedInstance.appLockMode == kPinCode || Settings.sharedInstance.appLockMode == kBoth) {
        [self requestPin];
    }
    else {
        Settings.sharedInstance.failedUnlockAttempts = 0;
        self.onUnlockDone();
    }
}

- (void)requestBiometric {
    [Settings.sharedInstance requestBiometricId:@"Identify to Open Strongbox"
                          allowDevicePinInstead:NO
                                     completion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (Settings.sharedInstance.appLockMode == kPinCode || Settings.sharedInstance.appLockMode == kBoth) {
                    [self requestPin];
                }
                else {
                    Settings.sharedInstance.failedUnlockAttempts = 0;
                    self.onUnlockDone();
                }
            });
        }
        else {
            [self incrementFailedUnlockCount];
        }}];
}

- (void)requestPin {
    PinEntryController *vc = [[PinEntryController alloc] init];
    
    __weak PinEntryController* weakVc = vc;
    
    vc.info = @"Please enter your PIN to Unlock Strongbox";
    vc.pinLength = Settings.sharedInstance.appLockPin.length;
    
    vc.onDone = ^(PinEntryResponse response, NSString * _Nullable pin) {
        if(response == kOk) {
            if([pin isEqualToString:Settings.sharedInstance.appLockPin]) {
                Settings.sharedInstance.failedUnlockAttempts = 0;
                self.onUnlockDone();
            }
            else {
                [Alerts info:weakVc title:@"PIN Incorrect" message:@"That is not the correct PIN code." completion:^{
                    [self dismissViewControllerAnimated:YES completion:nil];
                }];
                
                [self incrementFailedUnlockCount];
            }
        }
        else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    };
    
    [self presentViewController:vc animated:YES completion:nil];
}

- (BOOL)shouldLock {
    NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:self.startTime];
    NSInteger seconds = Settings.sharedInstance.appLockDelay;
    
    if (self.startupLockMode || seconds == 0 || secondsBetween > seconds)
    {
        NSLog(@"Locking App. %ld - %f", (long)seconds, secondsBetween);
        return YES;
    }

    NSLog(@"App Lock Not Required %f", secondsBetween);
    return NO;
}

- (void)incrementFailedUnlockCount {
    Settings.sharedInstance.failedUnlockAttempts = Settings.sharedInstance.failedUnlockAttempts + 1;
    NSLog(@"Failed Unlocks: %lu", (unsigned long)Settings.sharedInstance.failedUnlockAttempts);
    [self updateUnlockAttemptsRemainingLabel];

    if(Settings.sharedInstance.deleteDataAfterFailedUnlockCount > 0) {
        if(Settings.sharedInstance.failedUnlockAttempts >= Settings.sharedInstance.deleteDataAfterFailedUnlockCount) {
            [self deleteAllData];
        }
    }
}

- (void)deleteAllData {
    [SafesList.sharedInstance deleteAll]; // This also removes Key Chain Entries
    [LocalDeviceStorageProvider.sharedInstance deleteAllLocalAndAppGroupFiles]; // Key Files, Caches, etc
}

@end
