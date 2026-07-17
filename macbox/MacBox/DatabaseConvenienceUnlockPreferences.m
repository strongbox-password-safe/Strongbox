//
//  DatabasePreferences.m
//  Strongbox
//
//  Created by Mark on 27/01/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "DatabaseConvenienceUnlockPreferences.h"
#import "Utils.h"
#import "SecretStore.h"
#import "MacAlerts.h"
#import "NSArray+Extensions.h"
#import "BiometricIdHelper.h"
#import "DatabaseUnlocker.h"
#import "MacCompositeKeyDeterminer.h"
#import "Settings.h"
#import "NSDate+Extensions.h"
#import "DatabaseMetadata.h"
#import "WorkingCopyManager.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface DatabaseConvenienceUnlockPreferences () <SimplePinModalDelegate>

@property (weak) IBOutlet NSButton *checkboxUseTouchId;
@property (weak) IBOutlet NSSlider *sliderExpiry;
@property (weak) IBOutlet NSTextField *labelExpiryPeriod;
@property (weak) IBOutlet NSTextField *passwordStorageSummary;
@property (weak) IBOutlet NSTextField *labelRequireReentry;
@property (weak) IBOutlet NSButton *checkBoxEnableWatch;

@property (weak) IBOutlet NSStackView *biometricStackView;
@property (strong) NSStackView *pinStackView;
@property NSArray<NSNumber*>* sliderNotches;
@property (strong) NSButton *checkboxEnablePin;
@property (strong) NSButton *buttonChangePin;
@property (strong) NSTextField *labelPinExplanation;
@property (strong) NSTextField *labelCurrentPinStatus;

@end

@implementation DatabaseConvenienceUnlockPreferences

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self createPinUIElements];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    self.sliderNotches = @[@0, @1, @2, @3, @4, @8, @24, @48, @72, @96, @(1*7*24), @(2*7*24), @(3*7*24), @(4*7*24), @(5*7*24), @(6*7*24), @(7*7*24), @(8*7*24), @(12*7*24), @-1];

    
    if (self.pinStackView && self.biometricStackView) {
        if (![self.biometricStackView.arrangedSubviews containsObject:self.pinStackView]) {
            [self.biometricStackView insertArrangedSubview:self.pinStackView atIndex:0];
        } else {
            NSUInteger idx = [self.biometricStackView.arrangedSubviews indexOfObject:self.pinStackView];
            if (idx != 0) {
                [self.biometricStackView removeArrangedSubview:self.pinStackView];
                [self.biometricStackView insertArrangedSubview:self.pinStackView atIndex:0];
            }
        }
    }
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
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL methodAvailable = watchAvailable || touchAvailable;
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    BOOL showPinMode = [self shouldShowPinMode];
    
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    BOOL convenienceEnabled = meta.isConvenienceUnlockEnabled;
    BOOL conveniencePossible = methodAvailable && featureAvailable;
    BOOL showConvenienceUi = conveniencePossible || showPinMode;
    BOOL expiryEnabled = featureAvailable && convenienceEnabled;

    self.pinStackView.hidden = !showPinMode;
    self.biometricStackView.hidden = !showConvenienceUi;
    self.checkboxUseTouchId.enabled = touchAvailable && featureAvailable;
    self.checkboxUseTouchId.state = meta.isTouchIdEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.checkBoxEnableWatch.enabled = watchAvailable && featureAvailable;
    self.checkBoxEnableWatch.state = meta.isWatchUnlockEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.sliderExpiry.enabled = expiryEnabled;
    self.sliderExpiry.integerValue = [self getSliderValueFromHours:meta.touchIdPasswordExpiryPeriodHours];
    self.labelExpiryPeriod.stringValue = [self getExpiryPeriodString:meta.touchIdPasswordExpiryPeriodHours];
    self.labelExpiryPeriod.textColor = expiryEnabled ? nil : NSColor.disabledControlTextColor;
    self.labelRequireReentry.textColor = expiryEnabled ? nil : NSColor.disabledControlTextColor;
    self.passwordStorageSummary.textColor = showConvenienceUi ? nil : NSColor.disabledControlTextColor;
    self.passwordStorageSummary.stringValue = [self getSecureStorageSummary];
    if (showPinMode) {
        [self bindPinMode];
    }
}

