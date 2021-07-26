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
#import "MacYubiKeyManager.h"
#import "PasswordStrengthTester.h"
#import <CoreImage/CoreImage.h>

@interface CreateFormatAndSetCredentialsWizard () <NSTabViewDelegate>

@property (weak) IBOutlet NSButtonCell *checkboxUseYubiKey;
@property (weak) IBOutlet NSPopUpButtonCell *popupYubiKey;

@property (weak) IBOutlet NSTabView *tabView;

@property (weak) IBOutlet NSSecureTextField *textFieldNew;
@property (weak) IBOutlet NSSecureTextField *textFieldConfirm;
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

@end

@implementation CreateFormatAndSetCredentialsWizard

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _selectedDatabaseFormat = self.initialDatabaseFormat;
    _selectedKeyFileBookmark = self.initialKeyFileBookmark;
    _selectedYubiKeyConfiguration = self.initialYubiKeyConfiguration;

    self.useAKeyFile = self.selectedKeyFileBookmark != nil;
    self.useAYubiKey = self.selectedYubiKeyConfiguration != nil;
    
    [self setupUi];
    [self bindUi];
    
    [self updateYubiKeyUi];
}

- (void)setupUi {
    if(self.titleText) {
        self.textFieldTitle.stringValue = self.titleText;
    }
    
    self.tabView.delegate = self;
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[self.createSafeWizardMode ? 0 : 1]];
    
    NSString* loc = self.createSafeWizardMode ?
        NSLocalizedString(@"mac_create_new_database_title", @"Create New Password Database") :
        NSLocalizedString(@"mac_enter_database_master_credentials", @"Enter Database Master Credentials");
    
    self.window.title = loc;
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

- (IBAction)onBack:(id)sender {
    [self.tabView selectTabViewItem:self.tabView.tabViewItems[0]];
}

- (IBAction)onCancel:(id)sender {
    _selectedPassword = nil;
    _selectedKeyFileBookmark = nil;
    _selectedYubiKeyConfiguration = nil;
    
    if(self.createSafeWizardMode) {
        [NSApp stopModalWithCode:NSModalResponseCancel];
        [NSApp endSheet:self.window returnCode:NSModalResponseCancel];
    }
    else {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    }
}

- (IBAction)controlTextDidChange:(NSSecureTextField *)obj {
    [self bindUi];
}

- (IBAction)onBrowse:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    if (self.selectedKeyFileBookmark) { 
        NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark];
        openPanel.directoryURL = [url URLByDeletingLastPathComponent];
    }
                  
    [openPanel beginSheetModalForWindow:self.window
                      completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
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
    self.useAKeyFile = self.checkboxUseAKeyFile.state == NSOnState;
    [self bindUi];
}

- (void)setUIFromFormat {
    if(self.selectedDatabaseFormat == kPasswordSafe) {
        self.checkboxUseAKeyFile.state = NSOffState;
        self.checkboxUseAKeyFile.enabled = NO;
        self.checkboxUseAPassword.state = NSOnState;
        self.checkboxUseAPassword.enabled = NO;
        self.checkboxUseYubiKey.state = NSOffState;
        self.checkboxUseYubiKey.enabled = NO;
    }
    else {
        self.checkboxUseAPassword.state = NSOnState;
        self.checkboxUseAPassword.enabled = YES;
        self.checkboxUseAKeyFile.state = NSOffState;
        self.checkboxUseAKeyFile.enabled = YES;
        self.checkboxUseYubiKey.state = NSOffState;
        
        BOOL isPro = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
        self.checkboxUseYubiKey.enabled = isPro && self.selectedDatabaseFormat != kKeePass1;
        
        if (!isPro) {
            NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");
            [self.checkboxUseYubiKey setTitle:loc];
        }
    }

    switch (self.selectedDatabaseFormat) {
        case kPasswordSafe:
            self.formatPasswordSafe.state = NSOnState;
            break;
        case kKeePass4:
            self.formatKeePass2Advanced.state = NSOnState;
            break;
        case kKeePass:
            self.formatKeePass2Standard.state = NSOnState;
            break;
        case kKeePass1:
            self.formatKeePass1.state = NSOnState;
            break;
        default:
            break;
    }
}

