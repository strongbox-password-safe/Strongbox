//
//  PreferencesWindowController.m
//  Strongbox
//
//  Created by Mark on 03/04/2018.
//  Copyright © 2018 Mark McGuill. All rights reserved.
//

#import "PreferencesWindowController.h"
#import "Settings.h"
#import "PasswordMaker.h"
#import "Alerts.h"
#import "AppDelegate.h"
#import "Utils.h"
#import "NSCheckboxTableCellView.h"

@interface PreferencesWindowController () <NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate>

@property (weak) IBOutlet NSButton *checkboxShowTotpCodes;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInBrowse;
@property (weak) IBOutlet NSButton *checkboxShowRecycleBinInSearch;
@property (weak) IBOutlet NSButton *checkboxFloatDetailsWindowsOnTop;
@property (weak) IBOutlet NSButton *checkboxAlternatingGrid;
@property (weak) IBOutlet NSButton *checkboxHorizontalGridLines;
@property (weak) IBOutlet NSButton *checkboxVerticalGridLines;
@property (weak) IBOutlet NSButton *checkboxShowAutoCompleteSuggestions;


@property (weak) IBOutlet NSButton *checkboxTitleIsEditable;
@property (weak) IBOutlet NSButton *checkboxOtherFieldsAreEditable;
@property (weak) IBOutlet NSButton *checkboxDereferenceQuickView;
@property (weak) IBOutlet NSButton *checkboxDereferenceOutlineView;
@property (weak) IBOutlet NSButton *checkboxDereferenceSearch;
@property (weak) IBOutlet NSButton *checkboxConcealEmptyProtected;
@property (weak) IBOutlet NSButton *showCustomFieldsInQuickView;
@property (weak) IBOutlet NSTableView *tableViewWordLists;

@property (weak) IBOutlet NSButton *radioBasic;
@property (weak) IBOutlet NSButton *radioXkcd;
@property (weak) IBOutlet NSButton *checkboxUseLower;
@property (weak) IBOutlet NSButton *checkboxUseUpper;
@property (weak) IBOutlet NSButton *checkboxUseDigits;
@property (weak) IBOutlet NSButton *checkboxUseSymbols;
@property (weak) IBOutlet NSButton *checkboxUseEasy;
@property (weak) IBOutlet NSButton *checkboxNonAmbiguous;
@property (weak) IBOutlet NSButton *checkboxPickFromEveryGroup;
@property (weak) IBOutlet NSSlider *sliderPasswordLength;
@property (weak) IBOutlet NSTextField *labelPasswordLength;

@property (weak) IBOutlet NSTextField *labelXkcdWordCount;
@property (weak) IBOutlet NSStepper *stepperXkcdWordCount;
@property (weak) IBOutlet NSTextField *textFieldWordSeparator;
@property (weak) IBOutlet NSPopUpButton *popupCasing;
@property (weak) IBOutlet NSPopUpButton *popupHackerify;
@property (weak) IBOutlet NSPopUpButton *popupAddSalt;

@property (weak) IBOutlet NSTextField *labelSamplePassword;
@property (weak) IBOutlet NSTabView *tabView;

@property (weak) IBOutlet NSTextField *labelWordcount;

@property (weak) IBOutlet NSButton *checkboxAlwaysShowPassword;
@property (weak) IBOutlet NSButton *checkboxKeePassNoSort;

@property (weak) IBOutlet NSSegmentedControl *segmentTitle;
@property (weak) IBOutlet NSTextField *labelCustomTitle;
@property (weak) IBOutlet NSSegmentedControl *segmentUsername;
@property (weak) IBOutlet NSTextField *labelCustomUsername;
@property (weak) IBOutlet NSSegmentedControl *segmentEmail;
@property (weak) IBOutlet NSTextField *labelCustomEmail;
@property (weak) IBOutlet NSSegmentedControl *segmentPassword;
@property (weak) IBOutlet NSTextField *labelCustomPassword;
@property (weak) IBOutlet NSSegmentedControl *segmentUrl;
@property (weak) IBOutlet NSTextField *labelCustomUrl;
@property (weak) IBOutlet NSSegmentedControl *segmentNotes;
@property (weak) IBOutlet NSTextField *labelCustomNotes;

