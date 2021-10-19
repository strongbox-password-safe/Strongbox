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
#import "MacYubiKeyManager.h"
#import "DatabasesManagerVC.h"
#import "BookmarksHelper.h"
#import "DatabasesManager.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import "StrongboxErrorCodes.h"
#import "KeyFileParser.h"
#import "MBProgressHUD.h"

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

    NSLog(@"LockScreenViewController::viewDidLoad: doc=[%@] - vm=[%@]", self.view.window.windowController.document, self.view.window.windowController.document);

    
    
    
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
    [self.stackViewUnlock setCustomSpacing:6 afterView:self.labelUnlockYubiKeyHeader];
    
    [self.stackViewUnlockButtons setCustomSpacing:12 afterView:self.buttonUnlockWithTouchId];
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
        if([self convenienceUnlockIsPossible]) {
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

    NSLog(@"LockScreenViewController::load - Initial Load - doc=[%@] - vm=[%@]", self.document, self.viewModel);

    
    
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
    NSLog(@"LockScreenViewController::startObservingModelChanges");
    
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
    self.labelUnlockYubiKeyHeader.hidden = !show;
    self.yubiKeyPopup.hidden = !show;
}

- (void)bindUnlockButtons {
    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlockWithPassword setEnabled:enabled];

    [self bindBiometricButtonOnLockScreen];
}

- (void)bindBiometricButtonOnLockScreen {
    DatabaseMetadata* metaData = self.databaseMetadata;
    
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;

    BOOL convenienceMethodPossible = (watchAvailable && self.databaseMetadata.isWatchUnlockEnabled) || (touchAvailable && self.databaseMetadata.isTouchIdEnabled);

    BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    NSString* convenienceTitle;
    if ( (self.databaseMetadata.isTouchIdEnabled && touchAvailable) && (self.databaseMetadata.isWatchUnlockEnabled && watchAvailable) ) {
        NSString *fmt = NSLocalizedString(@"mac_unlock_database_with_biometric_fmt", @"Unlock with %@ or Watch");
        convenienceTitle = [NSString stringWithFormat:fmt, BiometricIdHelper.sharedInstance.biometricIdName];
    }
    else if ( self.databaseMetadata.isTouchIdEnabled && touchAvailable) {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_touch_id", @"Unlock with Touch ID");
    }
    else {
        convenienceTitle = NSLocalizedString(@"mac_unlock_database_with_apple_watch", @"Unlock with Watch");
    }
    
    [self.buttonUnlockWithTouchId setTitle:convenienceTitle];
    self.buttonUnlockWithTouchId.hidden = NO;
    self.buttonUnlockWithTouchId.enabled = YES;

    if( convenienceEnabled ) {
        if( metaData.isTouchIdEnrolled ) {
            if( convenienceMethodPossible ) {
                if ( featureAvailable ) {
                    if( passwordAvailable ) {
                        [self.buttonUnlockWithTouchId setKeyEquivalent:@"\r"];
                    }
                    else {
                        self.buttonUnlockWithTouchId.enabled = NO;
                        [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_expired", @"Convenience Unlock Expired")];
                    }
                }
                else {
                    [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_pro_only", @"Biometrics/Watch Unlock (Pro Only)")];
                    self.buttonUnlockWithTouchId.enabled = NO;
                }
            }
            else {
                [self.buttonUnlockWithTouchId setTitle:NSLocalizedString(@"mac_unlock_screen_button_title_convenience_unlock_bio_unavailable", @"Biometrics/Watch Unavailable")];
                self.buttonUnlockWithTouchId.enabled = NO;
            }
        }
        else {
            self.buttonUnlockWithTouchId.hidden = YES;
        }
    }
    else {
        self.buttonUnlockWithTouchId.hidden = YES;
    }
    
    self.checkboxAutoPromptOnActivate.hidden = self.buttonUnlockWithTouchId.hidden; 
    
    self.checkboxAutoPromptOnActivate.enabled = self.buttonUnlockWithTouchId.enabled; 
    
    self.checkboxAutoPromptOnActivate.state = self.viewModel.autoPromptForConvenienceUnlockOnActivate ? NSControlStateValueOn : NSControlStateValueOff;
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

    [MacYubiKeyManager.sharedInstance getAvailableYubiKey:^(YubiKeyData * _Nonnull yk) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self onGotAvailableYubiKey:yk];
        });
    }];
}