- (void)setFormatFromUI {
    if(self.formatPasswordSafe.state == NSOnState) {
        _selectedDatabaseFormat = kPasswordSafe;
    }
    else if(self.formatKeePass2Advanced.state == NSOnState) {
        _selectedDatabaseFormat = kKeePass4;
    }
    else if(self.formatKeePass2Standard.state == NSOnState) {
        _selectedDatabaseFormat = kKeePass;
    }
    else if(self.formatKeePass1.state == NSOnState) {
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
    self.useAYubiKey = self.checkboxUseYubiKey.state == NSOnState;
    
    if (self.useAYubiKey) {
        [self updateYubiKeyUi];
    }

    [self bindUi];
}



- (void)bindUi {
    
    
    if(self.checkboxUseAPassword.state == NSOnState) {
        self.textFieldNew.enabled = YES;
        self.textFieldConfirm.enabled = YES;
    }
    else {
        self.textFieldNew.enabled = NO;
        self.textFieldConfirm.enabled = NO;
    }
    
    
    
    [self bindPasswordStrength];
    
    
    
    self.checkboxUseAKeyFile.state = self.useAKeyFile ? NSOnState : NSOffState;
    self.buttonBrowse.enabled = self.useAKeyFile;
    self.labelKeyFilePath.enabled = self.useAKeyFile;
    
    NSURL* url = self.selectedKeyFileBookmark ? [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark] : nil;
    self.labelKeyFilePath.stringValue = self.useAKeyFile && url ? url.path : @"";
    self.labelKeyFilePath.placeholderString = !self.useAKeyFile ? @"" : NSLocalizedString(@"mac_click_browse_select_key_file", @"Click Browse to Select a Key File");
    
    
    
    self.checkboxUseYubiKey.state = self.useAYubiKey ? NSOnState : NSOffState;
    self.popupYubiKey.enabled = self.useAYubiKey;
    
    
    
    self.buttonOk.enabled = [self validateUi];
}

- (void)updateYubiKeyUi {
    [self.popupYubiKey.menu removeAllItems];
    
    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    [self.popupYubiKey.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];
    
    [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yubiKeyData) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKeyResponse:yubiKeyData];
        });
    }];
}

- (void)onGotAvailableYubiKeyResponse:(YubiKeyData*)yubiKeyData {
    [self.popupYubiKey.menu removeAllItems];

    BOOL yubiKeyPossible = NO;
    self.currentYubiKeySerial = yubiKeyData.serial;
    self.slot1IsBlocking = NO;
    self.slot2IsBlocking = NO;

    if (yubiKeyData == nil) {
        NSString* loc = NSLocalizedString(@"mac_no_yubikeys_found", @"No YubiKeys Found");
        [self.popupYubiKey.menu addItemWithTitle:loc
                                          action:nil
                                   keyEquivalent:@""];
        
        self.useAYubiKey = NO;
    }
    else {
        NSString* locBlocking = NSLocalizedString(@"mac_yubikey_serial_number_slot_n_touch_required_fmt2", @"YubiKey %@ Slot %@ (Touch Required)");
        NSString* locNonBlocking = NSLocalizedString(@"mac_yubikey_serial_number_slot_n_fmt2", @"YubiKey %@ Slot %@");

        
        
        NSMenuItem* slot1MenuItem = nil;
        if (yubiKeyData.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking) {
            NSString* fmt = [NSString stringWithFormat:locBlocking, yubiKeyData.serial, @(1)];
            slot1MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot1)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
            self.slot1IsBlocking = YES;
        }
        else if (yubiKeyData.slot1CrStatus == YubiKeySlotCrStatusSupportedNonBlocking) {
            NSString* fmt = [NSString stringWithFormat:locNonBlocking, yubiKeyData.serial, @(1)];

            slot1MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot1)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
        }

        
        
        NSMenuItem* slot2MenuItem = nil;
        if (yubiKeyData.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking) {
            NSString* fmt = [NSString stringWithFormat:locBlocking, yubiKeyData.serial, @(2)];
            slot2MenuItem = [self.popupYubiKey.menu addItemWithTitle:fmt
                                                              action:@selector(onSelectSlot2)
                                                       keyEquivalent:@""];
            yubiKeyPossible = YES;
            self.slot2IsBlocking = YES;
        }
        else if (yubiKeyData.slot2CrStatus == YubiKeySlotCrStatusSupportedNonBlocking) {
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
                YubiKeySlotCrStatus slotStatus = self.selectedYubiKeyConfiguration.slot == 1 ? yubiKeyData.slot1CrStatus : yubiKeyData.slot2CrStatus;
                
                if (slotStatus == YubiKeySlotCrStatusSupportedNonBlocking ||
                    slotStatus == YubiKeySlotCrStatusSupportedBlocking) {
                    
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
            NSString* loc = NSLocalizedString(@"mac_yubikey_available_but_no_compatible_slots", @"YubiKey found but no compatible HMACSHA1 slots available");
            
            [self.popupYubiKey.menu addItemWithTitle:loc
                                              action:nil
                                       keyEquivalent:@""];
            
            self.useAYubiKey = NO;
        }
    }
    
    [self bindUi];
}

