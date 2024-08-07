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
#import "NSArray+Extensions.h"
#import "BiometricIdHelper.h"
#import "Settings.h"
#import "NSDate+Extensions.h"
#import "DatabaseMetadata.h"

@interface DatabaseConvenienceUnlockPreferences ()

@property (weak) IBOutlet NSButton *checkboxUseTouchId;
@property (weak) IBOutlet NSSlider *sliderExpiry;
@property (weak) IBOutlet NSTextField *labelExpiryPeriod;
@property (weak) IBOutlet NSTextField *passwordStorageSummary;
@property (weak) IBOutlet NSTextField *labelRequireReentry;
@property (weak) IBOutlet NSButton *checkBoxEnableWatch;


@property NSArray<NSNumber*>* sliderNotches;

@end

@implementation DatabaseConvenienceUnlockPreferences

- (void)viewDidAppear {
    [super viewDidAppear];

    self.sliderNotches = @[@0, @1, @2, @3, @4, @8, @24, @48, @72, @96, @(1*7*24), @(2*7*24), @(3*7*24), @(4*7*24), @(5*7*24), @(6*7*24), @(7*7*24), @(8*7*24), @(12*7*24), @-1];

    [self bindUi];
}

- (IBAction)onSettingChanged:(id)sender {



    
    [self bindUi];
}

- (IBAction)onConvenienceUnlockMethodsChanged:(id)sender {
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    BOOL touch = self.checkboxUseTouchId.state == NSControlStateValueOn;
    BOOL watch = self.checkBoxEnableWatch.state == NSControlStateValueOn;
    BOOL on = touch || watch;
    BOOL wasOff = !meta.conveniencePasswordHasBeenStored;
    
    NSString* password = self.model.compositeKeyFactors.password;
    
    self.model.databaseMetadata.isTouchIdEnabled = touch;
    self.model.databaseMetadata.isWatchUnlockEnabled = watch;
    
    if ( on && wasOff )  {
        self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
    }
    
    if ( on ) {
        self.model.databaseMetadata.conveniencePasswordHasBeenStored = YES;
        self.model.databaseMetadata.conveniencePassword = password;
    }
    else {
        self.model.databaseMetadata.conveniencePasswordHasBeenStored = NO;
        self.model.databaseMetadata.conveniencePassword = nil;
    }
    
    [self bindUi];
}

- (void)bindUi {
    if ( BiometricIdHelper.sharedInstance.isWatchUnlockAvailable) {
        self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock", @"Watch Unlock");
    }
    else {
        if ( Settings.sharedInstance.isPro ) {
            self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock_system_disabled", @"Watch Unlock - (Enable in System Settings > Touch ID & Password)");
        }
    }
        
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL methodAvailable = watchAvailable || touchAvailable;
    BOOL featureAvailable = Settings.sharedInstance.isPro;

    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    self.checkboxUseTouchId.enabled = touchAvailable && featureAvailable;
    self.checkboxUseTouchId.state = meta.isTouchIdEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.checkBoxEnableWatch.enabled = watchAvailable && featureAvailable;
    self.checkBoxEnableWatch.state = meta.isWatchUnlockEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    BOOL convenienceEnabled = meta.isConvenienceUnlockEnabled;



    BOOL conveniencePossible = methodAvailable && featureAvailable;

    self.sliderExpiry.enabled = conveniencePossible && convenienceEnabled;
    self.sliderExpiry.integerValue = [self getSliderValueFromHours:meta.touchIdPasswordExpiryPeriodHours];
    
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:meta.touchIdPasswordExpiryPeriodHours];
    self.labelExpiryPeriod.textColor = (conveniencePossible && convenienceEnabled) ? nil : NSColor.disabledControlTextColor;
    self.labelRequireReentry.textColor = (conveniencePossible && convenienceEnabled) ? nil : NSColor.disabledControlTextColor;
    
    self.passwordStorageSummary.textColor = conveniencePossible ? nil : NSColor.disabledControlTextColor;
    self.passwordStorageSummary.stringValue = [self getSecureStorageSummary];
}

- (NSString*)getSecureStorageSummary {
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    if( !featureAvailable ) {
        return NSLocalizedString(@"mac_convenience_summary_only_available_on_pro", @"Convenience Unlock is only available in the Pro version of Strongbox. Please consider upgrading to support development.");
    }

    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL methodAvailable = watchAvailable || touchAvailable;

    if( !methodAvailable ) {
        return NSLocalizedString(@"mac_convenience_summary_biometrics_unavailable", @"Convenience Unlock (Biometrics/Watch Unavailable)");
    }

    BOOL methodEnabled = (meta.isTouchIdEnabled && touchAvailable) || (meta.isWatchUnlockEnabled && watchAvailable);
    
    if( !methodEnabled ) {
        return NSLocalizedString(@"mac_convenience_summary_disabled", @"Convenience Unlock Disabled");
    }
    
    BOOL passwordAvailable = meta.conveniencePasswordHasBeenStored;
    BOOL expired = meta.conveniencePasswordHasExpired;
    
    if( !passwordAvailable || expired ) {
        return NSLocalizedString(@"mac_convenience_summary_enabled_but_expired", @"Convenience Unlock is Enabled but the securely stored master password has expired.");
    }
    
    SecretExpiryMode mode = [meta getConveniencePasswordExpiryMode];
    if (mode == kExpiresAtTime) {
        NSDate* date = [meta getConveniencePasswordExpiryDate];
        if(SecretStore.sharedInstance.secureEnclaveAvailable) {
            NSString* loc = NSLocalizedString(@"mac_convenience_summary_secure_enclave_and_will_expire_fmt", @"Convenience Password is securely stored, protected by your device's Secure Enclave and will expire: %@.");
            
            return [NSString stringWithFormat:loc, date.friendlyDateTimeString];
        }
        else {
            NSString* loc = NSLocalizedString(@"mac_convenience_summary_keychain_and_will_expire_fmt", @"Convenience Password is securely stored in your Keychain (Secure Enclave unavailable on this device) and will expire: %@.");
            
            return [NSString stringWithFormat:loc, date.friendlyDateTimeString];
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
    NSInteger foo = [self getHoursFromSliderValue:self.sliderExpiry.integerValue];
    NSString* password = self.model.compositeKeyFactors.password;

    self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours = foo;
    self.model.databaseMetadata.conveniencePasswordHasBeenStored = YES;
    self.model.databaseMetadata.conveniencePassword = password;
    
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

- (IBAction)onClose:(id)sender {
    [self.view.window cancelOperation:nil];
}

@end