@property NSArray<NSString*> *sortedWordListKeys;

@property (weak) IBOutlet NSButton *checkboxShowPopupNotifications;
@property (weak) IBOutlet NSButton *checkboxDetectForeignChanges;
@property (weak) IBOutlet NSButton *checkboxReloadForeignChanges;
@property (weak) IBOutlet NSButton *checkboxAutoSave;
@property (weak) IBOutlet NSButton *checkboxAutoDownloadFavIcon;
@property (weak) IBOutlet NSButton *allowAppleWatchUnlock;

@property (weak) IBOutlet NSButton *switchAutoClearClipboard;
@property (weak) IBOutlet NSTextField *textFieldClearClipboard;
@property (weak) IBOutlet NSStepper *stepperClearClipboard;

@property (weak) IBOutlet NSButton *switchAutoLockAfter;
@property (weak) IBOutlet NSTextField *textFieldLockDatabase;
@property (weak) IBOutlet NSStepper *stepperLockDatabase;

@property (weak) IBOutlet NSButton *switchShowInMenuBar;
@property (weak) IBOutlet NSButton *switchAutoPromptTouchID;

@property (weak) IBOutlet NSButton *useDuckDuckGo;
@property (weak) IBOutlet NSButton *checkDomainOnly;
@property (weak) IBOutlet NSButton *useGoogle;
@property (weak) IBOutlet NSButton *scanHtml;
@property (weak) IBOutlet NSButton *ignoreSsl;
@property (weak) IBOutlet NSButton *scanCommonFiles;

@end

@implementation PreferencesWindowController

+ (instancetype)sharedInstance {
    static PreferencesWindowController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PreferencesWindowController alloc] initWithWindowNibName:@"PreferencesWindowController"];
    });
    
    return sharedInstance;
}

- (void)cancel:(id)sender { // Pick up escape key
    [self close];
}

- (void)show {
    [self showWindow:nil];
}

- (void)showOnTab:(NSUInteger)tab {
    [self show];
    [self.tabView selectTabViewItemAtIndex:tab];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self setupPasswordGenerationUi];
    
    [self bindPasswordUiToSettings];
    [self bindGeneralUiToSettings];
    [self bindAutoFillToSettings];
    [self bindAutoLockToSettings];
    [self bindAutoClearClipboard];
    
    [self bindFavIconDownloading];
    
    NSClickGestureRecognizer *click = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(onChangePasswordParameters:)];
    [self.labelSamplePassword addGestureRecognizer:click];
    
    [self refreshSamplePassword];
}

- (void)setupPasswordGenerationUi {
    NSDictionary* wordlists = PasswordGenerationConfig.wordLists;
    
    self.sortedWordListKeys = [wordlists.allKeys sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSString* v1 = wordlists[obj1];
        NSString* v2 = wordlists[obj2];
        return finderStringCompare(v1, v2);
    }];
    
    [self.tableViewWordLists registerNib:[[NSNib alloc] initWithNibNamed:@"CheckboxCell" bundle:nil] forIdentifier:@"CheckboxCell"];
    
    self.tableViewWordLists.delegate = self;
    self.tableViewWordLists.dataSource = self;
    
    self.textFieldWordSeparator.delegate = self;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSTextField *textField = [notification object];
    [self onChangePasswordParameters:textField];
}

