//
//  DatabasePreferences.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabasePreferences.h"
#import "BookmarksHelper.h"
#import "Utils.h"
#import "SecretStore.h"
#import "Alerts.h"
#import "DatabasesManager.h"
#import "NSArray+Extensions.h"
#import "BiometricIdHelper.h"
#import "Settings.h"

@interface DatabasePreferences ()

@property (weak) IBOutlet NSTextField *textFieldPath;
@property (weak) IBOutlet NSTextField *textFieldDatabaseName;
@property (weak) IBOutlet NSTextField *textFieldKeyFile;
@property (weak) IBOutlet NSButton *checkboxUseTouchId;
@property (weak) IBOutlet NSSlider *sliderExpiry;
@property (weak) IBOutlet NSTextField *labelExpiryPeriod;
@property (weak) IBOutlet NSTextField *passwordStorageSummary;
@property (weak) IBOutlet NSTextField *labelRequireReentry;
@property (weak) IBOutlet NSTextField *labelHeaderConvenienceUnlock;

@property NSArray<NSNumber*>* sliderNotches;
@end

@implementation DatabasePreferences

- (void)viewDidLoad {
    [super viewDidLoad];

    self.sliderNotches = @[@0, @1, @2, @3, @4, @8, @24, @48, @72, @96, @(1*7*24), @(2*7*24), @(3*7*24), @(4*7*24), @(5*7*24), @(6*7*24), @(7*7*24), @(8*7*24), @(12*7*24), @-1];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self bindUi];
}

- (void)bindUi {
    self.textFieldDatabaseName.stringValue = self.model.databaseMetadata.nickName;
    self.textFieldPath.stringValue = [BookmarksHelper getExpressUrlFromBookmark:self.model.databaseMetadata.storageInfo].path;
    self.textFieldKeyFile.stringValue = self.model.databaseMetadata.keyFileBookmark ?
        [BookmarksHelper getExpressUrlFromBookmark:self.model.databaseMetadata.keyFileBookmark].absoluteString :
        NSLocalizedString(@"mac_key_file_none", @"None");
    
    BOOL bioAvailable = BiometricIdHelper.sharedInstance.biometricIdAvailable;
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    
    if(featureAvailable) {
        self.labelHeaderConvenienceUnlock.stringValue = bioAvailable ?
            NSLocalizedString(@"mac_convenience_unlock_title", @"Convenience Unlock") :
            NSLocalizedString(@"mac_convenience_unlock_title_bio_unavailable", @"Convenience Unlock (Biometrics/Watch Unavailable)");
    }
    else {
        self.labelHeaderConvenienceUnlock.stringValue = NSLocalizedString(@"mac_convenience_unlock_title_pro_only", @"Convenience Unlock (Pro Feature Only)");
    }
    
    BOOL conveniencePossible = bioAvailable && featureAvailable;
    
    self.checkboxUseTouchId.enabled = conveniencePossible;
    self.checkboxUseTouchId.state = self.model.databaseMetadata.isTouchIdEnabled ? NSOnState : NSOffState;
    
    self.sliderExpiry.enabled = conveniencePossible && self.model.databaseMetadata.isTouchIdEnabled;
    self.sliderExpiry.integerValue = [self getSliderValueFromHours:self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours];
    
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours];
    self.labelExpiryPeriod.textColor = (conveniencePossible && self.model.databaseMetadata.isTouchIdEnabled) ? nil : NSColor.disabledControlTextColor;
    self.labelRequireReentry.textColor = (conveniencePossible && self.model.databaseMetadata.isTouchIdEnabled) ? nil : NSColor.disabledControlTextColor;
    
    self.passwordStorageSummary.textColor = conveniencePossible ? nil : NSColor.disabledControlTextColor;
    self.passwordStorageSummary.stringValue = [self getSecureStorageSummary];
}

- (NSString*)getSecureStorageSummary {
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;

    if(featureAvailable) {
        if(BiometricIdHelper.sharedInstance.biometricIdAvailable) {
            if(self.model.databaseMetadata.isTouchIdEnabled) {
                if(self.model.databaseMetadata.touchIdPassword != nil) {
                    SecretExpiryMode mode = [self.model.databaseMetadata getConveniencePasswordExpiryMode];
                    if (mode == kExpiresAtTime) {
                        NSDate* date = [self.model.databaseMetadata getConveniencePasswordExpiryDate];
                        if(SecretStore.sharedInstance.secureEnclaveAvailable) {
                            NSString* loc = NSLocalizedString(@"mac_convenience_summary_secure_enclave_and_will_expire_fmt", @"Convenience Password is securely stored, protected by your device's Secure Enclave and will expire: %@.");
                            
                            return [NSString stringWithFormat:loc, friendlyDateString(date)];
                        }
                        else {
                            NSString* loc = NSLocalizedString(@"mac_convenience_summary_keychain_and_will_expire_fmt", @"Convenience Password is securely stored in your Keychain (Secure Enclave unavailable on this device) and will expire: %@.");
                            
                            return [NSString stringWithFormat:loc, friendlyDateString(date)];
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

- (IBAction)onTouchIdToggled:(id)sender {
    if (self.checkboxUseTouchId.state == NSOnState) {
        self.model.databaseMetadata.isTouchIdEnabled = YES;
        self.model.databaseMetadata.isTouchIdEnrolled = YES;
        self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours = kDefaultPasswordExpiryHours;
    }
    else {
        self.model.databaseMetadata.isTouchIdEnrolled = NO;
        self.model.databaseMetadata.isTouchIdEnabled = NO;
    }
    
    [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
    [self.model.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:self.model.compositeKeyFactors.password];
    [self bindUi];
}

- (IBAction)onSlider:(id)sender {
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:[self getHoursFromSliderValue:self.sliderExpiry.integerValue]];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(throttledSliderChanged) object:nil];
    [self performSelector:@selector(throttledSliderChanged) withObject:nil afterDelay:0.2f];
}

- (void)throttledSliderChanged {
    self.model.databaseMetadata.touchIdPasswordExpiryPeriodHours = [self getHoursFromSliderValue:self.sliderExpiry.integerValue];
    [DatabasesManager.sharedInstance update:self.model.databaseMetadata];
    [self.model.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:self.model.compositeKeyFactors.password];
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
