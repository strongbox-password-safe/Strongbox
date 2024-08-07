//
//  LockScreenViewController.m
//  MacBox
//
//  Created by Strongbox on 26/08/2021.
//  Copyright © 2021 Mark McGuill. All rights reserved.
//

#import "LockScreenViewController.h"
#import "ViewModel.h"
#import "MacAlerts.h"
#import "Settings.h"
#import "Document.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "BiometricIdHelper.h"
#import "ClickableImageView.h"
#import "KSPasswordField.h"
#import "MacHardwareKeyManager.h"
#import "BookmarksHelper.h"
#import "StrongboxErrorCodes.h"
#import "MBProgressHUD.h"
#import "MacCompositeKeyDeterminer.h"
#import "NSDate+Extensions.h"
#import "macOSSpinnerUI.h"
#import "StrongboxMacFilesManager.h"
#import "AboutViewController.h"

#import "LocalAuthentication/LocalAuthentication.h"
#import "LocalAuthenticationEmbeddedUI/LocalAuthenticationEmbeddedUI.h"

#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif


@interface LockScreenViewController () < NSTextFieldDelegate >

@property BOOL hasLoaded;
@property (weak) Document*_Nullable document;
@property (readonly) ViewModel*_Nullable viewModel;
@property (readonly) MacDatabasePreferences*_Nullable databaseMetadata;
@property (weak) IBOutlet NSTextField *textFieldError;
@property (weak) IBOutlet NSTextField *textFieldBioUnavailableWarn;

@property (weak) IBOutlet ClickableTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;
@property (weak) IBOutlet MMcGSecureTextField *textFieldMasterPassword;
@property (weak) IBOutlet NSButton *checkboxShowAdvanced;
@property (weak) IBOutlet NSPopUpButton *yubiKeyPopup;
@property (weak) IBOutlet NSButton *checkboxAllowEmpty;
@property (weak) IBOutlet NSTextField *labelUnlockKeyFileHeader;
@property (weak) IBOutlet NSTextField *labelUnlockYubiKeyHeader;
@property (weak) IBOutlet NSPopUpButton *keyFilePopup;

@property (weak) IBOutlet NSStackView *stackViewUnlock;
@property (weak) IBOutlet NSButton *buttonUnlockWithPassword;

@property BOOL currentYubiKeySlot1IsBlocking;
@property BOOL currentYubiKeySlot2IsBlocking;
@property NSString* currentYubiKeySerial;
@property NSString* selectedKeyFileBookmark;
@property YubiKeyConfiguration *selectedYubiKeyConfiguration;

@property NSDate* biometricPromptLastDismissedAt; 
@property (weak) IBOutlet NSButton *checkboxAutoPromptOnActivate;
@property (weak) IBOutlet NSStackView *stackViewUnlockButtons;
@property (weak) IBOutlet NSStackView *yubiKeyHeaderStack;

@property (weak) IBOutlet NSView *quickTrialStartContainer;

@property (weak) IBOutlet NSStackView *upperLockContainerStack;

@property (weak) IBOutlet ClickableTextField *labelLearnMore;

@property (weak) IBOutlet NSTextField *labelPricing;
@property (weak) IBOutlet NSButton *buttonFreeTrialOrUpgrade;

@property LAContext* embeddedTouchIdContext;
@property (weak) IBOutlet NSStackView *masterPasswordAndEmbeddedTouchIDStack;
@property (weak) IBOutlet NSImageView *dummyEmbeddedTouchIDImageView;
@property (readonly) BOOL useEmbeddedTouchID;
@property (weak) IBOutlet NSTextField *textFieldSubtitleOrPrompt;

@property (readonly) BOOL bioOrWatchUnlockIsPossible;
@property (readonly) BOOL showTouchIDUnlockOption;
@property (nullable) LAAuthenticationView* embeddedLaAuthenticationView;
@property (weak) IBOutlet NSButton *imageButtonUnlock;
@property (weak) IBOutlet NSBox *boxVertLineDivider;

@property (weak) IBOutlet NSTextField *textFieldDatabaseNickName;

@end

@implementation LockScreenViewController

- (void)dealloc {
    slog(@"😎 LockScreenViewController::DEALLOC [%@]", self);
}

- (ViewModel *)viewModel {
    return self.document.viewModel;
}

- (MacDatabasePreferences*)databaseMetadata {
    return self.viewModel.databaseMetadata;
}

- (void)viewDidLoad {
    [super viewDidLoad];



    
    
    
    [self customizeUi];
}

- (void)customizeUi {
    self.textFieldDatabaseNickName.font = FontManager.shared.boldLargeTitleFont;
    
    NSString* fmt2 = Settings.sharedInstance.isPro ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt2, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;
    self.textFieldVersion.onClick = ^{
        [AboutViewController show];
    };

    [self customizeLockStackViewSpacing];
    
    NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    self.buttonUnlockWithTouchId.hidden = YES;
    
    [self bindRevealMasterPasswordTextField];
    
    self.textFieldMasterPassword.delegate = self;
    
    
    
    NSImageSymbolConfiguration* imageConfig = [NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge];
    
    [self.buttonUnlockWithPassword setImage:[NSImage imageWithSystemSymbolName:@"lock.open.fill" accessibilityDescription:nil]];
    self.buttonUnlockWithPassword.symbolConfiguration = imageConfig;
    
    [self.buttonUnlockWithTouchId setImage:[NSImage imageWithSystemSymbolName:@"touchid" accessibilityDescription:nil]];
    self.buttonUnlockWithTouchId.symbolConfiguration = imageConfig;
    
    
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(bindProOrFreeTrialWrapper)
                                               name:kProStatusChangedNotification
                                             object:nil];
    
    
    
    self.quickTrialStartContainer.wantsLayer = YES;
    NSColor *colour = ColorFromRGB(0x2C2C2E);
    self.quickTrialStartContainer.layer.backgroundColor = colour.CGColor;
    self.quickTrialStartContainer.layer.cornerRadius = 10;
    
    __weak LockScreenViewController* weakSelf = self;
    self.labelLearnMore.onClick = ^{
        [weakSelf onLearnMoreUpgradeScreen];
    };
    
    [self bindProOrFreeTrial];
    
    [self embedTouchIDIfAvailable];
    

}

- (void)customizeLockStackViewSpacing {
    [self.stackViewUnlock setCustomSpacing:8 afterView:self.textFieldMasterPassword];
    [self.stackViewUnlock setCustomSpacing:6 afterView:self.labelUnlockKeyFileHeader];
    [self.stackViewUnlock setCustomSpacing:6 afterView:self.yubiKeyHeaderStack];
    
    [self.stackViewUnlockButtons setCustomSpacing:12 afterView:self.buttonUnlockWithTouchId];
}

- (IBAction)onRefreshYubiKey:(id)sender {
    [self bindUI];
}

- (void)onDocumentLoaded {
    


    [self load];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    


    [self load];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [self setInitialFocus];
    

}



