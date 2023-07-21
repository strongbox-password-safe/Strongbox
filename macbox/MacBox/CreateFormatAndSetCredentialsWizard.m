//
//  ChangeMasterPasswordWindowController.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "CreateFormatAndSetCredentialsWizard.h"
#import "Settings.h"
#import "MacAlerts.h"
#import "Utils.h"
#import "KeyFileParser.h"
#import "BookmarksHelper.h"
#import "MacHardwareKeyManager.h"
#import "PasswordStrengthTester.h"
#import <CoreImage/CoreImage.h>
#import "MacCompositeKeyDeterminer.h"
#import "PasswordStrengthUIHelper.h"
#import "KSPasswordField.h"

@interface CreateFormatAndSetCredentialsWizard () <NSTabViewDelegate>

@property (weak) IBOutlet NSButtonCell *checkboxUseYubiKey;
@property (weak) IBOutlet NSPopUpButtonCell *popupYubiKey;

@property (weak) IBOutlet NSTabView *tabView;

@property (weak) IBOutlet KSPasswordField *textFieldNew;
@property (weak) IBOutlet KSPasswordField *textFieldConfirm;
@property (weak) IBOutlet NSButton *buttonOk;
@property (weak) IBOutlet NSButton *buttonCancel;

@property (weak) IBOutlet NSAdvancedTextField *labelPasswordsMatch;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@property (weak) IBOutlet NSButton *checkboxUseAPassword;
@property (weak) IBOutlet NSButton *checkboxUseAKeyFile;
@property (weak) IBOutlet NSButton *buttonBrowse;
@property (weak) IBOutlet NSTextField *labelKeyFilePath;

@property (weak) IBOutlet NSButton *formatPasswordSafe;
@property (weak) IBOutlet NSButton *formatKeePass2Advanced;
@property (weak) IBOutlet NSButton *formatKeePass2Standard;
@property (weak) IBOutlet NSButton *formatKeePass1;

@property BOOL useAKeyFile;
@property BOOL useAYubiKey;

@property BOOL slot1IsBlocking;
@property BOOL slot2IsBlocking;
@property NSString* currentYubiKeySerial;
@property (weak) IBOutlet NSProgressIndicator *progressStrength;
@property (weak) IBOutlet NSTextField *labelStrength;
@property (weak) IBOutlet NSStackView *stackStrength;

@property (weak) IBOutlet NSButton *buttonRevealConceal;
@property BOOL concealed;
@property (weak) IBOutlet NSButton *acceptEmptyPassword;

@property (weak) IBOutlet NSStackView *stackHeader;
@property (weak) IBOutlet NSStackView *stackOuterContainer;
@property (weak) IBOutlet NSStackView *stackViewKeyFile;
@property (weak) IBOutlet NSStackView *stackViewYubiKey;

@property (weak) IBOutlet NSButton *checkboxShowAdvanced;
@property BOOL showAdvanced;

@end

@implementation CreateFormatAndSetCredentialsWizard

- (IBAction)onToggleShowAdvanced:(id)sender {
    self.showAdvanced = !self.showAdvanced;
    [self bindUi];
}

- (IBAction)onRevealConceal:(id)sender {
    self.concealed = !self.concealed;
    [self bindConcealed];
}

- (IBAction)toggleAcceptEmpty:(id)sender {
    Settings.sharedInstance.allowEmptyOrNoPasswordEntry = !Settings.sharedInstance.allowEmptyOrNoPasswordEntry;
    
    [self bindUi];
}

- (void)bindAcceptEmpty {
    [self.acceptEmptyPassword setState:Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _selectedDatabaseFormat = self.initialDatabaseFormat;
    _selectedKeyFileBookmark = self.initialKeyFileBookmark;
    _selectedYubiKeyConfiguration = self.initialYubiKeyConfiguration;

    self.showAdvanced = self.initialKeyFileBookmark != nil || self.initialYubiKeyConfiguration != nil;
    
    self.useAKeyFile = self.selectedKeyFileBookmark != nil;
    self.useAYubiKey = self.selectedYubiKeyConfiguration != nil;
    
    self.concealed = YES;
    
    [self setupUi];
    [self bindUi];
    
    [self updateYubiKeyUi];
}

- (void)setupUi {
    self.tabView.delegate = self;
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[self.createSafeWizardMode ? 0 : 1]];
    
    NSString* loc = self.createSafeWizardMode ?
        NSLocalizedString(@"mac_create_new_database_title", @"Create New Password Database") :
        NSLocalizedString(@"mac_enter_database_master_credentials", @"Enter Database Master Credentials");
    
    self.window.title = loc;
    
    [self.stackOuterContainer setCustomSpacing:8.f afterView:self.stackHeader];
    
    [self setUIFromFormat];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    if(tabViewItem == self.tabView.tabViewItems[1]) {
        [self.window makeFirstResponder:self.textFieldNew];
        [self.textFieldNew becomeFirstResponder];
    }
}

