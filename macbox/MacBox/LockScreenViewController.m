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
#import "DatabasesManagerVC.h"
#import "BookmarksHelper.h"
#import "DatabasesManager.h"
#import "StrongboxErrorCodes.h"
#import "KeyFileParser.h"
#import "MBProgressHUD.h"
#import "MacCompositeKeyDeterminer.h"
#import "NSDate+Extensions.h"


#ifndef IS_APP_EXTENSION
#import "Strongbox-Swift.h"
#else
#import "Strongbox_Auto_Fill-Swift.h"
#endif

@interface LockScreenViewController () < NSTextFieldDelegate >

@property BOOL hasLoaded;
@property (weak) Document*_Nullable document;
@property (readonly) ViewModel*_Nullable viewModel;
@property (readonly) DatabaseMetadata*_Nullable databaseMetadata;

@property (weak) IBOutlet NSTextField *textFieldVersion;
@property (weak) IBOutlet NSButton *buttonUnlockWithTouchId;
@property (weak) IBOutlet KSPasswordField *textFieldMasterPassword;
@property (weak) IBOutlet NSButton *checkboxShowAdvanced;
@property (weak) IBOutlet NSPopUpButton *yubiKeyPopup;
@property (weak) IBOutlet NSButton *checkboxAllowEmpty;
@property (weak) IBOutlet NSTextField *labelUnlockKeyFileHeader;
@property (weak) IBOutlet NSTextField *labelUnlockYubiKeyHeader;
@property (weak) IBOutlet NSPopUpButton *keyFilePopup;
@property (weak) IBOutlet NSButton *buttonToggleRevealMasterPasswordTip;
@property (weak) IBOutlet NSStackView *stackViewUnlock;
@property (weak) IBOutlet NSStackView *stackViewMasterPasswordHeader;
@property (weak) IBOutlet NSButton *upgradeButton;
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

@end

@implementation LockScreenViewController

- (void)dealloc {
    NSLog(@"DEALLOC [%@]", self);
}

- (ViewModel *)viewModel {
    return self.document.viewModel;
}

- (DatabaseMetadata*)databaseMetadata {
    return self.viewModel.databaseMetadata;
}

- (void)viewDidLoad {
    [super viewDidLoad];



    
    
    
    [self customizeUi];
}

- (void)customizeUi {
    NSString* fmt2 = Settings.sharedInstance.fullVersion ? NSLocalizedString(@"subtitle_app_version_info_pro_fmt", @"Strongbox Pro %@") : NSLocalizedString(@"subtitle_app_version_info_none_pro_fmt", @"Strongbox %@");
    
    NSString* about = [NSString stringWithFormat:fmt2, [Utils getAppVersion]];
    self.textFieldVersion.stringValue = about;
        
    [self customizeLockStackViewSpacing];
            
    NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
    self.buttonUnlockWithTouchId.title = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    self.buttonUnlockWithTouchId.hidden = YES;

    [self bindRevealMasterPasswordTextField];
    
    self.textFieldMasterPassword.delegate = self;
    
    [self bindProOrFreeTrial];
}

- (void)customizeLockStackViewSpacing {
    [self.stackViewUnlock setCustomSpacing:3 afterView:self.stackViewMasterPasswordHeader];
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
        
    [self.view.window setLevel:Settings.sharedInstance.floatOnTop ? NSFloatingWindowLevel : NSNormalWindowLevel];

    [self setInitialFocus];
}