- (void)bindGeneralUiToSettings {
    self.checkboxAutoSave.state = Settings.sharedInstance.autoSave ? NSOnState : NSOffState;
    self.checkboxAlwaysShowPassword.state = Settings.sharedInstance.alwaysShowPassword ? NSOnState : NSOffState;
    self.checkboxKeePassNoSort.state = Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView ? NSOnState : NSOffState;
    self.checkboxShowTotpCodes.state = Settings.sharedInstance.doNotShowTotp ? NSOffState : NSOnState;
    self.checkboxShowRecycleBinInBrowse.state = Settings.sharedInstance.doNotShowRecycleBinInBrowse ? NSOffState : NSOnState;
    self.checkboxShowRecycleBinInSearch.state = Settings.sharedInstance.showRecycleBinInSearchResults ? NSOnState : NSOffState;
    self.checkboxFloatDetailsWindowsOnTop.state = Settings.sharedInstance.doNotFloatDetailsWindowOnTop ? NSOffState : NSOnState;
    self.checkboxAlternatingGrid.state = Settings.sharedInstance.noAlternatingRows ? NSOffState : NSOnState;
    self.checkboxHorizontalGridLines.state = Settings.sharedInstance.showHorizontalGrid ? NSOnState : NSOffState;
    self.checkboxVerticalGridLines.state = Settings.sharedInstance.showVerticalGrid ? NSOnState : NSOffState;
    self.checkboxShowAutoCompleteSuggestions.state = Settings.sharedInstance.doNotShowAutoCompleteSuggestions ? NSOffState : NSOnState;
    self.checkboxShowPopupNotifications.state = Settings.sharedInstance.doNotShowChangeNotifications ? NSOffState : NSOnState;
    self.checkboxTitleIsEditable.state = Settings.sharedInstance.outlineViewTitleIsReadonly ? NSOffState : NSOnState;
    self.checkboxOtherFieldsAreEditable.state = Settings.sharedInstance.outlineViewEditableFieldsAreReadonly ? NSOffState : NSOnState;
    self.checkboxDereferenceQuickView.state = Settings.sharedInstance.dereferenceInQuickView ? NSOnState : NSOffState;
    self.checkboxDereferenceOutlineView.state = Settings.sharedInstance.dereferenceInOutlineView ? NSOnState : NSOffState;
    self.checkboxDereferenceSearch.state = Settings.sharedInstance.dereferenceDuringSearch ? NSOnState : NSOffState;
    self.checkboxDetectForeignChanges.state = Settings.sharedInstance.detectForeignChanges ? NSOnState : NSOffState;
    self.checkboxReloadForeignChanges.state = Settings.sharedInstance.autoReloadAfterForeignChanges ? NSOnState : NSOffState;
    self.checkboxAutoDownloadFavIcon.state = Settings.sharedInstance.expressDownloadFavIconOnNewOrUrlChanged ? NSOnState : NSOffState;

    self.checkboxConcealEmptyProtected.state = Settings.sharedInstance.concealEmptyProtectedFields ? NSOnState : NSOffState;
    self.showCustomFieldsInQuickView.state = Settings.sharedInstance.showCustomFieldsOnQuickViewPanel ? NSOnState : NSOffState;
    
    self.switchShowInMenuBar.state = Settings.sharedInstance.showSystemTrayIcon ? NSOnState : NSOffState;
    self.switchAutoPromptTouchID.state = Settings.sharedInstance.autoPromptForTouchIdOnActivate ? NSOnState : NSOffState;

    self.allowAppleWatchUnlock.state = Settings.sharedInstance.allowWatchUnlock ? NSOnState : NSOffState;
    
    if(!Settings.sharedInstance.fullVersion) {
        self.checkboxAutoDownloadFavIcon.title = NSLocalizedString(@"mac_auto_download_favicon_pro_only", @"Automatically download FavIcon on URL Change (PRO Only)");
    }
}