- (void)onGotAvailableYubiKey:(YubiKeyData*)yk {
    self.currentYubiKeySerial = yk.serial;
    self.currentYubiKeySlot1IsBlocking = yk.slot1CrStatus == YubiKeySlotCrStatusSupportedBlocking;
    self.currentYubiKeySlot2IsBlocking = yk.slot2CrStatus == YubiKeySlotCrStatusSupportedBlocking;

    [self.yubiKeyPopup.menu removeAllItems];

    if (!Settings.sharedInstance.fullVersion && !Settings.sharedInstance.freeTrial) {
        NSString* loc = NSLocalizedString(@"mac_lock_screen_yubikey_popup_menu_yubico_pro_only", @"YubiKey (Pro Only)");

        [self.yubiKeyPopup.menu addItemWithTitle:loc
                                      action:nil
                               keyEquivalent:@""];

        [self.yubiKeyPopup selectItemAtIndex:0];
        return;
    }

    

    NSString* loc = NSLocalizedString(@"generic_none", @"None");
    NSMenuItem* noneMenuItem = [self.yubiKeyPopup.menu addItemWithTitle:loc
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
        slot1MenuItem = [self.yubiKeyPopup.menu addItemWithTitle:locFmt
                                                      action:@selector(onSelectYubiKeySlot1)
                                               keyEquivalent:@""];
        availableSlots = YES;
    }

    if ( [self yubiKeyCrIsSupported:yk.slot2CrStatus] ) {
        NSString* loc = self.currentYubiKeySlot2IsBlocking ? loc1 : loc2;
        NSString* locFmt = [NSString stringWithFormat:loc, 2];

        slot2MenuItem = [self.yubiKeyPopup.menu addItemWithTitle:locFmt
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
                    [self.yubiKeyPopup selectItem:slot1MenuItem];
                    selectedItem = YES;
                }
                else if (self.selectedYubiKeyConfiguration.slot == 2 && slot2MenuItem){
                    [self.yubiKeyPopup selectItem:slot2MenuItem];
                    selectedItem = YES;
                }
            }
        }
    }

    if (!selectedItem) { 
        [self.yubiKeyPopup selectItem:noneMenuItem];
        self.selectedYubiKeyConfiguration = nil;
    }

    self.yubiKeyPopup.enabled = YES;
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
    if(database && database.keyFileBookmark) {
        NSString* updatedBookmark = nil;
        NSError* error;
        configuredUrl = [BookmarksHelper getUrlFromBookmark:database.keyFileBookmark
                                                   readOnly:YES updatedBookmark:&updatedBookmark
                                                      error:&error];
            
        if(!configuredUrl) {
            NSLog(@"getUrlFromBookmark: [%@]", error);
        }
        else {
           
        }
        
        if(updatedBookmark) {
            [DatabasesManager.sharedInstance atomicUpdate:database.uuid
                                                    touch:^(DatabaseMetadata * _Nonnull metadata) {
                metadata.keyFileBookmark = updatedBookmark;
            }];
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
        
        [self.keyFilePopup.menu addItemWithTitle:configuredTitle action:@selector(onSelectPreconfiguredKeyFile) keyEquivalent:@""];
    
        if(currentlySelectedUrl) {
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
    else if(currentlySelectedUrl) {
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
    [DatabasesManagerVC show];
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

- (IBAction)onEnterMasterPassword:(id)sender {
    if(![self manualCredentialsAreValid]) {
        return;
    }
    
    NSString* password = self.textFieldMasterPassword.stringValue;
    
    if(password.length == 0) {
        [MacAlerts twoOptionsWithCancel:NSLocalizedString(@"casg_question_title_empty_password", @"Empty Password or None?")
                     informativeText:NSLocalizedString(@"casg_question_message_empty_password", @"You have left the password field empty. This can be interpreted in two ways. Select the interpretation you want.")
                   option1AndDefault:NSLocalizedString(@"casg_question_option_empty", @"Empty Password")
                             option2:NSLocalizedString(@"casg_question_option_none", @"No Password")
                              window:self.view.window
                          completion:^(NSUInteger zeroForCancel) {
            if (zeroForCancel == 1) {
                [self continueManualUnlockWithPassword:@""];
            }
            else if(zeroForCancel == 2) {
                [self continueManualUnlockWithPassword:nil];
            }
        }];
    }
    else {
        [self continueManualUnlockWithPassword:password];
    }
}

- (void)continueManualUnlockWithPassword:(NSString*_Nullable)password {
    NSError* error;
    CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:password error:&error];

    if(error) {
        [MacAlerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                error:error
               window:self.view.window];
        return;
    }

    [self unlock:ckf isBiometricOpen:NO];
}

- (IBAction)onUnlockWithTouchId:(id)sender {
    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    if( [self convenienceUnlockIsPossible] ) {
        [BiometricIdHelper.sharedInstance authorize:self.databaseMetadata completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.biometricPromptLastDismissedAt = NSDate.date;

                if(success) {
                    DatabaseMetadata* metaData = self.databaseMetadata;

                    NSError* err;
                    CompositeKeyFactors* ckf = [self getCompositeKeyFactorsWithSelectedUiFactors:metaData.conveniencePassword
                                                                                           error:&err];

                    if(err) {
                        [MacAlerts error:NSLocalizedString(@"mac_error_could_not_open_key_file", @"Could not read the key file.")
                                error:error
                               window:self.view.window];
                        return;
                    }

                    [self unlock:ckf isBiometricOpen:YES];
                }
                else {
                    NSLog(@"Error unlocking safe with Touch ID. [%@]", error);
                    
                    if(error && (error.code == LAErrorUserFallback || error.code == LAErrorUserCancel || error.code == -2412)) {
                        NSLog(@"User cancelled or selected fallback. Ignore...");
                    }
                    else {
                        [MacAlerts error:error window:self.view.window];
                    }
                }
            });
        }];
    }
    else if( !passwordAvailable ) {
        NSLog(@"Touch ID button pressed but no Touch ID Stored? Probably Expired...");
        
        NSString* loc = NSLocalizedString(@"mac_could_not_find_stored_credentials", @"Touch ID/Apple Watch Unlock is not possible because the stored credentials are unavailable. This is probably because they have expired. Please enter the password manually.");
        
        [MacAlerts info:loc window:self.view.window];
  
        [self bindUI];
    }
    else {
        NSString* loc = NSLocalizedString(@"mac_info_biometric_unlock_not_possible_right_now", @"Touch ID/Apple Watch Unlock is not possible at the moment because Biometrics/Apple Watch is not available.");
        
        [MacAlerts info:loc window:self.view.window];
    }
}