- (IBAction)onNext:(id)sender {
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[1]];
}

- (IBAction)onCancel:(id)sender {
    _selectedPassword = nil;
    _selectedKeyFileBookmark = nil;
    _selectedYubiKeyConfiguration = nil;
    
    if ( self.window.sheetParent ) {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    }
    else {
        [NSApp stopModalWithCode:NSModalResponseCancel];
        [NSApp endSheet:self.window returnCode:NSModalResponseCancel];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self bindPasswordStrength];

    [self validateUi];
}

- (IBAction)onBrowse:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    if (self.selectedKeyFileBookmark) { 
        NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark];
        openPanel.directoryURL = [url URLByDeletingLastPathComponent];
    }
                  
    [openPanel beginSheetModalForWindow:self.window
                      completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSError* error;
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:openPanel.URL readOnly:YES error:&error];
            
            if (error) {
                [MacAlerts error:error window:self.window];
            }
            else {
                self->_selectedKeyFileBookmark = bookmark;
                [self bindUi];
            }
        }
    }];
}

- (IBAction)onUseAPassword:(id)sender {
    [self bindUi];
}

- (IBAction)onUseAKeyFile:(id)sender {
    self.useAKeyFile = self.checkboxUseAKeyFile.state == NSControlStateValueOn;
    [self bindUi];
}

- (void)setUIFromFormat {
    if(self.selectedDatabaseFormat == kPasswordSafe || self.selectedDatabaseFormat == kKeePass1 ) {
        self.checkboxUseAKeyFile.state = NSControlStateValueOff;
        self.checkboxUseAKeyFile.enabled = NO;
        
        self.checkboxUseAPassword.state = NSControlStateValueOn;
        self.checkboxUseAPassword.enabled = NO;
        
        self.checkboxUseYubiKey.state = NSControlStateValueOff;
        self.checkboxUseYubiKey.enabled = NO;

        self.acceptEmptyPassword.state = NSControlStateValueOff;
        self.acceptEmptyPassword.enabled = NO;
        
        self.stackViewKeyFile.hidden = YES;
        self.stackViewYubiKey.hidden = YES;
        self.checkboxUseAPassword.hidden = YES;
        self.acceptEmptyPassword.hidden = YES;
    }
    else {
        self.checkboxUseAPassword.state = NSControlStateValueOn;
        self.checkboxUseAPassword.enabled = YES;
        self.checkboxUseAKeyFile.state = NSControlStateValueOff;
        self.checkboxUseAKeyFile.enabled = YES;
        self.checkboxUseYubiKey.state = NSControlStateValueOff;
        
        BOOL isPro = Settings.sharedInstance.isPro;
        self.checkboxUseYubiKey.enabled = isPro && self.selectedDatabaseFormat != kKeePass1;
        
        if (!isPro) {
            NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");
            [self.checkboxUseYubiKey setTitle:loc];
        }
    }

    switch (self.selectedDatabaseFormat) {
        case kPasswordSafe:
            self.formatPasswordSafe.state = NSControlStateValueOn;
            break;
        case kKeePass4:
            self.formatKeePass2Advanced.state = NSControlStateValueOn;
            break;
        case kKeePass:
            self.formatKeePass2Standard.state = NSControlStateValueOn;
            break;
        case kKeePass1:
            self.formatKeePass1.state = NSControlStateValueOn;
            break;
        default:
            break;
    }
}

- (void)setFormatFromUI {
    if(self.formatPasswordSafe.state == NSControlStateValueOn) {
        _selectedDatabaseFormat = kPasswordSafe;
    }
    else if(self.formatKeePass2Advanced.state == NSControlStateValueOn) {
        _selectedDatabaseFormat = kKeePass4;
    }
    else if(self.formatKeePass2Standard.state == NSControlStateValueOn) {
        _selectedDatabaseFormat = kKeePass;
    }
    else if(self.formatKeePass1.state == NSControlStateValueOn) {
        _selectedDatabaseFormat = kKeePass1;
    }
}