- (void)bindBiometricUI {
    if ( BiometricIdHelper.sharedInstance.isWatchUnlockAvailable) {
        self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock", @"Watch Unlock");
    }
    else {
        if ( Settings.sharedInstance.isPro ) {
            self.checkBoxEnableWatch.title = NSLocalizedString(@"preference_allow_watch_unlock_system_disabled", @"Watch Unlock - (Enable in System Settings > Touch ID & Password)");
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
        return NSLocalizedString(@"unknown_storage_mode", @"Unknown Storage Mode for Convenience Password.");
    }
}

- (void)bindPinMode {
    
    BOOL pinEnabled = [self isPinEnabled];
    self.checkboxEnablePin.state = pinEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    
    
    if (pinEnabled) {
        NSString* pinLength = [NSString stringWithFormat:NSLocalizedString(@"pin_status_set_format", @"PIN set (%lu digits)"), (unsigned long)self.model.databaseMetadata.conveniencePin.length];
        self.labelCurrentPinStatus.stringValue = pinLength;
        self.labelCurrentPinStatus.textColor = [NSColor labelColor];
        self.buttonChangePin.enabled = YES;
    } else {
        self.labelCurrentPinStatus.stringValue = NSLocalizedString(@"pin_status_not_set", @"No PIN set");
        self.labelCurrentPinStatus.textColor = [NSColor secondaryLabelColor];
        self.buttonChangePin.enabled = NO;
    }

    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL methodAvailable = watchAvailable || touchAvailable;
    MacDatabasePreferences* meta = self.model.databaseMetadata;
    BOOL biometricEnabled = (meta.isTouchIdEnabled && touchAvailable) || (meta.isWatchUnlockEnabled && watchAvailable);
    
    if (!biometricEnabled && (pinEnabled || !methodAvailable)) {
        self.passwordStorageSummary.stringValue = [self getPinSecureStorageSummary];
    }
}

- (void)hideBiometricUIElements {
    
    self.checkboxUseTouchId.hidden = YES;
    self.checkBoxEnableWatch.hidden = YES;
    self.sliderExpiry.hidden = YES;
    self.labelExpiryPeriod.hidden = YES;
    self.labelRequireReentry.hidden = YES;
}

- (void)showBiometricUIElements {
    
    self.checkboxUseTouchId.hidden = NO;
    self.checkBoxEnableWatch.hidden = NO;
    self.sliderExpiry.hidden = NO;
    self.labelExpiryPeriod.hidden = NO;
    self.labelRequireReentry.hidden = NO;
}

- (NSString*)getPinSecureStorageSummary {
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    if (!featureAvailable) {
        return NSLocalizedString(@"mac_convenience_summary_only_available_on_pro", @"Convenience Unlock is only available in the Pro version of Strongbox. Please consider upgrading to support development.");
    }
    
    BOOL pinEnabled = [self isPinEnabled];
    if (!pinEnabled) {
        return NSLocalizedString(@"pin_unlock_disabled_explanation", @"PIN Unlock is disabled. Enable PIN unlock to quickly access your database alongside Touch ID or Apple Watch, or as an alternative when biometric authentication is not available.");
    }
    
    if (SecretStore.sharedInstance.secureEnclaveAvailable) {
        return NSLocalizedString(@"pin_secure_enclave_summary", @"PIN is securely stored, protected by your device's Secure Enclave.");
    } else {
        return NSLocalizedString(@"pin_keychain_summary", @"PIN is securely stored in your Keychain (Secure Enclave unavailable on this device).");
    }
}

- (void)updatePinUIVisibility:(BOOL)showPinMode {
    if (showPinMode && !self.checkboxEnablePin.superview) {
        
        [self.view addSubview:self.checkboxEnablePin];
        [self.view addSubview:self.labelPinExplanation];
        [self.view addSubview:self.labelCurrentPinStatus];
        [self.view addSubview:self.buttonChangePin];
        
        
        [NSLayoutConstraint activateConstraints:@[
            [self.checkboxEnablePin.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20],
            [self.checkboxEnablePin.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
            
            [self.labelPinExplanation.topAnchor constraintEqualToAnchor:self.checkboxEnablePin.bottomAnchor constant:8],
            [self.labelPinExplanation.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
            [self.labelPinExplanation.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
            
            [self.labelCurrentPinStatus.topAnchor constraintEqualToAnchor:self.labelPinExplanation.bottomAnchor constant:12],
            [self.labelCurrentPinStatus.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
            
            [self.buttonChangePin.topAnchor constraintEqualToAnchor:self.labelCurrentPinStatus.bottomAnchor constant:8],
            [self.buttonChangePin.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        ]];
    }
    
    
    self.checkboxEnablePin.hidden = !showPinMode;
    self.labelPinExplanation.hidden = !showPinMode;
    self.labelCurrentPinStatus.hidden = !showPinMode;
    self.buttonChangePin.hidden = !showPinMode;
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

#pragma mark - Credential Verification

- (void)requestVerifyMasterCredentialsForPinChange:(void (^)(BOOL verified))completion {
    NSURL* url = [WorkingCopyManager.sharedInstance getLocalWorkingCache:self.model.databaseUuid];
    if ( url == nil ) {
        NSError* error = [Utils createNSError:@"Could not get working cache to verify credentials. Cannot continue."
                                    errorCode:-12345];
        [MacAlerts error:error window:self.view.window];
        completion(NO);
        return;
    }
    
    MacCompositeKeyDeterminer* ckd =
        [MacCompositeKeyDeterminer determinerWithViewController:self
                                                       database:self.model.databaseMetadata
                               isNativeAutoFillAppExtensionOpen:NO];
    
    ckd.verifyCkfsMode = YES;
    
    NSString* biometricMessage = NSLocalizedString(@"verify_creds_before_changing_bio_message_suffix",
                                                    @"verify credentials before you can change them");
    NSString* manualHeadline = NSLocalizedString(@"verify_creds_headline", @"Verify Master Credentials");
    NSString* manualSubhead = NSLocalizedString(@"verify_creds_subhead",
                                                @"For security reasons your master credentials must be verified before you can change them.");
    
    __weak typeof(self) weakSelf = self;
    [ckd getCkfs:biometricMessage
   manualHeadline:manualHeadline
    manualSubhead:manualSubhead
       completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            if ( result == kGetCompositeKeyResultError ) {
                if ( error ) {
                    [MacAlerts error:error window:strongSelf.view.window];
                }
                completion(NO);
                return;
            }
            
            if ( result == kGetCompositeKeyResultSuccess ) {
                if ( !factors ) {
                    completion(NO);
                    return;
                }
                
                [strongSelf verifyCkfsAreCorrect:factors completion:^(BOOL verified, NSError * _Nullable verifyError) {
                    if ( verifyError ) {
                        [MacAlerts error:verifyError window:strongSelf.view.window];
                        completion(NO);
                        return;
                    }
                    
                    if ( !verified ) {
                        NSString* title = NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title",
                                                            @"Incorrect Credentials");
                        NSString* message = NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message",
                                                              @"The credentials were incorrect for this database.");
                        [MacAlerts info:title informativeText:message window:strongSelf.view.window completion:nil];
                        completion(NO);
                        return;
                    }
                    
                    completion(YES);
                }];
                return;
            }
            
            completion(NO);
        });
    }];
}

- (void)verifyCkfsAreCorrect:(CompositeKeyFactors*)factors
                  completion:(void (^)(BOOL verified, NSError* _Nullable error))completion {
    DatabaseUnlocker *unlocker = [DatabaseUnlocker unlockerForDatabase:self.model.databaseMetadata
                                                        viewController:self
                                                         forceReadOnly:NO
                                      isNativeAutoFillAppExtensionOpen:NO
                                                           offlineMode:NO];
    
    [unlocker unlockLocalWithKey:factors
              keyFromConvenience:NO
                      completion:^(UnlockDatabaseResult result, Model * _Nullable model, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( result == kUnlockDatabaseResultSuccess ) {
                completion(YES, nil);
            }
            else if ( result == kUnlockDatabaseResultIncorrectCredentials ) {
                completion(NO, nil);
            }
            else if ( result == kUnlockDatabaseResultError ) {
                completion(NO, error);
            }
            else {
                completion(NO, nil);
            }
        });
    }];
}