- (void)setInitialFocus {
    if(self.viewModel == nil || self.viewModel.locked) {
        if([self bioOrWatchUnlockIsPossible] && !self.useEmbeddedTouchID ) {
            [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
        }
        else {
            [self.textFieldMasterPassword becomeFirstResponder];
        }
    }
}

- (void)load {
    if( self.hasLoaded || !self.view.window.windowController.document ) {
        return;
    }
    
    self.hasLoaded = YES;
    _document = self.view.window.windowController.document;

    slog(@"🐞 LockScreenViewController::load - Initial Load - doc=[%@] - vm=[%@]", self.document, self.viewModel);

    
    
    [self startObservingModelChanges];
    
    [self.view.window.windowController synchronizeWindowTitleWithDocumentName]; 
    
    self.selectedKeyFileBookmark = self.viewModel ? self.databaseMetadata.keyFileBookmark : nil;
    self.selectedYubiKeyConfiguration = self.viewModel ? self.databaseMetadata.yubiKeyConfiguration : nil;

    
    if ( !self.databaseMetadata.hasSetInitialWindowPosition ) {
        slog(@"First Launch of Database! Making reasonable size and centering...");
        [self.view.window setFrame:NSMakeRect(0,0, 600, 550) display:YES];
        [self.view.window center];
        
        self.databaseMetadata.hasSetInitialWindowPosition = YES;
    }
    
    [self bindUI];

    [self setInitialFocus];
    
    
    
    if ( !self.document.wasJustLocked ) { 
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self autoPromptForTouchIdIfDesired];
        });
    }
    else {
        self.document.wasJustLocked = NO;
    }
}

- (void)stopObservingModelChanges {

    
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)startObservingModelChanges {

    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowDidBecomeKey:)
                                               name:NSWindowDidBecomeKeyNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(windowWillClose:)
                                               name:NSWindowWillCloseNotification
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(onDatabasePreferencesChanged:) name:kModelUpdateNotificationDatabasePreferenceChanged object:nil];
}

- (void)windowWillClose:(NSNotification*)param {
    if ( param.object == self.view.window ) {
        slog(@"LockScreenViewController::windowWillClose");
        [self stopObservingModelChanges];
    }
}

- (void)onDatabasePreferencesChanged:(NSNotification*)param {
    if(param.object != self.viewModel) {
        return;
    }

    slog(@"LockScreenViewController::onDatabasePreferencesChanged");

    [self.view.window.windowController synchronizeWindowTitleWithDocumentName]; 
}



- (void)bindUI {
    [self bindTitlesAndBioAvailability];
    
    [self setEmbeddedBioErrorTextWithError:nil];
        
    [self bindProOrFreeTrial];
        
    [self refreshKeyFileDropdown];
    
    [self bindYubiKeyOnLockScreen];
    
    [self bindShowAdvancedOnUnlockScreen];
    
    [self bindUnlockButtons];
}

- (void)bindRevealMasterPasswordTextField { 







}

- (void)bindProOrFreeTrialWrapper {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self bindProOrFreeTrial];
    });
}

- (void)bindProOrFreeTrial {
    self.quickTrialStartContainer.hidden = YES; 

    if ( !Settings.sharedInstance.isPro ) {
        if ( ProUpgradeIAPManager.sharedInstance.isFreeTrialAvailable ) {
            [self bindFreeTrialPanel];
        }
        else {
            [self bindUpgradePanel];
        }
    }
}

- (void)bindFreeTrialPanel {
    self.quickTrialStartContainer.hidden = NO;
    self.labelLearnMore.hidden = NO;
    
    NSString* priceText = [self getPriceTextFromProduct:ProUpgradeIAPManager.sharedInstance.yearlyProduct];
    NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"price_per_year_after_free_trial_fmt", @"Then %@ every year"), priceText];
    
    self.labelPricing.stringValue = fmt;
    self.labelPricing.hidden = NO;
    
    [self.buttonFreeTrialOrUpgrade setAction:@selector(onQuickStartFreeTrialOrYearly)];
}

- (void)bindUpgradePanel {
    self.quickTrialStartContainer.hidden = NO;
    
    self.labelPricing.hidden = YES;

    [self.buttonFreeTrialOrUpgrade setTitle:NSLocalizedString(@"generic_upgrade_to_pro", @"Upgrade To Pro")];

    if ( MacCustomizationManager.isUnifiedFreemiumBundle && ProUpgradeIAPManager.sharedInstance.yearlyProduct ) {
        NSString* priceText = [self getPriceTextFromProduct:ProUpgradeIAPManager.sharedInstance.yearlyProduct];
        NSString* fmt = [NSString stringWithFormat:NSLocalizedString(@"upgrade_vc_price_per_year_fmt", @"%@ / year"), priceText];
        self.labelPricing.stringValue = fmt;
        self.labelPricing.hidden = NO;

        self.labelLearnMore.hidden = NO;

        [self.buttonFreeTrialOrUpgrade setAction:@selector(onQuickStartFreeTrialOrYearly)];
    }
    else {
        self.labelLearnMore.hidden = YES;
        [self.buttonFreeTrialOrUpgrade setAction:@selector(onLearnMoreUpgradeScreen)];
    }
}

- (void)onLearnMoreUpgradeScreen {
    if ( MacCustomizationManager.isUnifiedFreemiumBundle ) {
        UnifiedUpgrade* vc = [UnifiedUpgrade fromStoryboard];
        vc.naggy = NO;
        vc.isPresentedAsSheet = YES;

        [self presentViewControllerAsSheet:vc];
    }
    else {
        [UpgradeWindowController show:0];
    }
}

- (void)onQuickStartFreeTrialOrYearly {
    SKProduct* product = ProUpgradeIAPManager.sharedInstance.yearlyProduct;
    
    if ( product ) {
        [macOSSpinnerUI.sharedInstance show:NSLocalizedString(@"upgrade_vc_progress_purchasing", @"Purchasing...")
                             viewController:self];

        [ProUpgradeIAPManager.sharedInstance purchaseAndCheckReceipts:product
                                                           completion:^(NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [macOSSpinnerUI.sharedInstance dismiss];

                if ( error && error.code != SKErrorPaymentCancelled ) {
                    slog(@"⚠️ Purchase done with error = [%@]", error);
                    [MacAlerts error:error window:self.view.window];
                }
            });
        }];
    }
}

- (NSString*)getPriceTextFromProduct:(SKProduct*)product {
    if ( product == nil ) {
        return NSLocalizedString(@"generic_loading", @"Loading...");
    }
    else {
        NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.locale = product.priceLocale;
        return [formatter stringFromNumber:product.price];
    }
}

- (void)bindShowAdvancedOnUnlockScreen {
    BOOL show = self.viewModel.showAdvancedUnlockOptions;
    
    self.checkboxShowAdvanced.state = show ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.checkboxAllowEmpty.hidden = !show;
    self.checkboxAllowEmpty.state = Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSControlStateValueOn : NSControlStateValueOff;

    self.labelUnlockKeyFileHeader.hidden = !show;
    self.keyFilePopup.hidden = !show;
    self.yubiKeyHeaderStack.hidden = !show;
    self.yubiKeyPopup.hidden = !show;
}

- (void)bindUnlockButtons {

    [self bindBiometricButtonOnLockScreen];

    [self bindManualUnlockButtonFast];
}