- (IBAction)onGeneralSettingsChange:(id)sender {
    Settings.sharedInstance.alwaysShowPassword = self.checkboxAlwaysShowPassword.state == NSOnState;
    Settings.sharedInstance.autoSave = self.checkboxAutoSave.state == NSOnState;
    Settings.sharedInstance.uiDoNotSortKeePassNodesInBrowseView = self.checkboxKeePassNoSort.state == NSOnState;
    Settings.sharedInstance.doNotShowTotp = self.checkboxShowTotpCodes.state == NSOffState;
    Settings.sharedInstance.doNotShowRecycleBinInBrowse = self.checkboxShowRecycleBinInBrowse.state == NSOffState;
    Settings.sharedInstance.showRecycleBinInSearchResults = self.checkboxShowRecycleBinInSearch.state == NSOnState;
    Settings.sharedInstance.doNotFloatDetailsWindowOnTop = self.checkboxFloatDetailsWindowsOnTop.state == NSOffState;
    Settings.sharedInstance.noAlternatingRows = self.checkboxAlternatingGrid.state == NSOffState;
    Settings.sharedInstance.showHorizontalGrid = self.checkboxHorizontalGridLines.state == NSOnState;
    Settings.sharedInstance.showVerticalGrid = self.checkboxVerticalGridLines.state == NSOnState;
    Settings.sharedInstance.doNotShowAutoCompleteSuggestions = self.checkboxShowAutoCompleteSuggestions.state == NSOffState;
    Settings.sharedInstance.doNotShowChangeNotifications = self.checkboxShowPopupNotifications.state == NSOffState;
    Settings.sharedInstance.outlineViewTitleIsReadonly = self.checkboxTitleIsEditable.state == NSOffState;
    Settings.sharedInstance.outlineViewEditableFieldsAreReadonly = self.checkboxOtherFieldsAreEditable.state == NSOffState;
    Settings.sharedInstance.dereferenceInQuickView = self.checkboxDereferenceQuickView.state == NSOnState;
    Settings.sharedInstance.dereferenceInOutlineView = self.checkboxDereferenceOutlineView.state == NSOnState;
    Settings.sharedInstance.dereferenceDuringSearch = self.checkboxDereferenceSearch.state == NSOnState;
    Settings.sharedInstance.detectForeignChanges = self.checkboxDetectForeignChanges.state == NSOnState;
    Settings.sharedInstance.autoReloadAfterForeignChanges = Settings.sharedInstance.detectForeignChanges && (self.checkboxReloadForeignChanges.state == NSOnState);
    Settings.sharedInstance.expressDownloadFavIconOnNewOrUrlChanged = self.checkboxAutoDownloadFavIcon.state == NSOnState;
    
    Settings.sharedInstance.concealEmptyProtectedFields = self.checkboxConcealEmptyProtected.state == NSOnState;
    Settings.sharedInstance.showCustomFieldsOnQuickViewPanel = self.showCustomFieldsInQuickView.state == NSOnState;
    
    Settings.sharedInstance.showSystemTrayIcon =
        self.switchShowInMenuBar.state == NSOnState;
    
    Settings.sharedInstance.autoPromptForTouchIdOnActivate = self.switchAutoPromptTouchID.state == NSOnState;
    
    Settings.sharedInstance.allowWatchUnlock = self.allowAppleWatchUnlock.state ==  NSOnState;
    
    [self bindGeneralUiToSettings];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

-(void)bindAutoFillToSettings {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;

    int index = [self autoFillModeToSegmentIndex:settings.titleAutoFillMode];
    self.segmentTitle.selectedSegment = index;
    self.labelCustomTitle.stringValue = settings.titleAutoFillMode == kCustom ? settings.titleCustomAutoFill : @"";
    
    // Username Options: None / Most Used / Custom
    
    // KLUDGE: This is a bit hacky but saves some RSI typing... :/
    index = [self autoFillModeToSegmentIndex:settings.usernameAutoFillMode];
    self.segmentUsername.selectedSegment = index;
    self.labelCustomUsername.stringValue = settings.usernameAutoFillMode == kCustom ? settings.usernameCustomAutoFill : @"";
    
    // Password Options: None / Most Used / Generated / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.passwordAutoFillMode];
    self.segmentPassword.selectedSegment = index;
    self.labelCustomPassword.stringValue = settings.passwordAutoFillMode == kCustom ? settings.passwordCustomAutoFill : @"";
    
    // Email Options: None / Most Used / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.emailAutoFillMode];
    self.segmentEmail.selectedSegment = index;
    self.labelCustomEmail.stringValue = settings.emailAutoFillMode == kCustom ? settings.emailCustomAutoFill : @"";
    
    // URL Options: None / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.urlAutoFillMode];
    self.segmentUrl.selectedSegment = index;
    self.labelCustomUrl.stringValue = settings.urlAutoFillMode == kCustom ? settings.urlCustomAutoFill : @"";
    
    // Notes Options: None / Custom
    
    index = [self autoFillModeToSegmentIndex:settings.notesAutoFillMode];
    self.segmentNotes.selectedSegment = index;
    self.labelCustomNotes.stringValue = settings.notesAutoFillMode == kCustom ? settings.notesCustomAutoFill : @"";
}

- (void)bindFavIconDownloading {
    FavIconDownloadOptions* options = Settings.sharedInstance.favIconDownloadOptions;

    self.useDuckDuckGo.state = options.duckDuckGo ? NSOnState : NSOffState;
    self.checkDomainOnly.state = options.domainOnly ? NSOnState : NSOffState;
    self.useGoogle.state = options.google ? NSOnState : NSOffState;
    self.scanHtml.state = options.scanHtml ? NSOnState : NSOffState;
    self.ignoreSsl.state = options.ignoreInvalidSSLCerts ? NSOnState : NSOffState;
    self.scanCommonFiles.state = options.checkCommonFavIconFiles ? NSOnState : NSOffState;
}

- (IBAction)onChangeFavIconSettings:(id)sender {
    FavIconDownloadOptions* options = Settings.sharedInstance.favIconDownloadOptions;

    options.duckDuckGo = self.useDuckDuckGo.state == NSOnState;
    options.domainOnly = self.checkDomainOnly.state == NSOnState;
    options.google = self.useGoogle.state == NSOnState;
    options.scanHtml = self.scanHtml.state == NSOnState;
    options.ignoreInvalidSSLCerts = self.ignoreSsl.state == NSOnState;
    options.checkCommonFavIconFiles = self.scanCommonFiles.state == NSOnState;

    if(options.isValid) {
        Settings.sharedInstance.favIconDownloadOptions = options;
    }
    
    [self bindFavIconDownloading];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Password Generation

- (void)bindPasswordUiToSettings {
    PasswordGenerationConfig *params = Settings.sharedInstance.passwordGenerationConfig;

    self.radioBasic.state = params.algorithm == kPasswordGenerationAlgorithmBasic ? NSOnState : NSOffState;
    self.radioXkcd.state = params.algorithm == kPasswordGenerationAlgorithmDiceware ? NSOnState : NSOffState;

    // Basic - Enabled
    self.checkboxUseLower.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxUseUpper.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxUseDigits.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxUseSymbols.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxUseEasy.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxNonAmbiguous.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.checkboxPickFromEveryGroup.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.sliderPasswordLength.enabled = params.algorithm == kPasswordGenerationAlgorithmBasic;
    self.labelPasswordLength.textColor = params.algorithm == kBasic ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    
    // Basic - Values
    
    self.checkboxUseLower.state = [params.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolLower)] ? NSOnState : NSOffState;
    self.checkboxUseUpper.state = [params.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolUpper)] ? NSOnState : NSOffState;
    self.checkboxUseDigits.state = [params.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolNumeric)] ? NSOnState : NSOffState;
    self.checkboxUseSymbols.state = [params.useCharacterGroups containsObject:@(kPasswordGenerationCharacterPoolSymbols)] ? NSOnState : NSOffState;
    self.checkboxUseEasy.state = params.easyReadCharactersOnly ? NSOnState : NSOffState;

    self.checkboxNonAmbiguous.state = params.nonAmbiguousOnly ? NSOnState : NSOffState;
    self.checkboxPickFromEveryGroup.state = params.pickFromEveryGroup ? NSOnState : NSOffState;
    self.sliderPasswordLength.integerValue = params.basicLength;
    self.labelPasswordLength.stringValue = @(params.basicLength).stringValue;

    // Diceware - Enabled
    
    self.labelXkcdWordCount.enabled = params.algorithm == kXkcd;
    self.labelWordcount.textColor = params.algorithm == kXkcd ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
    self.stepperXkcdWordCount.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    self.textFieldWordSeparator.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    self.popupCasing.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    self.popupHackerify.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    self.popupAddSalt.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    
    // Diceware - Values
    
    [self.tableViewWordLists reloadData];
    self.labelXkcdWordCount.stringValue = @(params.wordCount).stringValue;
    self.stepperXkcdWordCount.integerValue = params.wordCount;
    
    self.textFieldWordSeparator.stringValue = params.wordSeparator ? params.wordSeparator : @"";
    
    [self.popupCasing selectItem:self.popupCasing.menu.itemArray[params.wordCasing]];
    [self.popupHackerify selectItem:self.popupHackerify.menu.itemArray[params.hackerify]];
    [self.popupAddSalt selectItem:self.popupAddSalt.menu.itemArray[params.saltConfig]];
}