- (IBAction)onChangeDatabaseFormat:(id)sender {
    [self setFormatFromUI];
    
    NSLog(@"Format = %ld", (long)self.selectedDatabaseFormat);
    
    [self setUIFromFormat];
    [self bindUi];
}

- (IBAction)onUseAYubiKey:(id)sender {
    self.useAYubiKey = self.checkboxUseYubiKey.state == NSControlStateValueOn;
    
    if (self.useAYubiKey) {
        [self updateYubiKeyUi];
    }

    [self bindUi];
}



- (void)bindUi {
    self.checkboxShowAdvanced.state = self.showAdvanced ? NSControlStateValueOn : NSControlStateValueOff;
    self.acceptEmptyPassword.hidden = !self.showAdvanced;
    self.stackViewKeyFile.hidden = !self.showAdvanced;
    self.stackViewYubiKey.hidden = !self.showAdvanced;
    
    
    
    if(self.checkboxUseAPassword.state == NSControlStateValueOn) {
        self.textFieldNew.enabled = YES;
        self.textFieldConfirm.enabled = YES;
    }
    else {
        self.textFieldNew.enabled = NO;
        self.textFieldConfirm.enabled = NO;
    }
    
    [self bindConcealed];
    [self bindAcceptEmpty];
    
    
    
    [self bindPasswordStrength];
    
    
    
    self.checkboxUseAKeyFile.state = self.useAKeyFile ? NSControlStateValueOn : NSControlStateValueOff;
    self.buttonBrowse.enabled = self.useAKeyFile;
    self.labelKeyFilePath.enabled = self.useAKeyFile;
    
    NSURL* url = self.selectedKeyFileBookmark ? [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark] : nil;
    
    self.labelKeyFilePath.stringValue = self.useAKeyFile && url ? url.path : @"";
    self.labelKeyFilePath.placeholderString = !self.useAKeyFile ? @"" : NSLocalizedString(@"mac_click_browse_select_key_file", @"Click Browse to Select a Key File");
    
    self.labelKeyFilePath.hidden = self.labelKeyFilePath.stringValue.length == 0;
    
    
    
    self.checkboxUseYubiKey.state = self.useAYubiKey ? NSControlStateValueOn : NSControlStateValueOff;
    self.popupYubiKey.enabled = self.useAYubiKey;
    
    
    
    [self validateUi];
}

- (void)bindConcealed {
    self.textFieldNew.showsText = !self.concealed;
    
    if (@available(macOS 11.0, *)) {
        [self.buttonRevealConceal setImage:[NSImage imageWithSystemSymbolName:self.concealed ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""]];
    }
}

- (void)updateYubiKeyUi {
    [self.popupYubiKey.menu removeAllItems];
    
    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    [self.popupYubiKey.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];
    
    [MacHardwareKeyManager.sharedInstance getAvailableKey:^(HardwareKeyData * _Nonnull yubiKeyData) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKeyResponse:yubiKeyData];
        });
    }];
}