- (void)bindTitlesAndBioAvailability {
    MacDatabasePreferences* database = self.databaseMetadata;
    
    self.textFieldDatabaseNickName.stringValue = database.nickName;
    self.textFieldBioUnavailableWarn.stringValue = @"";
    self.textFieldBioUnavailableWarn.hidden = YES;
    self.textFieldSubtitleOrPrompt.stringValue = NSLocalizedString(@"mac_lock_screen_enter_pw", @"Enter password to unlock.");

    if ( !database.isConvenienceUnlockEnabled ) { 
        return;
    }

    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL touchEnabled = (database.isTouchIdEnabled && touchAvailable);
    BOOL watchEnabled = (database.isWatchUnlockEnabled && watchAvailable);
    
    [database triggerPasswordExpiry];
    
    BOOL expired = database.conveniencePasswordHasExpired;
    BOOL isPro = Settings.sharedInstance.isPro;
    BOOL bioUnavailable = !touchEnabled && !watchEnabled;
    
    if ( !expired && isPro && !bioUnavailable ) {
        if ( touchEnabled && watchEnabled ) {
            self.textFieldSubtitleOrPrompt.stringValue = NSLocalizedString(@"mac_lock_screen_enter_pw_or_touchid_or_watch", @"Enter password or unlock with Touch ID/Watch.");
        }
        else if ( touchEnabled ) {
            self.textFieldSubtitleOrPrompt.stringValue = NSLocalizedString(@"mac_lock_screen_enter_pw_or_touchid", @"Enter password or unlock with Touch ID.");
        }
        else if ( watchEnabled ) {
            self.textFieldSubtitleOrPrompt.stringValue = NSLocalizedString(@"mac_lock_screen_enter_pw_or_watch", @"Enter password or unlock with Watch.");
        }
    }
    else {
        if ( bioUnavailable ) {
            self.textFieldBioUnavailableWarn.stringValue = NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_bio_unavailable", @"Touch ID/Watch Unavailable");
            self.textFieldBioUnavailableWarn.hidden = NO;
        }
        else if ( !isPro ) {
            self.textFieldBioUnavailableWarn.stringValue = NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_pro_only", @"Touch ID/Watch Unlock (Pro Only)");
            self.textFieldBioUnavailableWarn.hidden = NO;
        }
        else if( expired ) {
            self.textFieldBioUnavailableWarn.stringValue = NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_expired", @"Convenience Unlock Expired");
            self.textFieldBioUnavailableWarn.hidden = NO;
        }
    }
}




- (void)bindYubiKeyOnLockScreen {
    self.currentYubiKeySerial = nil;
    self.currentYubiKeySlot1IsBlocking = NO;
    self.currentYubiKeySlot2IsBlocking = NO;

    

    [self.yubiKeyPopup.menu removeAllItems];

    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    [self.yubiKeyPopup.menu addItemWithTitle:loc
                              action:nil
                       keyEquivalent:@""];
    self.yubiKeyPopup.enabled = NO;

    [MacHardwareKeyManager.sharedInstance getAvailableKey:^(HardwareKeyData * _Nonnull yk) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKey:yk];
        });
    }];
}

- (void)addNoneProHardwareKeyMenuItem {
    [self.yubiKeyPopup.menu removeAllItems];
    NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"Hardware Key (Pro Only)");
    [self.yubiKeyPopup.menu addItemWithTitle:loc action:nil keyEquivalent:@""];
    [self.yubiKeyPopup selectItemAtIndex:0];
}

- (NSMenuItem*)addNoneOrNoneAvailableHardwareKeyMenuItem:(NSUInteger)availableSlots {
    NSString* loc;
    if ( availableSlots > 0 ) {
        loc = [NSString stringWithFormat:NSLocalizedString(@"mac_hardware_key_dropdown_n_available_fmt", @"None (%@ Available)"), @(availableSlots)];
    }
    else {
        loc = NSLocalizedString(@"mac_hardware_key_dropdown_none_no_keys_detected", @"None (No Keys Detected)");
    }

    return [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectNoYubiKey) keyEquivalent:@""];
}

- (NSMenuItem*)addConfiguredButCRUnavailableHardwareKey {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_key_configured_but_cr_unavailable", @"🔴 Configured Key [CR Unavailable]");
    
    return [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectConfigured) keyEquivalent:@""];
}

- (NSMenuItem*)addConfiguredButUnavailableHardwareKey {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_key_configured_but_disconnected", @"⚠️ Disconnected Key (Configured)");
    return [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectConfigured) keyEquivalent:@""];
}

- (NSMenuItem*)addConfiguredAndReadyToGo:(YubiKeyConfiguration*)config {
    NSString* loc = [NSString stringWithFormat:NSLocalizedString(@"mac_hardware_key_configured_and_connected_slot_n_fmt", @"Connected Key Slot %@ (Configured)"), @(config.slot)];
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:@selector(onSelectConfigured) keyEquivalent:@""];
    
    item.identifier = @(config.slot).stringValue;
    
    return item;
}

- (NSMenuItem*)addConnectedAndReadyToGoAtSlot:(NSUInteger)slot {
    NSString* loc = [NSString stringWithFormat:NSLocalizedString(@"mac_hardware_key_connected_slot_n_fmt", @"Connected Key Slot %@"), @(slot)];
    NSMenuItem* item = [self.yubiKeyPopup.menu addItemWithTitle:loc action:slot == 1 ? @selector(onSelectYubiKeySlot1) : @selector(onSelectYubiKeySlot2) keyEquivalent:@""];
    
    item.identifier = @(slot).stringValue;
    
    return item;
}

- (NSMenuItem*)addConnectedAndReadyToGo:(YubiKeyConfiguration*)config {
    return [self addConnectedAndReadyToGoAtSlot:config.slot];
}

- (NSMenuItem*)addSelectedButUnavailableHardwareKey {
    NSString* loc = NSLocalizedString(@"mac_hardware_key_selected_but_has_been_disconnected", @"⚠️ Selected Key (Disconnected)");
    return [self.yubiKeyPopup.menu addItemWithTitle:loc action:nil keyEquivalent:@""];
}

- (NSMenuItem*)addConfigured:(YubiKeyConfiguration*)configuration
      connectedSerial:(NSString*)connectedSerial
       slot1CrEnabled:(BOOL)slot1CrEnabled
       slot2CrEnabled:(BOOL)slot2CrEnabled {
    BOOL deviceMatches = [configuration.deviceSerial isEqualToString:connectedSerial];
    BOOL slotGood = configuration.slot == 1 ? slot1CrEnabled : slot2CrEnabled;

    if ( deviceMatches ) {
        if ( slotGood ) {
            return [self addConfiguredAndReadyToGo:configuration];
        }
        else {
            return [self addConfiguredButCRUnavailableHardwareKey];
        }
    }
    else {
        return [self addConfiguredButUnavailableHardwareKey];
    }
}

- (NSMenuItem*)addSelected:(YubiKeyConfiguration*)configuration
    connectedSerial:(NSString*)connectedSerial
     slot1CrEnabled:(BOOL)slot1CrEnabled
     slot2CrEnabled:(BOOL)slot2CrEnabled {
    BOOL deviceMatches = [configuration.deviceSerial isEqualToString:connectedSerial];
    BOOL slotGood = configuration.slot == 1 ? slot1CrEnabled : slot2CrEnabled;

    if ( deviceMatches && slotGood ) {
        return [self addConnectedAndReadyToGo:configuration];
    }
    else {
        return [self addSelectedButUnavailableHardwareKey];
    }
}