- (void)unlock:(CompositeKeyFactors*)compositeKeyFactors isBiometricOpen:(BOOL)isBiometricOpen {
    NSLog(@"LockScreenViewController::unlock ENTER");
    
    if( self.viewModel ) {
        
        
        if ( self.databaseMetadata && self.databaseMetadata.storageProvider != kMacFile && !Settings.sharedInstance.isProOrFreeTrial ) {
            [MacAlerts info:NSLocalizedString(@"mac_non_file_database_pro_message", @"This database can only be unlocked by Strongbox Pro because it is stored via SFTP or WebDAV.\n\nPlease Upgrade.")
                     window:self.view.window];
            return;
        }
        
        [self enableMasterCredentialsEntry:NO];
                
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.document revertWithUnlock:compositeKeyFactors
                             viewController:self
                                completion:^(BOOL success, NSError * _Nullable error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(success) {
                        self.textFieldMasterPassword.stringValue = @"";
                    }
                    [self onUnlocked:success error:error compositeKeyFactors:compositeKeyFactors isBiometricUnlock:isBiometricOpen];
                });
            }];
        });
    }
    else { 
        [MacAlerts info:@"Model is not set. Could not unlock. Please close and reopen your database"
              window:self.view.window];
    }
}

- (void)onUnlocked:(BOOL)success
             error:(NSError*)error