- (void)onGotAvailableYubiKeyResponse:(HardwareKeyData*)yubiKeyData {
    [self.popupYubiKey.menu removeAllItems];

    BOOL yubiKeyPossible = NO;
    self.currentYubiKeySerial = yubiKeyData.serial;
    self.slot1IsBlocking = NO;
    self.slot2IsBlocking = NO;

    if (yubiKeyData == nil) {
        NSString* loc = NSLocalizedString(@"mac_no_yubikeys_found", @"No Hardware Keys Found");
        [self.popupYubiKey.menu addItemWithTitle:loc
                                          action:nil
                                   keyEquivalent:@""];
        
        self.useAYubiKey = NO;
    }
    else {
        NSString* locBlocking = NSLocalizedString(@"mac_yubikey_serial_number_slot_n_touch_required_fmt2", @"Hardware Key %@ Slot %@ (Touch Required)");
        NSString* locNonBlocking = NSLocalizedString(@"mac_yubikey_serial_number_slot_n_fmt2", @"Hardware Key %@ Slot %@");

        
        
        NSMenuItem* slot1MenuItem = nil;
        if (yubiKeyData.slot1CrStatus == kHardwareKeySlotCrStatusSupportedBlocking) {
            NSString* fmt = [NSString stringWithFormat:locBlocking, yubiKeyData.serial, @(1)];
            slot1MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot1)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
            self.slot1IsBlocking = YES;
        }
        else if (yubiKeyData.slot1CrStatus == kHardwareKeySlotCrStatusSupportedNonBlocking) {
            NSString* fmt = [NSString stringWithFormat:locNonBlocking, yubiKeyData.serial, @(1)];

            slot1MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot1)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
        }

        
        
        NSMenuItem* slot2MenuItem = nil;
        if (yubiKeyData.slot2CrStatus == kHardwareKeySlotCrStatusSupportedBlocking) {
            NSString* fmt = [NSString stringWithFormat:locBlocking, yubiKeyData.serial, @(2)];
            slot2MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot2)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
            self.slot2IsBlocking = YES;
        }
        else if (yubiKeyData.slot2CrStatus == kHardwareKeySlotCrStatusSupportedNonBlocking) {
            NSString* fmt = [NSString stringWithFormat:locNonBlocking, yubiKeyData.serial, @(2)];
            slot2MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot2)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
        }
        
        
        if (yubiKeyPossible) { 
            BOOL selectedItem = NO;
            
            if (self.selectedYubiKeyConfiguration &&
                ([self.selectedYubiKeyConfiguration.deviceSerial isEqualToString:yubiKeyData.serial])) {
                HardwareKeySlotCrStatus slotStatus = self.selectedYubiKeyConfiguration.slot == 1 ? yubiKeyData.slot1CrStatus : yubiKeyData.slot2CrStatus;
                
                if (slotStatus == kHardwareKeySlotCrStatusSupportedNonBlocking ||
                    slotStatus == kHardwareKeySlotCrStatusSupportedBlocking) {
                    
                    if (self.selectedYubiKeyConfiguration.slot == 1 && slot1MenuItem) {
                        [self.popupYubiKey selectItem:slot1MenuItem];
                        selectedItem = YES;
                    }
                    else if (self.selectedYubiKeyConfiguration.slot == 2 && slot2MenuItem){
                        [self.popupYubiKey selectItem:slot2MenuItem];
                        selectedItem = YES;
                    }
                }
            }
            
            if (!selectedItem) { 
                [self.popupYubiKey selectItemAtIndex:0];
                
                YubiKeyConfiguration* config = [[YubiKeyConfiguration alloc] init];
                config.deviceSerial = yubiKeyData.serial;
                config.slot = slot1MenuItem ? 1 : 2;
                
                _selectedYubiKeyConfiguration = config;
            }
        }
        else {
            NSString* loc = NSLocalizedString(@"mac_yubikey_available_but_no_compatible_slots", @"Hardware Key found but no compatible HMACSHA1 slots available");
            
            [self.popupYubiKey.menu addItemWithTitle:loc
                                              action:nil
                                       keyEquivalent:@""];
            
            self.useAYubiKey = NO;
        }
    }
    
    [self bindUi];
}

- (void)validateUi {
    self.labelPasswordsMatch.stringValue = @" ";
    self.labelPasswordsMatch.textColor = [NSColor redColor];
    
    if(self.checkboxUseAPassword.state == NSControlStateValueOn) {
        if ( !Settings.sharedInstance.allowEmptyOrNoPasswordEntry && self.textFieldNew.stringValue.length == 0 ) {
            self.buttonOk.enabled = NO;
            return;
        }
        
        if(![self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
            if(self.textFieldConfirm.stringValue.length) {
                NSString* loc = NSLocalizedString(@"mac_passwords_dont_match", @"Passwords don't match");
                self.labelPasswordsMatch.stringValue = loc;
            }
            
            self.buttonOk.enabled = NO;
            return;
        }
    }

    
    
    if(self.selectedDatabaseFormat == kKeePass1 || self.selectedDatabaseFormat == kPasswordSafe) {
        if(self.checkboxUseAPassword.state == NSControlStateValueOn) {
            if(self.textFieldNew.stringValue.length == 0) {
                NSString* loc = NSLocalizedString(@"mac_password_cannot_be_empty", @"Password cannot be Empty");
                self.labelPasswordsMatch.stringValue = loc;
                self.buttonOk.enabled = NO;
                return;
            }
        }
    }

    
    
    if(self.useAKeyFile) {
        if (self.selectedKeyFileBookmark == nil) {
            self.labelPasswordsMatch.stringValue = NSLocalizedString(@"mac_select_key_file", @"Select a Key File");
            self.buttonOk.enabled = NO;
            return;
        }
        
        NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark];
        if(url == nil || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
            NSString* loc = NSLocalizedString(@"mac_key_file_invalid", @"Key File Invalid");
            self.labelPasswordsMatch.stringValue = loc;
            self.buttonOk.enabled = NO;
            return;
        }
    }
        
    
    
    
    
    if (self.checkboxUseAPassword.state == NSControlStateValueOff && !self.useAKeyFile && !self.useAYubiKey) {
        NSString* loc = NSLocalizedString(@"mac_you_must_use_at_least_a_password_or_key_file", @"You must use at least one of either a password, a key file or a hardware key for your master credentials.");
        
        self.labelPasswordsMatch.stringValue = loc;
        self.buttonOk.enabled = NO;
        return;
    }
    
    
    
    BOOL justAPassword = !self.useAKeyFile && !self.useAYubiKey;

    if(justAPassword && self.textFieldNew.stringValue.length < 8) {
        NSString* loc = NSLocalizedString(@"mac_weak_credentials", @"Weak Credentials");
        self.labelPasswordsMatch.stringValue = loc;
        self.labelPasswordsMatch.textColor = [NSColor orangeColor];
    }
    else {
        NSString* loc = NSLocalizedString(@"mac_valid_credentials", @"Valid Credentials");
        self.labelPasswordsMatch.stringValue = loc;
        self.labelPasswordsMatch.textColor = [NSColor greenColor];
    }
    
    self.buttonOk.enabled = YES;
}