- (void)onGotAvailableYubiKey:(HardwareKeyData*)yk {
    if ( !Settings.sharedInstance.isPro ) {
        [self addNoneProHardwareKeyMenuItem];
        self.yubiKeyPopup.enabled = NO;
        return;
    }

    [self.yubiKeyPopup.menu removeAllItems];
    
    

    self.currentYubiKeySerial = yk.serial;
    self.currentYubiKeySlot1IsBlocking = yk.slot1CrStatus == kHardwareKeySlotCrStatusSupportedBlocking;
    self.currentYubiKeySlot2IsBlocking = yk.slot2CrStatus == kHardwareKeySlotCrStatusSupportedBlocking;
    BOOL slot1CrEnabled = [self yubiKeyCrIsSupported:yk.slot1CrStatus];
    BOOL slot2CrEnabled = [self yubiKeyCrIsSupported:yk.slot2CrStatus];

    NSUInteger availableSlots = (slot1CrEnabled ? 1 : 0) + (slot2CrEnabled ? 1 : 0);

    

    NSMenuItem* none = [self addNoneOrNoneAvailableHardwareKeyMenuItem:availableSlots];

    
    
    YubiKeyConfiguration* configured = self.databaseMetadata.yubiKeyConfiguration;
    YubiKeyConfiguration* selected = self.selectedYubiKeyConfiguration;
    

    
    NSMenuItem* configuredMenuItem = nil;
    if ( configured ) {
        configuredMenuItem = [self addConfigured:configured connectedSerial:yk.serial slot1CrEnabled:slot1CrEnabled slot2CrEnabled:slot2CrEnabled];
    }
    
    NSMenuItem* selectedMenuItem = nil;
    if ( selected ) {
        if ( ![selected isEqual:configured] ) {
            selectedMenuItem = [self addSelected:selected connectedSerial:yk.serial slot1CrEnabled:slot1CrEnabled slot2CrEnabled:slot2CrEnabled];
        }
        else {
            selectedMenuItem = configuredMenuItem;
        }
    }

    BOOL configuredIsConnected = ([selected.deviceSerial isEqualToString:yk.serial]);
    BOOL selectedIsConnected = ([selected.deviceSerial isEqualToString:yk.serial]);
    
    BOOL slot1Added = (configured != nil && configuredIsConnected && configured.slot == 1) || (selected != nil && selectedIsConnected && selected.slot == 1);
    BOOL slot2Added = (configured != nil && configuredIsConnected && configured.slot == 2) || (selected != nil && selectedIsConnected && selected.slot == 2);
        
    if ( slot1CrEnabled && !slot1Added ) {
        [self addConnectedAndReadyToGoAtSlot:1];
    }
    if ( slot2CrEnabled && !slot2Added ) {
        [self addConnectedAndReadyToGoAtSlot:2];
    }
    
    
    
    if ( self.yubiKeyPopup.menu.numberOfItems == 3 ) { 
        NSMenuItem* a = self.yubiKeyPopup.menu.itemArray[1];
        NSMenuItem* b = self.yubiKeyPopup.menu.itemArray[2];
        
        if ( [a.identifier isEqualToString:@"2"] && [b.identifier isEqualToString:@"1"] ) { 
            [self.yubiKeyPopup.menu removeItemAtIndex:2];
            [self.yubiKeyPopup.menu insertItem:b atIndex:1];
        }
    }

    if ( selectedMenuItem ) {
        [self.yubiKeyPopup selectItem:selectedMenuItem];
    }
    else {
        [self.yubiKeyPopup selectItem:none];
    }
    
    self.yubiKeyPopup.enabled = availableSlots > 0 || configured;
}

- (BOOL)yubiKeyCrIsSupported:(HardwareKeySlotCrStatus)status {
    return status == kHardwareKeySlotCrStatusSupportedBlocking || status == kHardwareKeySlotCrStatusSupportedNonBlocking;
}

- (void)onSelectConfigured {
    self.selectedYubiKeyConfiguration = self.databaseMetadata.yubiKeyConfiguration;
}

- (void)onSelectNoYubiKey {
    self.selectedYubiKeyConfiguration = nil;
}

- (void)onSelectYubiKeySlot1 {
    self.selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    self.selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    self.selectedYubiKeyConfiguration.slot = 1;
}

- (void)onSelectYubiKeySlot2 {
    self.selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    self.selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    self.selectedYubiKeyConfiguration.slot = 2;
}




- (BOOL)keyFileIsSet {
   return self.selectedKeyFileBookmark != nil;
}

- (void)refreshKeyFileDropdown {
    [self.keyFilePopup.menu removeAllItems];
    
    
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_key_file_none", @"None")
                                      action:@selector(onSelectNoneKeyFile)
                               keyEquivalent:@""];
    
    [self.keyFilePopup.menu addItemWithTitle:NSLocalizedString(@"mac_browse_for_key_file", @"Browse...")
                                      action:@selector(onBrowseForKeyFile)
                               keyEquivalent:@""];
    
    

    MacDatabasePreferences *database = self.databaseMetadata;
    NSURL* configuredUrl;
    if ( database && database.keyFileBookmark ) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:database.keyFileBookmark
                                                   readOnly:YES updatedBookmark:&updatedBookmark
                                                      error:&error];
            
        if(!configuredUrl) {
            slog(@"getUrlFromBookmark Error / Nil: [%@]", error);
        }
        else {
           
            if(updatedBookmark) {
                database.keyFileBookmark = updatedBookmark;
            }
        }
    }

    
    
    NSURL* currentlySelectedUrl;
    if ( self.selectedKeyFileBookmark ) {
        NSString* updatedBookmark = nil;
        NSError* error;
        currentlySelectedUrl = [BookmarksHelper getUrlFromBookmark:self.selectedKeyFileBookmark readOnly:YES updatedBookmark:&updatedBookmark error:&error];
        
        if ( currentlySelectedUrl == nil ) {
            self.selectedKeyFileBookmark = nil;
        }
        
        if ( updatedBookmark ) {
            self.selectedKeyFileBookmark = updatedBookmark;
        }
    }

    if ( configuredUrl ) {
        NSString* configuredTitle = Settings.sharedInstance.hideKeyFileNameOnLockScreen ?
                                        NSLocalizedString(@"mac_key_file_configured_but_filename_hidden", @"[Configured]") :
                                        [NSString stringWithFormat:NSLocalizedString(@"mac_key_file_filename_configured_fmt", @"%@ [Configured]"), configuredUrl.lastPathComponent];
        
        [self.keyFilePopup.menu addItemWithTitle:configuredTitle action:@selector(onSelectPreconfiguredKeyFile) keyEquivalent:@""];
    
        if ( currentlySelectedUrl ) {
            if(![configuredUrl.absoluteString isEqualToString:currentlySelectedUrl.absoluteString]) {
                NSString* filename = currentlySelectedUrl.lastPathComponent;
                
                [self.keyFilePopup.menu addItemWithTitle:filename action:nil keyEquivalent:@""];
                [self.keyFilePopup selectItemAtIndex:3];
            }
            else {
                [self.keyFilePopup selectItemAtIndex:2];
            }
        }
    }
    else if ( currentlySelectedUrl ) {
        [self.keyFilePopup.menu addItemWithTitle:currentlySelectedUrl.lastPathComponent action:nil keyEquivalent:@""];
        [self.keyFilePopup selectItemAtIndex:2];
    }
    else {
        [self.keyFilePopup selectItemAtIndex:0];
    }
}

