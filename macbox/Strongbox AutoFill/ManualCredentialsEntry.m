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
#import "MacYubiKeyManager.h"
#import "BookmarksHelper.h"
#import "DatabasesManager.h"
#import "Alerts.h"

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
@property (weak) IBOutlet NSPopUpButton *popupYubiKey;
@property (weak) IBOutlet NSButton *buttonUnlock;
@property (weak) IBOutlet NSButton *acceptEmptyPassword;

@property YubiKeyConfiguration *selectedYubiKeyConfiguration;
@property NSString* selectedKeyFileBookmark;

@property BOOL concealed;

@property BOOL currentYubiKeySlot1IsBlocking;
@property BOOL currentYubiKeySlot2IsBlocking;
@property NSString* currentYubiKeySerial;

@property BOOL hasSetInitialFocus;

@end

@implementation ManualCredentialsEntry




- (void)viewDidLoad {
    [super viewDidLoad];

    self.textFieldPassword.delegate = self;
    [self fixStackViewSpacing];

    self.concealed = YES;
    
    self.selectedKeyFileBookmark = self.database.autoFillKeyFileBookmark;
    self.selectedYubiKeyConfiguration = self.database.yubiKeyConfiguration;

    [self bindUi];
    [self validateUI];
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
    BOOL advanced = Settings.sharedInstance.showAdvancedUnlockOptions;
    self.acceptEmptyPassword.hidden = !advanced;
    self.labelKeyFile.hidden = !advanced;
    self.popupKeyFile.hidden = !advanced;
    self.labelYubiKey.hidden = !advanced;
    self.popupYubiKey.hidden = !advanced;

    [self.checkboxShowAdvanced setState:advanced ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)fixStackViewSpacing {
    [self.masterStackView setCustomSpacing:20 afterView:self.stackViewLogo];
    [self.masterStackView setCustomSpacing:4 afterView:self.stackViewLabelPasswordAndRevealConceal];
    [self.masterStackView setCustomSpacing:16 afterView:self.textFieldPassword];
    
    [self.masterStackView setCustomSpacing:20 afterView:self.acceptEmptyPassword];
    
    [self.masterStackView setCustomSpacing:4 afterView:self.labelKeyFile];

    [self.masterStackView setCustomSpacing:16 afterView:self.popupKeyFile];
    [self.masterStackView setCustomSpacing:4 afterView:self.labelYubiKey];
    [self.masterStackView setCustomSpacing:20 afterView:self.popupYubiKey];
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
    Settings.sharedInstance.showAdvancedUnlockOptions = !Settings.sharedInstance.showAdvancedUnlockOptions;
    
    [self bindAdvanced];
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewController:self];
    self.onDone(YES, nil, nil, nil);
}

- (IBAction)onUnlock:(id)sender {
    if(self.textFieldPassword.stringValue.length == 0) {
        [Alerts twoOptionsWithCancel:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
                     informativeText:NSLocalizedString(@"casg_question_message_empty_password", @"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want.")
                   option1AndDefault:NSLocalizedString(@"casg_question_option_empty", @"Empty Password")
                             option2:NSLocalizedString(@"casg_question_option_none", @"No Password")
                              window:self.view.window
                          completion:^(NSUInteger zeroForCancel) {
            if (zeroForCancel == 1) {
                [self continueUnlockWithPassword:@""];
            }
            else if(zeroForCancel == 2) {
                [self continueUnlockWithPassword:nil];
            }
        }];
    }
    else {
        [self continueUnlockWithPassword:self.textFieldPassword.stringValue];
    }

}

- (void)continueUnlockWithPassword:(NSString*)password {
    [self dismissViewController:self];
    
    self.onDone(NO, password, self.selectedKeyFileBookmark, self.selectedYubiKeyConfiguration);
}




