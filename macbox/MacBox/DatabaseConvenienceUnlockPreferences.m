//
//  DatabasePreferences.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseConvenienceUnlockPreferences.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "SecretStore.h"
#import "MacAlerts.h"
#import "DatabasesManager.h"
#import "NSArray+Extensions.h"
#import "BiometricIdHelper.h"
#import "Settings.h"
#import "NSDate+Extensions.h"

@interface DatabaseConvenienceUnlockPreferences ()

@property (weak) IBOutlet NSButton *checkboxUseTouchId;
@property (weak) IBOutlet NSSlider *sliderExpiry;
@property (weak) IBOutlet NSTextField *labelExpiryPeriod;
@property (weak) IBOutlet NSTextField *passwordStorageSummary;
@property (weak) IBOutlet NSTextField *labelRequireReentry;
@property (weak) IBOutlet NSButton *checkBoxEnableWatch;
@property (weak) IBOutlet NSButton *checkboxAutomaticallyPrompt;

@property NSArray<NSNumber*>* sliderNotches;

@end

@implementation DatabaseConvenienceUnlockPreferences

- (void)viewDidAppear {
    [super viewDidAppear];

    self.sliderNotches = @[@0, @1, @2, @3, @4, @8, @24, @48, @72, @96, @(1*7*24), @(2*7*24), @(3*7*24), @(4*7*24), @(5*7*24), @(6*7*24), @(7*7*24), @(8*7*24), @(12*7*24), @-1];

    [self bindUi];
}

- (IBAction)onSettingChanged:(id)sender {
    self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate = self.checkboxAutomaticallyPrompt.state == NSControlStateValueOn;
    
    [DatabasesManager.sharedInstance update:self.databaseMetadata];
    
    [self bindUi];
}

- (void)bindUi {
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL convenienceAvailable = watchAvailable || touchAvailable;
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL conveniencePossible = convenienceAvailable && featureAvailable;

    if ( BiometricIdHelper.sharedInstance.isWatchUnlockAvailable ) {
        self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock", @"Watch Unlock");
    }
    else {
        self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock_system_disabled", @"Watch Unlock - (Enable in System Preferences > Security & Privacy)");
    }
        
    self.checkboxUseTouchId.enabled = touchAvailable && featureAvailable;
    self.checkboxUseTouchId.state = self.databaseMetadata.isTouchIdEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkBoxEnableWatch.enabled = watchAvailable && featureAvailable;
    self.checkBoxEnableWatch.state = self.databaseMetadata.isWatchUnlockEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
    
    self.checkboxAutomaticallyPrompt.enabled = convenienceEnabled;
    self.checkboxAutomaticallyPrompt.state = self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate ? NSControlStateValueOn : NSControlStateValueOff;

    self.sliderExpiry.enabled = conveniencePossible && convenienceEnabled;
    self.sliderExpiry.integerValue = [self getSliderValueFromHours:self.databaseMetadata.touchIdPasswordExpiryPeriodHours];
    
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:self.databaseMetadata.touchIdPasswordExpiryPeriodHours];
    self.labelExpiryPeriod.textColor = (conveniencePossible && convenienceEnabled) ? nil : NSColor.disabledControlTextColor;
    self.labelRequireReentry.textColor = (conveniencePossible && convenienceEnabled) ? nil : NSColor.disabledControlTextColor;
    
    self.passwordStorageSummary.textColor = conveniencePossible ? nil : NSColor.disabledControlTextColor;
    self.passwordStorageSummary.stringValue = [self getSecureStorageSummary];
}

- (IBAction)onConvenienceUnlockMethodsChanged:(id)sender {
    BOOL wasOff = !self.databaseMetadata.isTouchIdEnrolled;
    
    BOOL touch = self.checkboxUseTouchId.state == NSControlStateValueOn;
    BOOL watch = self.checkBoxEnableWatch.state == NSControlStateValueOn;
    BOOL on = touch || watch;
    
    self.databaseMetadata.isTouchIdEnabled = touch;
    self.databaseMetadata.isWatchUnlockEnabled = watch;
    self.databaseMetadata.isTouchIdEnrolled = on;
    
    if ( on && wasOff )  {
        self.databaseMetadata.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
    }
    
    [DatabasesManager.sharedInstance update:self.databaseMetadata];
    
    [self.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:self.databaseModel.ckfs.password];
    
    [self bindUi];
}

