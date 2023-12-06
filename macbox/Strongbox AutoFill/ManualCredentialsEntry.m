//
//  ManualCredentialsEntry.m
//  Strongbox AutoFill
//
//  Created by Strongbox on 16/11/2020.
//  Copyright © 2020 Mark McGuill. All rights reserved.
//

#import "ManualCredentialsEntry.h"
#import "KSPasswordField.h"
#import "Settings.h"
#import "DatabaseModel.h"
#import "MacHardwareKeyManager.h"
#import "BookmarksHelper.h"
#import "MacAlerts.h"
#import "StrongboxMacFilesManager.h"
#import "DatabasesManagerVC.h"
#import "Constants.h"







@interface ManualCredentialsEntry () <NSTextFieldDelegate>

@property (weak) IBOutlet NSStackView *masterStackView;
@property (weak) IBOutlet NSStackView *stackViewLogo;

@property (weak) IBOutlet NSStackView *stackViewLabelPasswordAndRevealConceal;
@property (weak) IBOutlet NSTextField *labelPassword;
@property (weak) IBOutlet NSButton *buttonRevealConceal;
@property (weak) IBOutlet KSPasswordField *textFieldPassword;

@property (weak) IBOutlet NSButton *checkboxShowAdvanced;
@property (weak) IBOutlet NSTextField *labelKeyFile;
@property (weak) IBOutlet NSPopUpButton *popupKeyFile;
@property (weak) IBOutlet NSTextField *labelYubiKey;
@property (weak) IBOutlet NSPopUpButton *yubiKeyPopup;
@property (weak) IBOutlet NSButton *buttonUnlock;
@property (weak) IBOutlet NSButton *acceptEmptyPassword;

@property YubiKeyConfiguration *selectedYubiKeyConfiguration;
@property NSString* selectedKeyFileBookmark;

@property BOOL concealed;

@property BOOL currentYubiKeySlot1IsBlocking;
@property BOOL currentYubiKeySlot2IsBlocking;
@property NSString* currentYubiKeySerial;

@property BOOL hasSetInitialFocus;

@property (readonly) MacDatabasePreferences* database;
@property (nullable) NSString* contextAwareKeyFileBookmark;

@property (weak) IBOutlet NSStackView *stackHardwareKey;
@property (weak) IBOutlet NSTextField *textFIeldHeadline;
@property (weak) IBOutlet NSTextField *textFieldSubheadline;

@end

@implementation ManualCredentialsEntry

- (MacDatabasePreferences*)database {
    return [MacDatabasePreferences fromUuid:self.databaseUuid];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.textFieldPassword.delegate = self;
    [self fixStackViewSpacing];
    
    NSImageSymbolConfiguration* imageConfig = [NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge];
    
    [self.buttonUnlock setImage:[NSImage imageWithSystemSymbolName:@"lock.open.fill" accessibilityDescription:nil]];
    self.buttonUnlock.symbolConfiguration = imageConfig;
    
    self.concealed = YES;
    
    if ( !self.verifyCkfsMode ) {
        self.selectedKeyFileBookmark = [self contextAwareKeyFileBookmark];
        self.selectedYubiKeyConfiguration = self.database.yubiKeyConfiguration;
    }
    
    if ( self.headline ) {
        self.textFIeldHeadline.stringValue = self.headline;
    }
    
    if ( self.subheadline.length ) {
        self.textFieldSubheadline.stringValue = self.subheadline;
    }
    else {
        self.textFieldSubheadline.hidden = YES;
    }
    
    [self bindUi];
    [self validateUI];
    
    [self listenForDatabaseUnlock]; 
}

- (void)listenForDatabaseUnlock {
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(onDatabaseLockStatusChanged:)
                                               name:kDatabasesCollectionLockStateChangedNotification
                                             object:nil];
}

- (void)onDatabaseLockStatusChanged:(NSNotification*)notification {
    NSString* databaseUuid = notification.object;
    
    if ( [databaseUuid isEqualToString:self.databaseUuid] ) {
        NSLog(@"✅ ManualCredentialsEntry::onDatabaseLockStatusChanged: [%@]", notification);
        
        [self onCancel:nil];
    }
}