- (IBAction)onOk:(id)sender {
    
    
    _selectedPassword = nil;
    if(self.checkboxUseAPassword.state == NSControlStateValueOn) {
        if([self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
            _selectedPassword = self.textFieldNew.stringValue;
        }
    }

    
    
    if(self.useAKeyFile && self.selectedKeyFileBookmark) {
        NSError* error;
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:self.selectedKeyFileBookmark error:&error];
        
        if(!data) {
            NSLog(@"Could not read key file. Error: %@", error);
            
            NSString* loc = NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not open key file.");
            [MacAlerts error:loc error:error window:self.window];
            return;
        }
    }
    else {
        _selectedKeyFileBookmark = nil;
    }

    if (!self.useAYubiKey) {
        _selectedYubiKeyConfiguration = nil;
    }
    
    if ( self.window.sheetParent ) {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    }
    else {
        [NSApp stopModalWithCode:NSModalResponseOK];
        [NSApp endSheet:self.window returnCode:NSModalResponseOK];
    }
}

- (CompositeKeyFactors *)generateCkfFromSelectedFactors:(NSViewController *)yubiKeyInteractionVc
                                                  error:(NSError *__autoreleasing  _Nullable *)error {
    NSError* err;
    CompositeKeyFactors *ret = [MacCompositeKeyDeterminer getCkfsWithConfigs:self.selectedPassword
                                                             keyFileBookmark:self.selectedKeyFileBookmark
                                                        yubiKeyConfiguration:self.selectedYubiKeyConfiguration
                                        hardwareKeyInteractionViewController:yubiKeyInteractionVc
                                                           formatKeyFileHint:self.selectedDatabaseFormat
                                                                       error:&err];

    if ( err ) {
        NSLog(@"🔴 Could not get CKFs! [%@]", err);
        if ( error ) {
            *error = err;
        }
    }
    
    return ret;
}

- (BOOL)slotIsBlocking:(NSInteger)slot {
    return slot == 1 ? self.slot1IsBlocking : self.slot2IsBlocking;
}

- (void)onSelectSlot1 {
    _selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    _selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    _selectedYubiKeyConfiguration.slot = 1;
}

- (void)onSelectSlot2 {
    _selectedYubiKeyConfiguration = [[YubiKeyConfiguration alloc] init];
    _selectedYubiKeyConfiguration.deviceSerial = self.currentYubiKeySerial;
    _selectedYubiKeyConfiguration.slot = 2;
}

- (void)bindPasswordStrength {
    if ( self.checkboxUseAPassword.state == NSControlStateValueOff || self.textFieldNew.stringValue.length == 0) {
        self.stackStrength.hidden = YES;
        return;
    }
    self.stackStrength.hidden = NO;
    
    NSString* pw = self.textFieldNew.stringValue;
    
    [PasswordStrengthUIHelper bindPasswordStrength:pw
                                     labelStrength:self.labelStrength
                                          progress:self.progressStrength];
}

@end