compositeKeyFactors:(CompositeKeyFactors*)compositeKeyFactors
 isBiometricUnlock:(BOOL)isBiometricUnlock {

    
    [self enableMasterCredentialsEntry:YES];
    
    if(success) {
        [self stopObservingModelChanges];
        
        DatabaseMetadata* databaseMetadata = self.databaseMetadata;
                
        BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
        BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
        BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;
        BOOL convenienceAvailable = watchAvailable || touchAvailable;
        BOOL convenienceEnabled = self.databaseMetadata.isTouchIdEnabled || self.databaseMetadata.isWatchUnlockEnabled;
        
        BOOL convenienceIsPossible = convenienceAvailable && featureAvailable;
                
        NSString* password = self.viewModel.compositeKeyFactors.password;
        if( !isBiometricUnlock && convenienceIsPossible && convenienceEnabled ) {
            
            
            
            [self.databaseMetadata resetConveniencePasswordWithCurrentConfiguration:password];
            
            [DatabasesManager.sharedInstance atomicUpdate:databaseMetadata.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
                
                
                metadata.isTouchIdEnrolled = YES;
            }];
        }
        
        [DatabasesManager.sharedInstance atomicUpdate:databaseMetadata.uuid touch:^(DatabaseMetadata * _Nonnull metadata) {
            
            
            metadata.keyFileBookmark = Settings.sharedInstance.doNotRememberKeyFile ? nil : self.selectedKeyFileBookmark;
            metadata.yubiKeyConfiguration = self.selectedYubiKeyConfiguration;
        }];
    }
    else {
        if ( error && error.code == StrongboxErrorCodes.incorrectCredentials ) {
            if(isBiometricUnlock) { 
                [self clearTouchId];
            
                [MacAlerts info:NSLocalizedString(@"open_sequence_problem_opening_title", @"Could not open database")
                informativeText:NSLocalizedString(@"open_sequence_problem_opening_convenience_incorrect_message", @"The Convenience Password or Key File were incorrect for this database. Convenience Unlock Disabled.")
                         window:self.view.window
                     completion:nil];
            }
            else {
                if (compositeKeyFactors.keyFileDigest) {
                    [MacAlerts info:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_title", @"Incorrect Credentials")
                    informativeText:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message_verify_key_file", @"The credentials were incorrect for this database. Are you sure you are using this key file?\n\nNB: A key files are not the same as your database file.")
                             window:self.view.window
                         completion:nil];
                }
                else {
                    CGFloat yOffset = self.checkboxShowAdvanced.state == NSControlStateValueOn ? -125.0f : -75.0f; 
                    [self showToastNotification:NSLocalizedString(@"open_sequence_problem_opening_incorrect_credentials_message", @"The credentials were incorrect for this database.") error:YES yOffset:yOffset];
                }
            }
        }
        else {
            NSString* loc = NSLocalizedString(@"mac_could_not_unlock_database", @"Could Not Unlock Database");
            [MacAlerts error:loc error:error window:self.view.window];
        }
        
        [self bindBiometricButtonOnLockScreen];
        
        [self setInitialFocus];
    }
}



- (void)controlTextDidChange:(id)obj {

    BOOL enabled = [self manualCredentialsAreValid];
    [self.buttonUnlockWithPassword setEnabled:enabled];
}