- (void)viewWillAppear {
    [super viewWillAppear];

    [self setTitle:NSLocalizedString(@"mac_enter_database_master_credentials", "Enter Master Credentials")];
    
    NSWindow* window = self.view.window;

    NSButton *closeButton = [window standardWindowButton:NSWindowCloseButton];

    [closeButton setEnabled:NO];
    
    if (!self.hasSetInitialFocus) {
        self.hasSetInitialFocus = YES;
        [self.textFieldPassword becomeFirstResponder];
    }
}

- (void)bindUi {
    [self bindAdvanced];
    
    [self bindConcealed];
    
    [self bindAcceptEmpty];
    
    [self refreshKeyFileDropdown];

    [self bindYubiKey];
}

- (void)bindAcceptEmpty {
    [self.acceptEmptyPassword setState:Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)bindConcealed {
    self.textFieldPassword.showsText = !self.concealed;
    
    [self.buttonRevealConceal setImage:[NSImage imageWithSystemSymbolName:self.concealed ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""]];
}

- (void)bindAdvanced {
    BOOL advanced = self.database.showAdvancedUnlockOptions;
    
    self.acceptEmptyPassword.hidden = !advanced;
    self.labelKeyFile.hidden = !advanced;
    self.popupKeyFile.hidden = !advanced;
    self.stackHardwareKey.hidden = !advanced;
    self.yubiKeyPopup.hidden = !advanced;

    [self.checkboxShowAdvanced setState:advanced ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)fixStackViewSpacing {
    [self.masterStackView setCustomSpacing:20 afterView:self.stackViewLogo];
    [self.masterStackView setCustomSpacing:4 afterView:self.stackViewLabelPasswordAndRevealConceal];
    [self.masterStackView setCustomSpacing:16 afterView:self.textFieldPassword];
    
    [self.masterStackView setCustomSpacing:20 afterView:self.acceptEmptyPassword];
    
    [self.masterStackView setCustomSpacing:4 afterView:self.labelKeyFile];

    [self.masterStackView setCustomSpacing:16 afterView:self.popupKeyFile];
    [self.masterStackView setCustomSpacing:4 afterView:self.stackHardwareKey];
    [self.masterStackView setCustomSpacing:20 afterView:self.yubiKeyPopup];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self validateUI];
}

- (BOOL)manualCredentialsAreValid {
    DatabaseFormat heuristicFormat = [self getHeuristicFormat];

    BOOL formatAllowsEmptyOrNone =  heuristicFormat == kKeePass4 ||
                                    heuristicFormat == kKeePass ||
                                    heuristicFormat == kFormatUnknown ||
                                    (heuristicFormat == kKeePass1 && [self keyFileIsSet]);

    return self.textFieldPassword.stringValue.length || (formatAllowsEmptyOrNone && Settings.sharedInstance.allowEmptyOrNoPasswordEntry);
}

- (void)validateUI {
    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlock setEnabled:enabled];
}

- (IBAction)onRevealConceal:(id)sender {
    self.concealed = !self.concealed;
    [self bindConcealed];
}

- (IBAction)toggleAcceptEmpty:(id)sender {
    Settings.sharedInstance.allowEmptyOrNoPasswordEntry = !Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
    [self bindAcceptEmpty];
    [self validateUI];
}

- (IBAction)onToggleAdvanced:(id)sender {
    self.database.showAdvancedUnlockOptions = !self.database.showAdvancedUnlockOptions;
    
    [self bindAdvanced];
}

- (IBAction)onCancel:(id)sender {
    if ( self.presentingViewController ) {
        [self.presentingViewController dismissViewController:self];
    }
    else if ( self.view.window.sheetParent ) {
        [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.view.window close];
    }
    
    self.onDone(YES, nil, nil, nil);
}

- (IBAction)onUnlock:(id)sender {
    if ( self.presentingViewController ) {
        [self.presentingViewController dismissViewController:self];
    }
    else {
        [self.view.window close];
    }

    self.onDone(NO, self.textFieldPassword.stringValue, self.selectedKeyFileBookmark, self.selectedYubiKeyConfiguration);
}