- (void)onBrowseForKeyFile {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    
    
    
    
    NSString* desktop = StrongboxFilesManager.sharedInstance.desktopPath;
    openPanel.directoryURL = desktop ? [NSURL fileURLWithPath:desktop] : nil;
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
            
            
            NSError* error;
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:openPanel.URL readOnly:YES error:&error];
            
            if(!bookmark) {
                [MacAlerts error:error window:self.view.window];
                [self refreshKeyFileDropdown];
                return;
            }

            self.selectedKeyFileBookmark = bookmark;
        }

        [self refreshKeyFileDropdown];
    }];
}

- (void)onSelectNoneKeyFile {
    self.selectedKeyFileBookmark = nil;
    [self refreshKeyFileDropdown];
}

- (void)onSelectPreconfiguredKeyFile {
    self.selectedKeyFileBookmark = self.databaseMetadata.keyFileBookmark;
    [self refreshKeyFileDropdown];
}




- (IBAction)onViewAllDatabases:(id)sender {
    [DBManagerPanel.sharedInstance show];
}

- (IBAction)onAllowEmptyChanged:(id)sender {
    Settings.sharedInstance.allowEmptyOrNoPasswordEntry = self.checkboxAllowEmpty.state == NSControlStateValueOn;
    
    [self bindUnlockButtons];
}

- (IBAction)onShowAdvancedOnUnlockScreen:(id)sender {
    self.viewModel.showAdvancedUnlockOptions = !self.viewModel.showAdvancedUnlockOptions;
    
    [self bindShowAdvancedOnUnlockScreen];
}

- (IBAction)onShowPasswordGenerator:(id)sender {
    [PasswordGenerator.sharedInstance show];
}




- (DatabaseFormat)getHeuristicFormat {
    BOOL probablyPasswordSafe = [self.viewModel.fileUrl.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; 

    return heuristicFormat;
}

- (BOOL)manualCredentialsAreValid {
    DatabaseFormat heuristicFormat = [self getHeuristicFormat];
    
    BOOL formatAllowsEmptyOrNone =  heuristicFormat == kKeePass4 ||
                                    heuristicFormat == kKeePass ||
                                    heuristicFormat == kFormatUnknown ||
                                    (heuristicFormat == kKeePass1 && [self keyFileIsSet]);
    
    return self.textFieldMasterPassword.stringValue.length || (formatAllowsEmptyOrNone && Settings.sharedInstance.allowEmptyOrNoPasswordEntry);
}

+ (NSViewController*)getAppropriateOnDemandViewController:(NSString*)databaseUuid {
    DocumentController* dc = DocumentController.sharedDocumentController;
    Document* doc = [dc documentForDatabase:databaseUuid];
    
    if ( doc && doc.windowControllers.firstObject.contentViewController ) {
        slog(@"✅ onDemand Provider returning from document: [%@]", doc.windowControllers.firstObject.contentViewController);

        return doc.windowControllers.firstObject.contentViewController;
    }
    else {

        [[NSRunningApplication currentApplication] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)]; 
        [NSApp arrangeInFront:nil];
        
        [DBManagerPanel.sharedInstance show];
        
        
        
        slog(@"✅ onDemand Provider returning DBManagerPanel: [%@]", DBManagerPanel.sharedInstance.contentViewController);

        return DBManagerPanel.sharedInstance.contentViewController;
    }
}

- (IBAction)onUnlock:(id)sender {
    if(![self manualCredentialsAreValid]) {
        return;
    }

    NSString* uuid = self.databaseMetadata.uuid;
    MacCompositeKeyDeterminer *determiner = [MacCompositeKeyDeterminer determinerWithDatabase:self.databaseMetadata
                                                             isNativeAutoFillAppExtensionOpen:NO
                                                                      isAutoFillQuickTypeOpen:NO
                                                                            onDemandUiProvider:^NSViewController * {
        return [LockScreenViewController getAppropriateOnDemandViewController:uuid];
    }];
    
    NSString* password = self.textFieldMasterPassword.stringValue;
    NSString* keyFileBookmark = self.selectedKeyFileBookmark;
    YubiKeyConfiguration* yubiKeyConfiguration = self.selectedYubiKeyConfiguration;

    [determiner getCkfsWithExplicitPassword:password
                            keyFileBookmark:keyFileBookmark
                       yubiKeyConfiguration:yubiKeyConfiguration
                                 completion:^(GetCompositeKeyResult result, CompositeKeyFactors* factors, BOOL fromConvenience, NSError* error) {
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)handleGetCkfsResult:(GetCompositeKeyResult)result
                    factors:(CompositeKeyFactors*)factors
            fromConvenience:(BOOL)fromConvenience
                      error:(NSError*)error {


    if ( result == kGetCompositeKeyResultSuccess ) {
        [self unlockWithCkfs:factors fromConvenience:fromConvenience];
    }
    else if (result == kGetCompositeKeyResultError ) {
        [MacAlerts error:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                   error:error
                  window:self.view.window];
    }
    else {
        
        slog(@"LockScreenViewController: Unlock Request Cancelled. NOP.");
    }
}

- (void)unlockWithCkfs:(CompositeKeyFactors*)compositeKeyFactors
       fromConvenience:(BOOL)fromConvenience {

    
    
    
    StorageProvider provider = self.databaseMetadata.storageProvider;
    BOOL sftpOrDav = provider == kSFTP || provider == kWebDAV;
    
    if ( sftpOrDav && !Settings.sharedInstance.isPro ) {
        [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                 window:self.view.window];
        return;
    }
    
    [self enableMasterCredentialsEntry:NO];
            
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self unlock:compositeKeyFactors
      viewController:self
 alertOnJustPwdWrong:NO
     fromConvenience:fromConvenience
          completion:^(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handleUnlockResult:success
                    incorrectCredentials:incorrectCredentials
                                    ckfs:compositeKeyFactors
                         fromConvenience:fromConvenience
                                   error:error];
            });
        }];
    });
}



- (void)unlock:(CompositeKeyFactors *)compositeKeyFactors
viewController:(NSViewController *)viewController
    alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
    fromConvenience:(BOOL)fromConvenience
    completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {

    
    if ( !self.databaseMetadata.userRequestOfflineOpenEphemeralFlagForDocument && !self.databaseMetadata.alwaysOpenOffline ) {

        
        [self syncWorkingCopyAndUnlock:viewController
                   alertOnJustPwdWrong:alertOnJustPwdWrong
                       fromConvenience:fromConvenience
                                   key:compositeKeyFactors
                            completion:completion];
    }
    else {
        slog(@"OFFLINE MODE: loadWorkingCopyAndUnlock");
        
        [self loadWorkingCopyAndUnlock:compositeKeyFactors
                        viewController:viewController
                   alertOnJustPwdWrong:alertOnJustPwdWrong
                       fromConvenience:fromConvenience
                               offline:YES
                            completion:completion];
    }
}