- (void)clearTouchId {
    NSLog(@"Clearing Touch ID data...");
    
    [DatabasesManager.sharedInstance atomicUpdate:self.databaseMetadata.uuid
                                            touch:^(DatabaseMetadata * _Nonnull metadata) {
        metadata.hasPromptedForTouchIdEnrol = NO; 
        metadata.isTouchIdEnrolled = NO;
        [metadata resetConveniencePasswordWithCurrentConfiguration:nil];
    }];

    [self bindUI];
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

        if( weAreKeyWindow && self.databaseMetadata.autoPromptForConvenienceUnlockOnActivate && [self convenienceUnlockIsPossible] ) {
            NSTimeInterval secondsBetween = [NSDate.date timeIntervalSinceDate:self.biometricPromptLastDismissedAt];
            if(self.biometricPromptLastDismissedAt != nil && secondsBetween < 1.5) {
                NSLog(@"Too many auto biometric requests too soon - ignoring...");
                return;
            }

            [self onUnlockWithTouchId:nil];
        }
    }
}

- (BOOL)convenienceUnlockIsPossible {
    DatabaseMetadata* metaData = self.databaseMetadata;
    
    BOOL featureAvailable = Settings.sharedInstance.fullVersion || Settings.sharedInstance.freeTrial;
    BOOL watchAvailable = BiometricIdHelper.sharedInstance.isWatchUnlockAvailable;
    BOOL touchAvailable = BiometricIdHelper.sharedInstance.isTouchIdUnlockAvailable;

    BOOL convenienceMethodPossible = (watchAvailable && self.databaseMetadata.isWatchUnlockEnabled) || (touchAvailable && self.databaseMetadata.isTouchIdEnabled);

    BOOL passwordAvailable = self.databaseMetadata.conveniencePassword != nil;

    BOOL ret = metaData && convenienceMethodPossible && featureAvailable && passwordAvailable;


    
    return ret;
}

- (void)enableMasterCredentialsEntry:(BOOL)enable {
    [self.textFieldMasterPassword setEnabled:enable];
    [self.buttonUnlockWithTouchId setEnabled:enable];
    [self.buttonUnlockWithPassword setEnabled:enable];
    [self.keyFilePopup setEnabled:enable];
}

- (CompositeKeyFactors*)getCompositeKeyFactorsWithSelectedUiFactors:(NSString*)password error:(NSError**)error {
    NSData* keyFileDigest = [self getSelectedKeyFileDigest:error];

    if(*error) {
        return nil;
    }
        
    if (self.selectedYubiKeyConfiguration == nil) {
        return [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest];
    }
    else {
        NSWindow* windowHint = self.view.window; 

        NSInteger slot = self.selectedYubiKeyConfiguration.slot;
        BOOL blocking = slot == 1 ? self.currentYubiKeySlot1IsBlocking : self.currentYubiKeySlot2IsBlocking;

        return [CompositeKeyFactors password:password
                              keyFileDigest:keyFileDigest
                                  yubiKeyCR:^(NSData * _Nonnull challenge, YubiKeyCRResponseBlock  _Nonnull completion) {
                [MacYubiKeyManager.sharedInstance compositeKeyFactorCr:challenge
                                                            windowHint:windowHint
                                                                  slot:slot
                                                        slotIsBlocking:blocking
                                                            completion:completion];
        }];
    }
}

- (NSData*)getSelectedKeyFileDigest:(NSError**)error {
    NSData* keyFileDigest = nil;
    if(self.selectedKeyFileBookmark) {
        NSData* data = [BookmarksHelper dataWithContentsOfBookmark:self.selectedKeyFileBookmark error:error];
                
        if(data) {
            keyFileDigest = [KeyFileParser getNonePerformantKeyFileDigest:data checkForXml:self.viewModel.format != kKeePass1];
            
        }
        else {
            if (error) {
                *error = [Utils createNSError:@"Could not read key file..."  errorCode:-1];
            }
        }
    }
    
    return keyFileDigest;
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

        NSLog(@"%hu - %d => %ld", key, event.keyCode, number);

        [self onCmdPlusNumberPressed:number];
        return;
    }

    [super keyDown:event];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    NSEvent *event = [control.window currentEvent];
    NSLog(@"%@-%@-%@", control, textView, NSStringFromSelector(commandSelector));

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
            if([self convenienceUnlockIsPossible]) {
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
    NSLog(@"Cmd+Number %lu", (unsigned long)number);

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

@end