- (IBAction)onChangePasswordParameters:(id)sender {
    PasswordGenerationConfig *params = Settings.sharedInstance.passwordGenerationConfig;

    params.algorithm = self.radioBasic.state == NSOnState ? kPasswordGenerationAlgorithmBasic : kPasswordGenerationAlgorithmDiceware;

    // Lower
    
    NSMutableArray<NSNumber*> *newGroups = params.useCharacterGroups.mutableCopy;
    if(self.checkboxUseLower.state == NSOnState) {
        [newGroups addObject:@(kPasswordGenerationCharacterPoolLower)];
    }
    else {
        [newGroups removeObject:@(kPasswordGenerationCharacterPoolLower)];
    }

    // Upper
    
    if(self.checkboxUseUpper.state == NSOnState) {
        [newGroups addObject:@(kPasswordGenerationCharacterPoolUpper)];
    }
    else {
        [newGroups removeObject:@(kPasswordGenerationCharacterPoolUpper)];
    }

    // Numeric
    
    if(self.checkboxUseDigits.state == NSOnState) {
        [newGroups addObject:@(kPasswordGenerationCharacterPoolNumeric)];
    }
    else {
        [newGroups removeObject:@(kPasswordGenerationCharacterPoolNumeric)];
    }

    // Symbols
    
    if(self.checkboxUseSymbols.state == NSOnState) {
        [newGroups addObject:@(kPasswordGenerationCharacterPoolSymbols)];
    }
    else {
        [newGroups removeObject:@(kPasswordGenerationCharacterPoolSymbols)];
    }
    params.useCharacterGroups = newGroups;

    params.easyReadCharactersOnly = self.checkboxUseEasy.state == NSOnState;
    params.nonAmbiguousOnly = self.checkboxNonAmbiguous.state == NSOnState;
    params.pickFromEveryGroup = self.checkboxPickFromEveryGroup.state == NSOnState;
    params.basicLength = self.sliderPasswordLength.integerValue;

    // Diceware
    
    params.wordCount = (int)self.stepperXkcdWordCount.integerValue;
    params.wordSeparator = self.textFieldWordSeparator.stringValue;
    
    params.wordCasing = [self.popupCasing.menu.itemArray indexOfObject:self.popupCasing.selectedItem];
    params.hackerify = [self.popupHackerify.menu.itemArray indexOfObject:self.popupHackerify.selectedItem];
    params.saltConfig = [self.popupAddSalt.menu.itemArray indexOfObject:self.popupAddSalt.selectedItem];

    // Save
    
    Settings.sharedInstance.passwordGenerationConfig = params;
    
    [self bindPasswordUiToSettings];
    [self refreshSamplePassword];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.sortedWordListKeys.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSCheckboxTableCellView *result = [tableView makeViewWithIdentifier:@"CheckboxCell" owner:self];
    
    PasswordGenerationConfig *params = Settings.sharedInstance.passwordGenerationConfig;
    NSString* wordListKey = self.sortedWordListKeys[row];
    
    result.checkbox.state = [params.wordLists containsObject:wordListKey];
    [result.checkbox setTitle:PasswordGenerationConfig.wordLists[wordListKey]];
    
    result.onClicked = ^(BOOL checked) {
        NSLog(@"%@ - %d", wordListKey, checked);
        NSMutableArray *set = [Settings.sharedInstance.passwordGenerationConfig.wordLists mutableCopy];
        if(checked) {
            [set addObject:wordListKey];
        }
        else {
            [set removeObject:wordListKey];
        }
        
        PasswordGenerationConfig* config = Settings.sharedInstance.passwordGenerationConfig;
        config.wordLists = set;
        [Settings.sharedInstance setPasswordGenerationConfig:config];
        
        [self bindPasswordUiToSettings];
        [self refreshSamplePassword];
    };
    
    result.checkbox.enabled = params.algorithm == kPasswordGenerationAlgorithmDiceware;
    
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)onTitleSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;

    long selected = self.segmentTitle.selectedSegment;
    settings.titleAutoFillMode = selected == 0 ? kDefault : selected == 1 ? kSmartUrlFill : kCustom;
    
    if(settings.titleAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_title_default", @"Please enter your custom Title auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.titleCustomAutoFill allowEmpty:NO];

        if(response) {
            settings.titleCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onUsernameSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentUsername.selectedSegment;
    settings.usernameAutoFillMode = selected == 0 ? kNone : selected == 1 ? kMostUsed : kCustom;
    
    if(settings.usernameAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_username_default", @"Please enter your custom Username auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.usernameCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.usernameCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onEmailSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentEmail.selectedSegment;
    settings.emailAutoFillMode = selected == 0 ? kNone : selected == 1 ? kMostUsed : kCustom;
    
    if(settings.emailAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_email_default", @"Please enter your custom Email auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.emailCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.emailCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onPasswordSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentPassword.selectedSegment;
    settings.passwordAutoFillMode = selected == 0 ? kNone : selected == 1 ? kGenerated : kCustom;
    
    if(settings.passwordAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_password_default", @"Please enter your custom Password auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.passwordCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.passwordCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onUrlSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentUrl.selectedSegment;
    settings.urlAutoFillMode = selected == 0 ? kNone : selected == 1 ? kSmartUrlFill : kCustom;
    
    if(settings.urlAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_url_default", @"Please enter your custom URL auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.urlCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.urlCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

- (IBAction)onNotesSegment:(id)sender {
    AutoFillNewRecordSettings* settings = Settings.sharedInstance.autoFillNewRecordSettings;
    
    long selected = self.segmentNotes.selectedSegment;
    settings.notesAutoFillMode = selected == 0 ? kNone : selected == 1 ? kClipboard : kCustom;
    
    if(settings.notesAutoFillMode == kCustom) {
        NSString* loc = NSLocalizedString(@"mac_enter_custom_notes_default", @"Please enter your custom Notes auto fill");
        NSString* response = [[Alerts alloc] input:loc defaultValue:settings.notesCustomAutoFill allowEmpty:NO];
        
        if(response) {
            settings.notesCustomAutoFill = response;
        }
    }
    
    Settings.sharedInstance.autoFillNewRecordSettings = settings;
    [self bindAutoFillToSettings];
}

-(void)refreshSamplePassword {
    NSString* sample = [PasswordMaker.sharedInstance generateForConfig:Settings.sharedInstance.passwordGenerationConfig];
    self.labelSamplePassword.stringValue = sample ? sample : @"<Could not Generate>";
}

- (int)autoFillModeToSegmentIndex:(AutoFillMode)mode {
    // KLUDGE: This is a bit hacky but saves some RSI typing... :/
    
    switch (mode) {
        case kNone:
        case kDefault:
            return 0;
            break;
        case kMostUsed:
        case kSmartUrlFill:
        case kClipboard:
        case kGenerated:
            return 1;
            break;
        case kCustom:
            return 2;
            break;
        default:
            NSLog(@"Ruh ROh... ");
            break;
    }
}

// Auto Lock DB

-(void) bindAutoLockToSettings {
    NSInteger alt = Settings.sharedInstance.autoLockTimeoutSeconds;
    
    self.switchAutoLockAfter.state = alt != 0 ? NSOnState : NSOffState;
    self.textFieldLockDatabase.enabled = alt != 0;
    self.stepperLockDatabase.enabled = alt != 0;
    self.stepperLockDatabase.integerValue = alt;
    self.textFieldLockDatabase.stringValue =  self.stepperLockDatabase.stringValue;
}

- (IBAction)onAutolockChange:(id)sender {
    NSLog(@"onAutolockChange: [%d]", self.switchAutoLockAfter.state == NSOnState);
    
    Settings.sharedInstance.autoLockTimeoutSeconds = self.switchAutoLockAfter.state == NSOnState ? 120 : 0;
    
    [self bindAutoLockToSettings];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onStepperAutoLockDatabase:(id)sender {
    Settings.sharedInstance.autoLockTimeoutSeconds =     self.stepperLockDatabase.integerValue;
    
    [self bindAutoLockToSettings];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onTextFieldAutoLockEdited:(id)sender {
    self.stepperLockDatabase.integerValue = self.textFieldLockDatabase.integerValue;
    
    Settings.sharedInstance.autoLockTimeoutSeconds =     self.stepperLockDatabase.integerValue;
    
    [self bindAutoLockToSettings];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

// Auto Clear Clipboard

- (void)bindAutoClearClipboard {
    self.switchAutoClearClipboard.state = Settings.sharedInstance.clearClipboardEnabled ? NSOnState : NSOffState;

    self.textFieldClearClipboard.enabled = Settings.sharedInstance.clearClipboardEnabled;

    self.stepperClearClipboard.enabled = Settings.sharedInstance.clearClipboardEnabled;

    self.stepperClearClipboard.integerValue = Settings.sharedInstance.clearClipboardAfterSeconds;
    
    self.textFieldClearClipboard.stringValue =  self.stepperClearClipboard.stringValue;
}

- (IBAction)onStepperClearClipboard:(id)sender {
    Settings.sharedInstance.clearClipboardAfterSeconds =     self.stepperClearClipboard.integerValue;
    
    [self bindAutoClearClipboard];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onClearClipboardTextFieldEdited:(id)sender {
    self.stepperClearClipboard.integerValue = self.textFieldClearClipboard.integerValue;
    
    // Use the stepper to validate...
    
    Settings.sharedInstance.clearClipboardAfterSeconds =     self.stepperClearClipboard.integerValue;
    
    [self bindAutoClearClipboard];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

- (IBAction)onAutoClearClipboard:(id)sender {
    NSLog(@"onAutoClearClipboard: [%d]", self.switchAutoClearClipboard.state == NSOnState);
    
    Settings.sharedInstance.clearClipboardEnabled = self.switchAutoClearClipboard.state == NSOnState;
    
    [self bindAutoClearClipboard];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesChangedNotification object:nil];
}

@end