- (void)refreshKeyFileDropdown {
    [self.popupKeyFile.menu removeAllItems];

    

    [self.popupKeyFile.menu addItemWithTitle:NSLocalizedString(@"mac_key_file_none", @"None")
                                      action:@selector(onSelectNoneKeyFile)
                               keyEquivalent:@""];

    [self.popupKeyFile.menu addItemWithTitle:NSLocalizedString(@"mac_browse_for_key_file", @"Browse...")
                                      action:@selector(onBrowseForKeyFile)
                               keyEquivalent:@""];

    

    NSURL* configuredUrl;
    NSString* configuredBookmarkForKeyFile = [self contextAwareKeyFileBookmark];
    
    if(self.database && configuredBookmarkForKeyFile) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:configuredBookmarkForKeyFile
                                                   readOnly:YES
                                            updatedBookmark:&updatedBookmark
                                                      error:&error];

        if(!configuredUrl) {
            NSLog(@"getUrlFromBookmark: [%@]", error);
        }
        else {
           
        }

        if(updatedBookmark) {
            self.contextAwareKeyFileBookmark = updatedBookmark;
        }
    }

    

    NSString* bookmark = self.selectedKeyFileBookmark;
    NSURL* currentlySelectedUrl;
    if(bookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        currentlySelectedUrl = [BookmarksHelper getUrlFromBookmark:bookmark readOnly:YES updatedBookmark:&updatedBookmark error:&error];

        if(currentlySelectedUrl == nil) {
            self.selectedKeyFileBookmark = nil;
        }

        if(updatedBookmark) {
            self.selectedKeyFileBookmark = updatedBookmark;
        }
    }

    if ( configuredUrl && !self.verifyCkfsMode ) {
        NSString* configuredTitle = Settings.sharedInstance.hideKeyFileNameOnLockScreen ?
                                        NSLocalizedString(@"mac_key_file_configured_but_filename_hidden", @"[Configured]") :
                                        [NSString stringWithFormat:NSLocalizedString(@"mac_key_file_filename_configured_fmt", @"%@ [Configured]"), configuredUrl.lastPathComponent];

        [self.popupKeyFile.menu addItemWithTitle:configuredTitle action:@selector(onSelectPreconfiguredKeyFile) keyEquivalent:@""];

        if(currentlySelectedUrl) {
            if(![configuredUrl.absoluteString isEqualToString:currentlySelectedUrl.absoluteString]) {
                NSString* filename = currentlySelectedUrl.lastPathComponent;

                [self.popupKeyFile.menu addItemWithTitle:filename action:nil keyEquivalent:@""];
                [self.popupKeyFile selectItemAtIndex:3];
            }
            else {
                [self.popupKeyFile selectItemAtIndex:2];
            }
        }
    }
    else if(currentlySelectedUrl) {
        [self.popupKeyFile.menu addItemWithTitle:currentlySelectedUrl.lastPathComponent action:nil keyEquivalent:@""];
        [self.popupKeyFile selectItemAtIndex:2];
    }
    else {
        [self.popupKeyFile selectItemAtIndex:0];
    }
}

- (void)onBrowseForKeyFile {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];

    
    
    
    NSString* desktop = StrongboxFilesManager.sharedInstance.desktopPath;
    openPanel.directoryURL = desktop ? [NSURL fileURLWithPath:desktop] : nil;

    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
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
    self.selectedKeyFileBookmark = self.contextAwareKeyFileBookmark;
    [self refreshKeyFileDropdown];
}



- (BOOL)keyFileIsSet {
    return self.selectedKeyFileBookmark != nil;
}

- (DatabaseFormat)getHeuristicFormat {
    BOOL probablyPasswordSafe = [self.database.fileUrl.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
    DatabaseFormat heuristicFormat = probablyPasswordSafe ? kPasswordSafe : kKeePass; 
    return heuristicFormat;
}

- (IBAction)onRefreshHardwareKey:(id)sender {
    [self bindUi];
}

- (void)bindYubiKey {
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

    
    
    YubiKeyConfiguration* configured = self.verifyCkfsMode ? nil : self.database.yubiKeyConfiguration;
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
    self.selectedYubiKeyConfiguration = self.database.yubiKeyConfiguration;
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

- (NSString*)contextAwareKeyFileBookmark {
    return self.isNativeAutoFillAppExtensionOpen ? self.database.autoFillKeyFileBookmark : self.database.keyFileBookmark;
}

- (void)setContextAwareKeyFileBookmark:(NSString *)contextAwareKeyFileBookmark {
    if ( self.isNativeAutoFillAppExtensionOpen ) {
        self.database.autoFillKeyFileBookmark = contextAwareKeyFileBookmark;
    }
    else {
        self.database.keyFileBookmark = contextAwareKeyFileBookmark;
    }
}

@end