#pragma mark - PIN Functionality

- (void)createPinUIElements {
    
    self.checkboxEnablePin = [[NSButton alloc] init];
    [self.checkboxEnablePin setButtonType:NSButtonTypeSwitch];
    [self.checkboxEnablePin setTitle:NSLocalizedString(@"enable_pin_unlock_title", @"Enable PIN Unlock")];
    [self.checkboxEnablePin setTarget:self];
    [self.checkboxEnablePin setAction:@selector(onPinSettingChanged:)];
    [self.checkboxEnablePin setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    
    self.labelPinExplanation = [[NSTextField alloc] init];
    [self.labelPinExplanation setEditable:NO];
    [self.labelPinExplanation setBordered:NO];
    [self.labelPinExplanation setBackgroundColor:[NSColor clearColor]];
    [self.labelPinExplanation setStringValue:NSLocalizedString(@"pin_explanation_text", @"Use a PIN code to quickly unlock your database when biometric authentication is not available.")];
    [self.labelPinExplanation setFont:[NSFont systemFontOfSize:11]];
    [self.labelPinExplanation setTextColor:[NSColor secondaryLabelColor]];
    [self.labelPinExplanation setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.labelPinExplanation setLineBreakMode:NSLineBreakByWordWrapping];
    [self.labelPinExplanation setMaximumNumberOfLines:0];
    
    
    self.labelCurrentPinStatus = [[NSTextField alloc] init];
    [self.labelCurrentPinStatus setEditable:NO];
    [self.labelCurrentPinStatus setBordered:NO];
    [self.labelCurrentPinStatus setBackgroundColor:[NSColor clearColor]];
    [self.labelCurrentPinStatus setFont:[NSFont systemFontOfSize:12]];
    [self.labelCurrentPinStatus setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    
    self.buttonChangePin = [[NSButton alloc] init];
    [self.buttonChangePin setTitle:NSLocalizedString(@"change_pin_button_title", @"Change PIN")];
    [self.buttonChangePin setTarget:self];
    [self.buttonChangePin setAction:@selector(onChangePin:)];
    [self.buttonChangePin setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    
    self.pinStackView = [[NSStackView alloc] init];
    [self.pinStackView setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [self.pinStackView setSpacing:10];
    [self.pinStackView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.pinStackView setAlignment:NSLayoutAttributeLeading];
    [self.pinStackView addArrangedSubview:self.checkboxEnablePin];
    [self.pinStackView addArrangedSubview:self.labelPinExplanation];
    [self.pinStackView addArrangedSubview:self.labelCurrentPinStatus];
    [self.pinStackView addArrangedSubview:self.buttonChangePin];
}

- (BOOL)shouldShowPinMode {
    BOOL featureAvailable = Settings.sharedInstance.isPro;
    return featureAvailable || [self isPinEnabled];
}

- (BOOL)isPinEnabled {
    return self.model.databaseMetadata.conveniencePin != nil && self.model.databaseMetadata.conveniencePin.length > 0;
}

- (void)onPinSettingChanged:(id)sender {
    BOOL enablePin = self.checkboxEnablePin.state == NSControlStateValueOn;
    
    if (enablePin) {
        __weak typeof(self) weakSelf = self;
        [self requestVerifyMasterCredentialsForPinChange:^(BOOL verified) {
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            
            if ( verified ) {
                [SimplePinModal showFrom:strongSelf delegate:strongSelf];
            }
            else {
                strongSelf.checkboxEnablePin.state = NSControlStateValueOff;
                [strongSelf bindUi];
            }
        }];
    } else {
        self.model.databaseMetadata.conveniencePin = nil;
        [self bindUi];
        [self forceMenuRefresh];
    }
}

- (void)onChangePin:(id)sender {
    __weak typeof(self) weakSelf = self;
    [self requestVerifyMasterCredentialsForPinChange:^(BOOL verified) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if ( verified ) {
            [SimplePinModal showFrom:strongSelf delegate:strongSelf];
        }
    }];
}

#pragma mark - SimplePinModalDelegate

- (void)simplePinModalDidSubmitPin:(NSString *)pin {
    if (pin && pin.length >= 4) {
        self.model.databaseMetadata.conveniencePin = pin;
        if (!self.model.databaseMetadata.conveniencePasswordHasBeenStored) {
            self.model.databaseMetadata.conveniencePasswordHasBeenStored = YES;
            self.model.databaseMetadata.conveniencePassword = self.model.compositeKeyFactors.password;
        }
        [self bindUi];
        [self forceMenuRefresh];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"invalid_pin_title", @"Invalid PIN");
        alert.informativeText = NSLocalizedString(@"invalid_pin_message", @"PIN must be at least 4 characters long.");
        alert.alertStyle = NSAlertStyleWarning;
        [alert addButtonWithTitle:NSLocalizedString(@"generic_ok", @"OK")];
        [alert runModal];
    }
}

- (void)simplePinModalDidCancel {
    [self bindUi];
}

- (void)forceMenuRefresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMenu* mainMenu = [NSApplication sharedApplication].mainMenu;
        [self updateConvenienceUnlockMenuItemInMenu:mainMenu];
    });
}

- (void)updateConvenienceUnlockMenuItemInMenu:(NSMenu*)menu {
    for (NSMenuItem* item in menu.itemArray) {
        if (item.action == @selector(onConvenienceUnlockProperties:)) {
            BOOL pinEnabled = self.model.databaseMetadata.conveniencePin != nil;
            
            if (pinEnabled) {
                item.title = NSLocalizedString(@"pin_code_settings_menu", @"Pin Code Settings...");
            } else {
                item.title = NSLocalizedString(@"touchid_watch_unlock_settings_menu", @"Touch ID & Watch Unlock Settings...");
            }
            return;
        }
        if (item.hasSubmenu) {
            [self updateConvenienceUnlockMenuItemInMenu:item.submenu];
        }
    }
}

@end