- (BOOL)validateUi {
    self.labelPasswordsMatch.stringValue = @"";
    self.labelPasswordsMatch.textColor = [NSColor redColor];
    
    if(self.checkboxUseAPassword.state == NSOnState) {
        if(![self.textFieldNew.stringValue isEqualToString:self.textFieldConfirm.stringValue]) {
            if(self.textFieldConfirm.stringValue.length) {
                NSString* loc = NSLocalizedString(@"mac_passwords_dont_match", @"Passwords don't match");
                self.labelPasswordsMatch.stringValue = loc;
            }
            
            return NO;
        }
    }

    
    
    if(self.selectedDatabaseFormat == kKeePass1 || self.selectedDatabaseFormat == kPasswordSafe) {
        if(self.checkboxUseAPassword.state == NSOnState) {
            if(self.textFieldNew.stringValue.length == 0) {
                NSString* loc = NSLocalizedString(@"mac_password_cannot_be_empty", @"Password cannot be Empty");
                self.labelPasswordsMatch.stringValue = loc;
                return NO;
            }
        }
    }

    
    
    if(self.useAKeyFile) {
        if (self.selectedKeyFileBookmark == nil) {
            self.labelPasswordsMatch.stringValue = NSLocalizedString(@"mac_select_key_file", @"Select a Key File");
            return NO;
        }
        
        NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark];
        if(url == nil || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) {
            NSString* loc = NSLocalizedString(@"mac_key_file_invalid", @"Key File Invalid");
            self.labelPasswordsMatch.stringValue = loc;
            return NO;
        }
    }
        
    
    
    
    
    if (self.checkboxUseAPassword.state == NSOffState && !self.useAKeyFile && !self.useAYubiKey) {
        NSString* loc = NSLocalizedString(@"mac_you_must_use_at_least_a_password_or_key_file", @"You must at least one of either a Password, Key File or YubiKey for your master credentials.");
        
        self.labelPasswordsMatch.stringValue = loc;
        return NO;
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
    
    return YES;
}

- (IBAction)onOk:(id)sender {
    
    
    _selectedPassword = nil;
    if(self.checkboxUseAPassword.state == NSOnState) {
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
    
    if(self.createSafeWizardMode) {
        [NSApp stopModalWithCode:NSModalResponseOK];
        [NSApp endSheet:self.window returnCode:NSModalResponseOK];
    }
    else {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    }
}

- (CompositeKeyFactors *)generateCkfFromSelected:(NSWindow *)yubiKeyPressWindowHint {
    NSData* keyFileDigest = nil;
    
    if (self.selectedKeyFileBookmark) {
        NSError* error;
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:self.selectedKeyFileBookmark error:&error];
        
        if (error) {
            return nil;
        }
        
        keyFileDigest = [KeyFileParser getNonePerformantKeyFileDigest:data
                                                            checkForXml:self.selectedDatabaseFormat != kKeePass1];
    }
    
    YubiKeyCRHandlerBlock yubiKeyCR = nil;
    if (self.selectedYubiKeyConfiguration) {
        NSInteger slot = self.selectedYubiKeyConfiguration.slot;
        BOOL slotIsBlocking = [self slotIsBlocking:self.selectedYubiKeyConfiguration.slot];
        
        yubiKeyCR = ^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
            [MacYubiKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                        windowHint:yubiKeyPressWindowHint
                                                              slot:slot
                                                    slotIsBlocking:slotIsBlocking
                                                        completion:completion];
        };
    }

    return [CompositeKeyFactors password:self.selectedPassword keyFileDigest:keyFileDigest yubiKeyCR:yubiKeyCR];
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
    PasswordStrength* strength = [PasswordStrengthTester getStrength:pw config:PasswordStrengthConfig.defaults];
    
    self.labelStrength.stringValue = strength.summaryString;
    
    double relativeStrength = MIN(strength.entropy / 128.0f, 1.0f); 
        
    self.progressStrength.doubleValue = relativeStrength * 100.0f;
    
    CIFilter *colorPoly = [CIFilter filterWithName:@"CIColorPolynomial"];
    [colorPoly setDefaults];
    
    double red = 1.0 - relativeStrength;
    double green = relativeStrength;

    CIVector *redVector = [CIVector vectorWithX:red Y:0 Z:0 W:0];
    CIVector *greenVector = [CIVector vectorWithX:green Y:0 Z:0 W:0];
    CIVector *blueVector = [CIVector vectorWithX:0 Y:0 Z:0 W:0];
    
    [colorPoly setValue:redVector forKey:@"inputRedCoefficients"];
    [colorPoly setValue:greenVector forKey:@"inputGreenCoefficients"];
    [colorPoly setValue:blueVector forKey:@"inputBlueCoefficients"];
    [self.progressStrength setContentFilters:@[colorPoly]];
}

@end