- (void)syncWorkingCopyAndUnlock:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                             key:(CompositeKeyFactors*)key
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {

    
    [macOSSpinnerUI.sharedInstance show:NSLocalizedString(@"storage_provider_status_syncing", @"Syncing...")
                         viewController:self];
    
    [DatabasesCollection.shared syncWithUuid:self.databaseMetadata.uuid
                            allowInteractive:YES
                         suppressErrorAlerts:YES
                             ckfsForConflict:key
                                  completion:^(SyncAndMergeResult result, BOOL localWasChanged, NSError * _Nullable error) {
        [macOSSpinnerUI.sharedInstance dismiss];
        
        if ( result == kSyncAndMergeSuccess ) {
            [self loadWorkingCopyAndUnlock:key
                            viewController:viewController
                       alertOnJustPwdWrong:alertOnJustPwdWrong
                           fromConvenience:fromConvenience
                                   offline:NO
                                completion:completion];
        }
        else if (result == kSyncAndMergeError ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self onSyncError:viewController
              alertOnJustPwdWrong:alertOnJustPwdWrong
                  fromConvenience:fromConvenience
                              key:key
                            error:error
                       completion:completion];
            });
        }
        else if (result == kSyncAndMergeResultUserCancelled ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, YES, NO, nil);
            });
        }
        else {
            slog(@"🔴 WARNWARN: Unhandled Sync Result [%lu] - error = [%@]", (unsigned long)result, error);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, NO, NO, error);
            });
        }
    }];
}

- (void)onSyncError:(NSViewController*)viewController
alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
   fromConvenience:(BOOL)fromConvenience
               key:(CompositeKeyFactors*)key
             error:(NSError*)error
        completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    if ( self.databaseMetadata.storageProvider == kLocalDevice && [self errorIndicatesWeShouldAskUseToRelocateDatabase:error] ) {
        completion(NO, NO, NO, error);
    }
    else {
        if ( [WorkingCopyManager.sharedInstance getLocalWorkingCacheUrlForDatabase:self.databaseMetadata.uuid] == nil ) {
            completion(NO, NO, NO, error);
        }
        else {
            NSString* message = NSLocalizedString(@"open_sequence_storage_provider_error_open_local_ro_instead", @"If this happens repeatedly you should try re-adding your database. See the Debug Sync Log for more...\n\nWould you like to open in offline mode instead?");
            
            NSString* viewSyncError = NSLocalizedString(@"safes_vc_action_view_sync_status", @"View Sync Log");

            [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"open_sequence_storage_provider_error_title", @"Sync Error")
                            informativeText:message
                          option1AndDefault:NSLocalizedString(@"open_sequence_yes_use_local_copy_option", @"Yes, Open Offline")
                                    option2:viewSyncError
                                     window:self.view.window completion:^(int response) {
                if ( response == 0 ) {
                    [self loadWorkingCopyAndUnlock:key
                                    viewController:viewController
                               alertOnJustPwdWrong:alertOnJustPwdWrong
                                   fromConvenience:fromConvenience
                                           offline:YES
                                        completion:completion];
                }
                else if (response == 1) {
                    [self showSyncLog];
                    completion(NO, YES, NO, nil);
                }
                else {
                    completion(NO, YES, NO, nil);
                }
            }];
        }
    }
}

- (void)showSyncLog {
    NSViewController* vc = [SyncLogViewController showForDatabase:self.viewModel.databaseMetadata];
    [self presentViewControllerAsSheet:vc];
}

- (void)loadWorkingCopyAndUnlock:(CompositeKeyFactors*)key
                  viewController:(NSViewController*)viewController
             alertOnJustPwdWrong:(BOOL)alertOnJustPwdWrong
                 fromConvenience:(BOOL)fromConvenience
                         offline:(BOOL)offline
                      completion:(void (^)(BOOL success, BOOL userCancelled, BOOL incorrectCredentials, NSError* error))completion {
    [DatabasesCollection.shared unlockModelFromLocalWorkingCopyWithDatabase:self.databaseMetadata
                                                                       ckfs:key
                                                            fromConvenience:fromConvenience
                                                        alertOnJustPwdWrong:alertOnJustPwdWrong
                                                     offlineUnlockRequested:offline
                                                        showProgressSpinner:YES
                                                                    eagerVc:viewController
                                                     suppressErrorMessaging:YES
                                                              forceReadOnly:NO
                                                                 completion:^(UnlockDatabaseResult result, Model *model, NSError* error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result == kUnlockDatabaseResultSuccess,
                       result == kUnlockDatabaseResultUserCancelled,
                       result == kUnlockDatabaseResultIncorrectCredentials,
                       error);
        });
    }];
}

