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
#import "HardwareKeyMenuHelper.h"

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

@property NSString* selectedKeyFileBookmark;

@property BOOL concealed;
@property BOOL hasSetInitialFocus;

@property (readonly) MacDatabasePreferences* database;
@property (nullable) NSString* contextAwareKeyFileBookmark;

@property (weak) IBOutlet NSStackView *stackHardwareKey;
@property (weak) IBOutlet NSTextField *textFIeldHeadline;
@property (weak) IBOutlet NSTextField *textFieldSubheadline;
@property (weak) IBOutlet NSTextField *textFieldDatabaseName;

@property HardwareKeyMenuHelper* hardwareKeyMenuHelper;

@end

@implementation ManualCredentialsEntry

- (MacDatabasePreferences*)database {
    return [MacDatabasePreferences fromUuid:self.databaseUuid];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.textFieldDatabaseName.stringValue = self.database.nickName;
    
    self.textFieldPassword.delegate = self;
    [self fixStackViewSpacing];
    
    NSImageSymbolConfiguration* imageConfig = [NSImageSymbolConfiguration configurationWithTextStyle:NSFontTextStyleHeadline scale:NSImageSymbolScaleLarge];
    
    [self.buttonUnlock setImage:[NSImage imageWithSystemSymbolName:@"lock.open.fill" accessibilityDescription:nil]];
    self.buttonUnlock.symbolConfiguration = imageConfig;
    
    self.concealed = YES;
    
    self.hardwareKeyMenuHelper = [[HardwareKeyMenuHelper alloc] initWithViewController:self
                                                                          yubiKeyPopup:self.yubiKeyPopup
                                                                  currentConfiguration:self.database.yubiKeyConfiguration
                                                                            verifyMode:self.verifyCkfsMode];
    
    if ( !self.verifyCkfsMode ) {
        self.selectedKeyFileBookmark = [self contextAwareKeyFileBookmark];
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
        slog(@"✅ ManualCredentialsEntry::onDatabaseLockStatusChanged: [%@]", notification);
        
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

- (IBAction)onRefreshHardwareKey:(id)sender {
    [self bindUi];
}

- (void)bindUi {
    [self bindAdvanced];
    
    [self bindConcealed];
    
    [self bindAcceptEmpty];
    
    [self refreshKeyFileDropdown];

    [self bindYubiKey];
}

- (void)bindYubiKey {
    [self.hardwareKeyMenuHelper scanForConnectedAndRefresh];
}

- (void)bindAcceptEmpty {
    [self.acceptEmptyPassword setState:Settings.sharedInstance.allowEmptyOrNoPasswordEntry ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)bindConcealed {
    self.textFieldPassword.showsText = !self.concealed;
    
    [self.buttonRevealConceal setImage:[NSImage imageWithSystemSymbolName:self.concealed ? @"eye.fill" : @"eye.slash.fill" accessibilityDescription:@""]];
}

- (void)bindAdvanced {
    DatabaseFormat format = [self getDatabaseFormat];
    
    BOOL advanced = self.database.showAdvancedUnlockOptions && !( format == kKeePass1 || format == kPasswordSafe );
    
    self.checkboxShowAdvanced.enabled = !( format == kKeePass1 || format == kPasswordSafe );
    self.checkboxShowAdvanced.hidden = ( format == kKeePass1 || format == kPasswordSafe );
    
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
    DatabaseFormat format = [self getDatabaseFormat];

    BOOL formatAllowsEmptyOrNone =  format == kKeePass4 ||
        format == kKeePass ||
        format == kFormatUnknown ||
        (format == kKeePass1 && [self keyFileIsSet]);

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

    self.onDone(NO, self.textFieldPassword.stringValue, self.selectedKeyFileBookmark, self.hardwareKeyMenuHelper.selectedConfiguration);
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
            slog(@"getUrlFromBookmark: [%@]", error);
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
            slog(@"Open Key File: %@", openPanel.URL);

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

- (DatabaseFormat)getDatabaseFormat {
    if ( self.database.likelyFormat == kFormatUnknown ) {
        BOOL probablyPasswordSafe = [self.database.fileUrl.pathExtension caseInsensitiveCompare:@"psafe3"] == NSOrderedSame;
        
        if ( probablyPasswordSafe ) {
            return kPasswordSafe;
        }
        
        BOOL probablyKp1 = [self.database.fileUrl.pathExtension caseInsensitiveCompare:@"kdb"] == NSOrderedSame;
        if ( probablyKp1 ) {
            return kKeePass1;
        }
        
        return kKeePass; 
    }
    
    return self.database.likelyFormat;
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