- (NSString*)getSecureStorageSummary {
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL convenienceAvailable = watchAvailable || touchAvailable;
    BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;
    
    if( featureAvailable ) {
        if( convenienceAvailable ) {
            if( convenienceEnabled ) {
                if( passwordAvailable ) {
                    SecretExpiryMode mode = [self.databaseMetadata getConveniencePasswordExpiryMode];
                    if (mode == kExpiresAtTime) {
                        NSDate* date = [self.databaseMetadata getConveniencePasswordExpiryDate];
                        if(SecretStore.sharedInstance.secureEnclaveAvailable) {
                            NSString* loc = NSLocalizedString(@"mac_convenience_summary_secure_enclave_and_will_expire_fmt", @"Convenience Password is securely stored, protected by your device's Secure Enclave and will expire: %@.");
                            
                            return [NSString stringWithFormat:loc, date.friendlyDateString];
                        }
                        else {
                            NSString* loc = NSLocalizedString(@"mac_convenience_summary_keychain_and_will_expire_fmt", @"Convenience Password is securely stored in your Keychain (Secure Enclave unavailable on this device) and will expire: %@.");
                            
                            return [NSString stringWithFormat:loc, date.friendlyDateString];
                        }
                    }
                    else if (mode == kNeverExpires) {
                        if(SecretStore.sharedInstance.secureEnclaveAvailable) {
                            return NSLocalizedString(@"mac_convenience_summary_secure_enclave_and_will_not_expire", @"Convenience Password is securely stored, protected by your device's Secure Enclave and is configured not to expire.");
                        }
                        else {
                            return NSLocalizedString(@"mac_convenience_summary_keychain_and_will_not_expire", @"Convenience Password is securely stored in your Keychain (Secure Enclave unavailable on this device), and is configured not to expire.");
                        }
                    }
                    else if (mode == kExpiresOnAppExitStoreSecretInMemoryOnly) {
                        if(SecretStore.sharedInstance.secureEnclaveAvailable) {
                            return NSLocalizedString(@"mac_convenience_summary_secure_enclave_and_will_expire_on_exit", @"Convenience Password is securely stored (in memory only) encrypted by your device's Secure Enclave and will expire on Strongbox Exit.");
                        }
                        else {
                            return NSLocalizedString(@"mac_convenience_summary_keychain_and_will_expire_on_exit", @"Convenience Password is securely stored (in memory only) only and will expire on Strongbox Exit.");
                        }
                    }
                    else {
                        return @"Unknown Storage Mode for Convenience Password.";
                    }
                }
                else {
                    return NSLocalizedString(@"mac_convenience_summary_enabled_but_expired", @"Convenience Unlock is Enabled but the securely stored master password has expired.");
                }
            }
            else {
                return NSLocalizedString(@"mac_convenience_summary_disabled", @"Convenience Unlock Disabled");
            }
        }
        else {
            return NSLocalizedString(@"mac_convenience_summary_biometrics_unavailable", @"Convenience Unlock (Biometrics/Watch Unavailable)");
        }
    }
    else {
        return NSLocalizedString(@"mac_convenience_summary_only_available_on_pro", @"Convenience Unlock is only available in the Pro version of Strongbox. Please consider upgrading to support development.");
    }
}

- (NSString*)getExpiryPeriodString:(NSInteger)expiryPeriodInHours {
    if(expiryPeriodInHours == -1) {
        return NSLocalizedString(@"mac_convenience_expiry_period_never", @"Never");
    }
    else if (expiryPeriodInHours == 0) {
        return NSLocalizedString(@"mac_convenience_expiry_period_on_app_exit", @"App Exit");
    }
    else {
        NSDateComponentsFormatter* fmt =  [[NSDateComponentsFormatter alloc] init];
 
        fmt.allowedUnits = expiryPeriodInHours > 23 ? (NSCalendarUnitDay | NSCalendarUnitWeekOfMonth) : (NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitWeekOfMonth);
        fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        fmt.maximumUnitCount = 2;
        fmt.collapsesLargestUnit = YES;
        
        return [fmt stringFromTimeInterval:expiryPeriodInHours * 60 * 60];
    }
}

- (IBAction)onSlider:(id)sender {
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:[self getHoursFromSliderValue:self.sliderExpiry.integerValue]];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(throttledSliderChanged) object:nil];
    [self performSelector:@selector(throttledSliderChanged) withObject:nil afterDelay:0.2f];
}

- (void)throttledSliderChanged {
    self.databaseMetadata.touchIdPasswordExpiryPeriodHours = [self getHoursFromSliderValue:self.sliderExpiry.integerValue];
    [DatabasesManager.sharedInstance update:self.databaseMetadata];
    [self.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:self.databaseModel.ckfs.password];
    [self bindUi];
}

- (NSInteger)getSliderValueFromHours:(NSUInteger)value {
    for (int i=0;i<self.sliderNotches.count;i++) {
        if(self.sliderNotches[i].integerValue == value) {
            return i;
        }
    }

    return 0;
}

- (NSInteger)getHoursFromSliderValue:(NSUInteger)value {
    if(value < 0) {
        value = 0;
    }
    
    if(value >= self.sliderNotches.count) {
        value = self.sliderNotches.count - 1;
    }
    
    return self.sliderNotches[value].integerValue;
}

@end