- (void)onUnsuccessfulUnlock:(CompositeKeyFactors *)ckfs
                       error:(NSError *)error
             fromConvenience:(BOOL)fromConvenience
        incorrectCredentials:(BOOL)incorrectCredentials {
    [self enableMasterCredentialsEntry:YES];
    
    [self bindUI];
    
    [self setInitialFocus];
    
    if ( incorrectCredentials && !fromConvenience
        
        ) {
        [self showIncorrectPasswordToast];
    }
    else if (error) {
        if ( self.databaseMetadata.storageProvider == kLocalDevice && [self errorIndicatesWeShouldAskUseToRelocateDatabase:error] ) {
            [self askAboutRelocatingDatabase:ckfs fromConvenience:fromConvenience];
        }
        else {
            [MacAlerts error:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.") error:error window:self.view.window];
        }
    }
}



- (void)handleUnlockResult:(BOOL)success
      incorrectCredentials:(BOOL)incorrectCredentials
                      ckfs:(CompositeKeyFactors*)ckfs
           fromConvenience:(BOOL)fromConvenience
                     error:(NSError*)error {


    if ( success ) {
        [self enableMasterCredentialsEntry:YES];

        self.textFieldMasterPassword.stringValue = @"";
        [self stopObservingModelChanges];
        
        
        
        
        [BiometricIdHelper.sharedInstance invalidateCurrentRequest];
    }
    else {
        [self onUnsuccessfulUnlock:ckfs error:error fromConvenience:fromConvenience incorrectCredentials:incorrectCredentials];
    }
}



- (BOOL)errorIndicatesWeShouldAskUseToRelocateDatabase:(NSError*)error {
    return (error.code == NSFileReadNoPermissionError ||   
            error.code == NSFileReadNoSuchFileError ||     
            error.code == NSFileNoSuchFileError);
}

- (void)askAboutRelocatingDatabase:(CompositeKeyFactors*)factors fromConvenience:(BOOL)fromConvenience {
    NSString* relocateDatabase = NSLocalizedString(@"open_sequence_storage_provider_try_relocate_files_db", @"Locate Database...");
    
    [MacAlerts customOptionWithCancel:NSLocalizedString(@"relocate_database_title", @"Relocate Database")
                      informativeText:NSLocalizedString(@"relocate_database_msg", @"Strongbox's reference to this database has become invalid or the database cannot be found.\n\nPlease reselect this database from your files for Strongbox.")
                    option1AndDefault:relocateDatabase
                               window:self.view.window
                           completion:^(BOOL go) {
        if ( go ) {
            [self onRelocateFilesBasedDatabase:factors fromConvenience:fromConvenience];
        }
    }];
}

- (void)onRelocateFilesBasedDatabase:(CompositeKeyFactors*)factors fromConvenience:(BOOL)fromConvenience {
    NSOpenPanel* panel = NSOpenPanel.openPanel;
    
    NSURL* url;
    
    if ( [self.databaseMetadata.fileUrl.scheme isEqualToString:kStrongboxSyncManagedFileUrlScheme] ) {
        url = fileUrlFromManagedUrl(self.databaseMetadata.fileUrl);
    }
    else {
        url = self.databaseMetadata.fileUrl;
    }
    
    [panel setDirectoryURL:url]; 

    if ( [panel runModal] == NSModalResponseOK ) {
        slog (@"Reselected URL = [%@]", panel.URL);
        
        NSError* err;
        NSData* data = [NSData dataWithContentsOfURL:panel.URL options:kNilOptions error:&err];
 
        if ( !data || err ) {
            [MacAlerts error:err window:self.view.window];
        }
        else {
            [self readReselectedFilesDatabase:data url:panel.URL databaseFileName:url.lastPathComponent factors:factors fromConvenience:fromConvenience];
        }
    }
}

- (void)readReselectedFilesDatabase:(NSData*)data url:(NSURL*)url databaseFileName:(NSString*)databaseFileName factors:(CompositeKeyFactors*)factors fromConvenience:(BOOL)fromConvenience {
    NSError* error;

    if (![Serializator isValidDatabaseWithPrefix:data error:&error]) {
        [MacAlerts error:[NSString stringWithFormat:NSLocalizedString(@"open_sequence_invalid_database_filename_fmt", @"Invalid Database - [%@]"), url.lastPathComponent]
                   error:error
                  window:self.view.window];
        return;
    }

    if([url.lastPathComponent compare:databaseFileName] != NSOrderedSame) {
        [MacAlerts yesNo:NSLocalizedString(@"open_sequence_database_different_filename_title",@"Different Filename")
         informativeText:NSLocalizedString(@"open_sequence_database_different_filename_message",@"This doesn't look like it's the right file because the filename looks different than the one you originally added. Do you want to continue?")
                  window:self.view.window
              completion:^(BOOL yesNo) {
            if(yesNo) {
               [self updateFilesBookmarkWithRelocatedUrl:url factors:factors fromConvenience:fromConvenience];
            }
        }];
    }
    else {
        [self updateFilesBookmarkWithRelocatedUrl:url factors:factors fromConvenience:fromConvenience];
    }
}

- (void)updateFilesBookmarkWithRelocatedUrl:(NSURL*)url factors:(CompositeKeyFactors*)factors fromConvenience:(BOOL)fromConvenience {
    NSError* error;
    NSString * fileIdentifier = [BookmarksHelper getBookmarkFromUrl:url readOnly:NO error:&error];
    if (!fileIdentifier || error ) {
        [MacAlerts error:NSLocalizedString(@"open_sequence_error_could_not_bookmark_file", @"Could not bookmark this file")
                   error:error
                  window:self.view.window];
    }
    else {
        self.databaseMetadata.storageInfo = fileIdentifier;
        self.databaseMetadata.fileUrl = managedUrlFromFileUrl(url);

        [self unlockWithCkfs:factors fromConvenience:fromConvenience];
    }
}



- (void)controlTextDidChange:(id)obj {

    [self bindManualUnlockButtonFast];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    slog(@"🐞 [%@] Lock Screen Became Key! [%@]", notification.object, self.databaseMetadata.nickName);

    if ( notification.object == self.view.window ) {
        if( self.viewModel && self.viewModel.locked ) {
            [self bindUI];
        }

        
        
        if ( !self.useEmbeddedTouchID ) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self autoPromptForTouchIdIfDesired];
            });
        }
    }
}

- (void)autoPromptForTouchIdIfDesired {

    
    if(self.viewModel && self.viewModel.locked && !self.useEmbeddedTouchID ) { 
        BOOL weAreKeyWindow = NSApplication.sharedApplication.keyWindow == self.view.window;

        if( weAreKeyWindow && self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate && self.bioOrWatchUnlockIsPossible ) {
            NSTimeInterval secondsBetween = [NSDate.date timeIntervalSinceDate:self.biometricPromptLastDismissedAt];
            if(self.biometricPromptLastDismissedAt != nil && secondsBetween < 1.5) {
                slog(@"Too many auto biometric requests too soon - ignoring...");
                return;
            }

            [self onUnlockWithConvenience:nil];
        }
    }
}

- (void)enableMasterCredentialsEntry:(BOOL)enable {
    [self.textFieldMasterPassword setEnabled:enable];



    [self.keyFilePopup setEnabled:enable];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.view.window.isMiniaturized ) {
        slog(@"Not Showing Popup Change notification because window is miniaturized");
        return;
    }

    [self showToastNotification:message error:error yOffset:150.f];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error yOffset:(CGFloat)yOffset {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSColor *defaultColor = [NSColor colorWithDeviceRed:0.23 green:0.5 blue:0.82 alpha:0.60];
        NSColor *errorColor = [NSColor colorWithDeviceRed:1 green:0.55 blue:0.05 alpha:0.90];

        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.labelText = message;
        hud.color = error ? errorColor : defaultColor;
        hud.mode = MBProgressHUDModeText;
        hud.margin = 10.f;
        hud.yOffset = yOffset;
        hud.removeFromSuperViewOnHide = YES;
        hud.dismissible = YES;
        
        NSTimeInterval delay = error ? 3.0f : 1.0f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [hud hide:YES];
        });
    });
}



- (void)keyDown:(NSEvent *)event {
    BOOL cmd = ((event.modifierFlags & NSEventModifierFlagCommand) == NSEventModifierFlagCommand);
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];

    if ( cmd && key > 48 && key < 58 ) {
        NSUInteger number = key - 48;

        

        [self onCmdPlusNumberPressed:number];
        return;
    }

    [super keyDown:event];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSEvent *event = [control.window currentEvent];
    

    if (commandSelector == NSSelectorFromString(@"noop:")) { 
        if ( (event.modifierFlags & NSEventModifierFlagCommand ) == NSEventModifierFlagCommand) {
            NSString *chars = event.charactersIgnoringModifiers;
            unichar aChar = [chars characterAtIndex:0];

            if ( aChar > 48 && aChar < 58 ) {
                NSUInteger number = aChar - 48;

                [self onCmdPlusNumberPressed:number];
                return YES;
            }
        }
    }

    if( control == self.textFieldMasterPassword ) {
        if (commandSelector == @selector(insertTab:)) {
            if ( self.bioOrWatchUnlockIsPossible && !self.useEmbeddedTouchID ) {
                [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
            }
            else if ( [self manualCredentialsAreValid] ) {
                [self.view.window makeFirstResponder:self.buttonUnlockWithPassword];
            }

            return YES;
        }
    }

    return NO;
}

- (void)onCmdPlusNumberPressed:(NSUInteger)number {
    
    
    
    
    NSWindowTabGroup* group = self.view.window.tabGroup;
    
    if ( self.view.window.tabbedWindows && number <= self.view.window.tabbedWindows.count ) {
        group.selectedWindow = self.view.window.tabbedWindows[number - 1];
    }
}