- (void)setInitialFocus {
    if(self.viewModel == nil || self.viewModel.locked) {
        if([self bioOrWatchUnlockIsPossible]) {
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



    
    
    [self startObservingModelChanges];
    
    [self.view.window.windowController synchronizeWindowTitleWithDocumentName]; 

    if ( Settings.sharedInstance.nextGenUI ) {
        if (@available(macOS 11.0, *)) {
            self.view.window.subtitle = @"Lock Screen Subtitle - do or say something?"; 
        }
    }
    
    self.selectedKeyFileBookmark = self.viewModel ? self.databaseMetadata.keyFileBookmark : nil;
    self.selectedYubiKeyConfiguration = self.viewModel ? self.databaseMetadata.yubiKeyConfiguration : nil;

    
    if ( !self.databaseMetadata.hasSetInitialWindowPosition ) {
        NSLog(@"First Launch of Database! Making reasonable size and centering...");
        [self.view.window setFrame:NSMakeRect(0,0, 600, 750) display:YES];
        [self.view.window center];
        
        [DatabasesManager.sharedInstance atomicUpdate:self.databaseMetadata.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            metadata.hasSetInitialWindowPosition = YES;
        }];
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
    NSLog(@"LockScreenViewController::stopObservingModelChanges");
    
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
        NSLog(@"LockScreenViewController::windowWillClose");
        [self stopObservingModelChanges];
    }
}

- (void)onDatabasePreferencesChanged:(NSNotification*)param {
    if(param.object != self.viewModel) {
        return;
    }

    NSLog(@"LockScreenViewController::onDatabasePreferencesChanged");

    [self.view.window.windowController synchronizeWindowTitleWithDocumentName]; 
}



- (void)bindUI {
    [self bindProOrFreeTrial];
    
    [self bindUnlockButtons];
        
    [self refreshKeyFileDropdown];
    
    [self bindYubiKeyOnLockScreen];
    
    [self bindShowAdvancedOnUnlockScreen];
}

- (void)bindRevealMasterPasswordTextField {
    NSImage* img = nil;
    
    if (@available(macOS 11.0, *)) {
        img = [NSImage imageWithSystemSymbolName:!self.textFieldMasterPassword.showsText ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""];
    } else {
        img = !self.textFieldMasterPassword.showsText ?
         [NSImage imageNamed:@"show"] : [NSImage imageNamed:@"hide"];
    }
    
    [self.buttonToggleRevealMasterPasswordTip setImage:img];
}

- (void)bindProOrFreeTrial {
    if (!Settings.sharedInstance.fullVersion && !Settings.sharedInstance.freeTrial) {
        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:self.upgradeButton.title];
        NSUInteger len = [attrTitle length];
        NSRange range = NSMakeRange(0, len);
        [attrTitle addAttribute:NSForegroundColorAttributeName value:NSColor.systemRedColor range:range];
        [attrTitle addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:NSFont.systemFontSize] range:range];

        [attrTitle fixAttributesInRange:range];
        [self.upgradeButton setAttributedTitle:attrTitle];
    }
    
    self.upgradeButton.hidden = Settings.sharedInstance.fullVersion;
}

- (void)bindShowAdvancedOnUnlockScreen {
    BOOL show = self.viewModel.showAdvancedUnlockOptions;
    
    self.checkboxShowAdvanced.state = show ? NSControlStateValueOn : NSControlStateValueOff;
    
    self.checkboxAllowEmpty.hidden = !show;
    self.checkboxAllowEmpty.state = Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSOnState : NSOffState;

    self.labelUnlockKeyFileHeader.hidden = !show;
    self.keyFilePopup.hidden = !show;
    self.yubiKeyHeaderStack.hidden = !show;
    self.yubiKeyPopup.hidden = !show;
}

- (void)bindUnlockButtons {
    BOOL enabled = [self manualCredentialsAreValid];
    
    [self.buttonUnlockWithPassword setEnabled:enabled];

    [self bindBiometricButtonOnLockScreen];
}

