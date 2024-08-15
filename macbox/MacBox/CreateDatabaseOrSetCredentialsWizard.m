//
//  ChangeMasterPasswordWindowController.m
//  MacBox
//
//  Created by Mark on 11/08/2017.
//  Copyright © 2017 Mark McGuill. All rights reserved.
//

#import "CreateDatabaseOrSetCredentialsWizard.h"
#import "Settings.h"
#import "MacAlerts.h"
#import "Utils.h"
#import "BookmarksHelper.h"
#import "MacHardwareKeyManager.h"
#import "PasswordStrengthTester.h"
#import <CoreImage/CoreImage.h>
#import "MacCompositeKeyDeterminer.h"
#import "PasswordStrengthUIHelper.h"
#import "KSPasswordField.h"
#import "KeyFileManagement.h"
#import "Strongbox-Swift.h"
#import "HardwareKeyMenuHelper.h"

@interface CreateDatabaseOrSetCredentialsWizard () <NSTextFieldDelegate, NSWindowDelegate>

@property (weak) IBOutlet KSPasswordField *textFieldNew;
@property (weak) IBOutlet KSPasswordField *textFieldConfirm;
@property (weak) IBOutlet NSButton *buttonOk;
@property (weak) IBOutlet NSButton *buttonCancel;

@property (weak) IBOutlet NSAdvancedTextField *labelPasswordsMatch;
@property (weak) IBOutlet NSTextField *textFieldTitle;

@property (weak) IBOutlet NSButton *checkboxUseAPassword;
@property (weak) IBOutlet NSButton *checkboxUseAKeyFile;
@property (weak) IBOutlet NSButton *buttonBrowse;
@property (weak) IBOutlet NSButton *buttonCreateNewKeyFile;
@property (weak) IBOutlet NSTextField *labelKeyFilePath;

@property (weak) IBOutlet NSStackView *stackFormat;
@property (weak) IBOutlet NSPopUpButton *popupFormat;

@property (weak) IBOutlet NSProgressIndicator *progressStrength;
@property (weak) IBOutlet NSTextField *labelStrength;
@property (weak) IBOutlet NSStackView *stackStrength;
@property (weak) IBOutlet NSButton *buttonRevealConceal;
@property (weak) IBOutlet NSButton *acceptEmptyPassword;
@property (weak) IBOutlet NSStackView *stackHeader;
@property (weak) IBOutlet NSStackView *stackOuterContainer;
@property (weak) IBOutlet NSStackView *stackViewKeyFile;

@property (weak) IBOutlet NSButton *checkboxShowAdvanced;

@property (weak) IBOutlet NSStackView *stackNickname;
@property (weak) IBOutlet NSTextField *textFieldNickName;
@property (weak) IBOutlet NSTextField *textFieldSubtitle;

@property BOOL showAdvanced;
@property BOOL useAKeyFile;
@property BOOL useAYubiKey;
@property BOOL concealed;
@property BOOL createMode;

@property DatabaseFormat initialDatabaseFormat;
@property NSString* initialKeyFileBookmark;
@property YubiKeyConfiguration *initialYubiKeyConfiguration;

@property (weak) IBOutlet NSStackView *stackViewYubiKey;
@property (weak) IBOutlet NSButton *checkboxUseYubiKey;
@property (weak) IBOutlet NSPopUpButton *popupYubiKey;
@property HardwareKeyMenuHelper* hardwareKeyMenuHelper;

@end

@implementation CreateDatabaseOrSetCredentialsWizard