- (void)refreshKeyFileDropdown {
    [self.popupKeyFile.menu removeAllItems];

    

    [self.popupKeyFile.menu addItemWithTitle:NSLocalizedString(@"mac_key_file_none", @"None")
                                      action:@selector(onSelectNoneKeyFile)
                               keyEquivalent:@""];

    [self.popupKeyFile.menu addItemWithTitle:NSLocalizedString(@"mac_browse_for_key_file", @"Browse...")
                                      action:@selector(onBrowseForKeyFile)
                               keyEquivalent:@""];

    

    DatabaseMetadata *database = self.database;
    NSURL* configuredUrl;
    NSString* configuredBookmarkForKeyFile = self.isAutoFillOpen ? database.autoFillKeyFileBookmark : database.keyFileBookmark;
    
    if(database && configuredBookmarkForKeyFile) {
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
            if (self.isAutoFillOpen) {
                database.autoFillKeyFileBookmark = updatedBookmark;
            }
            else {
                database.keyFileBookmark = updatedBookmark;
            }
            [DatabasesManager.sharedInstance update:database];
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

    if (configuredUrl) {
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
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
            NSLog(@"Open Key File: %@", openPanel.URL);

            NSError* error;
            NSString* bookmark = [BookmarksHelper getBookmarkFromUrl:openPanel.URL readOnly:YES error:&error];

            if(!bookmark) {
                [Alerts error:error window:self.view.window];
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
    self.selectedKeyFileBookmark = self.isAutoFillOpen ? self.database.autoFillKeyFileBookmark : self.database.keyFileBookmark;
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
      
- (void)bindYubiKey {
    self.currentYubiKeySerial = nil;
    self.currentYubiKeySlot1IsBlocking = NO;
    self.currentYubiKeySlot2IsBlocking = NO;

    NSLog(@"Binding: [selectedYubiKeyConfiguration = [%@]]", self.selectedYubiKeyConfiguration);

    [self.popupYubiKey.menu removeAllItems];

    NSString* loc = NSLocalizedString(@"generic_refreshing_ellipsis", @"Refreshing...");
    [self.popupYubiKey.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];
    self.popupYubiKey.enabled = NO;

    [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yk) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKey:yk];
        });}];
}

- (void)onGotAvailableYubiKey:(YubiKeyData*)yk {
    self.currentYubiKeySerial = yk.serial;
    self.currentYubiKeySlot1IsBlocking = yk.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking;
    self.currentYubiKeySlot2IsBlocking = yk.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking;

    [self.popupYubiKey.menu removeAllItems];

    if (!Settings.sharedInstance.fullVersion && !Settings.sharedInstance.freeTrial) {
        NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");

        [self.popupYubiKey.menu addItemWithTitle:loc
                                          action:nil
                                   keyEquivalent:@""];

        [self.popupYubiKey selectItemAtIndex:0];
        return;
    }

    

    NSString* loc = NSLocalizedString(@"generic_none", @"None");
    NSMenuItem* noneMenuItem = [self.popupYubiKey.menu addItemWithTitle:loc
                                                                 action:@selector(onSelectNoYubiKey)
                                                          keyEquivalent:@""];

    NSMenuItem* slot1MenuItem;
    NSMenuItem* slot2MenuItem;

    

    BOOL availableSlots = NO;
    NSString* loc1 = NSLocalizedString(@"mac_yubikey_slot_n_touch_required_fmt", @"Yubikey Slot %ld (Touch Required)");
    NSString* loc2 = NSLocalizedString(@"mac_yubikey_slot_n_fmt", @"Yubikey Slot %ld");

    if ( [self yubiKeyCrIsSupported:yk.slot1CrStatus] ) {
        NSString* loc = self.currentYubiKeySlot1IsBlocking ? loc1 : loc2;
        NSString* locFmt = [NSString stringWithFormat:loc, 1];
        slot1MenuItem = [self.popupYubiKey.menu addItemWithTitle:locFmt
                                                          action:@selector(onSelectYubiKeySlot1)
                                                   keyEquivalent:@""];
        availableSlots = YES;
    }

    if ( [self yubiKeyCrIsSupported:yk.slot2CrStatus] ) {
        NSString* loc = self.currentYubiKeySlot2IsBlocking ? loc1 : loc2;
        NSString* locFmt = [NSString stringWithFormat:loc, 2];

        slot2MenuItem = [self.popupYubiKey.menu addItemWithTitle:locFmt
                                                          action:@selector(onSelectYubiKeySlot2)
                                                   keyEquivalent:@""];
        availableSlots = YES;
    }

    BOOL selectedItem = NO;

    if (availableSlots) {
        if (self.selectedYubiKeyConfiguration && ([self.selectedYubiKeyConfiguration.deviceSerial isEqualToString:yk.serial])) {
            

            YubiKeySlotCrStatus slotStatus = self.selectedYubiKeyConfiguration.slot == 1 ? yk.slot1CrStatus : yk.slot2CrStatus;

            if ([self yubiKeyCrIsSupported:slotStatus]) {
                
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
    }

    if (!selectedItem) { 
        [self.popupYubiKey selectItem:noneMenuItem];
        self.selectedYubiKeyConfiguration = nil;
    }

    self.popupYubiKey.enabled = YES;
}

- (BOOL)yubiKeyCrIsSupported:(YubiKeySlotCrStatus)status {
    return status == YubiKeySlotCrStatusSupportedBlocking || status == YubiKeySlotCrStatusSupportedNonBlocking;
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

@end