- (void)bindBiometricButtonOnLockScreen {
    DatabaseMetadata* database = self.databaseMetadata;
        
    BOOL passwordAvailable = database.conveniencePasswordHasBeenStored;
    BOOL convenienceEnabled = database.isConvenienceUnlockEnabled;
    
    if( !convenienceEnabled || !passwordAvailable) {
        NSLog(@"Convenience Unlock disabled or password unavailable.");
        self.buttonUnlockWithTouchId.hidden = YES;
        self.checkboxAutoPromptOnActivate.hidden = YES;
        return;
    }

    
    
    BOOL possible = [self bioOrWatchUnlockIsPossible];
    self.buttonUnlockWithTouchId.hidden = NO;
    self.buttonUnlockWithTouchId.enabled = possible;
    [self.buttonUnlockWithTouchId setKeyEquivalent:possible ? @"\r" : @""];

    self.checkboxAutoPromptOnActivate.hidden = NO;
    self.checkboxAutoPromptOnActivate.enabled = possible;
    self.checkboxAutoPromptOnActivate.state = self.viewModel.autoPromptForConvenienceUnlockOnActivate ? NSControlStateValueOn : NSControlStateValueOff;

    
    
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
    BOOL touchEnabled = (database.isTouchIdEnabled && touchAvailable);
    BOOL watchEnabled = (database.isWatchUnlockEnabled && watchAvailable);
    [database triggerPasswordExpiry];
    BOOL expired = database.conveniencePasswordHasExpired;

    if ( !touchEnabled && !watchEnabled ) {
        [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_bio_unavailable", @"Biometrics/Watch Unavailable")];
    }
    else if ( !Settings.sharedInstance.isProOrFreeTrial ) {
        [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_pro_only", @"Biometrics/Watch Unlock (Pro Only)")];
    }
    else if( expired ) {
        [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_expired", @"Convenience Unlock Expired")];
    }
    else {
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

        [self.buttonUnlockWithTouchId setTitle:convenienceTitle];
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
    if (!Settings.sharedInstance.isProOrFreeTrial ) {
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
    
    

    DatabaseMetadata *database = self.databaseMetadata;
    NSURL* configuredUrl;
    if ( database && database.keyFileBookmark ) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:database.keyFileBookmark
                                                   readOnly:YES updatedBookmark:&updatedBookmark
                                                      error:&error];
            
        if(!configuredUrl) {
            NSLog(@"getUrlFromBookmark Error / Nil: [%@]", error);
        }
        else {
           
            if(updatedBookmark) {
                [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                                        touch:^(DatabaseMetadata * _Nonnull metadata) {
                    metadata.keyFileBookmark = updatedBookmark;
                }];
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
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSLog(@"Open Key File: %@", openPanel.URL);
            
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

- (IBAction)toggleRevealMasterPasswordTextField:(id)sender {
    self.textFieldMasterPassword.showsText = !self.textFieldMasterPassword.showsText;

    [self bindRevealMasterPasswordTextField];
}

- (IBAction)onAllowEmptyChanged:(id)sender {
    Settings.sharedInstance.allowEmptyOrNoPasswordEntry = self.checkboxAllowEmpty.state == NSOnState;
    
    [self bindUnlockButtons];
}

- (IBAction)onShowAdvancedOnUnlockScreen:(id)sender {
    self.viewModel.showAdvancedUnlockOptions = !self.viewModel.showAdvancedUnlockOptions;
    
    [self bindShowAdvancedOnUnlockScreen];
}

- (IBAction)onUpgrade:(id)sender {
    AppDelegate* appDelegate = (AppDelegate*)[NSApplication sharedApplication].delegate;
    [appDelegate showUpgradeModal:0];
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

- (IBAction)onUnlock:(id)sender {
    if(![self manualCredentialsAreValid]) {
        return;
    }

    MacCompositeKeyDeterminer *determiner = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                           database:self.databaseMetadata
                                                                                     isAutoFillOpen:NO];

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

- (IBAction)onUnlockWithConvenience:(id)sender {
    MacCompositeKeyDeterminer* determiner = [MacCompositeKeyDeterminer determinerWithViewController:self
                                                                                           database:self.databaseMetadata
                                                                                     isAutoFillOpen:NO];

    if ( !determiner.bioOrWatchUnlockIsPossible ) {
        NSLog(@"🔴 WARNWARN - convenienceUnlockIsPossible but attempt initiated pressed?");
        [self bindUI];
        return;
    }

    NSString* keyFileBookmark = self.selectedKeyFileBookmark;
    YubiKeyConfiguration* yubiKeyConfiguration = self.selectedYubiKeyConfiguration;

    [determiner getCkfsWithBiometrics:keyFileBookmark
                 yubiKeyConfiguration:yubiKeyConfiguration
                           completion:^(GetCompositeKeyResult result, CompositeKeyFactors * _Nullable factors, BOOL fromConvenience, NSError * _Nullable error) {
        self.biometricPromptLastDismissedAt = NSDate.date;

        [self handleGetCkfsResult:result factors:factors fromConvenience:fromConvenience error:error];
    }];
}

- (void)handleGetCkfsResult:(GetCompositeKeyResult)result
                    factors:(CompositeKeyFactors*)factors
            fromConvenience:(BOOL)fromConvenience
                      error:(NSError*)error {
    NSLog(@"LockScreenViewController -> handleGetCkfsResult [%@] - Error = [%@] - Convenience = [%hhd]", result == kGetCompositeKeyResultSuccess ? @"Succeeded" : @"Failed", error, fromConvenience);

    if ( result == kGetCompositeKeyResultSuccess ) {
        [self unlockWithCkfs:factors fromConvenience:fromConvenience];
    }
    else if (result == kGetCompositeKeyResultError ) {
        [MacAlerts error:NSLocalizedString(@"open_sequence_problem_opening_title", @"There was a problem opening the database.")
                   error:error
                  window:self.view.window];
    }
    else {
        
        NSLog(@"LockScreenViewController: Unlock Request Cancelled. NOP.");
    }
}

- (void)unlockWithCkfs:(CompositeKeyFactors*)compositeKeyFactors fromConvenience:(BOOL)fromConvenience {
    NSLog(@"LockScreenViewController::unlockWithCkfs ENTER");
    
    
    
    if ( self.databaseMetadata.storageProvider != kMacFile && !Settings.sharedInstance.isProOrFreeTrial ) {
        [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                 window:self.view.window];
        return;
    }
    
    [self enableMasterCredentialsEntry:NO];
            
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.document revertWithUnlock:compositeKeyFactors
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

- (void)handleUnlockResult:(BOOL)success
      incorrectCredentials:(BOOL)incorrectCredentials
                      ckfs:(CompositeKeyFactors*)ckfs
           fromConvenience:(BOOL)fromConvenience
                     error:(NSError*)error {
    NSLog(@"LockScreenViewController -> handleUnlockResult [%@] - error = [%@]", success ? @"Succeeded" : @"Failed", error);

    [self enableMasterCredentialsEntry:YES];
    
    if(success) {
        self.textFieldMasterPassword.stringValue = @"";
        [self stopObservingModelChanges];
    }
    else {
        [self bindUI];
        
        [self setInitialFocus];

        
        
        
        if ( incorrectCredentials && !fromConvenience && ( ckfs.keyFileDigest == nil && ckfs.yubiKeyCR == nil ) ) {
            [self showIncorrectPasswordToast];
        }



    }
}



- (void)controlTextDidChange:(id)obj {

    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlockWithPassword setEnabled:enabled];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {


    if ( notification.object == self.view.window ) {
        if( self.viewModel && self.viewModel.locked ) {
            [self bindUI];
        }

        
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self autoPromptForTouchIdIfDesired];
        });
    }
}

- (void)autoPromptForTouchIdIfDesired {

    
    if(self.viewModel && self.viewModel.locked) {
        BOOL weAreKeyWindow = NSApplication.sharedApplication.keyWindow == self.view.window;

        if( weAreKeyWindow && self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate && [self bioOrWatchUnlockIsPossible] ) {
            NSTimeInterval secondsBetween = [NSDate.date timeIntervalSinceDate:self.biometricPromptLastDismissedAt];
            if(self.biometricPromptLastDismissedAt != nil && secondsBetween < 1.5) {
                NSLog(@"Too many auto biometric requests too soon - ignoring...");
                return;
            }

            [self onUnlockWithConvenience:nil];
        }
    }
}

- (void)enableMasterCredentialsEntry:(BOOL)enable {
    [self.textFieldMasterPassword setEnabled:enable];
    [self.buttonUnlockWithTouchId setEnabled:enable];
    [self.buttonUnlockWithPassword setEnabled:enable];
    [self.keyFilePopup setEnabled:enable];
}

- (void)showToastNotification:(NSString*)message error:(BOOL)error {
    if ( self.view.window.isMiniaturized ) {
        NSLog(@"Not Showing Popup Change notification because window is miniaturized");
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
        if ( (event.modifierFlags & NSCommandKeyMask ) == NSCommandKeyMask) {
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
            if([self bioOrWatchUnlockIsPossible]) {
                [self.view.window makeFirstResponder:self.buttonUnlockWithTouchId];
            }
            else {
                [self.view.window makeFirstResponder:self.buttonUnlockWithPassword];
            }

            return YES;
        }
    }

    return NO;
}

- (void)onCmdPlusNumberPressed:(NSUInteger)number {
    

    if (@available(macOS 10.13, *)) {


        NSWindowTabGroup* group = self.view.window.tabGroup;

        if ( self.view.window.tabbedWindows && number <= self.view.window.tabbedWindows.count ) {
            group.selectedWindow = self.view.window.tabbedWindows[number - 1];
        }
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

- (BOOL)bioOrWatchUnlockIsPossible {
    return [MacCompositeKeyDeterminer bioOrWatchUnlockIsPossible:self.databaseMetadata];
}

@end