+ (instancetype)newCreateDatabaseWizard {
    CreateDatabaseOrSetCredentialsWizard* wizard = [[CreateDatabaseOrSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];
    
    wizard.initialDatabaseFormat = kKeePass4;
    wizard.createMode = YES;
    
    return wizard;
}

+ (instancetype)newSetCredentialsWizard:(DatabaseFormat)format keyFileBookmark:(NSString *)keyFileBookmark yubiKeyConfig:(YubiKeyConfiguration *)yubiKeyConfig {
    CreateDatabaseOrSetCredentialsWizard* wizard = [[CreateDatabaseOrSetCredentialsWizard alloc] initWithWindowNibName:@"ChangeMasterPasswordWindowController"];

    wizard.initialDatabaseFormat = format;
    wizard.initialKeyFileBookmark = keyFileBookmark;
    wizard.initialYubiKeyConfiguration = yubiKeyConfig;
    
    wizard.createMode = NO;
    
    return wizard;
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
    
    [self bindYubiKeyUI];
}

- (void)setupUi {
    NSString* loc = self.createMode ?
        NSLocalizedString(@"mac_create_new_database_title", @"Create New Password Database") :
        NSLocalizedString(@"mac_enter_database_master_credentials", @"Enter Database Master Credentials");
    
    self.window.title = loc;
    
    [self.stackOuterContainer setCustomSpacing:8.f afterView:self.stackHeader];
    
    self.stackFormat.hidden = !self.createMode;
    
    [self bindUIBasedOnDatabaseFormat];

    self.textFieldNickName.delegate = self;
    
    if ( self.createMode ) {
        self.textFieldTitle.stringValue = NSLocalizedString(@"new_database_setup", @"New Database Setup");
        self.textFieldSubtitle.stringValue = NSLocalizedString(@"enter_creds_and_nickname", @"Enter a nickname for your new database and the master credentials to protect it.");
        
        self.textFieldNickName.stringValue = [MacDatabasePreferences getSuggestedNewDatabaseName];
        
        [self.window makeFirstResponder:self.textFieldNickName];
        [self.textFieldNickName becomeFirstResponder];
    }
    else {
        [self.window makeFirstResponder:self.textFieldNew];
        [self.textFieldNew becomeFirstResponder];
    }

    [self setupHardwareKeyHelper];
}

- (void)setupHardwareKeyHelper {
    __weak CreateDatabaseOrSetCredentialsWizard* weakSelf = self;
    
    self.hardwareKeyMenuHelper = [[HardwareKeyMenuHelper alloc] initWithViewController:self.contentViewController
                                                                          yubiKeyPopup:self.popupYubiKey
                                                                  currentConfiguration:self.initialYubiKeyConfiguration
                                                                            verifyMode:NO];
    
    self.hardwareKeyMenuHelper.alertWindowOverride = self.window;
    self.hardwareKeyMenuHelper.showViewControllerOverride = ^(NSViewController * _Nonnull vc) {
        NSWindow *wrapper = [NSWindow windowWithContentViewController:vc];
        [weakSelf.window beginSheet:wrapper completionHandler:nil];
    };
    self.hardwareKeyMenuHelper.dismissViewControllerOverride = ^{
        [weakSelf.window endSheet:weakSelf.window.attachedSheet];
    };
}

- (void)bindUi {
    BOOL noneKp2 = ( self.selectedDatabaseFormat == kPasswordSafe || self.selectedDatabaseFormat == kKeePass1 );
    
    self.stackViewKeyFile.hidden = !self.showAdvanced || noneKp2;
    self.stackViewYubiKey.hidden = !self.showAdvanced || noneKp2;
    self.stackFormat.hidden = !self.showAdvanced || !self.createMode || !self.allowFormatSelection;
    self.stackNickname.hidden = !self.createMode;
    
    self.acceptEmptyPassword.hidden = !self.showAdvanced || noneKp2;
    self.checkboxShowAdvanced.state = self.showAdvanced ? NSControlStateValueOn : NSControlStateValueOff;

    self.checkboxShowAdvanced.enabled = !(noneKp2 && !self.createMode);
    self.checkboxShowAdvanced.alphaValue = (noneKp2 && !self.createMode) ? 0.0 : 1.0;
    
    
    
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
    self.buttonCreateNewKeyFile.enabled = self.useAKeyFile;
    self.labelKeyFilePath.enabled = self.useAKeyFile;
    
    NSURL* url = self.selectedKeyFileBookmark ? [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark] : nil;
    
    self.labelKeyFilePath.stringValue = self.useAKeyFile && url ? url.path : @"";
    self.labelKeyFilePath.placeholderString = !self.useAKeyFile ? @"" : NSLocalizedString(@"mac_click_browse_select_key_file", @"Click Browse to Select a Key File");
    
    self.labelKeyFilePath.hidden = self.labelKeyFilePath.stringValue.length == 0;
    
    
    
    self.checkboxUseYubiKey.state = self.useAYubiKey ? NSControlStateValueOn : NSControlStateValueOff;
    self.popupYubiKey.enabled = self.useAYubiKey;
    
    
    
    [self validateUi];
}

- (void)bindUIBasedOnDatabaseFormat {
    if ( self.selectedDatabaseFormat == kPasswordSafe || self.selectedDatabaseFormat == kKeePass1 ) {
        self.checkboxUseAKeyFile.state = NSControlStateValueOff;
        self.checkboxUseAKeyFile.enabled = NO;
        
        self.checkboxUseAPassword.state = NSControlStateValueOn;
        self.checkboxUseAPassword.enabled = NO;
        
        self.checkboxUseYubiKey.state = NSControlStateValueOff;
        self.checkboxUseYubiKey.enabled = NO;
        
        self.acceptEmptyPassword.state = NSControlStateValueOff;
        self.acceptEmptyPassword.enabled = NO;
    }
    else {
        self.checkboxUseAPassword.state = NSControlStateValueOn;
        self.checkboxUseAPassword.enabled = YES;
        self.checkboxUseAKeyFile.state = NSControlStateValueOff;
        self.checkboxUseAKeyFile.enabled = YES;
        self.checkboxUseYubiKey.state = NSControlStateValueOff;
        

        self.acceptEmptyPassword.enabled = YES;
        [self bindAcceptEmpty];
        
        BOOL isPro = Settings.sharedInstance.isPro;
        self.checkboxUseYubiKey.enabled = isPro && self.selectedDatabaseFormat != kKeePass1;
        
        if (!isPro) {
            NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");
            [self.checkboxUseYubiKey setTitle:loc];
        }
    }
        
    switch (self.selectedDatabaseFormat) {
        case kPasswordSafe:
            [self.popupFormat selectItemAtIndex:3];
            break;
        case kKeePass4:
            [self.popupFormat selectItemAtIndex:0];
            break;
        case kKeePass:
            [self.popupFormat selectItemAtIndex:1];
            break;
        case kKeePass1:
            [self.popupFormat selectItemAtIndex:2];
            break;
        default:
            break;
    }
}

- (void)bindConcealed {
    self.textFieldNew.showsText = !self.concealed;
    
    [self.buttonRevealConceal setImage:[NSImage imageWithSystemSymbolName:self.concealed ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""]];
}

- (void)bindAcceptEmpty {
    [self.acceptEmptyPassword setState:Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSControlStateValueOn : NSControlStateValueOff];
}



- (void)onChangedFormat {

    
    [self bindUIBasedOnDatabaseFormat];
    [self bindUi];
}

- (IBAction)onChangeFormatToKDBX4:(id)sender {
    _selectedDatabaseFormat = kKeePass4;
    
    [self onChangedFormat];
}

- (IBAction)onChangeFormatToKDBX31:(id)sender {
    _selectedDatabaseFormat = kKeePass;
    
    [self onChangedFormat];

}

- (IBAction)onChangeFormatToKDB:(id)sender {
    _selectedDatabaseFormat = kKeePass1;
    
    [self onChangedFormat];

}

- (IBAction)onChangeFormatToPSafe:(id)sender {
    _selectedDatabaseFormat = kPasswordSafe;
    
    [self onChangedFormat];
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
    if ( obj.object == self.textFieldNickName ) {
        [self validateUi];
    }
    else {
        [self bindPasswordStrength];
        
        [self validateUi];
    }
}

- (IBAction)onCreateNew:(id)sender {
    __weak CreateDatabaseOrSetCredentialsWizard* weakSelf = self;
    
    KeyFile* keyFile = [KeyFileManagement generateNewV2];
    
    [SwiftUIViewFactory showKeyFileGeneratorScreenWithKeyFile:keyFile
                                                      onPrint:^{
        [weakSelf onPrintKeyFileRecoverySheet:keyFile];
    } onSave:^BOOL{
        NSURL* url = [weakSelf onSaveKeyFile:keyFile];
    
        if ( url ) {
            [self onSelectedKeyFileUrl:url];
        }
        
        return url != nil;
    }];
}

- (NSURL*)onSaveKeyFile:(KeyFile*)keyFile {
    NSSavePanel* panel = NSSavePanel.savePanel;
    panel.nameFieldStringValue = @"keyfile.keyx";
    
    
    [panel setTitle:NSLocalizedString(@"new_key_file_save_key_file", @"Save Key File")];
    
    NSInteger result = [panel runModal];
    if ( result == NSModalResponseOK ) {
        if ( panel.URL ) {
            NSData* data = [keyFile.xml dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
            if ( !data ) {
                [MacAlerts error:[Utils createNSError:@"Could not get xml data!" errorCode:123]
                          window:self.window];
                
                return nil;
            }

            NSError* error;
            if ( ![data writeToURL:panel.URL options:kNilOptions error:&error] ) {
                [MacAlerts error:error window:self.window];
                
                return nil;
            }
            else {
                return panel.URL;
            }
        }
    }
    
    return nil;
}

- (void)onPrintKeyFileRecoverySheet:(KeyFile*)keyFile {
    [keyFile printRecoverySheet];
}

- (IBAction)onBrowse:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    if (self.selectedKeyFileBookmark) { 
        NSURL* url = [BookmarksHelper getExpressUrlFromBookmark:self.selectedKeyFileBookmark];
        openPanel.directoryURL = [url URLByDeletingLastPathComponent];
    }
                  
    openPanel.allowsMultipleSelection = NO;
    
    [openPanel beginSheetModalForWindow:self.window
                      completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            [self onSelectedKeyFileUrl:openPanel.URL];
        }
    }];
}