- (IBAction)onToggleAutoPromptOnActivate:(id)sender {
    self.viewModel.autoPromptForConvenienceUnlockOnActivate = !self.viewModel.autoPromptForConvenienceUnlockOnActivate;
    
    [self bindUnlockButtons];
}

- (void)showIncorrectPasswordToast {
    CGFloat yOffset = self.checkboxShowAdvanced.state == NSControlStateValueOn ? -125.0f : -75.0f; 
    [self showToastNotification:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.") error:YES yOffset:yOffset];
}




- (BOOL)useEmbeddedTouchID {
    return YES;
}

- (BOOL)bioOrWatchUnlockIsPossible {
    return [MacCompositeKeyDeterminer bioOrWatchUnlockIsPossible:self.databaseMetadata];
}

- (void)embedTouchIDIfAvailable {
    self.dummyEmbeddedTouchIDImageView.hidden = YES; 

    if ( !self.useEmbeddedTouchID ) {
        return;
    }
    
    
    
    self.embeddedTouchIdContext = [[LAContext alloc] init];
    self.embeddedLaAuthenticationView = [[LAAuthenticationView alloc] initWithContext:self.embeddedTouchIdContext controlSize:NSControlSizeRegular];
    
    [self.embeddedLaAuthenticationView removeConstraints:self.embeddedLaAuthenticationView.constraints];
    
    self.embeddedLaAuthenticationView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.embeddedLaAuthenticationView.widthAnchor constraintEqualToConstant:30],
        [self.embeddedLaAuthenticationView.heightAnchor constraintEqualToConstant:30],
    ]];

    [self.masterPasswordAndEmbeddedTouchIDStack addArrangedSubview:self.embeddedLaAuthenticationView];
    
    
    

    





    
    



    



    





    

}

- (void)requestEmbeddedBioUnlock {
    if ( !self.useEmbeddedTouchID ) {
        return;
    }
    
    NSUInteger policy = [BiometricIdHelper.sharedInstance getPolicyForDatabase:self.databaseMetadata];
    
    NSError *authError;
    if( ![self.embeddedTouchIdContext canEvaluatePolicy:policy error:&authError] ) {
        [self setEmbeddedBioErrorTextWithError:authError];
        return;
    }
        
    [self setEmbeddedBioErrorTextWithError:nil];
    
    [self.embeddedTouchIdContext evaluatePolicy:policy
                                localizedReason:NSLocalizedString(@"mac_biometrics_identify_to_open_database", @"Unlock Database")
                                          reply:^(BOOL success, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( success ) {
                [self onTouchIDOrWatchUnlockEmbeddedSuccess];
            }
            else {
                [self setEmbeddedBioErrorTextWithError:error];
            }
        });
    }];
}

- (IBAction)onUnlockWithConvenience:(id)sender {
    if ( !self.bioOrWatchUnlockIsPossible ) {
        slog(@"🔴 WARNWARN - convenienceUnlockIsPossible but attempt initiated pressed?");
        [self bindUI];
        return;
    }
    
    NSString* uuid = self.databaseMetadata.uuid;
    
    MacCompositeKeyDeterminer *determiner = [MacCompositeKeyDeterminer determinerWithDatabase:self.databaseMetadata
                                                             isNativeAutoFillAppExtensionOpen:NO
                                                                      isAutoFillQuickTypeOpen:NO
                                                                           onDemandUiProvider:^NSViewController * {
        return [LockScreenViewController getAppropriateOnDemandViewController:uuid];
    }];
    
    NSString* keyFileBookmark = self.selectedKeyFileBookmark;
    YubiKeyConfiguration* yubiKeyConfiguration = self.selectedYubiKeyConfiguration;
    
    [determiner getCkfsWithBiometrics:keyFileBookmark
                 yubiKeyConfiguration:yubiKeyConfiguration
                           completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        self.biometricPromptLastDismissedAt = NSDate.date;
        
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)onTouchIDOrWatchUnlockEmbeddedSuccess {
    
    
    if ( !self.bioOrWatchUnlockIsPossible ) {
        slog(@"🔴 WARNWARN - convenienceUnlockIsPossible but attempt initiated pressed?");
        [self bindUI];
        return;
    }
    
    NSString* uuid = self.databaseMetadata.uuid;
    MacCompositeKeyDeterminer *determiner = [MacCompositeKeyDeterminer determinerWithDatabase:self.databaseMetadata
                                                             isNativeAutoFillAppExtensionOpen:NO
                                                                      isAutoFillQuickTypeOpen:NO
                                                                           onDemandUiProvider:^NSViewController * {
        return [LockScreenViewController getAppropriateOnDemandViewController:uuid];
    }];
    
    NSString* keyFileBookmark = self.selectedKeyFileBookmark;
    YubiKeyConfiguration* yubiKeyConfiguration = self.selectedYubiKeyConfiguration;
    
    [determiner getCkfsAfterSuccessfulBiometricAuth:keyFileBookmark
                               yubiKeyConfiguration:yubiKeyConfiguration
                                         completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        
        
        
        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (NSString*)getBiometricTooltip {
    MacDatabasePreferences* database = self.databaseMetadata;
    
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL touchEnabled = (database.isTouchIdEnabled && touchAvailable);
    BOOL watchEnabled = (database.isWatchUnlockEnabled && watchAvailable);
    
    NSString* convenienceTitle;
    
    if ( touchEnabled && watchEnabled ) {
        NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
        convenienceTitle = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    }
    else if ( touchEnabled ) {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_touch_id", @"Unlock with Touch ID");
    }
    else {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_apple_watch", @"Unlock with Watch");
    }
    
    return convenienceTitle;
}

- (void)bindBiometricButtonOnLockScreen {
    self.embeddedLaAuthenticationView.hidden = YES;

    self.buttonUnlockWithTouchId.hidden = YES;
    self.checkboxAutoPromptOnActivate.hidden = YES;
    











    
    BOOL isPossible = self.bioOrWatchUnlockIsPossible;
    
    
    
    

        if ( isPossible ) {
            self.embeddedLaAuthenticationView.hidden = NO;

            NSString* bioPrompt = [self getBiometricTooltip];

            self.embeddedLaAuthenticationView.toolTip = bioPrompt;

            [self requestEmbeddedBioUnlock];
        }













}

- (void)bindManualUnlockButtonFast { 
    BOOL enabled = [self manualCredentialsAreValid];

    
    
    self.buttonUnlockWithPassword.hidden = YES; 

    
    self.imageButtonUnlock.hidden = !enabled; 

    
    self.boxVertLineDivider.hidden = self.imageButtonUnlock.hidden || self.embeddedLaAuthenticationView.hidden;
}

- (void)setEmbeddedBioErrorTextWithError:(NSError*_Nullable)error {
    if ( error ) {
        if ( [error.domain isEqualToString:LAErrorDomain] ) {
            if (( error.code == kLAErrorUserCancel || error.code == kLAErrorSystemCancel ) ) {
                error = nil; 
            }
        }
    }

    if ( error ) {
        slog(@"🔴 %@", error, error.code);
    }
    
    self.textFieldError.stringValue = error ? error.localizedDescription : @"";
    self.textFieldError.hidden = error == nil;
}

@end