- (void)onSelectedKeyFileUrl:(NSURL*)url {
    NSError* error;
    NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:url readOnly:YES error:&error];
    
    if (error) {
        [MacAlerts error:error window:self.window];
    }
    else {
        self->_selectedKeyFileBookmark = bookmark;
        [self bindUi];
    }
}

- (IBAction)onUseAPassword:(id)sender {
    [self bindUi];
}

- (IBAction)onUseAKeyFile:(id)sender {
    self.useAKeyFile = self.checkboxUseAKeyFile.state == NSControlStateValueOn;
    [self bindUi];
}

- (IBAction)onUseAYubiKey:(id)sender {
    self.useAYubiKey = self.checkboxUseYubiKey.state == NSControlStateValueOn;
    
    if (self.useAYubiKey) {
        [self bindYubiKeyUI];
    }

    [self bindUi];
}

- (void)bindYubiKeyUI {
    [self.hardwareKeyMenuHelper scanForConnectedAndRefresh];
}

- (void)validateUi {
    if ( self.createMode ) {
        NSString* trimmed = trim(self.textFieldNickName.stringValue);
        
        if ( ![MacDatabasePreferences isValid:trimmed] ) {
            NSString* loc = @"Invalid Nickname";
            self.labelPasswordsMatch.stringValue = loc; 
            
            self.buttonOk.enabled = NO;
            return;
        }
        
        if ( ![MacDatabasePreferences isUnique:trimmed] ) {
            NSString* loc = NSLocalizedString(@"nickname_already_in_use", @"Nickname already in use"); 
            self.labelPasswordsMatch.stringValue = loc;
            
            self.buttonOk.enabled = NO;
            return;
        }
    }
        
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
    
    
    if ( self.createMode ) {
        NSString* trimmed = trim(self.textFieldNickName.stringValue);
        _selectedNickname = trimmed;
    }
    
    
    
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
            slog(@"Could not read key file. Error: %@", error);
            
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
    else {
        _selectedYubiKeyConfiguration = self.hardwareKeyMenuHelper.selectedConfiguration;
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
        slog(@"🔴 Could not get CKFs! [%@]", err);
        if ( error ) {
            *error = err;
        }
    }
    
    return ret;
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

@end
